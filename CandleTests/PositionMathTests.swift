import Foundation
import Testing
@testable import Candle

struct PositionMathTests {
    @Test func firstBuyIncludesFeeInAverageCost() {
        let outcome = PositionMath.apply(side: .buy, quantity: 10, gross: 1_000, fee: 10, to: PositionState())
        #expect(outcome.state.quantity == 10)
        #expect(outcome.state.averageCost == 101)
        #expect(outcome.realizedDelta == 0)
    }

    @Test func secondBuyBlendsAverageCost() {
        let first = PositionMath.apply(side: .buy, quantity: 10, gross: 1_000, fee: 0, to: PositionState())
        let second = PositionMath.apply(side: .buy, quantity: 10, gross: 1_200, fee: 0, to: first.state)
        #expect(second.state.quantity == 20)
        #expect(second.state.averageCost == 110)
    }

    @Test func partialSellRealizesProfitAndKeepsAverageCost() {
        let bought = PositionMath.apply(side: .buy, quantity: 10, gross: 1_000, fee: 0, to: PositionState())
        let sold = PositionMath.apply(side: .sell, quantity: 4, gross: 520, fee: 1, to: bought.state)
        #expect(sold.state.quantity == 6)
        #expect(sold.state.averageCost == 100)
        #expect(sold.realizedDelta == 119)
        #expect(sold.state.realizedPnL == 119)
    }

    @Test func fullSellResetsAverageCost() {
        let bought = PositionMath.apply(side: .buy, quantity: 5, gross: 500, fee: 0, to: PositionState())
        let sold = PositionMath.apply(side: .sell, quantity: 5, gross: 450, fee: 0, to: bought.state)
        #expect(sold.state.quantity == 0)
        #expect(sold.state.averageCost == 0)
        #expect(sold.realizedDelta == -50)
    }

    @Test func lossesAccumulateAcrossSells() {
        let bought = PositionMath.apply(side: .buy, quantity: 10, gross: 1_000, fee: 0, to: PositionState())
        let first = PositionMath.apply(side: .sell, quantity: 5, gross: 400, fee: 0, to: bought.state)
        let second = PositionMath.apply(side: .sell, quantity: 5, gross: 450, fee: 0, to: first.state)
        #expect(second.state.realizedPnL == -150)
    }
}
