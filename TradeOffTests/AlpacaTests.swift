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
        #expect(AlpacaParsing.barsRequest(for: .month).timeframe == "4Hour")
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
