import Foundation
@testable import TradeOff

enum TestSupport {
    static func decimal(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    static let referenceDate = Date(timeIntervalSince1970: 1_800_000_000)

    static func newYorkDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .gmt
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? .distantPast
    }

    static func instrument(
        _ symbol: String = "AAPL",
        assetClass: AssetClass = .stock,
        provider: ProviderID = .mock
    ) -> Instrument {
        Instrument(
            id: Instrument.makeID(provider: provider, symbol: symbol),
            symbol: symbol,
            name: symbol,
            assetClass: assetClass,
            provider: provider,
            providerSymbol: symbol,
            currency: "USD"
        )
    }

    static func quote(
        for instrument: Instrument,
        bid: String = "99.90",
        ask: String = "100.10",
        liquidity: String? = nil,
        timestamp: Date = referenceDate
    ) -> Quote {
        Quote(
            instrumentID: instrument.id,
            bid: decimal(bid),
            ask: decimal(ask),
            last: decimal("100"),
            previousClose: decimal("98"),
            dayHigh: decimal("101"),
            dayLow: decimal("97"),
            volume24h: nil,
            liquidityUSD: liquidity.map(decimal),
            timestamp: timestamp,
            source: .mock,
            quality: .simulated,
            isSyntheticSpread: true
        )
    }
}
