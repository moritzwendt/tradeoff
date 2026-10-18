import SwiftData
import SwiftUI

struct WatchlistScreen: View {
    @Environment(QuoteHub.self) private var hub
    @Environment(\.modelContext) private var context
    @Query(sort: \WatchlistEntry.sortIndex) private var entries: [WatchlistEntry]
    @State private var filter: AssetFilter = .all

    private struct Section: Identifiable {
        let assetClass: AssetClass
        let entries: [WatchlistEntry]

        var id: AssetClass { assetClass }
    }

    private var sections: [Section] {
        AssetClass.allCases.compactMap { assetClass in
            guard filter.assetClass == nil || filter.assetClass == assetClass else { return nil }
            let items = entries.filter { $0.instrument.assetClass == assetClass }
            return items.isEmpty ? nil : Section(assetClass: assetClass, entries: items)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    FilterChips(items: AssetFilter.allCases, selection: $filter) { $0.title }
                        .padding(.horizontal, -Theme.screenPadding)

                    if entries.isEmpty {
                        ContentUnavailableView("Keine Einträge", systemImage: "star")
                            .padding(.top, 60)
                    } else {
                        ForEach(sections) { section in
                            sectionView(section)
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .navigationTitle("Märkte")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if let quality = dominantQuality {
                        QualityBadge(quality: quality)
                    }
                }
            }
            .navigationDestination(for: Instrument.self) { InstrumentDetailScreen(instrument: $0) }
        }
    }

    private var dominantQuality: QuoteQuality? {
        hub.quotes.values.first?.quality
    }

    private func sectionView(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if filter == .all {
                Text(section.assetClass.title)
                    .font(.title3.weight(.bold))
                    .padding(.horizontal, 6)
            }
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(section.entries) { entry in
                        NavigationLink(value: entry.instrument) {
                            WatchlistRow(instrument: entry.instrument)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Entfernen", systemImage: "star.slash", role: .destructive) {
                                remove(entry)
                            }
                        }
                        if entry.id != section.entries.last?.id {
                            StatDivider().padding(.leading, 68)
                        }
                    }
                }
            }
        }
    }

    private func remove(_ entry: WatchlistEntry) {
        context.delete(entry)
        try? context.save()
    }
}
