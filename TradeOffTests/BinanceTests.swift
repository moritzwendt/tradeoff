import Foundation
import Testing
@testable import TradeOff

struct BinanceParsingTests {
    private func tickers() throws -> [BinanceTicker24h] {
        try JSONDecoder().decode([BinanceTicker24h].self, from: Data(BinanceFixtures.tickers24h.utf8))
    }

    @Test func tickerBecomesLiveQuoteWithRealBidAsk() throws {
        let eth = try #require(try tickers().first { $0.symbol == "ETHUSDT" })
        let quote = try #require(eth.quote(instrumentID: "binance:ETHUSDT", at: FixedClock.epoch))
        #expect(quote.bid == TestSupport.decimal("2258.75"))
        #expect(quote.ask == TestSupport.decimal("2258.76"))
        #expect(quote.last == TestSupport.decimal("2258.76"))
        #expect(quote.previousClose == TestSupport.decimal("2271.38"))
        #expect(quote.dayHigh == TestSupport.decimal("2317.84"))
        #expect(quote.dayLow == TestSupport.decimal("2237.38"))
        #expect(quote.volume24h == TestSupport.decimal("559047618.255866"))
        #expect(quote.quality == .live)
        #expect(quote.source == .binance)
        #expect(!quote.isSyntheticSpread)
        #expect(quote.timestamp == FixedClock.epoch)
    }

    @Test func tickerWithoutBookIsRejected() throws {
        let json = #"[{"symbol":"XUSDT","lastPrice":"1","bidPrice":"0.00000000","askPrice":"0.00000000","openPrice":"1","highPrice":"1","lowPrice":"1","quoteVolume":"0"}]"#
        let ticker = try #require(try JSONDecoder().decode([BinanceTicker24h].self, from: Data(json.utf8)).first)
        #expect(ticker.quote(instrumentID: "binance:XUSDT", at: FixedClock.epoch) == nil)
    }

    @Test func parsesBookTickerMessage() {
        let message = BinanceStreamMessage.parse(Data(BinanceFixtures.bookMessage.utf8))
        #expect(message == .book(
            symbol: "BTCUSDT",
            bid: TestSupport.decimal("77150.1"),
            ask: TestSupport.decimal("77150.2")
        ))
    }

    @Test func parsesMiniTickerMessage() {
        let message = BinanceStreamMessage.parse(Data(BinanceFixtures.miniMessage.utf8))
        #expect(message == .mini(
            symbol: "BTCUSDT",
            last: TestSupport.decimal("77155.5"),
            open: TestSupport.decimal("78128"),
            high: TestSupport.decimal("78878.01"),
            low: TestSupport.decimal("76663.9"),
            quoteVolume: TestSupport.decimal("986095633.4316812")
        ))
    }

    @Test func ignoresUnknownOrBrokenMessages() {
        #expect(BinanceStreamMessage.parse(Data("not json".utf8)) == nil)
        #expect(BinanceStreamMessage.parse(Data(#"{"result":null,"id":1}"#.utf8)) == nil)
        #expect(BinanceStreamMessage.parse(Data(#"{"stream":"x","data":{"s":"BTCUSDT"}}"#.utf8)) == nil)
    }

    @Test func parsesKlinesInChronologicalOrder() throws {
        let candles = try BinanceKlines.parse(Data(BinanceFixtures.klines.utf8))
        #expect(candles.count == 3)
        #expect(candles[0].time == Date(timeIntervalSince1970: 1_793_491_200))
        #expect(candles[0].open == TestSupport.decimal("77582.02"))
        #expect(candles[0].high == TestSupport.decimal("78422.23"))
        #expect(candles[0].low == TestSupport.decimal("77517.2"))
        #expect(candles[0].close == TestSupport.decimal("78354"))
        #expect(candles[0].volume == TestSupport.decimal("6544.36057"))
        #expect(candles[2].close == TestSupport.decimal("77096.01"))
        #expect(candles.map(\.time) == candles.map(\.time).sorted())
    }

    @Test func rejectsKlinesThatAreNotAnArray() {
        #expect(throws: ProviderError.invalidResponse(.binance)) {
            _ = try BinanceKlines.parse(Data(#"{"code":-1121}"#.utf8))
        }
    }

    @Test func mapsChartIntervalsToBinanceIntervals() {
        #expect(BinanceKlines.interval(for: .minutes5) == "5m")
        #expect(BinanceKlines.interval(for: .minutes30) == "30m")
        #expect(BinanceKlines.interval(for: .hours4) == "4h")
        #expect(BinanceKlines.interval(for: .day) == "1d")
        #expect(BinanceKlines.interval(for: .week) == "1w")
    }

    @Test func exchangeInfoKeepsOnlyTradableUsdtCoins() throws {
        let info = try JSONDecoder().decode(BinanceExchangeInfo.self, from: Data(BinanceFixtures.exchangeInfo.utf8))
        let symbols = info.listings.map(\.symbol)
        #expect(symbols == ["BTCUSDT", "PEPEUSDT", "WIFUSDT", "SOLUSDT", "SOLVUSDT"])
    }
}

