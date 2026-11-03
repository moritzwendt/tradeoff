import Foundation
import Testing
@testable import TradeOff

struct FinnhubParsingTests {
    @Test func quoteBecomesLiveQuoteWithSyntheticSpread() throws {
        let raw = try FinnhubParsing.quote(Data(FinnhubFixtures.quote.utf8))
        let quote = try #require(raw.quote(instrumentID: "finnhub:AAPL", at: FixedClock.epoch))
        #expect(quote.last == TestSupport.decimal("261.74"))
        #expect(quote.previousClose == TestSupport.decimal("259.45"))
        #expect(quote.dayHigh == TestSupport.decimal("263.31"))
        #expect(quote.dayLow == TestSupport.decimal("260.68"))
        #expect(quote.bid < quote.last)
        #expect(quote.ask > quote.last)
        #expect(abs(quote.mid - quote.last) < TestSupport.decimal("0.0001"))
        #expect(abs(quote.spreadFraction - TestSupport.decimal("0.0005")) < TestSupport.decimal("0.00001"))
        #expect(quote.isSyntheticSpread)
        #expect(quote.quality == .live)
        #expect(quote.source == .finnhub)
        #expect(quote.liquidityUSD == nil)
        #expect(quote.timestamp == FixedClock.epoch)
    }

    @Test func recordedLiveQuoteParses() throws {
        let raw = try FinnhubParsing.quote(Data(FinnhubFixtures.liveQuote.utf8))
        let quote = try #require(raw.quote(instrumentID: "finnhub:AAPL", at: FixedClock.epoch))
        #expect(quote.last == TestSupport.decimal("338.32"))
        #expect(quote.previousClose == TestSupport.decimal("344.63"))
        #expect(quote.dayHigh == TestSupport.decimal("343.8"))
        #expect(quote.dayLow == TestSupport.decimal("335.82"))
        #expect(quote.changeFraction < 0)
    }

    @Test func recordedLiveSearchDropsForeignListings() throws {
        let results = try FinnhubParsing.searchResults(Data(FinnhubFixtures.liveSearch.utf8))
        #expect(results.map(\.symbol) == ["AAPL", "APLE", "MLP", "AAPI", "PAPL", "SUNE"])
        #expect(results.allSatisfy { $0.assetClass == .stock })
        #expect(results[0].name == "Apple")
    }

    @Test func unknownSymbolsYieldNoQuote() throws {
        let raw = try FinnhubParsing.quote(Data(FinnhubFixtures.unknownQuote.utf8))
        #expect(raw.quote(instrumentID: "finnhub:XXXX", at: FixedClock.epoch) == nil)
    }

