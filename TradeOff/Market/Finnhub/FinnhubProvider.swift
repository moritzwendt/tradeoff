import Foundation

struct FinnhubProvider: PriceProvider {
    static let restBaseURL = "https://finnhub.io/api/v1"
    static let streamBaseURL = "wss://ws.finnhub.io"

    let id: ProviderID = .finnhub
    let apiKey: String?

    let capabilities = ProviderCapabilities(
        hasRealBidAsk: false,
        hasHistory: false,
        hasLiquidity: false,
        isDelayed: false,
        requiresAPIKey: true,
        supportedAssetClasses: [.stock, .etf],
        pollInterval: nil
    )

    var availability: ProviderAvailability {
        apiKey == nil ? .missingAPIKey : .notImplemented
    }

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
