import Foundation

typealias InstrumentID = String

struct Instrument: Identifiable, Hashable, Codable, Sendable {
    let id: InstrumentID
    let symbol: String
    let name: String
    let assetClass: AssetClass
    let provider: ProviderID
    let providerSymbol: String
    let currency: String

    static func makeID(provider: ProviderID, symbol: String) -> InstrumentID {
        "\(provider.rawValue):\(symbol)"
    }
}
