import SwiftData
import SwiftUI

struct SearchScreen: View {
    @Environment(QuoteHub.self) private var hub
    @Environment(\.modelContext) private var context
    @Query private var entries: [WatchlistEntry]
    @State private var query = ""
    @State private var results: [Instrument] = []

    private struct Group: Identifiable {
        let assetClass: AssetClass
        let instruments: [Instrument]

        var id: AssetClass { assetClass }
    }

    private var groups: [Group] {
        AssetClass.allCases.compactMap { assetClass in
            let items = results.filter { $0.assetClass == assetClass }
            return items.isEmpty ? nil : Group(assetClass: assetClass, instruments: items)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if results.isEmpty, !query.isEmpty {
                        ContentUnavailableView.search(text: query)
                            .padding(.top, 40)
                    }
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.assetClass.title)
                                .font(.title3.weight(.bold))
                                .padding(.horizontal, 6)
                            GlassCard(padding: 0) {
                                VStack(spacing: 0) {
                                    ForEach(group.instruments) { instrument in
                                        row(instrument)
                                        if instrument.id != group.instruments.last?.id {
                                            StatDivider().padding(.leading, 68)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .navigationTitle("Suche")
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Suchen")
            .navigationDestination(for: Instrument.self) { InstrumentDetailScreen(instrument: $0) }
            .task(id: query) {
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                let found = query.trimmingCharacters(in: .whitespaces).isEmpty
                    ? await hub.catalog()
                    : await hub.search(query)
                results = found
            }
        }
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
                        Text(instrument.name)
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button {
                toggle(instrument)
            } label: {
                Image(systemName: isWatched ? "star.fill" : "star")
                    .font(.title3)
                    .foregroundStyle(isWatched ? Theme.simulation : Theme.textSecondary)
                    .frame(width: 40, height: 40)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isWatched ? "Von Watchlist entfernen" : "Zur Watchlist")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .haptic(.selection, trigger: isWatched)
    }

    private func toggle(_ instrument: Instrument) {
        if let entry = entries.first(where: { $0.instrumentID == instrument.id }) {
            context.delete(entry)
        } else {
            context.insert(WatchlistEntry(instrument: instrument, sortIndex: entries.count))
        }
        try? context.save()
    }
}
