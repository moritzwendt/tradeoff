import Foundation

enum ProviderID: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case mock
    case binance
    case dexScreener
    case finnhub
    case alpaca

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mock: "Simulation"
        case .binance: "Binance"
        case .dexScreener: "DexScreener"
        case .finnhub: "Finnhub"
        case .alpaca: "Alpaca"
        }
    }
}
