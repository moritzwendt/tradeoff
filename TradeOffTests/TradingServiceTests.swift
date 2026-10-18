import Foundation
import SwiftData
import Testing
@testable import TradeOff

@MainActor
struct TradingServiceTests {
    private struct Harness {
        let container: ModelContainer
        let hub: QuoteHub
        let trading: TradingService
        let settings: AppSettings
        let instrument: Instrument
    }

    private func harness(startingBalance: Decimal = 10_000) throws -> Harness {
        let container = try PersistenceController.makeContainer(inMemory: true)
        let defaults = UserDefaults(suiteName: "tradeoff.tests.\(UUID().uuidString)") ?? .standard
        let settings = AppSettings(defaults: defaults)
        settings.values.startingBalance = startingBalance
        let mock = try MockPriceProvider.bundled()
        let hub = QuoteHub(registry: ProviderRegistry([mock]))
        let instrument = TestSupport.instrument("AAPL")
        hub.ingest(TestSupport.quote(for: instrument))
        let trading = TradingService(
            context: container.mainContext,
            hub: hub,
            settings: settings,
            clock: { TestSupport.referenceDate }
        )
        return Harness(container: container, hub: hub, trading: trading, settings: settings, instrument: instrument)
    }

    private func request(_ side: OrderSide, _ quantity: Decimal, _ instrument: Instrument) -> OrderRequest {
        OrderRequest(instrumentID: instrument.id, side: side, quantity: quantity)
    }

    @Test func accountIsCreatedOnDemandWithStartingBalance() throws {
        let setup = try harness(startingBalance: 2_500)
        #expect(setup.trading.account().cash == 2_500)
        #expect(setup.trading.account().startingBalance == 2_500)
    }

    @Test func buyReducesCashAndCreatesPosition() throws {
        let setup = try harness()
        let fill = try setup.trading.execute(request(.buy, 10, setup.instrument), instrument: setup.instrument)
        #expect(fill.total == TestSupport.decimal("1002.00"))
        #expect(setup.trading.account().cash == TestSupport.decimal("8998.00"))
        let position = try #require(setup.trading.position(for: setup.instrument.id))
        #expect(position.quantity == 10)
        #expect(position.averageCost == TestSupport.decimal("100.20"))
    }

    @Test func sellIncreasesCashAndRealizesProfit() throws {
        let setup = try harness()
        try setup.trading.execute(request(.buy, 10, setup.instrument), instrument: setup.instrument)
        setup.hub.ingest(TestSupport.quote(for: setup.instrument, bid: "109.90", ask: "110.10"))
        let fill = try setup.trading.execute(request(.sell, 10, setup.instrument), instrument: setup.instrument)
        #expect(fill.realizedPnL == TestSupport.decimal("96.00"))
        #expect(setup.trading.account().realizedPnL == TestSupport.decimal("96.00"))
        #expect(setup.trading.position(for: setup.instrument.id) == nil)
    }

    @Test func partialSellKeepsRemainingPosition() throws {
        let setup = try harness()
        try setup.trading.execute(request(.buy, 10, setup.instrument), instrument: setup.instrument)
        try setup.trading.execute(request(.sell, 4, setup.instrument), instrument: setup.instrument)
        #expect(setup.trading.position(for: setup.instrument.id)?.quantity == 6)
    }

    @Test func rejectedOrdersLeaveTheLedgerUntouched() throws {
        let setup = try harness(startingBalance: 100)
        #expect(throws: TradeRejection.self) {
            try setup.trading.execute(self.request(.buy, 10, setup.instrument), instrument: setup.instrument)
        }
        #expect(setup.trading.account().cash == 100)
        let fills = try setup.container.mainContext.fetch(FetchDescriptor<FillRecord>())
        #expect(fills.isEmpty)
    }

    @Test func sellingWithoutPositionIsRejected() throws {
        let setup = try harness()
        let evaluation = setup.trading.evaluate(request(.sell, 1, setup.instrument), instrument: setup.instrument)
        #expect(evaluation.rejection == .insufficientPosition(held: 0))
    }

    @Test func cashIsConservedAcrossManyTrades() throws {
        let setup = try harness()
        try setup.trading.execute(request(.buy, 10, setup.instrument), instrument: setup.instrument)
        try setup.trading.execute(request(.buy, 5, setup.instrument), instrument: setup.instrument)
        try setup.trading.execute(request(.sell, 7, setup.instrument), instrument: setup.instrument)
        let fills = try setup.container.mainContext.fetch(FetchDescriptor<FillRecord>())
        let net = fills.reduce(Decimal(0)) { partial, fill in
            fill.side == .buy ? partial - fill.total : partial + fill.total
        }
        #expect(setup.trading.account().cash == 10_000 + net)
        #expect(fills.count == 3)
    }

    @Test func feesAreAccumulatedOnTheAccount() throws {
        let setup = try harness()
        try setup.trading.execute(request(.buy, 10, setup.instrument), instrument: setup.instrument)
        try setup.trading.execute(request(.sell, 10, setup.instrument), instrument: setup.instrument)
        #expect(setup.trading.account().totalFees == 2)
    }

    @Test func staleQuotesBlockExecution() throws {
        let setup = try harness()
        setup.hub.ingest(TestSupport.quote(for: setup.instrument, timestamp: TestSupport.referenceDate.addingTimeInterval(-120)))
        #expect(throws: TradeRejection.self) {
            try setup.trading.execute(self.request(.buy, 1, setup.instrument), instrument: setup.instrument)
        }
    }

    @Test func resetAccountClearsLedgerAndRestoresStartingBalance() throws {
        let setup = try harness()
        try setup.trading.execute(request(.buy, 10, setup.instrument), instrument: setup.instrument)
        setup.trading.resetAccount()
        let context = setup.container.mainContext
        #expect(try context.fetch(FetchDescriptor<FillRecord>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<PositionRecord>()).isEmpty)
        #expect(setup.trading.account().cash == 10_000)
    }
}
