import Foundation

extension Decimal {
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }

    init(_ double: Double, scale: Int) {
        let handler = NSDecimalNumberHandler(
            roundingMode: .plain,
            scale: Int16(scale),
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        self = NSDecimalNumber(value: double).rounding(accordingToBehavior: handler).decimalValue
    }

    func rounded(scale: Int, mode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var source = self
        var result = Decimal()
        NSDecimalRound(&result, &source, scale, mode)
        return result
    }

    func roundedToSignificantDigits(_ digits: Int) -> Decimal {
        guard self != 0 else { return self }
        let magnitude = Int(floor(log10(abs(doubleValue))))
        return rounded(scale: digits - 1 - magnitude)
    }

    func marketRounded() -> Decimal {
        abs(self) >= 1 ? rounded(scale: 2) : roundedToSignificantDigits(4)
    }

    var isPositive: Bool {
        self > 0
    }
}
