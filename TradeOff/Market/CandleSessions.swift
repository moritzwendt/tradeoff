import Foundation

enum CandleSessions {
    static let regularOpenMinute = 9 * 60 + 30
    static let regularCloseMinute = 16 * 60

    static func regularHours(in candles: [Candlestick], bucket: TimeInterval) -> [Candlestick] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        let length = Int(bucket / 60)
        return candles.filter { candle in
            let parts = calendar.dateComponents([.hour, .minute], from: candle.time)
            let start = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            return start + length > regularOpenMinute && start < regularCloseMinute
        }
    }

    static func latest(in candles: [Candlestick]) -> [Candlestick] {
        guard let last = candles.last else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        let day = calendar.startOfDay(for: last.time)
        return candles.filter { calendar.startOfDay(for: $0.time) == day }
    }
}
