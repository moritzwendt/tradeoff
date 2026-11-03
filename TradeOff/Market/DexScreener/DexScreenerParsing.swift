import Foundation

struct LossyArray<Element: Decodable & Sendable>: Decodable, Sendable {
    private struct Skip: Decodable {
        init(from decoder: Decoder) throws {}
    }

    let elements: [Element]

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var result: [Element] = []
        while !container.isAtEnd {
            if let element = try? container.decode(Element.self) {
                result.append(element)
            } else {
                _ = try container.decode(Skip.self)
            }
        }
        elements = result
    }
}

struct DexPair: Decodable, Sendable {
    struct Token: Decodable, Sendable {
        let address: String
        let name: String
        let symbol: String
    }

    struct Liquidity: Decodable, Sendable {
        let usd: Double?
    }

    let chainId: String
    let pairAddress: String
    let baseToken: Token
    let quoteToken: Token
    let priceUsd: String?
    let liquidity: Liquidity?
    let volume: [String: Double]?
    let priceChange: [String: Double]?

    var price: Decimal? {
        guard let value = priceUsd.flatMap(Decimal.init(apiString:)), value > 0 else { return nil }
        return value
    }

    var liquidityUSD: Double {
        liquidity?.usd ?? 0
    }

    var volume24h: Double {
        volume?["h24"] ?? 0
    }

    var tokenRef: DexTokenRef {
        DexTokenRef(chain: chainId, address: baseToken.address)
    }
}

struct DexSearchResponse: Decodable, Sendable {
    let pairs: LossyArray<DexPair>?
}

enum DexParsing {
    static let syntheticSpread: Decimal = Decimal(string: "0.001") ?? 0

    static func pairs(fromTokens data: Data) throws -> [DexPair] {
        do {
            return try JSONDecoder().decode(LossyArray<DexPair>.self, from: data).elements
        } catch {
            throw ProviderError.invalidResponse(.dexScreener)
        }
    }

    static func pairs(fromSearch data: Data) throws -> [DexPair] {
        do {
            return try JSONDecoder().decode(DexSearchResponse.self, from: data).pairs?.elements ?? []
        } catch {
            throw ProviderError.invalidResponse(.dexScreener)
        }
    }

    static func bestPair(for ref: DexTokenRef, in pairs: [DexPair]) -> DexPair? {
        pairs
            .filter { $0.price != nil && ref.matches(chain: $0.chainId, address: $0.baseToken.address) }
            .max { $0.liquidityUSD < $1.liquidityUSD }
    }

    static func quote(from pair: DexPair, instrumentID: InstrumentID, at now: Date) -> Quote? {
        guard let price = pair.price else { return nil }
        let half = price * syntheticSpread / 2

        var previousClose = price
        if let change = pair.priceChange?["h24"], change > -99.9 {
            let factor = 1 + Decimal(change, scale: 6) / 100
            previousClose = (price / factor).roundedToSignificantDigits(10)
        }

        let liquidity = pair.liquidityUSD > 0 ? Decimal(pair.liquidityUSD, scale: 2) : nil
        return Quote(
            instrumentID: instrumentID,
            bid: (price - half).roundedToSignificantDigits(10),
            ask: (price + half).roundedToSignificantDigits(10),
            last: price,
            previousClose: previousClose,
            dayHigh: nil,
            dayLow: nil,
            volume24h: pair.volume?["h24"].map { Decimal($0, scale: 2) },
            liquidityUSD: liquidity,
            timestamp: now,
            source: .dexScreener,
            quality: .live,
            isSyntheticSpread: true
        )
    }

    static func searchResults(from pairs: [DexPair]) -> [Instrument] {
        var best: [String: DexPair] = [:]
        for pair in pairs {
            guard
                pair.price != nil,
                pair.liquidityUSD >= DexScreenerCatalog.minimumSearchLiquidity,
                !DexScreenerCatalog.excludedSymbols.contains(pair.baseToken.symbol.uppercased()),
                !pair.baseToken.address.isEmpty
            else { continue }
            let key = "\(pair.chainId.lowercased()):\(pair.baseToken.address.hasPrefix("0x") ? pair.baseToken.address.lowercased() : pair.baseToken.address)"
            if let existing = best[key], existing.liquidityUSD >= pair.liquidityUSD { continue }
            best[key] = pair
        }
        return best.values
            .sorted { lhs, rhs in
                if lhs.volume24h != rhs.volume24h { return lhs.volume24h > rhs.volume24h }
                return lhs.liquidityUSD > rhs.liquidityUSD
            }
            .prefix(DexScreenerCatalog.searchLimit)
            .map {
                DexScreenerCatalog.instrument(symbol: $0.baseToken.symbol, name: $0.baseToken.name, ref: $0.tokenRef)
            }
    }
}

enum GeckoTerminalOHLCV {
    struct Request: Equatable, Sendable {
        let timeframe: String
        let aggregate: Int
        let limit: Int
    }

    private struct Response: Decodable {
        struct Payload: Decodable {
            struct Attributes: Decodable {
                let ohlcv_list: [[Double]]
            }

            let attributes: Attributes
        }

        let data: Payload
    }

    static func request(for range: ChartRange) -> Request {
        switch range {
        case .day: Request(timeframe: "minute", aggregate: 5, limit: 288)
        case .week: Request(timeframe: "hour", aggregate: 1, limit: 168)
        case .month: Request(timeframe: "hour", aggregate: 4, limit: 180)
        case .quarter: Request(timeframe: "day", aggregate: 1, limit: 90)
        case .year: Request(timeframe: "day", aggregate: 1, limit: 365)
        case .max: Request(timeframe: "day", aggregate: 1, limit: 1000)
        }
    }

    static func parse(_ data: Data) throws -> [Candlestick] {
        let response: Response
        do {
            response = try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw ProviderError.invalidResponse(.dexScreener)
        }
        return response.data.attributes.ohlcv_list
            .compactMap { row -> Candlestick? in
                guard row.count >= 6 else { return nil }
                return Candlestick(
                    time: Date(timeIntervalSince1970: row[0]),
                    open: decimal(row[1]),
                    high: decimal(row[2]),
                    low: decimal(row[3]),
                    close: decimal(row[4]),
                    volume: decimal(row[5])
                )
            }
            .sorted { $0.time < $1.time }
    }

    private static func decimal(_ value: Double) -> Decimal {
        Decimal(apiString: String(value)) ?? Decimal(value, scale: 18)
    }
}
