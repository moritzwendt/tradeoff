import Foundation

struct PositionState: Equatable, Sendable {
    var quantity: Decimal = 0
    var averageCost: Decimal = 0
    var realizedPnL: Decimal = 0
}

enum PositionMath {
    struct Outcome: Equatable, Sendable {
        let state: PositionState
        let realizedDelta: Decimal
    }

    static func apply(
        side: OrderSide,
        quantity: Decimal,
        gross: Decimal,
        fee: Decimal,
        to state: PositionState
    ) -> Outcome {
        var next = state
        switch side {
        case .buy:
            let totalCost = state.quantity * state.averageCost + gross + fee
            next.quantity = state.quantity + quantity
            next.averageCost = next.quantity > 0 ? (totalCost / next.quantity).roundedToSignificantDigits(12) : 0
            return Outcome(state: next, realizedDelta: 0)
        case .sell:
            let proceeds = gross - fee
            let costBasis = quantity * state.averageCost
            let realized = (proceeds - costBasis).rounded(scale: 2)
            next.quantity = state.quantity - quantity
            next.realizedPnL += realized
            if next.quantity == 0 {
                next.averageCost = 0
            }
            return Outcome(state: next, realizedDelta: realized)
        }
    }
}
