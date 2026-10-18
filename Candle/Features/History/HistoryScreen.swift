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
            ScrollView {
                VStack(spacing: 18) {
                    if fills.isEmpty {
                        ContentUnavailableView("Keine Trades", systemImage: "clock.arrow.circlepath")
                            .padding(.top, 60)
                    } else {
                        summary
                        FilterChips(items: HistoryFilter.allCases, selection: $filter) { $0.title }
                            .padding(.horizontal, -Theme.screenPadding)
                        ForEach(groups) { group in
                            dayView(group)
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .navigationTitle("Verlauf")
            .sheet(item: $selected) { fill in
                FillDetailSheet(fill: fill)
            }
        }
    }

    private var summary: some View {
        let fees = fills.reduce(Decimal(0)) { $0 + $1.fee }
        let realized = fills.reduce(Decimal(0)) { $0 + $1.realizedPnL }
        return HStack(spacing: 12) {
            tile("Trades", "\(fills.count)", Theme.textPrimary)
            tile("Gebühren", PriceFormatter.money(fees), Theme.textPrimary)
            tile("Realisiert", PriceFormatter.money(realized, signed: true), Theme.pnl(realized))
        }
    }

    private func tile(_ title: String, _ value: String, _ color: Color) -> some View {
        GlassCard(padding: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private func dayView(_ group: DayGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(TimeFormat.dayTitle(group.day))
                .font(.title3.weight(.bold))
                .padding(.horizontal, 6)
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(group.fills) { fill in
                        Button {
                            selected = fill
                        } label: {
                            FillRow(fill: fill)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)
                        if fill.id != group.fills.last?.id {
                            StatDivider().padding(.leading, 68)
                        }
                    }
                }
            }
        }
    }
}

private struct FillRow: View {
    let fill: FillRecord

    var body: some View {
        HStack(spacing: 12) {
            AssetIcon(instrument: fill.instrument)
            VStack(alignment: .leading, spacing: 2) {
                Text(fill.instrument.symbol)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(fill.side == .buy ? "Kauf" : "Verkauf")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(fill.side == .buy ? Theme.positive : Theme.negative)
                    Text(PriceFormatter.holding(fill.quantity, assetClass: fill.instrument.assetClass))
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(PriceFormatter.money(fill.total))
                    .font(.headline)
                    .monospacedDigit()
                if fill.side == .sell {
                    Text(PriceFormatter.money(fill.realizedPnL, signed: true))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.pnl(fill.realizedPnL))
                        .monospacedDigit()
                } else {
                    Text(TimeFormat.clock(fill.timestamp))
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .contentShape(.rect)
    }
}
