import SwiftData
import SwiftUI

struct SearchScreen: View {
    @Environment(QuoteHub.self) private var hub
    @Environment(\.modelContext) private var context
    @Query private var entries: [WatchlistEntry]
    @AppStorage(RecentSearches.storageKey) private var recentsText = ""
    @State private var query = ""
    @State private var results: [Instrument] = []
    @State private var suggestions: [Instrument] = []
    @State private var isSearching = false

    private struct Group: Identifiable {
        let assetClass: AssetClass
        let instruments: [Instrument]

        var id: AssetClass { assetClass }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private var recents: [Instrument] {
        RecentSearches.decode(recentsText)
    }

    private func groups(of instruments: [Instrument]) -> [Group] {
        AssetClass.allCases.compactMap { assetClass in
            let items = instruments.filter { $0.assetClass == assetClass }
            return items.isEmpty ? nil : Group(assetClass: assetClass, instruments: items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    idleContent
                } else {
                    resultContent
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .navigationTitle("Suche")
            .searchable(text: $query, prompt: "Suchen")
            .navigationDestination(for: Instrument.self) { InstrumentDetailScreen(instrument: $0) }
            .task { suggestions = await hub.catalog() }
            .task(id: trimmedQuery) { await runSearch() }
        }
    }

    @ViewBuilder
    private var idleContent: some View {
        if !recents.isEmpty {
            Section {
                ForEach(recents) { row($0) }
            } header: {
                header("Zuletzt gesucht") {
                    Button("Leeren") { recentsText = "" }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .listSectionSeparator(.hidden)
        }
        ForEach(groups(of: suggestions)) { group in
            Section {
                ForEach(group.instruments) { row($0) }
            } header: {
                header(group.assetClass.title) { EmptyView() }
            }
            .listSectionSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        if isSearching && results.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.top, 40)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        } else if results.isEmpty {
            ContentUnavailableView.search(text: trimmedQuery)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.top, 40)
        } else {
            ForEach(groups(of: results)) { group in
                Section {
                    ForEach(group.instruments) { row($0) }
                } header: {
                    header(group.assetClass.title) { EmptyView() }
                }
                .listSectionSeparator(.hidden)
            }
        }
    }

    private func header<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            SectionHeader(title: title)
            trailing()
        }
        .textCase(nil)
        .padding(.top, 8)
    }

    private func row(_ instrument: Instrument) -> some View {
        let isWatched = entries.contains { $0.instrumentID == instrument.id }
        return HStack(spacing: 12) {
            NavigationLink(value: instrument) {
                HStack(spacing: 12) {
                    AssetIcon(instrument: instrument)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(instrument.symbol)
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text([instrument.name, instrument.network].compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .frame(minHeight: Theme.rowHeight)
                .contentShape(.rect)
            }
            .navigationLinkIndicatorVisibility(.hidden)
            .simultaneousGesture(TapGesture().onEnded { remember(instrument) })

            Button {
                toggle(instrument)
            } label: {
                Image(systemName: isWatched ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(isWatched ? Theme.textPrimary : Theme.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isWatched ? "Von Watchlist entfernen" : "Zur Watchlist")
        }
        .listRowBackground(Color.clear)
        .listRowSeparatorTint(Theme.separator)
        .listRowInsets(EdgeInsets(top: 0, leading: Theme.screenPadding, bottom: 0, trailing: 8))
        .haptic(.selection, trigger: isWatched)
    }

    private func runSearch() async {
        guard !trimmedQuery.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let found = await hub.search(trimmedQuery)
        guard !Task.isCancelled else { return }
        results = found
        isSearching = false
    }

    private func remember(_ instrument: Instrument) {
        recentsText = RecentSearches.encode(RecentSearches.adding(instrument, to: recents))
    }

    private func toggle(_ instrument: Instrument) {
        if let entry = entries.first(where: { $0.instrumentID == instrument.id }) {
            context.delete(entry)
        } else {
            context.insert(WatchlistEntry(instrument: instrument, sortIndex: entries.count))
            remember(instrument)
        }
        try? context.save()
    }
}
