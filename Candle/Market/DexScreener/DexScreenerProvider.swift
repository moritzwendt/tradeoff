import Foundation

struct DexScreenerProvider: PriceProvider {
    static let restBaseURL = "https://api.dexscreener.com/latest/dex"
    static let maxAddressesPerRequest = 30

    let id: ProviderID = .dexScreener

    let capabilities = ProviderCapabilities(
        hasRealBidAsk: false,
        hasHistory: false,
        hasLiquidity: true,
        isDelayed: false,
        requiresAPIKey: false,
        supportedAssetClasses: [.memeCoin],
        pollInterval: 5
    )

    var availability: ProviderAvailability { .notImplemented }

    func catalog() async -> [Instrument] {
        []
    }

    func search(query: String) async throws -> [Instrument] {
        throw ProviderError.notImplemented(id)
    }

    func snapshot(for instruments: [Instrument]) async throws -> [Quote] {
        throw ProviderError.notImplemented(id)
    }

    func quotes(for instruments: [Instrument]) async -> AsyncStream<Quote> {
        AsyncStream { $0.finish() }
    }

    func history(for instrument: Instrument, range: ChartRange) async throws -> [Candlestick] {
        throw ProviderError.notImplemented(id)
    }
}
