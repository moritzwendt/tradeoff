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
    private let defaults: UserDefaults

    init(
        inMemory: Bool = false,
        defaults: UserDefaults = .standard,
        config: AppConfig = AppConfig(),
        registry: ProviderRegistry? = nil
    ) throws {
        let container = try PersistenceController.makeContainer(inMemory: inMemory)
        let settings = AppSettings(defaults: defaults)
        let registry = registry ?? ProviderRegistry([
            BinanceProvider(),
            DexScreenerProvider(),
            FinnhubProvider(apiKey: config.finnhubAPIKey),
            AlpacaProvider(keyID: config.alpacaKeyID, secretKey: config.alpacaSecretKey)
        ])
        let hub = QuoteHub(registry: registry)

        self.container = container
        self.settings = settings
        self.hub = hub
        self.config = config
        self.defaults = defaults
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
