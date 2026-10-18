import Foundation
import Testing
@testable import TradeOff

struct PriceSeriesGeneratorTests {
    private func definition(_ symbol: String = "AAPL") throws -> MockInstrumentDefinition {
        let market = try MockMarketDefinition.load()
        return try #require(market.instruments.first { $0.symbol == symbol })
    }

    private func series(_ range: ChartRange, symbol: String = "AAPL") throws -> [Candlestick] {
        PriceSeriesGenerator.candles(
            for: try definition(symbol),
            range: range,
            anchor: TestSupport.decimal("227.4"),
            now: TestSupport.referenceDate
        )
    }

    @Test func producesTheConfiguredNumberOfCandlesPerRange() throws {
        for range in ChartRange.allCases {
            #expect(try series(range).count == range.candleCount)
        }
    }

    @Test func isDeterministicForSameInputs() throws {
        #expect(try series(.month) == series(.month))
    }

    @Test func differsBetweenInstruments() throws {
        let first = try series(.month, symbol: "AAPL")
        let second = try series(.month, symbol: "NVDA")
        #expect(first != second)
    }

    @Test func instrumentsAreStatisticallyIndependent() throws {
        func returns(_ symbol: String) throws -> [Double] {
            let closes = try series(.day, symbol: symbol).map { $0.close.doubleValue }
            return zip(closes, closes.dropFirst()).map { log($1 / $0) }
        }
        func correlation(_ first: [Double], _ second: [Double]) -> Double {
            let meanFirst = first.reduce(0, +) / Double(first.count)
            let meanSecond = second.reduce(0, +) / Double(second.count)
            var covariance = 0.0
            var varianceFirst = 0.0
            var varianceSecond = 0.0
            for (a, b) in zip(first, second) {
                covariance += (a - meanFirst) * (b - meanSecond)
                varianceFirst += (a - meanFirst) * (a - meanFirst)
                varianceSecond += (b - meanSecond) * (b - meanSecond)
            }
            return covariance / (varianceFirst * varianceSecond).squareRoot()
        }
        let apple = try returns("AAPL")
        let tesla = try returns("TSLA")
        let nvidia = try returns("NVDA")
        #expect(abs(correlation(apple, tesla)) < 0.25)
        #expect(abs(correlation(apple, nvidia)) < 0.25)
        #expect(abs(correlation(tesla, nvidia)) < 0.25)
    }

    @Test func lastCloseEqualsAnchor() throws {
        #expect(try series(.week).last?.close == TestSupport.decimal("227.4"))
    }

    @Test func candlesAreInternallyConsistent() throws {
        for candle in try series(.quarter) {
            #expect(candle.high >= candle.open)
            #expect(candle.high >= candle.close)
            #expect(candle.low <= candle.open)
            #expect(candle.low <= candle.close)
            #expect(candle.low > 0)
        }
    }

    @Test func timestampsAscendInIntervalSteps() throws {
        let candles = try series(.day)
        for (previous, next) in zip(candles, candles.dropFirst()) {
            #expect(next.time.timeIntervalSince(previous.time) == ChartRange.day.interval.seconds)
        }
    }

    @Test func tinyPricesKeepPrecision() throws {
        let candles = PriceSeriesGenerator.candles(
            for: try definition("BONK"),
            range: .week,
            anchor: TestSupport.decimal("0.00002145"),
            now: TestSupport.referenceDate
        )
        #expect(candles.allSatisfy { $0.low > 0 })
        #expect(candles.last?.close == TestSupport.decimal("0.00002145"))
    }

    @Test func candleCanAbsorbLivePrice() throws {
        let candle = try #require(try series(.day).last)
        let higher = candle.applying(price: candle.high + 1)
        #expect(higher.close == candle.high + 1)
        #expect(higher.high == candle.high + 1)
        let lower = candle.applying(price: candle.low - 1)
        #expect(lower.low == candle.low - 1)
    }
}
