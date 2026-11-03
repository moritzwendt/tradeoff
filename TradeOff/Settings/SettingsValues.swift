import Foundation

struct SettingsValues: Codable, Equatable, Sendable {
    var startingBalance: Decimal = 10_000
    var fees: FeeSchedule = .standard
    var ignoreMarketHours: Bool = false
    var maxQuoteAge: Double = 30
    var chartStyle: ChartStyle = .line
    var hapticsEnabled: Bool = true
    var watchlistSort: WatchlistSort = .manual
    var groupWatchlist: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SettingsValues()
        startingBalance = try container.decodeIfPresent(Decimal.self, forKey: .startingBalance) ?? defaults.startingBalance
        fees = try container.decodeIfPresent(FeeSchedule.self, forKey: .fees) ?? defaults.fees
        ignoreMarketHours = try container.decodeIfPresent(Bool.self, forKey: .ignoreMarketHours) ?? defaults.ignoreMarketHours
        maxQuoteAge = try container.decodeIfPresent(Double.self, forKey: .maxQuoteAge) ?? defaults.maxQuoteAge
        chartStyle = try container.decodeIfPresent(ChartStyle.self, forKey: .chartStyle) ?? defaults.chartStyle
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? defaults.hapticsEnabled
        watchlistSort = try container.decodeIfPresent(WatchlistSort.self, forKey: .watchlistSort) ?? defaults.watchlistSort
        groupWatchlist = try container.decodeIfPresent(Bool.self, forKey: .groupWatchlist) ?? defaults.groupWatchlist
    }
}
