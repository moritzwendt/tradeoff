import Foundation
import Testing
@testable import TradeOff

struct AlpacaParsingTests {
    @Test func barsAreSortedAndFilteredBySymbol() throws {
        let candles = try AlpacaParsing.candles(Data(AlpacaFixtures.bars.utf8), symbol: "AAPL")
        #expect(candles.count == 4)
        #expect(candles.map(\.time) == candles.map(\.time).sorted())
        #expect(candles[0].time == AlpacaParsing.parseDate("2026-10-30T13:30:00Z"))
        #expect(candles[0].open == TestSupport.decimal("264.1"))
        #expect(candles[0].close == TestSupport.decimal("263.9"))
        #expect(candles[3].close == TestSupport.decimal("262.9"))
        #expect(candles[3].volume == 150_320)
    }

    @Test func otherSymbolsAreNotMixedIn() throws {
        let candles = try AlpacaParsing.candles(Data(AlpacaFixtures.bars.utf8), symbol: "MSFT")
        #expect(candles.count == 1)
        #expect(candles[0].close == TestSupport.decimal("507.1"))
    }

    @Test func missingSymbolOrBarsYieldNoCandles() throws {
        #expect(try AlpacaParsing.candles(Data(AlpacaFixtures.bars.utf8), symbol: "NVDA").isEmpty)
        #expect(try AlpacaParsing.candles(Data(#"{"bars":null,"next_page_token":null}"#.utf8), symbol: "AAPL").isEmpty)
        #expect(try AlpacaParsing.candles(Data(#"{"bars":{},"next_page_token":null}"#.utf8), symbol: "AAPL").isEmpty)
    }

    @Test func recordedBarsIncludeExtendedHours() throws {
        let candles = try AlpacaParsing.candles(Data(AlpacaFixtures.liveBars.utf8), symbol: "AAPL")
        #expect(candles.count == 9)
        #expect(candles.map(\.time) == candles.map(\.time).sorted())
        #expect(candles.allSatisfy { $0.high >= $0.low && $0.volume > 0 })
    }

    @Test func regularHoursFilterDropsPreAndAfterMarketBars() throws {
        let candles = try AlpacaParsing.candles(Data(AlpacaFixtures.liveBars.utf8), symbol: "AAPL")
        let regular = CandleSessions.regularHours(in: candles, bucket: 300)
        let starts = regular.map { AlpacaParsing.timestamp($0.time) }
        #expect(starts == [
            "2026-10-30T13:30:00Z",
            "2026-10-30T13:35:00Z",
            "2026-11-02T14:30:00Z",
            "2026-11-02T14:35:00Z",
            "2026-11-02T20:55:00Z"
        ])
    }

    @Test func hourlyBarsOverlappingTheOpenAreKept() {
        func bar(_ hour: Int, _ minute: Int) -> Candlestick {
            let time = TestSupport.newYorkDate(2026, 11, 4, hour, minute)
            return Candlestick(time: time, open: 1, high: 1, low: 1, close: 1, volume: 1)
        }
        let candles = [bar(8, 0), bar(9, 0), bar(10, 0), bar(15, 0), bar(16, 0)]
        let kept = CandleSessions.regularHours(in: candles, bucket: 3_600)
        #expect(kept.count == 3)
        #expect(kept.first?.time == candles[1].time)
        #expect(kept.last?.time == candles[3].time)
    }

    @Test func latestSessionKeepsOnlyTheLastTradingDay() throws {
        let candles = try AlpacaParsing.candles(Data(AlpacaFixtures.bars.utf8), symbol: "AAPL")
        let session = CandleSessions.latest(in: candles)
        #expect(session.count == 2)
        #expect(session.allSatisfy { $0.time >= candles[2].time })
        #expect(CandleSessions.latest(in: []).isEmpty)
    }

    @Test func brokenResponsesAreInvalid() {
        #expect(throws: ProviderError.invalidResponse(.alpaca)) {
            _ = try AlpacaParsing.candles(Data("[]".utf8), symbol: "AAPL")
        }
    }

    @Test func parsesTimestampsWithAndWithoutFractionalSeconds() throws {
        let whole = try #require(AlpacaParsing.parseDate("2026-11-02T14:30:00Z"))
        let fractional = try #require(AlpacaParsing.parseDate("2026-11-02T14:30:00.5Z"))
        #expect(fractional.timeIntervalSince(whole) == 0.5)
        #expect(AlpacaParsing.parseDate("nonsense") == nil)
    }

    @Test func formatsRequestTimestampsAsUtc() {
        #expect(AlpacaParsing.timestamp(Date(timeIntervalSince1970: 1_800_000_000)) == "2027-01-15T08:00:00Z")
    }

    @Test func rangesMapToSupportedTimeframes() {
        #expect(AlpacaParsing.barsRequest(for: .day).timeframe == "5Min")
        #expect(AlpacaParsing.barsRequest(for: .week).timeframe == "30Min")
        #expect(AlpacaParsing.barsRequest(for: .month).timeframe == "1Hour")
        #expect(AlpacaParsing.barsRequest(for: .quarter).timeframe == "1Day")
        #expect(AlpacaParsing.barsRequest(for: .year).timeframe == "1Day")
        #expect(AlpacaParsing.barsRequest(for: .max).timeframe == "1Week")
    }
}

