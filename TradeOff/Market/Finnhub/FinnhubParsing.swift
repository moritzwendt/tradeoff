import Foundation

struct FinnhubQuote: Decodable, Sendable {
    let c: Double?
    let h: Double?
    let l: Double?
    let o: Double?
    let pc: Double?

    func quote(instrumentID: InstrumentID, at now: Date) -> Quote? {
        guard let current = c, current > 0, let price = Decimal(apiString: String(current)) else { return nil }
        let half = price * FinnhubParsing.syntheticSpread / 2
        let previous = pc.flatMap { $0 > 0 ? Decimal(apiString: String($0)) : nil }
        let high = h.flatMap { $0 > 0 ? Decimal(apiString: String($0)) : nil }
        let low = l.flatMap { $0 > 0 ? Decimal(apiString: String($0)) : nil }
        return Quote(
            instrumentID: instrumentID,
            bid: (price - half).roundedToSignificantDigits(8),
            ask: (price + half).roundedToSignificantDigits(8),
            last: price,
            previousClose: previous ?? price,
            dayHigh: high,
            dayLow: low,
            volume24h: nil,
            liquidityUSD: nil,
            timestamp: now,
            source: .finnhub,
            quality: .live,
            isSyntheticSpread: true
        )
    }
}

struct FinnhubSearchResponse: Decodable, Sendable {
    struct Item: Decodable, Sendable {
        let description: String
        let symbol: String
        let type: String
    }

    let result: LossyArray<Item>?
}

struct FinnhubCandles: Decodable, Sendable {
    let s: String
    let t: [Double]?
    let o: [Double]?
    let h: [Double]?
    let l: [Double]?
    let c: [Double]?
    let v: [Double]?
}

enum FinnhubParsing {
    static let syntheticSpread: Decimal = Decimal(string: "0.0005") ?? 0

    static func quote(_ data: Data) throws -> FinnhubQuote {
        do {
            return try JSONDecoder().decode(FinnhubQuote.self, from: data)
        } catch {
            throw ProviderError.invalidResponse(.finnhub)
        }
    }

    static func searchResults(_ data: Data) throws -> [Instrument] {
        let response: FinnhubSearchResponse
        do {
            response = try JSONDecoder().decode(FinnhubSearchResponse.self, from: data)
        } catch {
            throw ProviderError.invalidResponse(.finnhub)
        }
        var seen = Set<String>()
        var instruments: [Instrument] = []
        for item in response.result?.elements ?? [] {
            guard
                FinnhubCatalog.isUSSymbol(item.symbol),
                let assetClass = FinnhubCatalog.assetClass(forType: item.type),
                seen.insert(item.symbol).inserted
            else { continue }
            instruments.append(
                FinnhubCatalog.instrument(
                    symbol: item.symbol,
                    name: FinnhubCatalog.displayName(item.description, symbol: item.symbol),
                    assetClass: assetClass
                )
            )
        }
        return Array(instruments.prefix(FinnhubCatalog.searchLimit))
    }

    static func candles(_ data: Data) throws -> [Candlestick] {
        let response: FinnhubCandles
        do {
            response = try JSONDecoder().decode(FinnhubCandles.self, from: data)
        } catch {
            throw ProviderError.invalidResponse(.finnhub)
        }
        guard
            response.s == "ok",
            let times = response.t, let opens = response.o, let highs = response.h,
            let lows = response.l, let closes = response.c, let volumes = response.v
        else { return [] }
        let count = min(times.count, opens.count, highs.count, lows.count, closes.count, volumes.count)
        return (0..<count)
            .compactMap { index -> Candlestick? in
                guard
                    let open = Decimal(apiString: String(opens[index])),
                    let high = Decimal(apiString: String(highs[index])),
                    let low = Decimal(apiString: String(lows[index])),
                    let close = Decimal(apiString: String(closes[index])),
                    let volume = Decimal(apiString: String(volumes[index]))
                else { return nil }
                return Candlestick(
                    time: Date(timeIntervalSince1970: times[index]),
                    open: open,
                    high: high,
                    low: low,
                    close: close,
                    volume: volume
                )
            }
            .sorted { $0.time < $1.time }
    }

    struct CandleRequest: Equatable, Sendable {
        let resolution: String
        let lookback: TimeInterval
    }

    static func candleRequest(for range: ChartRange) -> CandleRequest {
        switch range {
        case .day: CandleRequest(resolution: "5", lookback: 5 * 86_400)
        case .week: CandleRequest(resolution: "30", lookback: 9 * 86_400)
        case .month: CandleRequest(resolution: "60", lookback: 30 * 86_400)
        case .quarter: CandleRequest(resolution: "D", lookback: 90 * 86_400)
        case .year: CandleRequest(resolution: "D", lookback: 365 * 86_400)
        case .max: CandleRequest(resolution: "W", lookback: 5 * 365 * 86_400)
        }
    }
}
