import Foundation

enum FinnhubCatalog {
    struct Entry: Sendable {
        let symbol: String
        let name: String
        let assetClass: AssetClass
    }

    static let featured: [Entry] = [
        Entry(symbol: "AAPL", name: "Apple", assetClass: .stock),
        Entry(symbol: "MSFT", name: "Microsoft", assetClass: .stock),
        Entry(symbol: "NVDA", name: "Nvidia", assetClass: .stock),
        Entry(symbol: "TSLA", name: "Tesla", assetClass: .stock),
        Entry(symbol: "AMZN", name: "Amazon", assetClass: .stock),
        Entry(symbol: "VOO", name: "Vanguard S&P 500", assetClass: .etf),
        Entry(symbol: "QQQ", name: "Invesco QQQ", assetClass: .etf),
        Entry(symbol: "SPY", name: "SPDR S&P 500", assetClass: .etf)
    ]

    static let searchLimit = 20

    static func instrument(symbol: String, name: String, assetClass: AssetClass) -> Instrument {
        Instrument(
            id: Instrument.makeID(provider: .finnhub, symbol: symbol),
            symbol: symbol,
            name: name,
            assetClass: assetClass,
            provider: .finnhub,
            providerSymbol: symbol,
            currency: "USD"
        )
    }

    static var featuredInstruments: [Instrument] {
        featured.map { instrument(symbol: $0.symbol, name: $0.name, assetClass: $0.assetClass) }
    }

    static func assetClass(forType type: String) -> AssetClass? {
        switch type {
        case "Common Stock": .stock
        case "ETP": .etf
        default: nil
        }
    }

    static func isUSSymbol(_ symbol: String) -> Bool {
        guard (1...5).contains(symbol.count) else { return false }
        return symbol.allSatisfy { $0.isASCII && $0.isUppercase && $0.isLetter }
    }

    static func displayName(_ description: String, symbol: String) -> String {
        if let featured = featured.first(where: { $0.symbol == symbol }) {
            return featured.name
        }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? symbol : trimmed.localizedCapitalized
    }
}
