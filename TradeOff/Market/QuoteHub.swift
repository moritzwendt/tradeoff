import Foundation
import Observation

enum ConnectionState: Equatable, Sendable {
    case live
    case updating
    case problem
}

@MainActor
@Observable
final class QuoteHub {
    nonisolated static let problemGrace: TimeInterval = 5

    private(set) var quotes: [InstrumentID: Quote] = [:]
    private(set) var sparklines: [InstrumentID: [Double]] = [:]
    private(set) var statuses: [ProviderID: ProviderStatus] = [:]

    @ObservationIgnored let registry: ProviderRegistry
    @ObservationIgnored private var baseline: [InstrumentID: Instrument] = [:]
    @ObservationIgnored private var pins: [InstrumentID: Pin] = [:]
    @ObservationIgnored private var streams: [ProviderID: Stream] = [:]
    @ObservationIgnored private var loadingSparklines: Set<InstrumentID> = []
    @ObservationIgnored private var isPaused = false
    @ObservationIgnored private let backoff: Backoff
    @ObservationIgnored private var degradedSince: [ProviderID: Date] = [:]
    @ObservationIgnored private let sparklineStore: SparklineStore?

    private struct Pin {
        var instrument: Instrument
        var count: Int
    }

    private struct Stream {
        var ids: Set<InstrumentID>
        var task: Task<Void, Never>
    }

    init(
        registry: ProviderRegistry,
        backoff: Backoff = Backoff(base: 2, factor: 2, maximum: 30),
        sparklineStore: SparklineStore? = nil
    ) {
        self.registry = registry
        self.backoff = backoff
        self.sparklineStore = sparklineStore
        sparklines = sparklineStore?.load() ?? [:]
    }

    var degradedProviders: [ProviderID] {
        statuses
            .filter { $0.value.isDegraded }
            .map(\.key)
            .sorted { $0.rawValue < $1.rawValue }
    }

    func problems(at now: Date = Date()) -> [ProviderID] {
        degradedProviders.filter { now.timeIntervalSince(degradedSince[$0] ?? now) >= Self.problemGrace }
    }

    func connectionState(at now: Date = Date()) -> ConnectionState {
        if !problems(at: now).isEmpty { return .problem }
        let busy = statuses.values.contains { $0 == .connecting || $0.isDegraded }
        return busy ? .updating : .live
    }

    func quote(for id: InstrumentID) -> Quote? {
        quotes[id]
    }

    private func setStatus(_ status: ProviderStatus, for id: ProviderID) {
        let wasDegraded = statuses[id]?.isDegraded ?? false
        if status.isDegraded, !wasDegraded {
            degradedSince[id] = Date()
        } else if !status.isDegraded {
            degradedSince[id] = nil
        }
        statuses[id] = status
    }

    func message(for provider: ProviderID) -> String? {
        switch statuses[provider] {
        case .failed(let text): text
        case .reconnecting: "Verbindung zu \(provider.displayName) wird neu aufgebaut"
        default: nil
        }
    }

    func reconnect() {
        for stream in streams.values {
            stream.task.cancel()
        }
        streams = [:]
        for id in degradedProviders {
            setStatus(.connecting, for: id)
        }
        reconcile()
    }

    func ingest(_ quote: Quote) {
        quotes[quote.instrumentID] = quote
    }

    func refresh(_ instruments: [Instrument]) async {
        let grouped = Dictionary(grouping: instruments, by: \.provider)
        for (id, items) in grouped {
            guard let provider = registry.provider(for: id) else { continue }
            if let snapshot = try? await provider.snapshot(for: items) {
                apply(snapshot)
            }
        }
    }

