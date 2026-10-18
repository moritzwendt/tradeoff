import Foundation

protocol PriceProvider: Sendable {
    var id: ProviderID { get }
    var capabilities: ProviderCapabilities { get }
    var availability: ProviderAvailability { get }

    func catalog() async -> [Instrument]
    func search(query: String) async throws -> [Instrument]
    func snapshot(for instruments: [Instrument]) async throws -> [Quote]
    func quotes(for instruments: [Instrument]) async -> AsyncStream<Quote>
    func history(for instrument: Instrument, range: ChartRange) async throws -> [Candlestick]
}
