import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppEnvironment {
    let container: ModelContainer
    let settings: AppSettings
    let hub: QuoteHub
    let trading: TradingService
    let recorder: EquityCurveRecorder
    let config: AppConfig
    private(set) var isReady = false
    private let defaults: UserDefaults
    private let launchTimeout: Duration

    init(
        inMemory: Bool = false,
        defaults: UserDefaults = .standard,
        config: AppConfig = AppConfig(),
        registry: ProviderRegistry? = nil,
        launchTimeout: Duration = .seconds(4)
    ) throws {
        let container = try PersistenceController.makeContainer(inMemory: inMemory)
        let settings = AppSettings(defaults: defaults)
        let registry = registry ?? ProviderRegistry([
            BinanceProvider(),
            DexScreenerProvider(),
            FinnhubProvider(apiKey: config.finnhubAPIKey),
            AlpacaProvider(keyID: config.alpacaKeyID, secretKey: config.alpacaSecretKey)
        ])
        let hub = QuoteHub(registry: registry, sparklineStore: inMemory ? nil : .standard)

        self.container = container
        self.settings = settings
        self.hub = hub
        self.config = config
        self.defaults = defaults
        self.launchTimeout = launchTimeout
        trading = TradingService(context: container.mainContext, hub: hub, settings: settings)
        recorder = EquityCurveRecorder(context: container.mainContext, hub: hub)
    }

    static func live() -> AppEnvironment {
        do {
            return try AppEnvironment()
        } catch {
            fatalError("App environment could not be created: \(error)")
        }
    }

    func prepare() async {
        _ = trading.account()
        await seedWatchlist()
    }

    func bootstrap() async {
        guard !isReady else { return }
        await prepare()
        let instruments = watchedInstruments()
        hub.setBaseline(instruments)
        Task { await hub.refreshSparklines(instruments) }
        await hub.waitForQuotes(instruments, timeout: launchTimeout)
        isReady = true
    }

    func watchedInstruments() -> [Instrument] {
        let context = container.mainContext
        let watched = ((try? context.fetch(FetchDescriptor<WatchlistEntry>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? []).map(\.instrument)
        let held = ((try? context.fetch(FetchDescriptor<PositionRecord>())) ?? []).map(\.instrument)
        var seen = Set<InstrumentID>()
        return (watched + held).filter { seen.insert($0.id).inserted }
    }

    func seedWatchlist() async {
        let legacyKey = "tradeoff.watchlist.seeded.live"
        let providersKey = "tradeoff.watchlist.seededProviders"
        var seeded = Set(defaults.stringArray(forKey: providersKey) ?? [])
        if defaults.bool(forKey: legacyKey) {
            seeded.formUnion([ProviderID.binance.rawValue, ProviderID.dexScreener.rawValue])
        }

        let context = container.mainContext
        var nextIndex = ((try? context.fetch(FetchDescriptor<WatchlistEntry>())) ?? []).count
        var changed = false
        for provider in hub.registry.all where provider.availability == .ready && !seeded.contains(provider.id.rawValue) {
            let catalog = await provider.catalog()
            guard !catalog.isEmpty else { continue }
            for instrument in catalog {
                context.insert(WatchlistEntry(instrument: instrument, sortIndex: nextIndex))
                nextIndex += 1
            }
            seeded.insert(provider.id.rawValue)
            changed = true
        }
        guard changed else { return }
        try? context.save()
        defaults.set(Array(seeded).sorted(), forKey: providersKey)
    }

    func resetAccount() {
        trading.resetAccount()
        recorder.record(force: true)
    }
}
