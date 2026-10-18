import Foundation

struct AccountSnapshot: Equatable, Sendable {
    let cash: Decimal
    let startingBalance: Decimal
    let realizedPnL: Decimal
    let totalFees: Decimal
}

struct HoldingSnapshot: Identifiable, Equatable, Sendable {
    let instrument: Instrument
    let quantity: Decimal
    let averageCost: Decimal

    var id: InstrumentID { instrument.id }
}

struct PositionValuation: Identifiable, Equatable, Sendable {
    let holding: HoldingSnapshot
    let price: Decimal
    let value: Decimal
    let costBasis: Decimal
    let unrealizedPnL: Decimal
    let unrealizedFraction: Decimal
    let dayChange: Decimal
    let hasQuote: Bool

    var id: InstrumentID { holding.id }
}

struct PortfolioValuation: Equatable, Sendable {
    let cash: Decimal
    let positionsValue: Decimal
    let unrealizedPnL: Decimal
    let realizedPnL: Decimal
    let totalFees: Decimal
    let equity: Decimal
    let startingBalance: Decimal
    let dayChange: Decimal
    let positions: [PositionValuation]

    var totalReturn: Decimal {
        equity - startingBalance
    }

    var totalReturnFraction: Decimal {
        startingBalance > 0 ? totalReturn / startingBalance : 0
    }

    var dayChangeFraction: Decimal {
        let base = equity - dayChange
        return base > 0 ? dayChange / base : 0
    }
}

enum PortfolioValuator {
    static func value(
        account: AccountSnapshot,
        holdings: [HoldingSnapshot],
        quotes: [InstrumentID: Quote]
    ) -> PortfolioValuation {
        let rows = holdings.map { holding -> PositionValuation in
            let quote = quotes[holding.id]
            let price = quote?.bid ?? holding.averageCost
            let value = (holding.quantity * price).rounded(scale: 2)
            let cost = (holding.quantity * holding.averageCost).rounded(scale: 2)
            let unrealized = value - cost
            let dayChange = quote.map { (holding.quantity * ($0.last - $0.previousClose)).rounded(scale: 2) } ?? 0
            return PositionValuation(
                holding: holding,
                price: price,
                value: value,
                costBasis: cost,
                unrealizedPnL: unrealized,
                unrealizedFraction: cost > 0 ? unrealized / cost : 0,
                dayChange: dayChange,
                hasQuote: quote != nil
            )
        }

        let positionsValue = rows.reduce(Decimal(0)) { $0 + $1.value }
        let unrealized = rows.reduce(Decimal(0)) { $0 + $1.unrealizedPnL }
        let dayChange = rows.reduce(Decimal(0)) { $0 + $1.dayChange }

        return PortfolioValuation(
            cash: account.cash,
            positionsValue: positionsValue,
            unrealizedPnL: unrealized,
            realizedPnL: account.realizedPnL,
            totalFees: account.totalFees,
            equity: account.cash + positionsValue,
            startingBalance: account.startingBalance,
            dayChange: dayChange,
            positions: rows.sorted { $0.value > $1.value }
        )
    }
}
