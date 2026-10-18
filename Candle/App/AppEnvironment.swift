import Foundation
import SwiftData

@MainActor
final class AppEnvironment {
    let container: ModelContainer
    let settings: AppSettings
    let hub: QuoteHub
    let trading: TradingService
    let recorder: EquityCurveRecorder
    let mock: MockPriceProvider
    let config: AppConfig
    private let defaults: UserDefaults

    init(
        inMemory: Bool = false,
        defaults: UserDefaults = .standard,
        config: AppConfig = AppConfig()
    ) throws {
        let container = try PersistenceController.makeContainer(inMemory: inMemory)
        let settings = AppSettings(defaults: defaults)
        let mock = try MockPriceProvider.bundled()
        let registry = ProviderRegistry([
            mock,
            BinanceProvider(),
            DexScreenerProvider(),
            FinnhubProvider(apiKey: config.finnhubAPIKey)
        ])
        let hub = QuoteHub(registry: registry)

        self.container = container
        self.settings = settings
        self.hub = hub
        self.mock = mock
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
        await applyMockTuning()
        let key = "candle.watchlist.seeded"
        guard !defaults.bool(forKey: key) else { return }
        let context = container.mainContext
        let catalog = await hub.catalog()
        for (index, instrument) in catalog.enumerated() {
            context.insert(WatchlistEntry(instrument: instrument, sortIndex: index))
        }
        try? context.save()
        defaults.set(true, forKey: key)
    }

    func applyMockTuning() async {
        await mock.update(
            tuning: MockPriceProvider.Tuning(
                tickInterval: settings.values.mockTickInterval,
                volatilityMultiplier: settings.values.mockVolatility
            )
        )
    }

    func loadDemoPortfolio() async {
        await DemoSeeder.seed(context: container.mainContext, hub: hub, settings: settings)
        recorder.record(force: true)
    }

    func resetAccount() {
        trading.resetAccount()
        recorder.record(force: true)
    }
}
