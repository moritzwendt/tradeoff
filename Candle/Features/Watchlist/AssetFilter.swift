import Foundation

enum AssetFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case stock
    case etf
    case crypto
    case memeCoin

    var id: String { rawValue }

    var assetClass: AssetClass? {
        switch self {
        case .all: nil
        case .stock: .stock
        case .etf: .etf
        case .crypto: .crypto
        case .memeCoin: .memeCoin
        }
    }

    var title: String {
        assetClass?.title ?? "Alle"
    }
}