struct AlpacaProviderTests {
    private let keyID = "test-key-id"
    private let secret = "test-secret-value"

    private func provider(_ transport: StubTransport, keys: Bool = true) -> AlpacaProvider {
        AlpacaProvider(
            keyID: keys ? keyID : nil,
            secretKey: keys ? secret : nil,
            transport: transport,
            clock: { FixedClock.epoch }
        )
    }

    private let apple = FinnhubCatalog.instrument(symbol: "AAPL", name: "Apple", assetClass: .stock)

    @Test func availabilityNeedsBothKeys() {
        let transport = StubTransport(body: "")
        #expect(provider(transport).availability == .ready)
        #expect(provider(transport, keys: false).availability == .missingAPIKey)
        #expect(AlpacaProvider(keyID: "id", secretKey: nil, transport: transport).availability == .missingAPIKey)
        #expect(AlpacaProvider(keyID: nil, secretKey: "secret", transport: transport).availability == .missingAPIKey)
    }

    @Test func isAHistoryOnlyProviderForStocksAndEtfs() async throws {
        let alpaca = provider(StubTransport(body: ""))
        #expect(alpaca.capabilities.hasHistory)
        #expect(!alpaca.capabilities.providesQuotes)
        #expect(alpaca.capabilities.supportedAssetClasses == [.stock, .etf])
        #expect(await alpaca.catalog().isEmpty)
        #expect(try await alpaca.search(query: "apple").isEmpty)
        #expect(try await alpaca.snapshot(for: [apple]).isEmpty)
    }

    @Test func historyRequestsDelayedSipBarsWithKeysInHeaders() async throws {
        let transport = StubTransport(body: AlpacaFixtures.bars)
        let candles = try await provider(transport).history(for: apple, range: .day)
        #expect(candles.count == 2)

        let url = try #require(transport.log.urls.first)
        #expect(url.host == "data.alpaca.markets")
        #expect(url.path == "/v2/stocks/bars")
        let query = url.query ?? ""
        let end = FixedClock.epoch.addingTimeInterval(-16 * 60)
        let start = end.addingTimeInterval(-5 * 86_400)
        #expect(query.contains("symbols=AAPL"))
        #expect(query.contains("timeframe=5Min"))
        #expect(query.contains("feed=sip"))
        #expect(query.contains("adjustment=split"))
        #expect(query.contains("sort=asc"))
        #expect(query.contains("limit=10000"))
        #expect(query.contains("end=\(AlpacaParsing.timestamp(end))"))
        #expect(query.contains("start=\(AlpacaParsing.timestamp(start))"))

        let headers = try #require(transport.log.headers.first)
        #expect(headers["APCA-API-KEY-ID"] == keyID)
        #expect(headers["APCA-API-SECRET-KEY"] == secret)
        #expect(!url.absoluteString.contains(keyID))
        #expect(!url.absoluteString.contains(secret))
    }

