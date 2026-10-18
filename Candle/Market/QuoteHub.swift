import Foundation
import Observation

enum ProviderStatus: Equatable, Sendable {
    case idle
    case connecting
    case live
    case failed(String)
}

@MainActor
@Observable
final class QuoteHub {
    private(set) var quotes: [InstrumentID: Quote] = [:]
    private(set) var sparklines: [InstrumentID: [Double]] = [:]
    private(set) var statuses: [ProviderID: ProviderStatus] = [:]

    @ObservationIgnored let registry: ProviderRegistry
    @ObservationIgnored private var baseline: [InstrumentID: Instrument] = [:]
    @ObservationIgnored private var pins: [InstrumentID: Pin] = [:]
    @ObservationIgnored private var streams: [ProviderID: Stream] = [:]
    @ObservationIgnored private var loadingSparklines: Set<InstrumentID> = []
    @ObservationIgnored private var isPaused = false

    private struct Pin {
        var instrument: Instrument
        var count: Int
    }

    private struct Stream {
        var ids: Set<InstrumentID>
        var task: Task<Void, Never>
    }

    init(registry: ProviderRegistry) {
        self.registry = registry
    }

    func quote(for id: InstrumentID) -> Quote? {
        quotes[id]
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
        guard let provider = registry.provider(for: instrument.provider) else {
            throw ProviderError.notImplemented(instrument.provider)
        }
        return try await provider.history(for: instrument, range: range)
    }

    func catalog() async -> [Instrument] {
        var result: [Instrument] = []
        for provider in registry.all where provider.availability == .ready {
            result += await provider.catalog()
        }
        return result
    }

    func search(_ query: String) async -> [Instrument] {
        var result: [Instrument] = []
        for provider in registry.all where provider.availability == .ready {
            if let found = try? await provider.search(query: query) {
                result += found
            }
        }
        return result
    }

    func loadSparkline(for instrument: Instrument) async {
        guard sparklines[instrument.id] == nil, !loadingSparklines.contains(instrument.id) else { return }
        loadingSparklines.insert(instrument.id)
        defer { loadingSparklines.remove(instrument.id) }
        if let candles = try? await history(for: instrument, range: .day) {
            sparklines[instrument.id] = candles.map { $0.close.doubleValue }
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
            statuses[id] = .idle
        }

        for (id, instruments) in grouped {
            let ids = Set(instruments.map(\.id))
            if let existing = streams[id], existing.ids == ids { continue }
            streams[id]?.task.cancel()
            guard let provider = registry.provider(for: id) else {
                statuses[id] = .failed(ProviderError.notImplemented(id).localizedDescription)
                continue
            }
            streams[id] = Stream(ids: ids, task: start(provider: provider, instruments: instruments))
        }
    }

    private func start(provider: any PriceProvider, instruments: [Instrument]) -> Task<Void, Never> {
        let id = provider.id
        return Task { [weak self] in
            self?.statuses[id] = .connecting
            do {
                let snapshot = try await provider.snapshot(for: instruments)
                guard !Task.isCancelled else { return }
                self?.apply(snapshot)
                self?.statuses[id] = .live
                let stream = await provider.quotes(for: instruments)
                for await quote in stream {
                    if Task.isCancelled { break }
                    self?.apply([quote])
                }
            } catch {
                if !Task.isCancelled {
                    self?.statuses[id] = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func apply(_ batch: [Quote]) {
        for quote in batch {
            quotes[quote.instrumentID] = quote
        }
    }
}