    func setBaseline(_ instruments: [Instrument]) {
        baseline = Dictionary(instruments.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        reconcile()
    }

    func pin(_ instrument: Instrument) {
        var entry = pins[instrument.id] ?? Pin(instrument: instrument, count: 0)
        entry.count += 1
        pins[instrument.id] = entry
        reconcile()
    }

    func unpin(_ instrument: Instrument) {
        guard var entry = pins[instrument.id] else { return }
        entry.count -= 1
        pins[instrument.id] = entry.count > 0 ? entry : nil
        reconcile()
    }

    func pause() {
        isPaused = true
        reconcile()
    }

    func resume() {
        isPaused = false
        reconcile()
    }

    func history(for instrument: Instrument, range: ChartRange) async throws -> [Candlestick] {
        var firstError: Error?
        if let provider = registry.provider(for: instrument.provider) {
            if provider.capabilities.hasHistory {
                do {
                    return try await provider.history(for: instrument, range: range)
                } catch {
                    if error is CancellationError { throw error }
                    firstError = error
                }
            }
        } else {
            firstError = ProviderError.notImplemented(instrument.provider)
        }
        for fallback in registry.historyFallbacks(for: instrument) {
            do {
                return try await fallback.history(for: instrument, range: range)
            } catch {
                if error is CancellationError { throw error }
            }
        }
        throw firstError ?? ProviderError.historyUnavailable(instrument.id)
    }

    func catalog() async -> [Instrument] {
        var result: [Instrument] = []
        for provider in registry.all where provider.availability == .ready {
            result += await provider.catalog()
        }
        return result
    }

    func search(_ query: String) async -> [Instrument] {
        let providers = registry.all.filter { $0.availability == .ready }
        return await withTaskGroup(of: (Int, [Instrument]).self) { group in
            for (index, provider) in providers.enumerated() {
                group.addTask {
                    (index, (try? await provider.search(query: query)) ?? [])
                }
            }
            var found: [Int: [Instrument]] = [:]
            for await (index, items) in group {
                found[index] = items
            }
            return providers.indices.flatMap { found[$0] ?? [] }
        }
    }

    func loadSparkline(for instrument: Instrument) async {
        guard sparklines[instrument.id] == nil else { return }
        await fetchSparkline(for: instrument)
        sparklineStore?.save(sparklines)
    }

    func refreshSparklines(_ instruments: [Instrument], concurrency: Int = 4) async {
        var pending = instruments[...]
        await withTaskGroup(of: Void.self) { group in
            func addNext() {
                guard let next = pending.popFirst() else { return }
                group.addTask { await self.fetchSparkline(for: next) }
            }
            for _ in 0..<max(concurrency, 1) { addNext() }
            while await group.next() != nil { addNext() }
        }
        sparklineStore?.save(sparklines)
    }

    func waitForQuotes(_ instruments: [Instrument], timeout: Duration) async {
        let expected = Set(
            instruments
                .filter { registry.availability(for: $0.provider) == .ready }
                .map(\.id)
        )
        guard !expected.isEmpty else { return }
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if expected.allSatisfy({ quotes[$0] != nil }) { return }
            try? await Task.sleep(for: .milliseconds(60))
        }
    }

    private func fetchSparkline(for instrument: Instrument) async {
        guard !loadingSparklines.contains(instrument.id) else { return }
        loadingSparklines.insert(instrument.id)
        defer { loadingSparklines.remove(instrument.id) }
        if let candles = try? await history(for: instrument, range: .day), candles.count > 1 {
            sparklines[instrument.id] = SparklineStore.downsample(candles.map { $0.close.doubleValue })
        }
    }

    private var watched: [Instrument] {
        var map = baseline
        for pin in pins.values {
            map[pin.instrument.id] = pin.instrument
        }
        return Array(map.values)
    }

    private func reconcile() {
        let grouped: [ProviderID: [Instrument]] = isPaused ? [:] : Dictionary(grouping: watched, by: \.provider)

        for (id, stream) in streams where grouped[id] == nil {
            stream.task.cancel()
            streams[id] = nil
            setStatus(.idle, for: id)
        }

        for (id, instruments) in grouped {
            let ids = Set(instruments.map(\.id))
            if let existing = streams[id], existing.ids == ids { continue }
            streams[id]?.task.cancel()
            guard let provider = registry.provider(for: id) else {
                setStatus(.failed(ProviderError.notImplemented(id).localizedDescription), for: id)
                continue
            }
            streams[id] = Stream(ids: ids, task: start(provider: provider, instruments: instruments))
        }
    }

    private func start(provider: any PriceProvider, instruments: [Instrument]) -> Task<Void, Never> {
        let id = provider.id
        let backoff = backoff
        return Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                self?.setStatus(attempt == 0 ? .connecting : .reconnecting, for: id)
                do {
                    let snapshot = try await provider.snapshot(for: instruments)
                    guard !Task.isCancelled else { return }
                    self?.apply(snapshot)
                    self?.setStatus(.live, for: id)
                    attempt = 0
                    let stream = await provider.quotes(for: instruments)
                    for await event in stream {
                        if Task.isCancelled { return }
                        self?.handle(event, from: id)
                    }
                    return
                } catch {
                    if Task.isCancelled || error is CancellationError { return }
                    self?.setStatus(.failed(error.localizedDescription), for: id)
                    let wait = Self.retryDelay(for: error, attempt: attempt, backoff: backoff)
                    try? await Task.sleep(for: .seconds(wait))
                    attempt += 1
                }
            }
        }
    }

    nonisolated static func retryDelay(for error: Error, attempt: Int, backoff: Backoff) -> TimeInterval {
        let base = backoff.delay(attempt: attempt)
        if case ProviderError.rateLimited(_, let retryAfter?) = error {
            return max(base, retryAfter)
        }
        return base
    }

    private func handle(_ event: ProviderEvent, from id: ProviderID) {
        switch event {
        case .quote(let quote):
            quotes[quote.instrumentID] = quote
        case .status(let status):
            setStatus(status, for: id)
        }
    }

    private func apply(_ batch: [Quote]) {
        for quote in batch {
            quotes[quote.instrumentID] = quote
        }
    }
}
