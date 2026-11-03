import Foundation

struct AlpacaBar: Decodable, Sendable {
    let t: String
    let o: Double
    let h: Double
    let l: Double
    let c: Double
    let v: Double
}

struct AlpacaBarsResponse: Decodable, Sendable {
    let bars: [String: LossyArray<AlpacaBar>]?
}

enum AlpacaParsing {
    struct BarsRequest: Equatable, Sendable {
        let timeframe: String
        let lookback: TimeInterval
        let intradayBucket: TimeInterval?

        init(timeframe: String, lookback: TimeInterval, intradayBucket: TimeInterval? = nil) {
            self.timeframe = timeframe
            self.lookback = lookback
            self.intradayBucket = intradayBucket
        }
    }

    static let recentDataDelay: TimeInterval = 16 * 60
    static let barLimit = 10_000

    static func barsRequest(for range: ChartRange) -> BarsRequest {
        switch range {
        case .day: BarsRequest(timeframe: "5Min", lookback: 5 * 86_400, intradayBucket: 300)
        case .week: BarsRequest(timeframe: "30Min", lookback: 9 * 86_400, intradayBucket: 1_800)
        case .month: BarsRequest(timeframe: "1Hour", lookback: 30 * 86_400, intradayBucket: 3_600)
        case .quarter: BarsRequest(timeframe: "1Day", lookback: 90 * 86_400)
        case .year: BarsRequest(timeframe: "1Day", lookback: 365 * 86_400)
        case .max: BarsRequest(timeframe: "1Week", lookback: 5 * 365 * 86_400)
        }
    }

    static func timestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    static func candles(_ data: Data, symbol: String) throws -> [Candlestick] {
        let response: AlpacaBarsResponse
        do {
            response = try JSONDecoder().decode(AlpacaBarsResponse.self, from: data)
        } catch {
            throw ProviderError.invalidResponse(.alpaca)
        }
        let bars = response.bars?[symbol]?.elements ?? []
        return bars
            .compactMap { bar -> Candlestick? in
                guard
                    let time = parseDate(bar.t),
                    let open = Decimal(apiString: String(bar.o)),
                    let high = Decimal(apiString: String(bar.h)),
                    let low = Decimal(apiString: String(bar.l)),
                    let close = Decimal(apiString: String(bar.c)),
                    let volume = Decimal(apiString: String(bar.v))
                else { return nil }
                return Candlestick(time: time, open: open, high: high, low: low, close: close, volume: volume)
            }
            .sorted { $0.time < $1.time }
    }

    static func parseDate(_ text: String) -> Date? {
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: text) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }
}
