import Foundation
import Testing
@testable import TradeOff

struct FeeScheduleTests {
    private let fees = FeeSchedule.standard

    @Test func stocksPayFlatFee() {
        #expect(fees.fee(for: 2_500, assetClass: .stock) == 1)
        #expect(fees.fee(for: 10, assetClass: .etf) == 1)
    }

    @Test func cryptoPaysTenthOfAPercent() {
        #expect(fees.fee(for: 1_000, assetClass: .crypto) == 1)
    }

    @Test func memeCoinsPayPoolFeePlusNetworkFee() {
        #expect(fees.fee(for: 500, assetClass: .memeCoin) == TestSupport.decimal("2"))
    }

    @Test func minimumFeeApplies() {
        let rule = FeeRule(percent: TestSupport.decimal("0.001"), flat: 0, minimum: TestSupport.decimal("0.5"))
        #expect(rule.fee(for: 10) == TestSupport.decimal("0.5"))
    }

    @Test func feesRoundToCents() {
        let rule = FeeRule(percent: TestSupport.decimal("0.001"), flat: 0, minimum: 0)
        #expect(rule.fee(for: TestSupport.decimal("15.55")) == TestSupport.decimal("0.02"))
    }

    @Test func rulesCanBeReplaced() {
        var schedule = FeeSchedule.standard
        schedule.setRule(FeeRule(percent: 0, flat: 5, minimum: 0), for: .stock)
        #expect(schedule.fee(for: 100, assetClass: .stock) == 5)
        #expect(schedule.fee(for: 100, assetClass: .etf) == 1)
    }
}