    @Test func missingPreviousCloseFallsBackToPrice() throws {
        let raw = try FinnhubParsing.quote(Data(#"{"c":10.5,"h":0,"l":0,"o":0,"pc":0}"#.utf8))
        let quote = try #require(raw.quote(instrumentID: "id", at: FixedClock.epoch))
        #expect(quote.previousClose == quote.last)
        #expect(quote.dayHigh == nil)
        #expect(quote.dayLow == nil)
    }

    @Test func garbageQuoteIsInvalid() {
        #expect(throws: ProviderError.invalidResponse(.finnhub)) {
            _ = try FinnhubParsing.quote(Data("[]".utf8))
        }
    }

    @Test func searchKeepsOnlyUsStocksAndEtfs() throws {
        let results = try FinnhubParsing.searchResults(Data(FinnhubFixtures.search.utf8))
        #expect(results.map(\.symbol) == ["AAPL", "APLE", "IVV"])
        #expect(results.map(\.assetClass) == [.stock, .stock, .etf])
        #expect(results.allSatisfy { $0.provider == .finnhub && $0.currency == "USD" })
        #expect(results[0].id == "finnhub:AAPL")
    }

    @Test func searchUsesFeaturedNamesAndCapitalizesOthers() throws {
        let results = try FinnhubParsing.searchResults(Data(FinnhubFixtures.search.utf8))
        #expect(results[0].name == "Apple")
        #expect(results[1].name == "Apple Hospitality Reit Inc")
    }

    @Test func searchWithoutResultsIsEmpty() throws {
        #expect(try FinnhubParsing.searchResults(Data(#"{"count":0,"result":[]}"#.utf8)).isEmpty)
        #expect(try FinnhubParsing.searchResults(Data(#"{"count":0}"#.utf8)).isEmpty)
    }

    @Test func usSymbolRule() {
        #expect(FinnhubCatalog.isUSSymbol("AAPL"))
        #expect(FinnhubCatalog.isUSSymbol("F"))
        #expect(!FinnhubCatalog.isUSSymbol("AAPL.SW"))
        #expect(!FinnhubCatalog.isUSSymbol("BRK.B"))
        #expect(!FinnhubCatalog.isUSSymbol("ABCDEF"))
        #expect(!FinnhubCatalog.isUSSymbol("aapl"))
        #expect(!FinnhubCatalog.isUSSymbol(""))
    }

    @Test func featuredCatalogCoversStocksAndEtfs() {
        let items = FinnhubCatalog.featuredInstruments
        #expect(items.count == 8)
        #expect(Set(items.map(\.id)).count == 8)
        #expect(items.filter { $0.assetClass == .etf }.map(\.symbol) == ["VOO", "QQQ", "SPY"])
        #expect(items.filter { $0.assetClass == .stock }.count == 5)
    }

    @Test func parsesCandlesInOrder() throws {
        let candles = try FinnhubParsing.candles(Data(FinnhubFixtures.candles.utf8))
        #expect(candles.count == 4)
        #expect(candles.map(\.time) == candles.map(\.time).sorted())
        #expect(candles[0].open == TestSupport.decimal("263.9"))
        #expect(candles[3].close == TestSupport.decimal("262.9"))
        #expect(candles[3].volume == 150_320)
    }

    @Test func noDataMeansNoCandles() throws {
        #expect(try FinnhubParsing.candles(Data(#"{"s":"no_data"}"#.utf8)).isEmpty)
    }

    @Test func latestSessionKeepsOnlyTheLastTradingDay() throws {
        let candles = try FinnhubParsing.candles(Data(FinnhubFixtures.candles.utf8))
        let session = FinnhubParsing.latestSession(in: candles)
        #expect(session.count == 2)
        #expect(session.allSatisfy { $0.time >= candles[2].time })
        #expect(FinnhubParsing.latestSession(in: []).isEmpty)
    }

    @Test func candleRequestsMatchChartRanges() {
        #expect(FinnhubParsing.candleRequest(for: .day).resolution == "5")
        #expect(FinnhubParsing.candleRequest(for: .week).resolution == "30")
        #expect(FinnhubParsing.candleRequest(for: .month).resolution == "60")
        #expect(FinnhubParsing.candleRequest(for: .quarter).resolution == "D")
        #expect(FinnhubParsing.candleRequest(for: .year).resolution == "D")
        #expect(FinnhubParsing.candleRequest(for: .max).resolution == "W")
    }
}

struct FinnhubProviderTests {
    private let key = "test-key-123"

    private func provider(_ transport: StubTransport, apiKey: String? = "test-key-123") -> FinnhubProvider {
        FinnhubProvider(apiKey: apiKey, transport: transport, clock: { FixedClock.epoch })
    }

    private func instruments(_ symbols: [String]) -> [Instrument] {
        symbols.map { FinnhubCatalog.instrument(symbol: $0, name: $0, assetClass: .stock) }
    }

    @Test func availabilityFollowsTheKey() {
        let transport = StubTransport(body: "")
        #expect(provider(transport, apiKey: nil).availability == .missingAPIKey)
        #expect(provider(transport).availability == .ready)
        #expect(provider(transport).capabilities.requiresAPIKey)
        #expect(provider(transport).capabilities.supportedAssetClasses == [.stock, .etf])
    }

