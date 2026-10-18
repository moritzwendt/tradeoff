import Foundation

struct BinanceProvider: PriceProvider {
    static let streamBaseURL = "wss://stream.binance.com:9443/stream"
    static let restBaseURL = "https://api.binance.com"

    let id: ProviderID = .binance

    let capabilities = ProviderCapabilities(
        hasRealBidAsk: true,
        hasHistory: true,
        hasLiquidity: false,
        isDelayed: false,
        requiresAPIKey: false,
        supportedAssetClasses: [.crypto],
        pollInterval: nil
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
