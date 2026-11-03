import Foundation
import Testing
@testable import TradeOff

private let wifRef = DexTokenRef(chain: "solana", address: "EKpQGSJtjMFqKZ9KQanSqYXRcF8fBopzLHYxdM65zcjm")

private func wifInstrument() -> Instrument {
    DexScreenerCatalog.featuredInstruments.first { $0.symbol == "WIF" }!
}

struct DexParsingTests {
    private func tokenPairs() throws -> [DexPair] {
        try DexParsing.pairs(fromTokens: Data(DexFixtures.tokens.utf8))
    }

    @Test func lossyArraySkipsBrokenElements() throws {
        let json = #"[{"chainId":"solana","pairAddress":"A","baseToken":{"address":"x","name":"X","symbol":"X"},"quoteToken":{"address":"y","name":"Y","symbol":"Y"},"priceUsd":"1"},{"broken":true},"text",{"chainId":"base","pairAddress":"B","baseToken":{"address":"z","name":"Z","symbol":"Z"},"quoteToken":{"address":"y","name":"Y","symbol":"Y"},"priceUsd":"2"}]"#
        let pairs = try DexParsing.pairs(fromTokens: Data(json.utf8))
        #expect(pairs.map(\.pairAddress) == ["A", "B"])
    }

    @Test func nonArrayTokenResponseIsInvalid() {
        #expect(throws: ProviderError.invalidResponse(.dexScreener)) {
            _ = try DexParsing.pairs(fromTokens: Data(#"{"error":"x"}"#.utf8))
        }
    }

    @Test func searchResponseWithoutPairsIsEmpty() throws {
        #expect(try DexParsing.pairs(fromSearch: Data(#"{"schemaVersion":"1.0.0","pairs":null}"#.utf8)).isEmpty)
        #expect(try DexParsing.pairs(fromSearch: Data(#"{"schemaVersion":"1.0.0"}"#.utf8)).isEmpty)
    }

    @Test func bestPairMatchesRequestedBaseToken() throws {
        let pairs = try tokenPairs()
        let pair = try #require(DexParsing.bestPair(for: wifRef, in: pairs))
        #expect(pair.baseToken.symbol == "$WIF")
        #expect(pair.pairAddress == "EP2ib6dYdEeqD8MfE2ezHCxX3kP3K2eLKkirfPm5eyMx")
    }

    @Test func bestPairIgnoresUnknownTokensAndWrongChains() throws {
        let pairs = try tokenPairs()
        #expect(DexParsing.bestPair(for: DexTokenRef(chain: "solana", address: "unknown"), in: pairs) == nil)
        #expect(DexParsing.bestPair(for: DexTokenRef(chain: "base", address: wifRef.address), in: pairs) == nil)
    }

    @Test func quoteUsesPoolPriceWithSyntheticSpread() throws {
        let pair = try #require(DexParsing.bestPair(for: wifRef, in: tokenPairs()))
        let quote = try #require(DexParsing.quote(from: pair, instrumentID: "id", at: FixedClock.epoch))
        #expect(quote.last == TestSupport.decimal("0.17"))
        #expect(quote.bid == TestSupport.decimal("0.169915"))
        #expect(quote.ask == TestSupport.decimal("0.170085"))
        #expect(quote.isSyntheticSpread)
        #expect(quote.quality == .live)
        #expect(quote.source == .dexScreener)
        #expect(quote.liquidityUSD == TestSupport.decimal("4989380.36"))
        #expect(quote.volume24h == TestSupport.decimal("498646.47"))
        #expect(quote.dayHigh == nil)
        #expect(quote.dayLow == nil)
        #expect(quote.timestamp == FixedClock.epoch)
    }

    @Test func previousCloseIsDerivedFromDayChange() throws {
        let pair = try #require(DexParsing.bestPair(for: wifRef, in: tokenPairs()))
        let quote = try #require(DexParsing.quote(from: pair, instrumentID: "id", at: FixedClock.epoch))
        let expected = TestSupport.decimal("0.17") / TestSupport.decimal("0.9678")
        let difference = abs(quote.previousClose - expected)
        #expect(difference < TestSupport.decimal("0.000001"))
        #expect(quote.changeFraction < 0)
    }

    @Test func missingDayChangeMeansNoChange() throws {
        let json = #"{"chainId":"solana","pairAddress":"A","baseToken":{"address":"x","name":"X","symbol":"X"},"quoteToken":{"address":"y","name":"Y","symbol":"Y"},"priceUsd":"0.000002797"}"#
        let pair = try JSONDecoder().decode(DexPair.self, from: Data(json.utf8))
        let quote = try #require(DexParsing.quote(from: pair, instrumentID: "id", at: FixedClock.epoch))
        #expect(quote.previousClose == quote.last)
        #expect(quote.liquidityUSD == nil)
        #expect(quote.volume24h == nil)
        #expect(quote.bid < quote.last)
        #expect(quote.ask > quote.last)
    }

    @Test func pairWithoutPriceYieldsNoQuote() throws {
        let json = #"{"chainId":"solana","pairAddress":"A","baseToken":{"address":"x","name":"X","symbol":"X"},"quoteToken":{"address":"y","name":"Y","symbol":"Y"},"priceUsd":null}"#
        let pair = try JSONDecoder().decode(DexPair.self, from: Data(json.utf8))
        #expect(DexParsing.quote(from: pair, instrumentID: "id", at: FixedClock.epoch) == nil)
    }

    @Test func crashedDayChangeFallsBackToCurrentPrice() throws {
        let json = #"{"chainId":"solana","pairAddress":"A","baseToken":{"address":"x","name":"X","symbol":"X"},"quoteToken":{"address":"y","name":"Y","symbol":"Y"},"priceUsd":"1","priceChange":{"h24":-100}}"#
        let pair = try JSONDecoder().decode(DexPair.self, from: Data(json.utf8))
        let quote = try #require(DexParsing.quote(from: pair, instrumentID: "id", at: FixedClock.epoch))
        #expect(quote.previousClose == quote.last)
    }

    @Test func searchRanksByVolumeAndDropsIlliquidDuplicates() throws {
        let pairs = try DexParsing.pairs(fromSearch: Data(DexFixtures.search.utf8))
        let results = DexParsing.searchResults(from: pairs)
        let chains = results.map { $0.providerSymbol.split(separator: ":").first.map(String.init) }
        #expect(results.count == 6)
        #expect(chains == ["ethereum", "bsc", "solana", "base", "solana", "robinhood"])
        #expect(results.map(\.id).count == Set(results.map(\.id)).count)
        #expect(results.allSatisfy { $0.assetClass == .memeCoin && $0.provider == .dexScreener })
    }

    @Test func searchResultsCarryChainInName() throws {
        let pairs = try DexParsing.pairs(fromSearch: Data(DexFixtures.search.utf8))
        let first = try #require(DexParsing.searchResults(from: pairs).first)
        #expect(first.symbol == "PEPE")
        #expect(first.name == "Pepe (Ethereum)")
        #expect(first.id == "dexScreener:ethereum:0x6982508145454Ce325dDbE47a25d4ec3d2311933")
        #expect(first.currency == "USD")
    }

    @Test func searchSkipsMajorsAndWrappedAssets() throws {
        let renamed = DexFixtures.search.replacingOccurrences(of: #""symbol":"PEPE""#, with: #""symbol":"SOL""#)
        let results = DexParsing.searchResults(from: try DexParsing.pairs(fromSearch: Data(renamed.utf8)))
        #expect(results.map(\.symbol) == ["Pepe"])
    }

    @Test func displaySymbolDropsDollarPrefixAndLimitsLength() {
        #expect(DexScreenerCatalog.displaySymbol("$WIF") == "WIF")
        #expect(DexScreenerCatalog.displaySymbol(" $$BONK ") == "BONK")
        #expect(DexScreenerCatalog.displaySymbol("ABCDEFGHIJKLMNOP").count == 12)
    }

    @Test func tokenRefRoundTripsThroughProviderSymbol() throws {
        let ref = try #require(DexTokenRef(providerSymbol: wifRef.providerSymbol))
        #expect(ref == wifRef)
        #expect(DexTokenRef(providerSymbol: "nochain") == nil)
        #expect(DexTokenRef(providerSymbol: ":addr") == nil)
        #expect(DexTokenRef(providerSymbol: "chain:") == nil)
    }

    @Test func addressMatchingIsCaseInsensitiveOnlyForHexAddresses() {
        let evm = DexTokenRef(chain: "ethereum", address: "0xAbC")
        #expect(evm.matches(chain: "Ethereum", address: "0xabc"))
        let solana = DexTokenRef(chain: "solana", address: "AbC")
        #expect(!solana.matches(chain: "solana", address: "abc"))
        #expect(solana.matches(chain: "SOLANA", address: "AbC"))
    }

    @Test func featuredCatalogHasUniqueIdentities() {
        let instruments = DexScreenerCatalog.featuredInstruments
        #expect(instruments.count == 7)
        #expect(Set(instruments.map(\.id)).count == 7)
        #expect(instruments.allSatisfy { DexTokenRef(providerSymbol: $0.providerSymbol) != nil })
        #expect(instruments.first { $0.symbol == "PEPE" }?.name == "Pepe (Ethereum)")
    }
}

struct GeckoTerminalTests {
    @Test func parsesCandlesOldestFirst() throws {
        let candles = try GeckoTerminalOHLCV.parse(Data(DexFixtures.ohlcv.utf8))
        #expect(candles.count == 3)
        #expect(candles.map(\.time) == candles.map(\.time).sorted())
        #expect(candles[0].time == Date(timeIntervalSince1970: 1_793_665_800))
        #expect(candles[0].open == TestSupport.decimal("92.13569496020449"))
        #expect(candles[0].close == TestSupport.decimal("92.0919191919192"))
        #expect(candles[2].time == Date(timeIntervalSince1970: 1_793_666_400))
    }

    @Test func rejectsUnexpectedPayload() {
        #expect(throws: ProviderError.invalidResponse(.dexScreener)) {
            _ = try GeckoTerminalOHLCV.parse(Data(#"{"errors":[{"status":"404"}]}"#.utf8))
        }
    }

    @Test func mapsEveryChartRangeToSupportedTimeframes() {
        for range in ChartRange.allCases {
            let request = GeckoTerminalOHLCV.request(for: range)
            #expect(["minute", "hour", "day"].contains(request.timeframe))
            #expect(request.limit <= 1000)
            switch request.timeframe {
            case "minute": #expect([1, 5, 15].contains(request.aggregate))
            case "hour": #expect([1, 4, 12].contains(request.aggregate))
            default: #expect(request.aggregate == 1)
            }
        }
        #expect(GeckoTerminalOHLCV.request(for: .day) == .init(timeframe: "minute", aggregate: 5, limit: 288))
    }
}

struct DexScreenerProviderTests {
    private func provider(_ transport: StubTransport) -> DexScreenerProvider {
        let client = HTTPClient(provider: .dexScreener, transport: transport)
        return DexScreenerProvider(dex: client, gecko: client, clock: { FixedClock.epoch })
    }

    private func router(failing chains: Set<String> = []) -> StubTransport {
        StubTransport { url in
            if url.host == "api.geckoterminal.com" {
                return StubResponse(body: DexFixtures.ohlcv)
            }
            if url.path.hasPrefix("/tokens/v1/") {
                let chain = url.pathComponents[3]
                if chains.contains(chain) { return StubResponse(status: 500) }
                return StubResponse(body: DexFixtures.tokens)
            }
            if url.path == "/latest/dex/search" {
                return StubResponse(body: DexFixtures.search)
            }
            return StubResponse(status: 404)
        }
    }

    private func instruments(chain: String, count: Int) -> [Instrument] {
        (0..<count).map {
            DexScreenerCatalog.instrument(symbol: "T\($0)", name: "Token \($0)", ref: DexTokenRef(chain: chain, address: "addr\($0)"))
        }
    }

    @Test func capabilitiesDescribePoolData() {
        let dex = provider(router())
        #expect(dex.availability == .ready)
        #expect(!dex.capabilities.hasRealBidAsk)
        #expect(dex.capabilities.hasLiquidity)
        #expect(dex.capabilities.supportedAssetClasses == [.memeCoin])
        #expect(dex.capabilities.pollInterval == 5)
    }

    @Test func catalogListsFeaturedTokens() async {
        let items = await provider(router()).catalog()
        #expect(items == DexScreenerCatalog.featuredInstruments)
    }

    @Test func snapshotFetchesTokensByChainAndAddress() async throws {
        let transport = router()
        let quotes = try await provider(transport).snapshot(for: [wifInstrument()])
        #expect(quotes.map(\.instrumentID) == [wifInstrument().id])
        let url = try #require(transport.log.urls.first)
        #expect(url.path == "/tokens/v1/solana/\(wifRef.address)")
        #expect(quotes[0].liquidityUSD != nil)
    }

    @Test func snapshotBatchesUpToThirtyAddressesPerRequest() async throws {
        let transport = router()
        _ = try await provider(transport).snapshot(for: instruments(chain: "solana", count: 65))
        let paths = transport.log.urls.map(\.path)
        #expect(paths.count == 3)
        let sizes = paths.map { $0.split(separator: "/").last?.split(separator: ",").count ?? 0 }
        #expect(sizes == [30, 30, 5])
    }

    @Test func snapshotSeparatesChains() async throws {
        let transport = router()
        let mixed = instruments(chain: "solana", count: 2) + instruments(chain: "base", count: 2)
        _ = try await provider(transport).snapshot(for: mixed)
        let chains = Set(transport.log.urls.map { $0.pathComponents[3] })
        #expect(chains == ["solana", "base"])
        #expect(transport.log.urls.count == 2)
    }

    @Test func snapshotKeepsQuotesWhenOneChainFails() async throws {
        let transport = router(failing: ["base"])
        let mixed = [wifInstrument()] + instruments(chain: "base", count: 2)
        let quotes = try await provider(transport).snapshot(for: mixed)
        #expect(quotes.map(\.instrumentID) == [wifInstrument().id])
    }

    @Test func snapshotThrowsWhenEverythingFails() async {
        let transport = router(failing: ["solana"])
        await #expect(throws: ProviderError.invalidResponse(.dexScreener)) {
            _ = try await provider(transport).snapshot(for: [wifInstrument()])
        }
    }

    @Test func snapshotIgnoresForeignInstruments() async throws {
        let transport = router()
        let quotes = try await provider(transport).snapshot(for: [TestSupport.instrument("BTC", provider: .binance)])
        #expect(quotes.isEmpty)
        #expect(transport.log.urls.isEmpty)
    }

    @Test func shortSearchReturnsFeaturedTokensWithoutRequest() async throws {
        let transport = router()
        let results = try await provider(transport).search(query: "p")
        #expect(results == DexScreenerCatalog.featuredInstruments)
        #expect(transport.log.urls.isEmpty)
    }

    @Test func searchQueriesDexScreenerAndFiltersResults() async throws {
        let transport = router()
        let results = try await provider(transport).search(query: " pepe ")
        let url = try #require(transport.log.urls.first)
        #expect(url.path == "/latest/dex/search")
        #expect(url.query == "q=pepe")
        #expect(results.count == 6)
    }

    @Test func historyResolvesPoolThenLoadsCandles() async throws {
        let transport = router()
        let candles = try await provider(transport).history(for: wifInstrument(), range: .day)
        #expect(candles.count == 3)
        let urls = transport.log.urls
        #expect(urls.count == 2)
        #expect(urls[0].path.hasPrefix("/tokens/v1/solana/"))
        #expect(urls[1].path == "/api/v2/networks/solana/pools/EP2ib6dYdEeqD8MfE2ezHCxX3kP3K2eLKkirfPm5eyMx/ohlcv/minute")
        let query = urls[1].query ?? ""
        #expect(query.contains("aggregate=5"))
        #expect(query.contains("limit=288"))
        #expect(query.contains("token=base"))
    }

    @Test func historyIsCachedAndReusesKnownPool() async throws {
        let transport = router()
        let dex = provider(transport)
        _ = try await dex.history(for: wifInstrument(), range: .day)
        _ = try await dex.history(for: wifInstrument(), range: .day)
        _ = try await dex.history(for: wifInstrument(), range: .week)
        #expect(transport.log.urls.count == 3)
    }

    @Test func historyIsUnavailableForUnknownNetworks() async throws {
        let transport = StubTransport { _ in StubResponse(body: DexFixtures.tokens.replacingOccurrences(of: #""chainId":"solana""#, with: #""chainId":"unknownchain""#)) }
        let dex = provider(transport)
        let instrument = DexScreenerCatalog.instrument(
            symbol: "WIF",
            name: "dogwifhat",
            ref: DexTokenRef(chain: "unknownchain", address: wifRef.address)
        )
        await #expect(throws: ProviderError.historyUnavailable(instrument.id)) {
            _ = try await dex.history(for: instrument, range: .day)
        }
    }

    @Test func historyIsUnavailableWhenPoolCannotBeFound() async {
        let dex = provider(StubTransport(body: "[]"))
        let instrument = wifInstrument()
        await #expect(throws: ProviderError.historyUnavailable(instrument.id)) {
            _ = try await dex.history(for: instrument, range: .day)
        }
    }
}
