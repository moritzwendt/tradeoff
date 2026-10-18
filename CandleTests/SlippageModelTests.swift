import Foundation
import Testing
@testable import Candle

struct SlippageModelTests {
    private let model = SlippageModel.constantProduct(liquidityUSD: 1_000_000)

    @Test func buyPremiumIsNotionalOverReserve() {
        #expect(model.fraction(side: .buy, notional: 5_000) == TestSupport.decimal("0.01"))
    }

    @Test func sellDiscountIsNotionalOverReservePlusNotional() {
        let fraction = model.fraction(side: .sell, notional: 5_000)
        let expected = TestSupport.decimal("5000") / TestSupport.decimal("505000")
        #expect(fraction == expected)
    }

    @Test func noneModelHasNoSlippage() {
        #expect(SlippageModel.none.fraction(side: .buy, notional: 1_000_000) == 0)
    }

    @Test func zeroLiquidityOrNotionalIsHarmless() {
        #expect(SlippageModel.constantProduct(liquidityUSD: 0).fraction(side: .buy, notional: 100) == 0)
        #expect(model.fraction(side: .sell, notional: 0) == 0)
    }

    @Test func thinPoolsSlipMoreThanDeepPools() {
        let thin = SlippageModel.constantProduct(liquidityUSD: 60_000).fraction(side: .buy, notional: 1_000)
        let deep = SlippageModel.constantProduct(liquidityUSD: 9_000_000).fraction(side: .buy, notional: 1_000)
        #expect(thin > deep)
    }
}
