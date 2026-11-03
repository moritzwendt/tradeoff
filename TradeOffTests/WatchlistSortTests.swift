import Foundation
import Testing
@testable import TradeOff

struct WatchlistSortTests {
    private func instrument(_ symbol: String) -> Instrument {
        TestSupport.instrument(symbol, assetClass: .crypto, provider: .binance)
    }

    private func quote(_ instrument: Instrument, last: String, previous: String) -> Quote {
        var quote = TestSupport.quote(for: instrument)
        quote.last = TestSupport.decimal(last)
        quote.previousClose = TestSupport.decimal(previous)
        return quote
    }

    private func fixture() -> (items: [Instrument], quotes: [InstrumentID: Quote]) {
        let a = instrument("AAA")
        let b = instrument("BBB")
        let c = instrument("CCC")
        let d = instrument("DDD")
        let quotes = [
            a.id: quote(a, last: "110", previous: "100"),
            b.id: quote(b, last: "50", previous: "100"),
            c.id: quote(c, last: "300", previous: "290")
        ]
        return ([b, d, a, c], quotes)
    }

    @Test func manualKeepsTheGivenOrder() {
        let (items, quotes) = fixture()
        #expect(WatchlistOrdering.sorted(items, by: .manual, quotes: quotes).map(\.symbol) == ["BBB", "DDD", "AAA", "CCC"])
    }

    @Test func nameSortsAlphabetically() {
        let (items, quotes) = fixture()
        #expect(WatchlistOrdering.sorted(items, by: .name, quotes: quotes).map(\.symbol) == ["AAA", "BBB", "CCC", "DDD"])
    }

    @Test func bestFirstOrdersByChangeAndPutsUnpricedLast() {
        let (items, quotes) = fixture()
        #expect(WatchlistOrdering.sorted(items, by: .bestFirst, quotes: quotes).map(\.symbol) == ["AAA", "CCC", "BBB", "DDD"])
    }

    @Test func worstFirstReversesTheChangeOrder() {
        let (items, quotes) = fixture()
        #expect(WatchlistOrdering.sorted(items, by: .worstFirst, quotes: quotes).map(\.symbol) == ["BBB", "CCC", "AAA", "DDD"])
    }

    @Test func priceOrdersByLastPrice() {
        let (items, quotes) = fixture()
        #expect(WatchlistOrdering.sorted(items, by: .priceHigh, quotes: quotes).map(\.symbol) == ["CCC", "AAA", "BBB", "DDD"])
    }

    @Test func equalValuesKeepTheirManualOrder() {
        let a = instrument("AAA")
        let b = instrument("BBB")
        let quotes = [
            a.id: quote(a, last: "110", previous: "100"),
            b.id: quote(b, last: "110", previous: "100")
        ]
        #expect(WatchlistOrdering.sorted([b, a], by: .bestFirst, quotes: quotes).map(\.symbol) == ["BBB", "AAA"])
    }

    @Test func emptyInputStaysEmpty() {
        #expect(WatchlistOrdering.sorted([], by: .bestFirst, quotes: [:]).isEmpty)
    }

    @Test func sortAndGroupingPersistInSettings() throws {
        var values = SettingsValues()
        values.watchlistSort = .worstFirst
        values.groupWatchlist = false
        let decoded = try JSONDecoder().decode(SettingsValues.self, from: JSONEncoder().encode(values))
        #expect(decoded.watchlistSort == .worstFirst)
        #expect(!decoded.groupWatchlist)
        #expect(SettingsValues().watchlistSort == .manual)
        #expect(SettingsValues().groupWatchlist)
    }
}
