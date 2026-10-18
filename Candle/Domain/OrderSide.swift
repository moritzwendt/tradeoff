import Foundation

enum OrderSide: String, Codable, CaseIterable, Sendable, Identifiable {
    case buy
    case sell

    var id: String { rawValue }

    var title: String {
        switch self {
        case .buy: "Kaufen"
        case .sell: "Verkaufen"
        }
    }

    var pastTitle: String {
        switch self {
        case .buy: "Gekauft"
        case .sell: "Verkauft"
        }
    }
}
