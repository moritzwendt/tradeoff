import Foundation

enum PriceFormatter {
    static func price(_ value: Decimal, currency: String = "USD") -> String {
        if abs(value) >= 1 || value == 0 {
            return value.formatted(.currency(code: currency).precision(.fractionLength(2)))
        }
        return value.formatted(.currency(code: currency).precision(.significantDigits(2...4)))
    }

    static func money(_ value: Decimal, currency: String = "USD", signed: Bool = false) -> String {
        if signed {
            return value.formatted(
                .currency(code: currency)
                    .precision(.fractionLength(2))
                    .sign(strategy: .always())
            )
        }
        return value.formatted(.currency(code: currency).precision(.fractionLength(2)))
    }

    static func change(_ value: Decimal, currency: String = "USD") -> String {
        if abs(value) >= 1 || value == 0 {
            return money(value, currency: currency, signed: true)
        }
        return value.formatted(
            .currency(code: currency)
                .precision(.significantDigits(2...4))
                .sign(strategy: .always())
        )
    }

    static func percent(_ fraction: Decimal, signed: Bool = true) -> String {
        if signed {
            return fraction.formatted(
                .percent
                    .precision(.fractionLength(2))
                    .sign(strategy: .always())
            )
        }
        return fraction.formatted(.percent.precision(.fractionLength(2)))
    }

    static func quantity(_ value: Decimal, assetClass: AssetClass) -> String {
        value.formatted(.number.precision(.fractionLength(0...assetClass.quantityScale)))
    }

    static func holding(_ value: Decimal, assetClass: AssetClass) -> String {
        if value >= 100_000 {
            return value.formatted(.number.notation(.compactName).precision(.fractionLength(0...2)))
        }
        return quantity(value, assetClass: assetClass)
    }

    static func compactMoney(_ value: Decimal, currency: String = "USD") -> String {
        value.formatted(
            .currency(code: currency)
                .notation(.compactName)
                .precision(.fractionLength(0...2))
        )
    }

    static func axis(_ value: Double) -> String {
        let magnitude = abs(value)
        if magnitude >= 1000 {
            return value.formatted(.number.precision(.fractionLength(0)))
        }
        if magnitude >= 1 {
            return value.formatted(.number.precision(.fractionLength(2)))
        }
        return value.formatted(.number.precision(.significantDigits(2...3)))
    }

    static func input(_ text: String) -> String {
        guard !text.isEmpty else { return "0" }
        let separator = Locale.current.decimalSeparator ?? "."
        return text.replacingOccurrences(of: ".", with: separator)
    }

    static func seconds(_ value: Double) -> String {
        "\(Int(value.rounded())) s"
    }
}
