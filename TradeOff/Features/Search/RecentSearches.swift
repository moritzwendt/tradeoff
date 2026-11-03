import Foundation

enum RecentSearches {
    static let limit = 8
    static let storageKey = "tradeoff.recentSearches"

    static func decode(_ text: String) -> [Instrument] {
        guard let data = text.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([Instrument].self, from: data)) ?? []
    }

    static func encode(_ instruments: [Instrument]) -> String {
        guard let data = try? JSONEncoder().encode(instruments) else { return "" }
        return String(decoding: data, as: UTF8.self)
    }

    static func adding(_ instrument: Instrument, to recents: [Instrument]) -> [Instrument] {
        Array(([instrument] + recents.filter { $0.id != instrument.id }).prefix(limit))
    }
}
