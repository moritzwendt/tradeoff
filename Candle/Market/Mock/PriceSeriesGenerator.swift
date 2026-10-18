import Foundation

enum PriceSeriesGenerator {
    private struct RawCandle {
        var open: Double
        var high: Double
        var low: Double
        var close: Double
        var volume: Double
    }

    static func candles(
        for definition: MockInstrumentDefinition,
        range: ChartRange,
        anchor: Decimal,
        now: Date
    ) -> [Candlestick] {
        let count = range.candleCount
        let interval = range.interval.seconds
        let stepFraction = interval / 86_400
        let sigma = definition.dailyVolatility * stepFraction.squareRoot()
        let drift = definition.dailyDrift * stepFraction
        let rangeIndex = UInt64(ChartRange.allCases.firstIndex(of: range) ?? 0)
        var generator = SplitMix64(seed: definition.seed &* 1_000 &+ rangeIndex)

        let substeps = 4
        var raw: [RawCandle] = []
        raw.reserveCapacity(count)
        var price = 1.0
        for _ in 0..<count {
            let open = price
            var high = open
            var low = open
            for _ in 0..<substeps {
                let shock = generator.nextGaussian()
                price *= exp(drift / Double(substeps) + sigma / Double(substeps).squareRoot() * shock)
                high = max(high, price)
                low = min(low, price)
            }
            let upperWick = 1 + abs(generator.nextGaussian()) * sigma * 0.2
            let lowerWick = 1 + abs(generator.nextGaussian()) * sigma * 0.2
            raw.append(
                RawCandle(
                    open: open,
                    high: max(high, open, price) * upperWick,
                    low: min(low, open, price) / lowerWick,
                    close: price,
                    volume: 0.6 + generator.nextUnit() * 0.8
                )
            )
        }

        guard let lastClose = raw.last?.close, lastClose > 0 else { return [] }
        let scale = anchor.doubleValue / lastClose
        let end = (now.timeIntervalSince1970 / interval).rounded(.down) * interval

        return raw.enumerated().map { index, item in
            Candlestick(
                time: Date(timeIntervalSince1970: end - Double(count - 1 - index) * interval),
                open: money(item.open * scale),
                high: money(item.high * scale),
                low: money(item.low * scale),
                close: index == count - 1 ? anchor.marketRounded() : money(item.close * scale),
                volume: Decimal(item.volume * 1_000_000, scale: 0)
            )
        }
    }

    private static func money(_ value: Double) -> Decimal {
        Decimal(value, scale: 12).marketRounded()
    }
}
