import Foundation

enum WatchlistSort: String, Codable, CaseIterable, Identifiable, Sendable {
    case manual
    case name
    case bestFirst
    case worstFirst
    case priceHigh

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manual: "Eigene Reihenfolge"
        case .name: "Name"
        case .bestFirst: "Gewinner zuerst"
        case .worstFirst: "Verlierer zuerst"
        case .priceHigh: "Preis"
        }
    }
}

enum WatchlistOrdering {
    static func sorted(
        _ instruments: [Instrument],
        by sort: WatchlistSort,
        quotes: [InstrumentID: Quote]
    ) -> [Instrument] {
        switch sort {
        case .manual:
            return instruments
        case .name:
            return instruments.sorted { $0.symbol.localizedStandardCompare($1.symbol) == .orderedAscending }
        case .bestFirst:
            return ranked(instruments, quotes: quotes) { $0.changeFraction > $1.changeFraction }
        case .worstFirst:
            return ranked(instruments, quotes: quotes) { $0.changeFraction < $1.changeFraction }
        case .priceHigh:
            return ranked(instruments, quotes: quotes) { $0.last > $1.last }
        }
    }

    private static func ranked(
        _ instruments: [Instrument],
        quotes: [InstrumentID: Quote],
        by areInOrder: (Quote, Quote) -> Bool
    ) -> [Instrument] {
        let priced = instruments.enumerated().compactMap { offset, instrument in
            quotes[instrument.id].map { (offset, instrument, $0) }
        }
        let unpriced = instruments.filter { quotes[$0.id] == nil }
        let ordered = priced.sorted { lhs, rhs in
            if areInOrder(lhs.2, rhs.2) { return true }
            if areInOrder(rhs.2, lhs.2) { return false }
            return lhs.0 < rhs.0
        }
        return ordered.map(\.1) + unpriced
    }
}
