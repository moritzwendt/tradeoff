import Foundation
import Testing
@testable import Candle

struct ExecutionModelTests {
    private let stock = TestSupport.instrument("AAPL")
    private let now = TestSupport.referenceDate

    private func evaluate(
        _ side: OrderSide,
        quantity: String,
        instrument: Instrument? = nil,
        quote: Quote? = nil,
        cash: String = "10000",
        held: String = "0",
        model: ExecutionModel = TestSupport.model(),
        at date: Date? = nil
    ) -> ExecutionEvaluation {
        let target = instrument ?? stock
        return model.evaluate(
            OrderRequest(instrumentID: target.id, side: side, quantity: TestSupport.decimal(quantity)),
            instrument: target,
            quote: quote ?? TestSupport.quote(for: target),
            cash: TestSupport.decimal(cash),
            heldQuantity: TestSupport.decimal(held),
            now: date ?? now
        )
    }

    @Test func buysAtAskAndAddsFee() throws {
        let result = evaluate(.buy, quantity: "10")
        let preview = try #require(result.preview)
        #expect(result.rejection == nil)
        #expect(preview.executionPrice == TestSupport.decimal("100.10"))
        #expect(preview.gross == TestSupport.decimal("1001.00"))
        #expect(preview.fee == 1)
        #expect(preview.total == TestSupport.decimal("1002.00"))
        #expect(preview.slippageFraction == 0)
    }

    @Test func sellsAtBidAndSubtractsFee() throws {
        let result = evaluate(.sell, quantity: "10", held: "10")
        let preview = try #require(result.preview)
        #expect(result.rejection == nil)
        #expect(preview.executionPrice == TestSupport.decimal("99.90"))
        #expect(preview.gross == TestSupport.decimal("999.00"))
        #expect(preview.total == TestSupport.decimal("998.00"))
    }

    @Test func rejectsWithoutQuote() {
        let result = TestSupport.model().evaluate(
            OrderRequest(instrumentID: stock.id, side: .buy, quantity: 1),
            instrument: stock,
            quote: nil,
            cash: 1_000,
            heldQuantity: 0,
            now: now
        )
        #expect(result.rejection == .noQuote)
        #expect(result.preview == nil)
    }

    @Test func rejectsZeroQuantity() {
        #expect(evaluate(.buy, quantity: "0").rejection == .invalidQuantity)
    }

    @Test func roundsQuantityDownToAssetScale() throws {
        let result = evaluate(.buy, quantity: "1.23456789")
        let preview = try #require(result.preview)
        #expect(preview.quantity == TestSupport.decimal("1.2345"))
    }

    @Test func rejectsInsufficientFunds() {
        let result = evaluate(.buy, quantity: "10", cash: "500")
        #expect(result.rejection == .insufficientFunds(required: TestSupport.decimal("1002.00"), available: 500))
        #expect(result.preview != nil)
        #expect(!result.isExecutable)
    }

    @Test func allowsSpendingExactlyAllCash() {
        let result = evaluate(.buy, quantity: "10", cash: "1002.00")
        #expect(result.isExecutable)
    }

    @Test func rejectsSellingMoreThanHeld() {
        let result = evaluate(.sell, quantity: "11", held: "10")
        #expect(result.rejection == .insufficientPosition(held: 10))
    }

    @Test func rejectsStaleQuotes() {
        let result = evaluate(.buy, quantity: "1", at: now.addingTimeInterval(45))
        #expect(result.rejection == .staleQuote(age: 45))
    }

    @Test func rejectsBelowMinimumNotional() {
        let result = evaluate(.buy, quantity: "0.001")
        #expect(result.rejection == .belowMinimum(1))
    }

    @Test func rejectsStocksWhenMarketIsClosed() {
        let saturday = TestSupport.newYorkDate(2026, 10, 17, 12)
        let quote = TestSupport.quote(for: stock, timestamp: saturday)
        let result = evaluate(.buy, quantity: "1", quote: quote, model: TestSupport.model(ignoreMarketHours: false), at: saturday)
        guard case .marketClosed(let session) = result.rejection else {
            Issue.record("Expected market closed rejection")
            return
        }
        #expect(!session.isOpen)
    }

    @Test func tradesCryptoAroundTheClock() {
        let bitcoin = TestSupport.instrument("BTC", assetClass: .crypto)
        let result = evaluate(.buy, quantity: "0.01", instrument: bitcoin, model: TestSupport.model(ignoreMarketHours: false))
        #expect(result.isExecutable)
    }

    @Test func memeCoinBuyPaysSlippageFromPoolLiquidity() throws {
        let meme = TestSupport.instrument("BONK", assetClass: .memeCoin)
        let quote = TestSupport.quote(for: meme, bid: "0.00002", ask: "0.00002", liquidity: "1000000")
        let result = evaluate(.buy, quantity: "250000000", instrument: meme, quote: quote)
        let preview = try #require(result.preview)
        #expect(preview.slippageFraction == TestSupport.decimal("0.01"))
        #expect(preview.executionPrice == TestSupport.decimal("0.0000202"))
        #expect(preview.gross == TestSupport.decimal("5050.00"))
        #expect(preview.slippageCost == TestSupport.decimal("50.00"))
    }

    @Test func memeCoinWithoutLiquidityDataIsRejected() {
        let meme = TestSupport.instrument("BONK", assetClass: .memeCoin)
        let result = evaluate(.buy, quantity: "1000", instrument: meme)
        #expect(result.rejection == .noLiquidityData)
    }

    @Test func memeCoinSellIsPenalizedLessThanEquivalentBuy() throws {
        let meme = TestSupport.instrument("MOONCAT", assetClass: .memeCoin)
        let quote = TestSupport.quote(for: meme, bid: "0.004", ask: "0.004", liquidity: "62000")
        let buy = try #require(evaluate(.buy, quantity: "250000", instrument: meme, quote: quote).preview)
        let sell = try #require(evaluate(.sell, quantity: "250000", instrument: meme, quote: quote, held: "250000").preview)
        #expect(buy.slippageFraction > sell.slippageFraction)
    }

    @Test func spreadIsReportedOnPreview() throws {
        let preview = try #require(evaluate(.buy, quantity: "1").preview)
        #expect(preview.spreadFraction > 0)
        #expect(preview.isSyntheticSpread)
    }
}
