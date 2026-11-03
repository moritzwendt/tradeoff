import SwiftData
import SwiftUI

struct WatchlistScreen: View {
    @Environment(QuoteHub.self) private var hub
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Query(sort: \WatchlistEntry.sortIndex) private var entries: [WatchlistEntry]
    @State private var filter: AssetFilter = .all

    private struct Group: Identifiable {
        let assetClass: AssetClass?
        let instruments: [Instrument]

        var id: String { assetClass?.rawValue ?? "all" }
    }

    private var visible: [Instrument] {
        let items = entries.map(\.instrument).filter { filter.assetClass == nil || $0.assetClass == filter.assetClass }
        return WatchlistOrdering.sorted(items, by: settings.values.watchlistSort, quotes: hub.quotes)
    }

    private var groups: [Group] {
        let items = visible
        guard settings.values.groupWatchlist, filter == .all else {
            return items.isEmpty ? [] : [Group(assetClass: nil, instruments: items)]
        }
        return AssetClass.allCases.compactMap { assetClass in
            let part = items.filter { $0.assetClass == assetClass }
            return part.isEmpty ? nil : Group(assetClass: assetClass, instruments: part)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenHeader(title: "Märkte") { TopBarActions() }
                List {
                    FilterChips(
                        items: AssetFilter.available(in: hub.registry.activeAssetClasses),
                        selection: $filter
                    ) { $0.title }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    sortRow
                        .listRowInsets(EdgeInsets(top: 0, leading: Theme.screenPadding, bottom: 0, trailing: Theme.screenPadding))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    if entries.isEmpty {
                        ContentUnavailableView("Keine Einträge", systemImage: "star")
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.top, 48)
                    }
                    ForEach(groups) { group in
                        Section {
                            if let assetClass = group.assetClass {
                                SectionHeader(title: assetClass.title, detail: marketDetail(for: assetClass))
                                    .listRowInsets(EdgeInsets(top: 12, leading: Theme.screenPadding, bottom: 4, trailing: Theme.screenPadding))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                            }
                            ForEach(group.instruments) { instrument in
                                row(instrument)
                            }
                        }
                        .listSectionSeparator(.hidden)
                    }
                    Color.clear
                        .frame(height: 24)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .environment(\.defaultMinListHeaderHeight, 0)
                .listSectionSpacing(0)
                .refreshable {
                    await hub.refresh(entries.map(\.instrument))
                }
            }
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottom) {
                ConnectionBanner()
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.bottom, 8)
            }
            .navigationDestination(for: Instrument.self) { InstrumentDetailScreen(instrument: $0) }
        }
    }

    private var sortRow: some View {
        @Bindable var settings = settings
        return HStack {
            Menu {
                Picker("Sortierung", selection: $settings.values.watchlistSort) {
                    ForEach(WatchlistSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
                Toggle("Nach Anlageklasse gruppieren", isOn: $settings.values.groupWatchlist)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(settings.values.watchlistSort.title)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .font(Typography.labelStrong)
                .foregroundStyle(Theme.textSecondary)
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .accessibilityLabel("Sortierung")
            Spacer(minLength: 0)
        }
    }

    private func row(_ instrument: Instrument) -> some View {
        NavigationLink(value: instrument) {
            WatchlistRow(instrument: instrument)
        }
        .navigationLinkIndicatorVisibility(.hidden)
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(Theme.separator)
        .listRowInsets(EdgeInsets(top: 0, leading: Theme.screenPadding, bottom: 0, trailing: Theme.screenPadding))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Entfernen", systemImage: "star.slash", role: .destructive) {
                remove(instrument)
            }
        }
    }

    private func marketDetail(for assetClass: AssetClass) -> String? {
        guard assetClass.calendarKind == .usEquities else { return nil }
        switch MarketCalendars().session(for: assetClass, at: Date()) {
        case .always: return nil
        case .open(let closesAt): return "Geöffnet bis \(TimeFormat.clock(closesAt))"
        case .closed(let opensAt):
            guard let opensAt else { return "Geschlossen" }
            return "Geschlossen, öffnet \(TimeFormat.opening(opensAt))"
        }
    }

    private func remove(_ instrument: Instrument) {
        guard let entry = entries.first(where: { $0.instrumentID == instrument.id }) else { return }
        context.delete(entry)
        try? context.save()
    }
}
