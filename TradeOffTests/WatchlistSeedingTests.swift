import Foundation
import SwiftData
import Testing
@testable import TradeOff

@MainActor
struct WatchlistSeedingTests {
    private func defaults() -> UserDefaults {
        UserDefaults(suiteName: "tradeoff.tests.\(UUID().uuidString)") ?? .standard
    }

    private func environment(_ store: UserDefaults, apiKey: String?) throws -> AppEnvironment {
        let registry = ProviderRegistry([
            BinanceProvider(http: HTTPClient(provider: .binance, transport: StubTransport(body: ""))),
            FinnhubProvider(apiKey: apiKey, transport: StubTransport(body: ""))
        ])
        return try AppEnvironment(inMemory: true, defaults: store, registry: registry)
    }

    private func symbols(_ environment: AppEnvironment) throws -> Set<ProviderID> {
        let entries = try environment.container.mainContext.fetch(FetchDescriptor<WatchlistEntry>())
        return Set(entries.map(\.instrument.provider))
    }

    @Test func seedsOnlyProvidersThatAreReady() async throws {
        let env = try environment(defaults(), apiKey: nil)
        await env.prepare()
        #expect(try symbols(env) == [.binance])
    }

    @Test func seedsAllReadyProviders() async throws {
        let env = try environment(defaults(), apiKey: "key")
        await env.prepare()
        #expect(try symbols(env) == [.binance, .finnhub])
        let entries = try env.container.mainContext.fetch(FetchDescriptor<WatchlistEntry>())
        #expect(entries.count == BinanceCatalog.featured.count + FinnhubCatalog.featured.count)
        #expect(Set(entries.map(\.sortIndex)).count == entries.count)
    }

    @Test func addingAKeyLaterSeedsOnlyTheNewProvider() async throws {
        let store = defaults()
        let first = try environment(store, apiKey: nil)
        await first.prepare()

        let second = try environment(store, apiKey: "key")
        await second.prepare()
        #expect(try symbols(second) == [.finnhub])
    }

    @Test func seedingIsIdempotent() async throws {
        let env = try environment(defaults(), apiKey: "key")
        await env.prepare()
        await env.prepare()
        let entries = try env.container.mainContext.fetch(FetchDescriptor<WatchlistEntry>())
        #expect(entries.count == BinanceCatalog.featured.count + FinnhubCatalog.featured.count)
    }

    @Test func legacySeedFlagCountsCryptoProvidersAsSeeded() async throws {
        let store = defaults()
        store.set(true, forKey: "tradeoff.watchlist.seeded.live")
        let env = try environment(store, apiKey: "key")
        await env.prepare()
        #expect(try symbols(env) == [.finnhub])
    }
}
