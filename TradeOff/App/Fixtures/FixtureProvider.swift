#if DEBUG
import Foundation

struct FixtureEntry: Sendable {
    let instrument: Instrument
    let price: Decimal
    let previousClose: Decimal
    let liquidity: Decimal?
    let inCatalog: Bool
}

enum FixtureMarket {
    private static func stock(_ symbol: String, _ name: String, _ price: String, _ previous: String, etf: Bool = false, catalog: Bool = true) -> FixtureEntry {
        FixtureEntry(
            instrument: FinnhubCatalog.instrument(symbol: symbol, name: name, assetClass: etf ? .etf : .stock),
            price: Decimal(string: price) ?? 0,
            previousClose: Decimal(string: previous) ?? 0,
            liquidity: nil,
            inCatalog: catalog
        )
    }

    private static func coin(_ base: String, _ name: String, _ price: String, _ previous: String, catalog: Bool = true) -> FixtureEntry {
        FixtureEntry(
            instrument: BinanceCatalog.listing(base: base, name: name).instrument,
            price: Decimal(string: price) ?? 0,
            previousClose: Decimal(string: previous) ?? 0,
            liquidity: nil,
            inCatalog: catalog
        )
    }

    private static func meme(_ symbol: String, _ name: String, _ chain: String, _ address: String, _ price: String, _ previous: String) -> FixtureEntry {
        FixtureEntry(
            instrument: DexScreenerCatalog.instrument(symbol: symbol, name: name, ref: DexTokenRef(chain: chain, address: address)),
            price: Decimal(string: price) ?? 0,
            previousClose: Decimal(string: previous) ?? 0,
            liquidity: 3_000_000,
            inCatalog: true
        )
    }

    static let finnhub: [FixtureEntry] = [
        stock("AAPL", "Apple", "338.32", "344.63"),
        stock("MSFT", "Microsoft", "507.12", "521.90"),
        stock("NVDA", "Nvidia", "202.06", "204.64"),
        stock("TSLA", "Tesla", "403.82", "399.80"),
        stock("AMZN", "Amazon", "245.63", "240.34"),
        stock("VOO", "Vanguard S&P 500", "691.32", "694.81", etf: true),
        stock("QQQ", "Invesco QQQ", "681.09", "690.50", etf: true),
        stock("AMAT", "Applied Materials Inc", "212.40", "209.10", catalog: false),
        stock("AMD", "Advanced Micro Devices", "164.75", "160.20", catalog: false),
        stock("BRKB", "Berkshire Hathaway Class B mit sehr langem Namen", "478.10", "476.00", catalog: false)
    ]

    static let binance: [FixtureEntry] = [
        coin("BTC", "Bitcoin", "77100.50", "78128.00"),
        coin("ETH", "Ethereum", "2258.76", "2271.38"),
        coin("SOL", "Solana", "92.30", "94.10"),
        coin("DOGE", "Dogecoin", "0.07442", "0.07536"),
        coin("APE", "ApeCoin", "0.5120", "0.5010", catalog: false)
    ]

    static let dexScreener: [FixtureEntry] = [
        meme("PEPE", "Pepe", "ethereum", "0xPEPE", "0.000004804", "0.000004891"),
        meme("BONK", "Bonk", "solana", "BONKADDR", "0.000002795", "0.000002900"),
        meme("WIF", "dogwifhat", "solana", "WIFADDR", "0.1689", "0.1752")
    ]
}

