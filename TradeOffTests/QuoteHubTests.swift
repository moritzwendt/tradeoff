import Foundation
import Testing
@testable import TradeOff

actor FakeProvider: PriceProvider {
    nonisolated let id: ProviderID
    nonisolated let capabilities = ProviderCapabilities(
        hasRealBidAsk: true,
        hasHistory: true,
        hasLiquidity: false,
        isDelayed: false,
        requiresAPIKey: false,
        supportedAssetClasses: [.crypto],
        pollInterval: nil
    )
    nonisolated var availability: ProviderAvailability { .ready }

    private var snapshotResults: [Result<[Quote], Error>]
    private let events: [ProviderEvent]
    private let searchResult: Result<[Instrument], Error>
    private(set) var snapshotCalls = 0

    init(
        id: ProviderID = .binance,
        snapshots: [Result<[Quote], Error>],
        events: [ProviderEvent] = [],
        search: Result<[Instrument], Error> = .success([])
    ) {
        self.id = id
        snapshotResults = snapshots
        self.events = events
        searchResult = search
    }

    func catalog() -> [Instrument] { [] }

    func search(query: String) async throws -> [Instrument] {
        try searchResult.get()
    }

    func snapshot(for instruments: [Instrument]) async throws -> [Quote] {
        snapshotCalls += 1
        guard !snapshotResults.isEmpty else { return [] }
        let next = snapshotResults.count > 1 ? snapshotResults.removeFirst() : snapshotResults[0]
        return try next.get()
    }

    func quotes(for instruments: [Instrument]) async -> AsyncStream<ProviderEvent> {
        let events = events
        let (stream, continuation) = AsyncStream.makeStream(of: ProviderEvent.self)
        for event in events {
            continuation.yield(event)
        }
        return stream
    }

    func history(for instrument: Instrument, range: ChartRange) async throws -> [Candlestick] {
        throw ProviderError.historyUnavailable(instrument.id)
    }
}

@MainActor
struct QuoteHubTests {
    private let instrument = TestSupport.instrument("BTC", assetClass: .crypto, provider: .binance)
    private let fast = Backoff(base: 0.01, factor: 2, maximum: 0.02)

    private func quote(_ bid: String = "99", _ ask: String = "101") -> Quote {
        TestSupport.quote(for: instrument, bid: bid, ask: ask)
    }

    private func waitUntil(_ condition: @MainActor () async -> Bool) async -> Bool {
        for _ in 0..<300 {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return await condition()
    }

    @Test func snapshotMakesProviderLive() async {
        let provider = FakeProvider(snapshots: [.success([quote()])])
        let hub = QuoteHub(registry: ProviderRegistry([provider]), backoff: fast)
        hub.setBaseline([instrument])
        #expect(await waitUntil { hub.statuses[.binance] == .live })
        #expect(hub.quote(for: instrument.id)?.bid == 99)
        #expect(hub.degradedProviders.isEmpty)
        #expect(hub.message(for: .binance) == nil)
    }

    @Test func failingSnapshotMarksProviderDegradedAndRetries() async {
        let provider = FakeProvider(snapshots: [
            .failure(ProviderError.network(.binance)),
            .failure(ProviderError.network(.binance)),
            .success([quote()])
        ])
        let hub = QuoteHub(registry: ProviderRegistry([provider]), backoff: fast)
        hub.setBaseline([instrument])
        #expect(await waitUntil { hub.degradedProviders == [.binance] })
        #expect(hub.message(for: .binance) == "Keine Verbindung zu Binance")
        #expect(await waitUntil { hub.statuses[.binance] == .live })
        #expect(hub.degradedProviders.isEmpty)
        #expect(hub.quote(for: instrument.id) != nil)
        #expect(await provider.snapshotCalls == 3)
    }

    @Test func streamEventsUpdateStatusAndQuotes() async {
        let provider = FakeProvider(
            snapshots: [.success([quote()])],
            events: [.status(.reconnecting), .quote(quote("120", "122"))]
        )
        let hub = QuoteHub(registry: ProviderRegistry([provider]), backoff: fast)
        hub.setBaseline([instrument])
        #expect(await waitUntil { hub.quote(for: instrument.id)?.bid == 120 })
        #expect(hub.statuses[.binance] == .reconnecting)
        #expect(hub.degradedProviders == [.binance])
        #expect(hub.message(for: .binance) == "Verbindung zu Binance wird neu aufgebaut")
    }

    @Test func reconnectStartsFreshSnapshots() async {
        let provider = FakeProvider(snapshots: [.success([quote()])])
        let hub = QuoteHub(registry: ProviderRegistry([provider]), backoff: fast)
        hub.setBaseline([instrument])
        #expect(await waitUntil { hub.statuses[.binance] == .live })
        hub.reconnect()
        #expect(await waitUntil { await provider.snapshotCalls >= 2 })
        #expect(await waitUntil { hub.statuses[.binance] == .live })
    }

    @Test func unsubscribingStopsTheStream() async {
        let provider = FakeProvider(snapshots: [.success([quote()])])
        let hub = QuoteHub(registry: ProviderRegistry([provider]), backoff: fast)
        hub.setBaseline([instrument])
        #expect(await waitUntil { hub.statuses[.binance] == .live })
        hub.setBaseline([])
        #expect(await waitUntil { hub.statuses[.binance] == .idle })
    }

    @Test func pausingStopsAndResumingRestartsStreams() async {
        let provider = FakeProvider(snapshots: [.success([quote()])])
        let hub = QuoteHub(registry: ProviderRegistry([provider]), backoff: fast)
        hub.setBaseline([instrument])
        #expect(await waitUntil { hub.statuses[.binance] == .live })
        hub.pause()
        #expect(hub.statuses[.binance] == .idle)
        hub.resume()
        #expect(await waitUntil { hub.statuses[.binance] == .live })
    }

    @Test func searchMergesProvidersInRegistryOrderAndToleratesFailures() async {
        let bitcoin = instrument
        let pepe = TestSupport.instrument("PEPE", assetClass: .memeCoin, provider: .dexScreener)
        let registry = ProviderRegistry([
            FakeProvider(id: .binance, snapshots: [], search: .success([bitcoin])),
            FakeProvider(id: .finnhub, snapshots: [], search: .failure(ProviderError.network(.finnhub))),
            FakeProvider(id: .dexScreener, snapshots: [], search: .success([pepe]))
        ])
        let hub = QuoteHub(registry: registry, backoff: fast)
        #expect(await hub.search("x") == [bitcoin, pepe])
    }

    @Test func rateLimitDelayHonorsRetryAfter() {
        let backoff = Backoff(base: 2, factor: 2, maximum: 30)
        let limited = ProviderError.rateLimited(.binance, retryAfter: 45)
        #expect(QuoteHub.retryDelay(for: limited, attempt: 0, backoff: backoff) == 45)
        #expect(QuoteHub.retryDelay(for: ProviderError.network(.binance), attempt: 2, backoff: backoff) == 8)
        #expect(QuoteHub.retryDelay(for: ProviderError.rateLimited(.binance, retryAfter: 1), attempt: 3, backoff: backoff) == 16)
    }

    @Test func activeAssetClassesFollowReadyProviders() {
        let registry = ProviderRegistry([
            FakeProvider(id: .binance, snapshots: []),
            FinnhubProvider(apiKey: nil)
        ])
        #expect(registry.activeAssetClasses == [.crypto])
        #expect(AssetFilter.available(in: registry.activeAssetClasses) == [.all, .crypto])
    }
}
