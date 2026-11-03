import Foundation
import SwiftData
import Testing
@testable import TradeOff

struct SparklineStoreTests {
    private func store() -> SparklineStore {
        SparklineStore(url: URL.temporaryDirectory.appending(path: "sparklines-\(UUID().uuidString).json"))
    }

    @Test func roundTripsValues() {
        let store = store()
        store.save(["binance:BTCUSDT": [1, 2, 3]])
        #expect(store.load() == ["binance:BTCUSDT": [1, 2, 3]])
    }

    @Test func missingOrBrokenFilesLoadAsEmpty() throws {
        let store = store()
        #expect(store.load().isEmpty)
        try Data("not json".utf8).write(to: store.url)
        #expect(store.load().isEmpty)
    }

    @Test func downsamplingKeepsEndpointsAndLimit() {
        let values = (0..<500).map(Double.init)
        let sampled = SparklineStore.downsample(values, limit: 48)
        #expect(sampled.count == 48)
        #expect(sampled.first == 0)
        #expect(sampled.last == 499)
        #expect(sampled == sampled.sorted())
    }

    @Test func shortSeriesAreLeftAlone() {
        #expect(SparklineStore.downsample([1, 2, 3], limit: 48) == [1, 2, 3])
        #expect(SparklineStore.downsample([], limit: 48).isEmpty)
    }
}

@MainActor
struct HubStartupTests {
    private let btc = TestSupport.instrument("BTC", assetClass: .crypto, provider: .binance)
    private let fast = Backoff(base: 0.01, factor: 2, maximum: 0.02)

    private func candles() -> [Candlestick] {
        (0..<100).map {
            Candlestick(time: FixedClock.epoch.addingTimeInterval(Double($0) * 300), open: 1, high: 2, low: 1, close: Decimal($0 + 1), volume: 1)
        }
    }

    @Test func refreshingSparklinesStoresDownsampledSeriesAndPersistsThem() async {
        let url = URL.temporaryDirectory.appending(path: "sparklines-\(UUID().uuidString).json")
        let store = SparklineStore(url: url)
        let provider = FakeProvider(candles: candles())
        let hub = QuoteHub(registry: ProviderRegistry([provider]), backoff: fast, sparklineStore: store)
        await hub.refreshSparklines([btc])
        #expect(hub.sparklines[btc.id]?.count == SparklineStore.pointLimit)
        #expect(store.load()[btc.id]?.count == SparklineStore.pointLimit)
    }

    @Test func cachedSparklinesAreAvailableImmediately() {
        let url = URL.temporaryDirectory.appending(path: "sparklines-\(UUID().uuidString).json")
        let store = SparklineStore(url: url)
        store.save([btc.id: [1, 2, 3, 4]])
        let hub = QuoteHub(registry: ProviderRegistry([]), sparklineStore: store)
        #expect(hub.sparklines[btc.id] == [1, 2, 3, 4])
    }

    @Test func waitingReturnsAsSoonAsAllQuotesArrive() async {
        let provider = FakeProvider(snapshots: [.success([TestSupport.quote(for: btc)])])
        let hub = QuoteHub(registry: ProviderRegistry([provider]), backoff: fast)
        hub.setBaseline([btc])
        let started = ContinuousClock.now
        await hub.waitForQuotes([btc], timeout: .seconds(5))
        #expect(hub.quote(for: btc.id) != nil)
        #expect(ContinuousClock.now - started < .seconds(2))
    }

    @Test func waitingGivesUpAfterTheTimeout() async {
        let hub = QuoteHub(registry: ProviderRegistry([FakeProvider()]), backoff: fast)
        let started = ContinuousClock.now
        await hub.waitForQuotes([btc], timeout: .milliseconds(200))
        #expect(ContinuousClock.now - started >= .milliseconds(150))
        #expect(hub.quote(for: btc.id) == nil)
    }

    @Test func waitingIgnoresInstrumentsOfUnavailableProviders() async {
        let stock = TestSupport.instrument("AAPL", assetClass: .stock, provider: .finnhub)
        let registry = ProviderRegistry([FinnhubProvider(apiKey: nil)])
        let hub = QuoteHub(registry: registry, backoff: fast)
        let started = ContinuousClock.now
        await hub.waitForQuotes([stock], timeout: .seconds(5))
        #expect(ContinuousClock.now - started < .seconds(1))
    }

    @Test func bootstrapSeedsTheWatchlistAndBecomesReadyOnceQuotesArrive() async throws {
        let store = UserDefaults(suiteName: "tradeoff.tests.\(UUID().uuidString)") ?? .standard
        let transport = StubTransport(body: BinanceFixtures.tickers24h)
        let registry = ProviderRegistry([BinanceProvider(http: HTTPClient(provider: .binance, transport: transport))])
        let env = try AppEnvironment(inMemory: true, defaults: store, registry: registry, launchTimeout: .milliseconds(1500))
        #expect(!env.isReady)
        await env.bootstrap()
        #expect(env.isReady)
        #expect(env.watchedInstruments().count == BinanceCatalog.featured.count)
        #expect(env.hub.quote(for: "binance:BTCUSDT") != nil)
    }

    @Test func problemsAppearOnlyAfterTheGracePeriod() async {
        let provider = FakeProvider(snapshots: [.failure(ProviderError.network(.binance))])
        let hub = QuoteHub(registry: ProviderRegistry([provider]), backoff: Backoff(base: 5, factor: 1, maximum: 5))
        hub.setBaseline([btc])
        for _ in 0..<100 where hub.degradedProviders.isEmpty {
            try? await Task.sleep(for: .milliseconds(10))
        }
        let now = Date()
        #expect(hub.degradedProviders == [.binance])
        #expect(hub.problems(at: now).isEmpty)
        #expect(hub.connectionState(at: now) == .updating)
        let later = now.addingTimeInterval(QuoteHub.problemGrace + 1)
        #expect(hub.problems(at: later) == [.binance])
        #expect(hub.connectionState(at: later) == .problem)
    }

    @Test func liveProvidersReportALiveConnection() async {
        let provider = FakeProvider(snapshots: [.success([TestSupport.quote(for: btc)])])
        let hub = QuoteHub(registry: ProviderRegistry([provider]), backoff: fast)
        hub.setBaseline([btc])
        for _ in 0..<200 where hub.statuses[.binance] != .live {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(hub.connectionState() == .live)
        #expect(hub.problems(at: Date().addingTimeInterval(60)).isEmpty)
    }
}
