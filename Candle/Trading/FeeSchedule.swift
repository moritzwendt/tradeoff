import Foundation

struct FeeRule: Codable, Equatable, Sendable {
    var percent: Decimal
    var flat: Decimal
    var minimum: Decimal

    func fee(for notional: Decimal) -> Decimal {
        max(minimum, notional * percent + flat).rounded(scale: 2)
    }
}

struct FeeSchedule: Codable, Equatable, Sendable {
    var stock: FeeRule
    var etf: FeeRule
    var crypto: FeeRule
    var memeCoin: FeeRule

    static let standard = FeeSchedule(
        stock: FeeRule(percent: 0, flat: 1, minimum: 0),
        etf: FeeRule(percent: 0, flat: 1, minimum: 0),
        crypto: FeeRule(percent: Decimal(sign: .plus, exponent: -3, significand: 1), flat: 0, minimum: 0),
        memeCoin: FeeRule(
            percent: Decimal(sign: .plus, exponent: -3, significand: 3),
            flat: Decimal(sign: .plus, exponent: -1, significand: 5),
            minimum: 0
        )
    )

    func rule(for assetClass: AssetClass) -> FeeRule {
        switch assetClass {
        case .stock: stock
        case .etf: etf
        case .crypto: crypto
        case .memeCoin: memeCoin
        }
    }

    mutating func setRule(_ rule: FeeRule, for assetClass: AssetClass) {
        switch assetClass {
        case .stock: stock = rule
        case .etf: etf = rule
        case .crypto: crypto = rule
        case .memeCoin: memeCoin = rule
        }
    }

    func fee(for notional: Decimal, assetClass: AssetClass) -> Decimal {
        rule(for: assetClass).fee(for: notional)
    }
}