struct BinanceCatalogTests {
    private func listings() throws -> [BinanceListing] {
        try JSONDecoder().decode(BinanceExchangeInfo.self, from: Data(BinanceFixtures.exchangeInfo.utf8)).listings
    }

    @Test func featuredCoinsAreUsdtPairsWithBinanceIdentity() {
        let bitcoin = BinanceCatalog.featured[0].instrument
        #expect(bitcoin.id == "binance:BTCUSDT")
        #expect(bitcoin.symbol == "BTC")
        #expect(bitcoin.name == "Bitcoin")
        #expect(bitcoin.providerSymbol == "BTCUSDT")
        #expect(bitcoin.assetClass == .crypto)
        #expect(bitcoin.provider == .binance)
    }

    @Test func searchPrefersExactThenPrefixThenName() throws {
        let result = try BinanceCatalog.search("sol", in: listings()).map(\.base)
        #expect(result == ["SOL", "SOLV"])
    }

    @Test func searchMatchesFeaturedNames() throws {
        let result = try BinanceCatalog.search("bitcoin", in: listings()).map(\.base)
        #expect(result == ["BTC"])
    }

    @Test func searchFindsCoinsOutsideTheFeaturedList() throws {
        let result = try BinanceCatalog.search("pepe", in: listings())
        #expect(result.first?.symbol == "PEPEUSDT")
        #expect(result.first?.name == "PEPE")
    }

    @Test func emptySearchReturnsFeaturedCoins() throws {
        #expect(try BinanceCatalog.search("  ", in: listings()) == BinanceCatalog.featured)
    }

    @Test func searchWithoutMatchIsEmpty() throws {
        #expect(try BinanceCatalog.search("zzzz", in: listings()).isEmpty)
    }
}

struct BinanceQuoteBookTests {
    private func seeded() throws -> BinanceQuoteBook {
        let ticker = try #require(
            try JSONDecoder().decode([BinanceTicker24h].self, from: Data(BinanceFixtures.tickers24h.utf8)).first
        )
        let quote = try #require(ticker.quote(instrumentID: "binance:BTCUSDT", at: FixedClock.epoch))
        return BinanceQuoteBook(seed: ["BTCUSDT": quote])
    }

    @Test func bookUpdateReplacesBidAndAskOnly() throws {
        var book = try seeded()
        book.apply(.book(symbol: "BTCUSDT", bid: 77_000, ask: 77_001))
        let quote = try #require(book.quotes(at: FixedClock.epoch).first)
        #expect(quote.bid == 77_000)
        #expect(quote.ask == 77_001)
        #expect(quote.last == TestSupport.decimal("77140"))
    }

    @Test func miniUpdateReplacesStatistics() throws {
        var book = try seeded()
        book.apply(.mini(symbol: "BTCUSDT", last: 77_200, open: 78_000, high: 79_000, low: 76_000, quoteVolume: 5))
        let quote = try #require(book.quotes(at: FixedClock.epoch).first)
        #expect(quote.last == 77_200)
        #expect(quote.previousClose == 78_000)
        #expect(quote.dayHigh == 79_000)
        #expect(quote.dayLow == 76_000)
        #expect(quote.volume24h == 5)
        #expect(quote.bid == TestSupport.decimal("77140"))
    }

    @Test func crossedOrEmptyBooksAreIgnored() throws {
        var book = try seeded()
        book.apply(.book(symbol: "BTCUSDT", bid: 0, ask: 0))
        book.apply(.book(symbol: "BTCUSDT", bid: 77_010, ask: 77_000))
        let quote = try #require(book.quotes(at: FixedClock.epoch).first)
        #expect(quote.bid == TestSupport.decimal("77140"))
        #expect(quote.ask == TestSupport.decimal("77140.01"))
    }

    @Test func unknownSymbolsAreIgnored() throws {
        var book = try seeded()
        book.apply(.book(symbol: "ETHUSDT", bid: 1, ask: 2))
        #expect(book.quotes(at: FixedClock.epoch).count == 1)
    }

    @Test func drainingStampsQuotesWithCurrentTime() throws {
        let book = try seeded()
        let later = FixedClock.epoch.addingTimeInterval(20)
        let quote = try #require(book.quotes(at: later).first)
        #expect(quote.timestamp == later)
    }
}