actor FixtureProvider: PriceProvider {
    struct Behavior: Sendable {
        var snapshotDelay: Duration = .zero
        var historyDelay: Duration = .zero
        var offline = false
    }

    nonisolated let id: ProviderID
    nonisolated let capabilities: ProviderCapabilities
    nonisolated var availability: ProviderAvailability { .ready }

    private let entries: [FixtureEntry]
    private let behavior: Behavior

    init(id: ProviderID, entries: [FixtureEntry], assetClasses: Set<AssetClass>, behavior: Behavior) {
        self.id = id
        self.entries = entries
        self.behavior = behavior
        capabilities = ProviderCapabilities(
            hasRealBidAsk: id == .binance,
            hasHistory: true,
            hasLiquidity: id == .dexScreener,
            isDelayed: false,
            requiresAPIKey: false,
            supportedAssetClasses: assetClasses,
            pollInterval: nil
        )
    }

    func catalog() -> [Instrument] {
        entries.filter(\.inCatalog).map(\.instrument)
    }

    func search(query: String) async throws -> [Instrument] {
        if behavior.offline { throw ProviderError.network(id) }
        try? await Task.sleep(for: behavior.snapshotDelay)
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return catalog() }
        return entries
            .map(\.instrument)
            .filter { $0.symbol.lowercased().contains(needle) || $0.name.lowercased().contains(needle) }
    }

    func snapshot(for instruments: [Instrument]) async throws -> [Quote] {
        try? await Task.sleep(for: behavior.snapshotDelay)
        if behavior.offline { throw ProviderError.network(id) }
        return instruments.compactMap { instrument in
            entries.first { $0.instrument.id == instrument.id }.map { makeQuote($0) }
        }
    }

    func quotes(for instruments: [Instrument]) async -> AsyncStream<ProviderEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: ProviderEvent.self, bufferingPolicy: .bufferingNewest(64))
        let task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { break }
                if let quotes = try? await self.snapshot(for: instruments) {
                    for quote in quotes { continuation.yield(.quote(quote)) }
                }
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
        return stream
    }

    func history(for instrument: Instrument, range: ChartRange) async throws -> [Candlestick] {
        try? await Task.sleep(for: behavior.historyDelay)
        if behavior.offline { throw ProviderError.network(id) }
        guard let entry = entries.first(where: { $0.instrument.id == instrument.id }) else {
            throw ProviderError.unknownInstrument(instrument.id)
        }
        return Self.candles(for: entry, range: range)
    }

    private func makeQuote(_ entry: FixtureEntry) -> Quote {
        let spread = entry.price * Decimal(string: "0.0002")!
        return Quote(
            instrumentID: entry.instrument.id,
            bid: entry.price - spread,
            ask: entry.price + spread,
            last: entry.price,
            previousClose: entry.previousClose,
            dayHigh: id == .dexScreener ? nil : entry.price * Decimal(string: "1.012")!,
            dayLow: id == .dexScreener ? nil : entry.price * Decimal(string: "0.985")!,
            volume24h: nil,
            liquidityUSD: entry.liquidity,
            timestamp: Date(),
            source: id,
            quality: .live,
            isSyntheticSpread: id != .binance
        )
    }

    static func candles(for entry: FixtureEntry, range: ChartRange) -> [Candlestick] {
        let count = min(range.candleCount, 140)
        let seed = Double(entry.instrument.symbol.unicodeScalars.reduce(0) { $0 + Int($1.value) })
        let end = entry.price.doubleValue
        let start = entry.previousClose.doubleValue
        let now = Date()
        return (0..<count).map { index in
            let progress = Double(index) / Double(count - 1)
            let wave = sin(Double(index) / 7 + seed) * 0.012 + sin(Double(index) / 19 + seed / 3) * 0.02
            let base = (start + (end - start) * progress) * (1 + wave * (1 - progress * 0.6))
            let close = index == count - 1 ? end : base
            let open = index == 0 ? start : (start + (end - start) * (progress - 1 / Double(count))) * (1 + wave)
            let time = now.addingTimeInterval(-range.interval.seconds * Double(count - 1 - index))
            return Candlestick(
                time: time,
                open: Decimal(open, scale: 8),
                high: Decimal(max(open, close) * 1.002, scale: 8),
                low: Decimal(min(open, close) * 0.998, scale: 8),
                close: Decimal(close, scale: 8),
                volume: 1_000
            )
        }
    }
}

extension AppEnvironment {
    static func uiTesting(arguments: [String]) throws -> AppEnvironment {
        let behavior = FixtureProvider.Behavior(
            snapshotDelay: arguments.contains("-uitest-slow") ? .seconds(2.5) : .zero,
            historyDelay: arguments.contains("-uitest-slow") ? .seconds(1.5) : .zero,
            offline: arguments.contains("-uitest-offline")
        )
        let registry = ProviderRegistry([
            FixtureProvider(id: .binance, entries: FixtureMarket.binance, assetClasses: [.crypto], behavior: behavior),
            FixtureProvider(id: .dexScreener, entries: FixtureMarket.dexScreener, assetClasses: [.memeCoin], behavior: behavior),
            FixtureProvider(id: .finnhub, entries: FixtureMarket.finnhub, assetClasses: [.stock, .etf], behavior: behavior)
        ])
        let defaults = UserDefaults(suiteName: "tradeoff.uitest.\(UUID().uuidString)") ?? .standard
        let environment = try AppEnvironment(inMemory: true, defaults: defaults, registry: registry, launchTimeout: .seconds(4))
        if arguments.contains("-uitest-ignore-hours") {
            environment.settings.values.ignoreMarketHours = true
        }
        return environment
    }
}
#endif
