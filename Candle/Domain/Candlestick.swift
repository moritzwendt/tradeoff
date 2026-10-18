import Foundation

struct Candlestick: Identifiable, Equatable, Sendable {
    let time: Date
    var open: Decimal
    var high: Decimal
    var low: Decimal
    var close: Decimal
    var volume: Decimal

    var id: Date { time }

    var isRising: Bool {
        close >= open
    }

    func applying(price: Decimal) -> Candlestick {
        var copy = self
        copy.close = price
        copy.high = max(high, price)
        copy.low = min(low, price)
        return copy
    }
}
