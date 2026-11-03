import Foundation

struct Backoff: Sendable, Equatable {
    var base: TimeInterval = 1
    var factor: Double = 2
    var maximum: TimeInterval = 30

    func delay(attempt: Int) -> TimeInterval {
        let exponent = Double(max(attempt, 0))
        return min(maximum, base * pow(factor, exponent))
    }
}