    @Test func catalogListsFeaturedInstrumentsEvenWithoutKey() async {
        let items = await provider(StubTransport(body: ""), apiKey: nil).catalog()
        #expect(items == FinnhubCatalog.featuredInstruments)
    }

    @Test func requestsWithoutKeyFailBeforeTouchingTheNetwork() async {
        let transport = StubTransport(body: FinnhubFixtures.quote)
        let finnhub = provider(transport, apiKey: nil)
        await #expect(throws: ProviderError.missingAPIKey(.finnhub)) {
            _ = try await finnhub.snapshot(for: instruments(["AAPL"]))
        }
        await #expect(throws: ProviderError.missingAPIKey(.finnhub)) {
            _ = try await finnhub.search(query: "apple")
        }
        await #expect(throws: ProviderError.missingAPIKey(.finnhub)) {
            _ = try await finnhub.history(for: instruments(["AAPL"])[0], range: .day)
        }
        #expect(transport.log.urls.isEmpty)
    }

    @Test func snapshotFetchesOneQuotePerSymbolAndSendsKeyInHeader() async throws {
        let transport = StubTransport(body: FinnhubFixtures.quote)
        let quotes = try await provider(transport).snapshot(for: instruments(["AAPL", "MSFT"]))
        #expect(quotes.map(\.instrumentID) == ["finnhub:AAPL", "finnhub:MSFT"])
        let urls = transport.log.urls
        #expect(urls.count == 2)
        #expect(Set(urls.map(\.path)) == ["/api/v1/quote"])
        #expect(Set(urls.compactMap(\.query)) == ["symbol=AAPL", "symbol=MSFT"])
        #expect(urls.allSatisfy { !$0.absoluteString.contains(key) })
        #expect(transport.log.headers.allSatisfy { $0["X-Finnhub-Token"] == key })
    }

    @Test func snapshotSkipsSymbolsWithoutPrice() async throws {
        let transport = StubTransport { url in
            url.query == "symbol=AAPL"
                ? StubResponse(body: FinnhubFixtures.quote)
                : StubResponse(body: FinnhubFixtures.unknownQuote)
        }
        let quotes = try await provider(transport).snapshot(for: instruments(["AAPL", "ZZZZ"]))
        #expect(quotes.map(\.instrumentID) == ["finnhub:AAPL"])
    }

    @Test func snapshotKeepsQuotesWhenOneRequestIsLimited() async throws {
        let transport = StubTransport { url in
            url.query == "symbol=AAPL"
                ? StubResponse(body: FinnhubFixtures.quote)
                : StubResponse(status: 429, headers: ["Retry-After": "5"])
        }
        let quotes = try await provider(transport).snapshot(for: instruments(["AAPL", "MSFT"]))
        #expect(quotes.map(\.instrumentID) == ["finnhub:AAPL"])
    }

    @Test func snapshotReportsRejectedKeys() async {
        let transport = StubTransport(body: #"{"error":"Invalid API key."}"#, status: 401)
        await #expect(throws: ProviderError.accessDenied(.finnhub)) {
            _ = try await provider(transport).snapshot(for: instruments(["AAPL", "MSFT"]))
        }
    }

    @Test func snapshotIgnoresForeignInstruments() async throws {
        let transport = StubTransport(body: FinnhubFixtures.quote)
        let quotes = try await provider(transport).snapshot(for: [TestSupport.instrument("BTC", provider: .binance)])
        #expect(quotes.isEmpty)
        #expect(transport.log.urls.isEmpty)
    }

    @Test func searchQueriesFinnhubAndFilters() async throws {
        let transport = StubTransport(body: FinnhubFixtures.search)
        let results = try await provider(transport).search(query: " apple ")
        #expect(results.map(\.symbol) == ["AAPL", "APLE", "IVV"])
        let url = try #require(transport.log.urls.first)
        #expect(url.path == "/api/v1/search")
        #expect(url.query == "q=apple")
    }

    @Test func emptySearchReturnsFeaturedInstruments() async throws {
        let transport = StubTransport(body: "")
        let results = try await provider(transport).search(query: "  ")
        #expect(results == FinnhubCatalog.featuredInstruments)
        #expect(transport.log.urls.isEmpty)
    }

    @Test func historyRequestsTheRightWindowAndResolution() async throws {
        let transport = StubTransport(body: FinnhubFixtures.candles)
        let candles = try await provider(transport).history(for: instruments(["AAPL"])[0], range: .day)
        #expect(candles.count == 2)
        let url = try #require(transport.log.urls.first)
        #expect(url.path == "/api/v1/stock/candle")
        let query = url.query ?? ""
        #expect(query.contains("symbol=AAPL"))
        #expect(query.contains("resolution=5"))
        let now = Int(FixedClock.epoch.timeIntervalSince1970)
        #expect(query.contains("to=\(now)"))
        #expect(query.contains("from=\(now - 5 * 86_400)"))
    }

    @Test func longerRangesKeepAllCandles() async throws {
        let transport = StubTransport(body: FinnhubFixtures.candles)
        let candles = try await provider(transport).history(for: instruments(["AAPL"])[0], range: .week)
        #expect(candles.count == 4)
    }

    @Test func historyIsCached() async throws {
        let transport = StubTransport(body: FinnhubFixtures.candles)
        let finnhub = provider(transport)
        let instrument = instruments(["AAPL"])[0]
        _ = try await finnhub.history(for: instrument, range: .day)
        _ = try await finnhub.history(for: instrument, range: .day)
        #expect(transport.log.urls.count == 1)
    }

    @Test func historyBlockedByThePlanIsUnavailable() async {
        let transport = StubTransport(body: #"{"error":"You don't have access to this resource."}"#, status: 403)
        let instrument = instruments(["AAPL"])[0]
        await #expect(throws: ProviderError.historyUnavailable(instrument.id)) {
            _ = try await provider(transport).history(for: instrument, range: .day)
        }
    }

    @Test func deniedHistoryStopsFurtherRequestsUntilTheCooldownEnds() async throws {
        let transport = StubTransport(body: #"{"error":"You don't have access to this resource."}"#, status: 403)
        let clock = ClockBox(FixedClock.epoch)
        let finnhub = FinnhubProvider(apiKey: key, transport: transport, clock: { clock.now })
        let instrument = instruments(["AAPL"])[0]

        await #expect(throws: ProviderError.historyUnavailable(instrument.id)) {
            _ = try await finnhub.history(for: instrument, range: .day)
        }
        await #expect(throws: ProviderError.historyUnavailable(instrument.id)) {
            _ = try await finnhub.history(for: instrument, range: .month)
        }
        #expect(transport.log.urls.count == 1)

        clock.now = FixedClock.epoch.addingTimeInterval(FinnhubProvider.deniedHistoryCooldown + 1)
        await #expect(throws: ProviderError.historyUnavailable(instrument.id)) {
            _ = try await finnhub.history(for: instrument, range: .week)
        }
        #expect(transport.log.urls.count == 2)
    }

    @Test func emptyHistoryIsUnavailable() async {
        let transport = StubTransport(body: #"{"s":"no_data"}"#)
        let instrument = instruments(["AAPL"])[0]
        await #expect(throws: ProviderError.historyUnavailable(instrument.id)) {
            _ = try await provider(transport).history(for: instrument, range: .month)
        }
    }

    @Test func pollIntervalStaysWithinTheRateLimit() {
        #expect(FinnhubProvider.pollInterval(forSymbols: 1) == 10)
        #expect(FinnhubProvider.pollInterval(forSymbols: 8) == 12)
        #expect(FinnhubProvider.pollInterval(forSymbols: 40) == 60)
        let requestsPerMinute = 8.0 * 60 / FinnhubProvider.pollInterval(forSymbols: 8)
        #expect(requestsPerMinute < Double(FinnhubProvider.requestsPerMinute))
    }
}
