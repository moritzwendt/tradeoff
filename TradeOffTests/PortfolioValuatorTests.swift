import Foundation
import Testing
@testable import TradeOff

struct PortfolioValuatorTests {
    private let apple = TestSupport.instrument("AAPL")

    private func account(cash: String = "5000") -> AccountSnapshot {
        AccountSnapshot(cash: TestSupport.decimal(cash), startingBalance: 10_000, realizedPnL: 25, totalFees: 3)
    }

    @Test func emptyPortfolioEqualsCash() {
        let valuation = PortfolioValuator.value(account: account(), holdings: [], quotes: [:])
        #expect(valuation.equity == 5_000)
        #expect(valuation.positionsValue == 0)
        #expect(valuation.positions.isEmpty)
    }

    @Test func positionsAreValuedAtBid() {
        let holding = HoldingSnapshot(instrument: apple, quantity: 10, averageCost: 90)
        let quote = TestSupport.quote(for: apple, bid: "99.90", ask: "100.10")
        let valuation = PortfolioValuator.value(account: account(), holdings: [holding], quotes: [apple.id: quote])
        #expect(valuation.positionsValue == TestSupport.decimal("999.00"))
        #expect(valuation.unrealizedPnL == TestSupport.decimal("99.00"))
        #expect(valuation.equity == TestSupport.decimal("5999.00"))
        #expect(valuation.positions.first?.hasQuote == true)
    }

    @Test func missingQuoteFallsBackToAverageCost() {
        let holding = HoldingSnapshot(instrument: apple, quantity: 10, averageCost: 90)
        let valuation = PortfolioValuator.value(account: account(), holdings: [holding], quotes: [:])
        #expect(valuation.positionsValue == 900)
        #expect(valuation.unrealizedPnL == 0)
        #expect(valuation.positions.first?.hasQuote == false)
    }

    @Test func dayChangeUsesPreviousClose() {
        let holding = HoldingSnapshot(instrument: apple, quantity: 10, averageCost: 90)
        let quote = TestSupport.quote(for: apple)
        let valuation = PortfolioValuator.value(account: account(), holdings: [holding], quotes: [apple.id: quote])
        #expect(valuation.dayChange == 20)
    }

    @Test func totalReturnComparesAgainstStartingBalance() {
        let valuation = PortfolioValuator.value(account: account(cash: "10500"), holdings: [], quotes: [:])
        #expect(valuation.totalReturn == 500)
        #expect(valuation.totalReturnFraction == TestSupport.decimal("0.05"))
    }

    @Test func positionsAreSortedByValue() {
        let microsoft = TestSupport.instrument("MSFT")
        let holdings = [
            HoldingSnapshot(instrument: apple, quantity: 1, averageCost: 100),
            HoldingSnapshot(instrument: microsoft, quantity: 10, averageCost: 100)
        ]
        let valuation = PortfolioValuator.value(account: account(), holdings: holdings, quotes: [:])
        #expect(valuation.positions.map(\.id) == [microsoft.id, apple.id])
    }
}
