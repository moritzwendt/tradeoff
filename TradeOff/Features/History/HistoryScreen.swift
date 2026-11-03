import SwiftData
import SwiftUI

struct HistoryScreen: View {
    @Query(sort: \FillRecord.timestamp, order: .reverse) private var fills: [FillRecord]
    @State private var filter: HistoryFilter = .all
    @State private var selected: FillRecord?

    private struct DayGroup: Identifiable {
        let day: Date
        let fills: [FillRecord]

        var id: Date { day }
    }

    private var filtered: [FillRecord] {
        fills.filter { filter.includes($0.side) }
    }

    private var groups: [DayGroup] {
        Dictionary(grouping: filtered) { Calendar.current.startOfDay(for: $0.timestamp) }
            .map { DayGroup(day: $0.key, fills: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScreenHeader(title: "Verlauf") { TopBarActions() }
                List {
                    if fills.isEmpty {
                        ContentUnavailableView("Keine Trades", systemImage: "clock.arrow.circlepath")
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .padding(.top, 48)
                    } else {
                        summary
                            .listRowInsets(EdgeInsets(top: 4, leading: Theme.screenPadding, bottom: 12, trailing: Theme.screenPadding))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        FilterChips(items: HistoryFilter.allCases, selection: $filter) { $0.title }
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        ForEach(groups) { group in
                            Section {
                                SectionHeader(title: TimeFormat.dayTitle(group.day))
                                    .listRowInsets(EdgeInsets(top: 16, leading: Theme.screenPadding, bottom: 4, trailing: Theme.screenPadding))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                ForEach(group.fills) { fill in
                                    Button {
                                        selected = fill
                                    } label: {
                                        FillRow(fill: fill)
                                    }
                                    .buttonStyle(.plain)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparatorTint(Theme.separator)
                                    .listRowInsets(EdgeInsets(top: 0, leading: Theme.screenPadding, bottom: 0, trailing: Theme.screenPadding))
                                }
                            }
                            .listSectionSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .environment(\.defaultMinListHeaderHeight, 0)
            }
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $selected) { fill in
                FillDetailSheet(fill: fill)
            }
        }
    }

    private var summary: some View {
        let fees = fills.reduce(Decimal(0)) { $0 + $1.fee }
        let realized = fills.reduce(Decimal(0)) { $0 + $1.realizedPnL }
        return Card(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                stat("Trades", "\(fills.count)", Theme.textPrimary)
                stat("Gebühren", PriceFormatter.money(fees), Theme.textPrimary)
                stat("Realisiert", PriceFormatter.money(realized, signed: true), Theme.pnl(realized))
            }
        }
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Typography.label)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(Typography.value)
                .foregroundStyle(color)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FillRow: View {
    let fill: FillRecord

    var body: some View {
        HStack(spacing: 12) {
            AssetIcon(instrument: fill.instrument)
            VStack(alignment: .leading, spacing: 2) {
                Text(fill.instrument.symbol)
                    .font(Typography.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
                HStack(spacing: 6) {
                    Text(fill.side == .buy ? "Kauf" : "Verkauf")
                        .font(Typography.value)
                        .foregroundStyle(Theme.textPrimary)
                    Text(PriceFormatter.holding(fill.quantity, assetClass: fill.instrument.assetClass))
                        .font(Typography.rowDetail)
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(PriceFormatter.money(fill.total))
                    .font(Typography.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                if fill.side == .sell {
                    Text(PriceFormatter.money(fill.realizedPnL, signed: true))
                        .font(Typography.labelStrong)
                        .foregroundStyle(Theme.pnl(fill.realizedPnL))
                        .monospacedDigit()
                } else {
                    Text(TimeFormat.clock(fill.timestamp))
                        .font(Typography.label)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .frame(minHeight: Theme.rowHeight)
        .contentShape(.rect)
    }
}