struct BinanceLiveFeedTests {
    @Test func staleConnectionReturnsNothing() async throws {
        let feed = BinanceLiveFeed(book: BinanceQuoteBook(seed: [:]), now: FixedClock.epoch)
        let fresh = await feed.drain(at: FixedClock.epoch.addingTimeInterval(10), staleAfter: 45)
        #expect(fresh != nil)
        let stale = await feed.drain(at: FixedClock.epoch.addingTimeInterval(46), staleAfter: 45)
        #expect(stale == nil)
    }

    @Test func messagesAndPongsKeepConnectionAlive() async {
        let feed = BinanceLiveFeed(book: BinanceQuoteBook(seed: [:]), now: FixedClock.epoch)
        await feed.ingest(Data(BinanceFixtures.bookMessage.utf8), at: FixedClock.epoch.addingTimeInterval(40))
        #expect(await feed.drain(at: FixedClock.epoch.addingTimeInterval(80), staleAfter: 45) != nil)
        await feed.markAlive(at: FixedClock.epoch.addingTimeInterval(100))
        #expect(await feed.drain(at: FixedClock.epoch.addingTimeInterval(140), staleAfter: 45) != nil)
        #expect(await feed.receivedMessages == 1)
    }

    @Test func ingestAppliesMessagesToTheBook() async throws {
        let ticker = try #require(
            try JSONDecoder().decode([BinanceTicker24h].self, from: Data(BinanceFixtures.tickers24h.utf8)).first
        )
        let quote = try #require(ticker.quote(instrumentID: "binance:BTCUSDT", at: FixedClock.epoch))
        let feed = BinanceLiveFeed(book: BinanceQuoteBook(seed: ["BTCUSDT": quote]), now: FixedClock.epoch)
        await feed.ingest(Data(BinanceFixtures.bookMessage.utf8), at: FixedClock.epoch)
        let drained = try #require(await feed.drain(at: FixedClock.epoch, staleAfter: 45)?.first)
        #expect(drained.bid == TestSupport.decimal("77150.1"))
        #expect(drained.ask == TestSupport.decimal("77150.2"))
    }
}

struct BinanceProviderTests {
    private func provider(_ transport: StubTransport) -> BinanceProvider {
        BinanceProvider(
            http: HTTPClient(provider: .binance, transport: transport),
            clock: { FixedClock.epoch }
        )
    }

    private func instruments(_ bases: [String]) -> [Instrument] {
        bases.map { BinanceCatalog.listing(base: $0).instrument }
    }

    @Test func catalogListsFeaturedCoins() async {
        let items = await provider(StubTransport(body: "")).catalog()
        #expect(items.count == BinanceCatalog.featured.count)
        #expect(items.allSatisfy { $0.provider == .binance })
    }

    @Test func availabilityIsReadyWithoutKey() {
        let binance = provider(StubTransport(body: ""))
        #expect(binance.availability == .ready)
        #expect(!binance.capabilities.requiresAPIKey)
        #expect(binance.capabilities.hasRealBidAsk)
    }

    @Test func snapshotMapsTickersToInstruments() async throws {
        let transport = StubTransport(body: BinanceFixtures.tickers24h)
        let quotes = try await provider(transport).snapshot(for: instruments(["BTC", "ETH"]))
        #expect(Set(quotes.map(\.instrumentID)) == ["binance:BTCUSDT", "binance:ETHUSDT"])
        let url = try #require(transport.log.urls.first)
        #expect(url.path == "/api/v3/ticker/24hr")
        #expect(url.absoluteString.contains("BTCUSDT"))
    }

