import Foundation

struct BinanceTicker24h: Decodable, Sendable {
    let symbol: String
    let lastPrice: String
    let bidPrice: String
    let askPrice: String
    let openPrice: String
    let highPrice: String
    let lowPrice: String
    let quoteVolume: String?

    func quote(instrumentID: InstrumentID, at now: Date) -> Quote? {
        guard
            let bid = Decimal(apiString: bidPrice),
            let ask = Decimal(apiString: askPrice),
            let last = Decimal(apiString: lastPrice),
            bid > 0, ask >= bid, last > 0
        else { return nil }
        let open = Decimal(apiString: openPrice) ?? last
        return Quote(
            instrumentID: instrumentID,
            bid: bid,
            ask: ask,
            last: last,
            previousClose: open > 0 ? open : last,
            dayHigh: Decimal(apiString: highPrice),
            dayLow: Decimal(apiString: lowPrice),
            volume24h: quoteVolume.flatMap(Decimal.init(apiString:)),
            liquidityUSD: nil,
            timestamp: now,
            source: .binance,
            quality: .live,
            isSyntheticSpread: false
        )
    }
}

struct BinanceExchangeInfo: Decodable, Sendable {
    struct Symbol: Decodable, Sendable {
        let symbol: String
        let status: String
        let baseAsset: String
        let quoteAsset: String
        let isSpotTradingAllowed: Bool
    }

    let symbols: [Symbol]

    var listings: [BinanceListing] {
        symbols
            .filter {
                $0.status == "TRADING"
                    && $0.isSpotTradingAllowed
                    && $0.quoteAsset == BinanceCatalog.quoteAsset
                    && !BinanceCatalog.excludedBases.contains($0.baseAsset)
            }
            .map { BinanceCatalog.listing(base: $0.baseAsset) }
    }
}

enum BinanceStreamMessage: Equatable, Sendable {
    case book(symbol: String, bid: Decimal, ask: Decimal)
    case mini(symbol: String, last: Decimal, open: Decimal, high: Decimal, low: Decimal, quoteVolume: Decimal?)

    private struct Envelope: Decodable {
        struct Payload: Decodable {
            let s: String?
            let b: String?
            let a: String?
            let c: String?
            let o: String?
            let h: String?
            let l: String?
            let q: String?
        }

        let data: Payload
    }

    static func parse(_ data: Data) -> BinanceStreamMessage? {
        guard let payload = (try? JSONDecoder().decode(Envelope.self, from: data))?.data,
              let symbol = payload.s?.uppercased()
        else { return nil }

        if let bid = payload.b.flatMap(Decimal.init(apiString:)),
           let ask = payload.a.flatMap(Decimal.init(apiString:)) {
            return .book(symbol: symbol, bid: bid, ask: ask)
        }

        if let last = payload.c.flatMap(Decimal.init(apiString:)),
           let open = payload.o.flatMap(Decimal.init(apiString:)),
           let high = payload.h.flatMap(Decimal.init(apiString:)),
           let low = payload.l.flatMap(Decimal.init(apiString:)) {
            return .mini(
                symbol: symbol,
                last: last,
                open: open,
                high: high,
                low: low,
                quoteVolume: payload.q.flatMap(Decimal.init(apiString:))
            )
        }
        return nil
    }
}

enum BinanceKlines {
    static func interval(for interval: CandleInterval) -> String {
        switch interval {
        case .minutes5: "5m"
        case .minutes30: "30m"
        case .hours4: "4h"
        case .day: "1d"
        case .week: "1w"
        }
    }

    static func parse(_ data: Data) throws -> [Candlestick] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
            throw ProviderError.invalidResponse(.binance)
        }
        return rows.compactMap { row -> Candlestick? in
            guard
                row.count >= 6,
                let openTime = (row[0] as? NSNumber)?.doubleValue,
                let open = (row[1] as? String).flatMap(Decimal.init(apiString:)),
                let high = (row[2] as? String).flatMap(Decimal.init(apiString:)),
                let low = (row[3] as? String).flatMap(Decimal.init(apiString:)),
                let close = (row[4] as? String).flatMap(Decimal.init(apiString:)),
                let volume = (row[5] as? String).flatMap(Decimal.init(apiString:))
            else { return nil }
            return Candlestick(
                time: Date(timeIntervalSince1970: openTime / 1000),
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume
            )
        }
    }
}
