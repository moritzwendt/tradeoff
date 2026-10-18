import Foundation
import Testing
@testable import Candle

struct MockMarketTests {
    private func provider() throws -> MockPriceProvider {
        try MockPriceProvider.bundled(clock: { TestSupport.referenceDate })
    }

    @Test func bundledDefinitionLoadsAllAssetClasses() throws {
        let definition = try MockMarketDefinition.load()
        let classes = Set(definition.instruments.map(\.assetClass))
        #expect(definition.instruments.count == 10)
        #expect(classes == Set(AssetClass.allCases))
    }

    @Test func decimalPricesDecodeWithoutBinaryNoise() throws {
        let definition = try MockMarketDefinition.load()
        let apple = try #require(definition.instruments.first { $0.symbol == "AAPL" })
        #expect(apple.startPrice == TestSupport.decimal("227.4"))
    }

    @Test func memeCoinsCarryLiquidityAndOthersDoNot() throws {
        let definition = try MockMarketDefinition.load()
        for item in definition.instruments {
            #expect((item.liquidityUSD != nil) == (item.assetClass == .memeCoin))
        }
    }

    @Test func catalogKeepsDefinitionOrder() async throws {
        let catalog = await (try provider()).catalog()
        #expect(catalog.first?.symbol == "AAPL")
        #expect(catalog.count == 10)
    }

    @Test func searchMatchesSymbolAndNameCaseInsensitively() async throws {
        let mock = try provider()
        #expect(await mock.search(query: "bit").map(\.symbol) == ["BTC"])
        #expect(await mock.search(query: "aapl").map(\.symbol) == ["AAPL"])
        #expect(await mock.search(query: "   ").count == 10)
        #expect(await mock.search(query: "zzz").isEmpty)
    }

    @Test func snapshotQuotesHaveAskAboveBid() async throws {
        let mock = try provider()
        let catalog = await mock.catalog()
        let quotes = await mock.snapshot(for: catalog)
        #expect(quotes.count == catalog.count)
        for quote in quotes {
            #expect(quote.ask > quote.bid)
            #expect(quote.quality == .simulated)
            #expect(quote.isSyntheticSpread)
        }
    }

    @Test func memeQuotesCarryLiquidity() async throws {
        let mock = try provider()
        let catalog = await mock.catalog()
        let quotes = await mock.snapshot(for: catalog)
        let memes = Set(catalog.filter { $0.assetClass == .memeCoin }.map(\.id))
        for quote in quotes {
            #expect((quote.liquidityUSD != nil) == memes.contains(quote.instrumentID))
        }
    }

    @Test func streamEmitsQuotesAfterTuning() async throws {
        let mock = try provider()
        await mock.update(tuning: MockPriceProvider.Tuning(tickInterval: 0.05, volatilityMultiplier: 40))
        let apple = try #require(await mock.catalog().first)
        let stream = await mock.quotes(for: [apple])
        var received: Quote?
        for await quote in stream {
            received = quote
            break
        }
        #expect(received?.instrumentID == apple.id)
    }

    @Test func historyEndsAtCurrentPrice() async throws {
        let mock = try provider()
        let apple = try #require(await mock.catalog().first)
        let quote = try #require(await mock.snapshot(for: [apple]).first)
        let candles = try await mock.history(for: apple, range: .month)
        #expect(candles.count == ChartRange.month.candleCount)
        #expect(candles.last?.close == quote.last)
    }

    @Test func historyForUnknownInstrumentThrows() async throws {
        let mock = try provider()
        await #expect(throws: ProviderError.self) {
            try await mock.history(for: TestSupport.instrument("NOPE"), range: .day)
        }
    }

    @Test func tuningCanBeUpdated() async throws {
        let mock = try provider()
        await mock.update(tuning: MockPriceProvider.Tuning(tickInterval: 2, volatilityMultiplier: 5))
        let tuning = await mock.tuning
        #expect(tuning == MockPriceProvider.Tuning(tickInterval: 2, volatilityMultiplier: 5))
    }
}
