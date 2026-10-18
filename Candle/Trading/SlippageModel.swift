import Foundation

enum SlippageModel: Equatable, Sendable {
    case none
    case constantProduct(liquidityUSD: Decimal)

    func fraction(side: OrderSide, notional: Decimal) -> Decimal {
        switch self {
        case .none:
            return 0
        case .constantProduct(let liquidity):
            let reserve = liquidity / 2
            guard reserve > 0, notional > 0 else { return 0 }
            switch side {
            case .buy: return notional / reserve
            case .sell: return notional / (reserve + notional)
            }
        }
    }
}
