import Foundation

struct BinanceListing: Equatable, Sendable {
    let symbol: String
    let base: String
    let name: String

    var instrument: Instrument {
        Instrument(
            id: Instrument.makeID(provider: .binance, symbol: symbol),
            symbol: base,
            name: name,
            assetClass: .crypto,
            provider: .binance,
            providerSymbol: symbol,
            currency: "USD"
        )
    }
}

enum BinanceCatalog {
    static let quoteAsset = "USDT"

    static let featured: [BinanceListing] = [
        ("BTC", "Bitcoin"),
        ("ETH", "Ethereum"),
        ("SOL", "Solana"),
        ("BNB", "BNB"),
        ("XRP", "XRP"),
        ("ADA", "Cardano"),
        ("DOGE", "Dogecoin"),
        ("AVAX", "Avalanche"),
        ("LINK", "Chainlink"),
        ("DOT", "Polkadot"),
        ("LTC", "Litecoin"),
        ("TRX", "TRON")
    ].map { listing(base: $0.0, name: $0.1) }

    static let excludedBases: Set<String> = [
        "USDC", "FDUSD", "TUSD", "USDP", "DAI", "USD1", "BUSD", "XUSD", "RLUSD", "USDE",
        "EUR", "EURI", "AEUR", "GBP", "TRY", "BRL", "AUD", "RUB", "UAH", "PLN", "RON", "ARS", "JPY", "CZK", "MXN", "COP"
    ]

    static func listing(base: String, name: String? = nil) -> BinanceListing {
        BinanceListing(symbol: base + quoteAsset, base: base, name: name ?? featuredName(for: base) ?? base)
    }

    static func featuredName(for base: String) -> String? {
        featured.first { $0.base == base }?.name
    }

    static func search(_ query: String, in listings: [BinanceListing], limit: Int = 25) -> [BinanceListing] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return Array(featured.prefix(limit)) }

        func rank(_ listing: BinanceListing) -> Int? {
            let base = listing.base.lowercased()
            let name = listing.name.lowercased()
            if base == needle { return 0 }
            if base.hasPrefix(needle) { return 1 }
            if name.hasPrefix(needle) { return 2 }
            if base.contains(needle) || name.contains(needle) { return 3 }
            return nil
        }

        return listings
            .compactMap { listing in rank(listing).map { (listing, $0) } }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                let lhsFeatured = featuredName(for: lhs.0.base) != nil
                let rhsFeatured = featuredName(for: rhs.0.base) != nil
                if lhsFeatured != rhsFeatured { return lhsFeatured }
                return lhs.0.base < rhs.0.base
            }
            .prefix(limit)
            .map(\.0)
    }
}
