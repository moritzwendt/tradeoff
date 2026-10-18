import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case markets
    case portfolio
    case history
    case settings
    case search
}

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(QuoteHub.self) private var hub
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \WatchlistEntry.sortIndex) private var watchlist: [WatchlistEntry]
    @Query private var positions: [PositionRecord]
    @State private var selection: AppTab = .markets

    private var watchedInstruments: [Instrument] {
        watchlist.map(\.instrument) + positions.map(\.instrument)
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab("Märkte", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.markets) {
                WatchlistScreen()
            }
            Tab("Portfolio", systemImage: "chart.pie", value: AppTab.portfolio) {
                PortfolioScreen()
            }
            Tab("Verlauf", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                HistoryScreen()
            }
            Tab("Einstellungen", systemImage: "gearshape", value: AppTab.settings) {
                SettingsScreen()
            }
            Tab(value: AppTab.search, role: .search) {
                SearchScreen()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .task { await environment.prepare() }
        .task(id: watchedInstruments.map(\.id)) {
            hub.setBaseline(watchedInstruments)
        }
        .task { await recordEquityLoop() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: hub.resume()
            case .background: hub.pause()
            default: break
            }
        }
        .onChange(of: settings.values.mockVolatility) { Task { await environment.applyMockTuning() } }
        .onChange(of: settings.values.mockTickInterval) { Task { await environment.applyMockTuning() } }
    }

    private func recordEquityLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(60))
            environment.recorder.record()
        }
    }
}
