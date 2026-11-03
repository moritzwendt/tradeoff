import Foundation

struct DexTokenRef: Hashable, Sendable {
    let chain: String
    let address: String

    var providerSymbol: String {
        "\(chain):\(address)"
    }

    init(chain: String, address: String) {
        self.chain = chain
        self.address = address
    }

    init?(providerSymbol: String) {
        guard let separator = providerSymbol.firstIndex(of: ":") else { return nil }
        let chain = String(providerSymbol[..<separator])
        let address = String(providerSymbol[providerSymbol.index(after: separator)...])
        guard !chain.isEmpty, !address.isEmpty else { return nil }
        self.init(chain: chain, address: address)
    }

    func matches(chain candidateChain: String, address candidateAddress: String) -> Bool {
        guard chain.lowercased() == candidateChain.lowercased() else { return false }
        return Self.sameAddress(address, candidateAddress)
    }

    static func sameAddress(_ lhs: String, _ rhs: String) -> Bool {
        lhs.hasPrefix("0x") ? lhs.lowercased() == rhs.lowercased() : lhs == rhs
    }
}

enum DexScreenerCatalog {
    struct Entry: Sendable {
        let symbol: String
        let name: String
        let ref: DexTokenRef
    }

    static let featured: [Entry] = [
        Entry(symbol: "BONK", name: "Bonk", ref: DexTokenRef(chain: "solana", address: "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263")),
        Entry(symbol: "WIF", name: "dogwifhat", ref: DexTokenRef(chain: "solana", address: "EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm")),
        Entry(symbol: "PEPE", name: "Pepe", ref: DexTokenRef(chain: "ethereum", address: "0x6982508145454Ce325dDbE47a25d4ec3d2311933")),
        Entry(symbol: "POPCAT", name: "Popcat", ref: DexTokenRef(chain: "solana", address: "7GCihgDB8fe6KNjn2MYtkzZcRjQy3t9GHdC8uHYmW2hr")),
        Entry(symbol: "SHIB", name: "Shiba Inu", ref: DexTokenRef(chain: "ethereum", address: "0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE")),
        Entry(symbol: "BRETT", name: "Brett", ref: DexTokenRef(chain: "base", address: "0x532f27101965dd16442E59d40670FaF5eBB142E4")),
        Entry(symbol: "FLOKI", name: "Floki", ref: DexTokenRef(chain: "ethereum", address: "0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E"))
    ]

    static let chainLabels: [String: String] = [
        "solana": "Solana",
        "ethereum": "Ethereum",
        "base": "Base",
        "bsc": "BNB Chain",
        "arbitrum": "Arbitrum",
        "polygon": "Polygon",
        "avalanche": "Avalanche",
        "optimism": "Optimism"
    ]

    static let geckoNetworks: [String: String] = [
        "solana": "solana",
        "ethereum": "eth",
        "base": "base",
        "bsc": "bsc",
        "arbitrum": "arbitrum",
        "polygon": "polygon_pos",
        "avalanche": "avax",
        "optimism": "optimism"
    ]

    static let excludedSymbols: Set<String> = [
        "SOL", "WSOL", "ETH", "WETH", "BTC", "WBTC", "CBBTC", "BNB", "WBNB", "AVAX", "WAVAX",
        "POL", "WPOL", "MATIC", "WMATIC", "USDC", "USDT", "DAI", "USDS", "USDE", "PYUSD", "FDUSD"
    ]

    static let minimumSearchLiquidity: Double = 10_000
    static let searchLimit = 20

    static func chainLabel(for chain: String) -> String {
        chainLabels[chain.lowercased()] ?? chain.capitalized
    }

    static func instrument(symbol: String, name: String, ref: DexTokenRef) -> Instrument {
        Instrument(
            id: Instrument.makeID(provider: .dexScreener, symbol: ref.providerSymbol),
            symbol: displaySymbol(symbol),
            name: name,
            assetClass: .memeCoin,
            provider: .dexScreener,
            providerSymbol: ref.providerSymbol,
            currency: "USD"
        )
    }

    static var featuredInstruments: [Instrument] {
        featured.map { instrument(symbol: $0.symbol, name: $0.name, ref: $0.ref) }
    }

    static func displaySymbol(_ raw: String) -> String {
        let trimmed = raw
            .trimmingCharacters(in: CharacterSet(charactersIn: "$").union(.whitespacesAndNewlines))
        return String(trimmed.prefix(12))
    }
}

extension Instrument {
    var network: String? {
        guard provider == .dexScreener, let ref = DexTokenRef(providerSymbol: providerSymbol) else { return nil }
        return DexScreenerCatalog.chainLabel(for: ref.chain)
    }
}