    @Test func dayChartShowsTheLastRegularSessionEvenWithPreMarketBarsToday() async throws {
        let transport = StubTransport(body: AlpacaFixtures.liveBars)
        let candles = try await provider(transport).history(for: apple, range: .day)
        #expect(candles.map { AlpacaParsing.timestamp($0.time) } == [
            "2026-11-02T14:30:00Z",
            "2026-11-02T14:35:00Z",
            "2026-11-02T20:55:00Z"
        ])
    }

    @Test func weekChartKeepsOnlyRegularHoursOfEverySession() async throws {
        let transport = StubTransport(body: AlpacaFixtures.liveBars)
        let candles = try await provider(transport).history(for: apple, range: .week)
        let starts = candles.map { AlpacaParsing.timestamp($0.time) }
        #expect(!starts.contains("2026-11-03T09:35:00Z"))
        #expect(!starts.contains("2026-11-02T21:00:00Z"))
        #expect(starts.contains("2026-11-02T14:30:00Z"))
        #expect(starts.contains("2026-10-30T13:30:00Z"))
    }

    @Test func dailyAndWeeklyBarsAreNotFiltered() async throws {
        let transport = StubTransport(body: AlpacaFixtures.liveBars)
        let candles = try await provider(transport).history(for: apple, range: .year)
        #expect(candles.count == 9)
    }

    @Test func longerRangesKeepAllBars() async throws {
        let candles = try await provider(StubTransport(body: AlpacaFixtures.bars)).history(for: apple, range: .week)
        #expect(candles.count == 4)
    }

    @Test func historyIsCached() async throws {
        let transport = StubTransport(body: AlpacaFixtures.bars)
        let alpaca = provider(transport)
        _ = try await alpaca.history(for: apple, range: .month)
        _ = try await alpaca.history(for: apple, range: .month)
        #expect(transport.log.urls.count == 1)
    }

    @Test func requestsWithoutKeysFailBeforeTouchingTheNetwork() async {
        let transport = StubTransport(body: AlpacaFixtures.bars)
        await #expect(throws: ProviderError.missingAPIKey(.alpaca)) {
            _ = try await provider(transport, keys: false).history(for: apple, range: .day)
        }
        #expect(transport.log.urls.isEmpty)
    }

    @Test func cryptoInstrumentsHaveNoAlpacaHistory() async {
        let transport = StubTransport(body: AlpacaFixtures.bars)
        let coin = TestSupport.instrument("BTC", assetClass: .crypto, provider: .binance)
        await #expect(throws: ProviderError.historyUnavailable(coin.id)) {
            _ = try await provider(transport).history(for: coin, range: .day)
        }
        #expect(transport.log.urls.isEmpty)
    }

    @Test func rejectedKeysAreReportedAsDeniedAccess() async {
        let transport = StubTransport(body: AlpacaFixtures.recentSipError, status: 403)
        await #expect(throws: ProviderError.accessDenied(.alpaca)) {
            _ = try await provider(transport).history(for: apple, range: .day)
        }
    }

    @Test func badRequestsMeanNoHistory() async {
        let transport = StubTransport(body: #"{"message":"invalid symbol"}"#, status: 422)
        await #expect(throws: ProviderError.historyUnavailable(apple.id)) {
            _ = try await provider(transport).history(for: apple, range: .day)
        }
    }

    @Test func emptyBarsMeanNoHistory() async {
        let transport = StubTransport(body: #"{"bars":{},"next_page_token":null}"#)
        await #expect(throws: ProviderError.historyUnavailable(apple.id)) {
            _ = try await provider(transport).history(for: apple, range: .day)
        }
    }
}
