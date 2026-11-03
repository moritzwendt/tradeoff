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
}
