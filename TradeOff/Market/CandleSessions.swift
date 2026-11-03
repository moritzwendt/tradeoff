import Foundation

enum CandleSessions {
    static func latest(in candles: [Candlestick]) -> [Candlestick] {
        guard let last = candles.last else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        let day = calendar.startOfDay(for: last.time)
        return candles.filter { calendar.startOfDay(for: $0.time) == day }
    }
}
