import Foundation

enum HistoryFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case buys
    case sells

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "Alle"
        case .buys: "Käufe"
        case .sells: "Verkäufe"
        }
    }

    func includes(_ side: OrderSide) -> Bool {
        switch self {
        case .all: true
        case .buys: side == .buy
        case .sells: side == .sell
        }
    }
}