    @Test func snapshotSplitsLargeRequestsIntoChunks() async throws {
        let transport = StubTransport(body: "[]")
        let bases = (0..<45).map { "C\($0)" }
        _ = try await provider(transport).snapshot(for: instruments(bases))
        #expect(transport.log.urls.count == 3)
    }

    @Test func snapshotSkipsSymbolsBinanceRejects() async throws {
        let transport = StubTransport { url in
            let text = url.absoluteString
            if text.contains("BTCUSDT"), !text.contains("GONEUSDT") {
                return StubResponse(body: BinanceFixtures.tickers24h)
            }
            return StubResponse(status: 400, body: #"{"code":-1121,"msg":"Invalid symbol."}"#)
        }
        let quotes = try await provider(transport).snapshot(for: instruments(["BTC", "GONE"]))
        #expect(quotes.map(\.instrumentID) == ["binance:BTCUSDT"])
    }

    @Test func snapshotIgnoresInstrumentsFromOtherProviders() async throws {
        let transport = StubTransport(body: "[]")
        let foreign = TestSupport.instrument("AAPL", provider: .finnhub)
        let quotes = try await provider(transport).snapshot(for: [foreign])
        #expect(quotes.isEmpty)
        #expect(transport.log.urls.isEmpty)
    }

    @Test func historyRequestsMatchingIntervalAndLimit() async throws {
        let transport = StubTransport(body: BinanceFixtures.klines)
        let candles = try await provider(transport).history(for: instruments(["BTC"])[0], range: .day)
        #expect(candles.count == 3)
        let url = try #require(transport.log.urls.first)
        #expect(url.path == "/api/v3/klines")
        #expect(url.absoluteString.contains("interval=5m"))
        #expect(url.absoluteString.contains("limit=288"))
        #expect(url.absoluteString.contains("symbol=BTCUSDT"))
    }

    @Test func historyIsCachedBriefly() async throws {
        let transport = StubTransport(body: BinanceFixtures.klines)
        let binance = provider(transport)
        let instrument = instruments(["BTC"])[0]
        _ = try await binance.history(for: instrument, range: .week)
        _ = try await binance.history(for: instrument, range: .week)
        _ = try await binance.history(for: instrument, range: .month)
        #expect(transport.log.urls.count == 2)
    }

    @Test func emptyHistoryIsReportedAsUnavailable() async {
        let binance = provider(StubTransport(body: "[]"))
        let instrument = instruments(["BTC"])[0]
        await #expect(throws: ProviderError.historyUnavailable(instrument.id)) {
            _ = try await binance.history(for: instrument, range: .day)
        }
    }

    @Test func searchLoadsExchangeInfoOnlyOnce() async throws {
        let transport = StubTransport(body: BinanceFixtures.exchangeInfo)
        let binance = provider(transport)
        let first = try await binance.search(query: "pepe")
        let second = try await binance.search(query: "wif")
        #expect(first.map(\.symbol) == ["PEPE"])
        #expect(second.map(\.symbol) == ["WIF"])
        #expect(transport.log.urls.count == 1)
    }

    @Test func failedExchangeInfoIsRetriedOnNextSearch() async throws {
        let counter = RequestLog()
        let transport = StubTransport { url in
            counter.append(url)
            if counter.urls.count == 1 { return StubResponse(status: 500) }
            return StubResponse(body: BinanceFixtures.exchangeInfo)
        }
        let binance = provider(transport)
        await #expect(throws: ProviderError.invalidResponse(.binance)) {
            _ = try await binance.search(query: "pepe")
        }
        #expect(try await binance.search(query: "pepe").count == 1)
    }

    @Test func streamURLCombinesBookAndMiniTickerStreams() throws {
        let url = try #require(BinanceProvider.streamURL(for: ["BTCUSDT", "ETHUSDT"]))
        #expect(url.absoluteString == "wss://stream.binance.com:9443/stream?streams=btcusdt@bookTicker/btcusdt@miniTicker/ethusdt@bookTicker/ethusdt@miniTicker")
    }

    @Test func streamURLStaysWithinStreamLimit() throws {
        let symbols = (0..<700).map { "C\($0)USDT" }
        let url = try #require(BinanceProvider.streamURL(for: symbols))
        let streams = url.absoluteString.components(separatedBy: "streams=")[1].components(separatedBy: "/")
        #expect(streams.count <= 1024)
    }
}
