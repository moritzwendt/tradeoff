import Foundation

enum AssetClass: String, Codable, CaseIterable, Sendable, Hashable, Identifiable {
    case stock
    case etf
    case crypto
    case memeCoin

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stock: "Aktien"
        case .etf: "ETFs"
        case .crypto: "Krypto"
        case .memeCoin: "Meme Coins"
        }
    }

    var singularTitle: String {
        switch self {
        case .stock: "Aktie"
        case .etf: "ETF"
        case .crypto: "Krypto"
        case .memeCoin: "Meme Coin"
        }
    }

    var systemImage: String {
        switch self {
        case .stock: "building.columns"
        case .etf: "square.stack.3d.up"
        case .crypto: "bitcoinsign"
        case .memeCoin: "flame"
        }
    }

    var quantityScale: Int {
        switch self {
        case .stock, .etf: 4
        case .crypto: 6
        case .memeCoin: 2
        }
    }

    var calendarKind: MarketCalendarKind {
        switch self {
        case .stock, .etf: .usEquities
        case .crypto, .memeCoin: .alwaysOpen
        }
    }

    var usesPoolSlippage: Bool {
        self == .memeCoin
    }
}
