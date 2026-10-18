import Charts
import SwiftData
import SwiftUI

struct PortfolioScreen: View {
    @Environment(QuoteHub.self) private var hub
    @Query private var accounts: [AccountRecord]
    @Query private var positions: [PositionRecord]
    @Query(sort: \EquitySnapshotRecord.time) private var snapshots: [EquitySnapshotRecord]
    @State private var range: ChartRange = .month
    @State private var selectedPoint: EquityPoint?

    private var valuation: PortfolioValuation {
        let account = accounts.first?.snapshot
            ?? AccountSnapshot(cash: 0, startingBalance: 0, realizedPnL: 0, totalFees: 0)
        return PortfolioValuator.value(
            account: account,
            holdings: positions.map(\.holding),
            quotes: hub.quotes
        )
    }

    var body: some View {
        let current = valuation
        let points = equityPoints(for: current)

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard(valuation: current, points: points)
                    tiles(valuation: current)
                    if current.positions.isEmpty {
                        ContentUnavailableView("Keine Positionen", systemImage: "chart.pie")
                            .padding(.top, 24)
                    } else {
                        AllocationCard(valuation: current)
                        positionsCard(valuation: current)
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .navigationTitle("Portfolio")
            .navigationDestination(for: Instrument.self) { InstrumentDetailScreen(instrument: $0) }
        }
    }

    private func headerCard(valuation: PortfolioValuation, points: [EquityPoint]) -> some View {
        let first = points.first?.value ?? 0
        let last = points.last?.value ?? 0
        let hasHistory = points.count > 1 && first > 0
        let change = hasHistory ? Decimal(last - first) : valuation.totalReturn
        let fraction = hasHistory ? Decimal((last - first) / first) : valuation.totalReturnFraction
        let displayed = selectedPoint.map { Decimal($0.value, scale: 2) } ?? valuation.equity

        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Gesamtwert")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
                Text(PriceFormatter.money(displayed))
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: displayed.doubleValue))
                    .animation(.snappy(duration: 0.25), value: displayed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                HStack(spacing: 10) {
                    if let selectedPoint {
                        Text(TimeFormat.detail(selectedPoint.time, range: range))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        ChangePill(fraction: fraction)
                        Text(PriceFormatter.money(change, signed: true))
                            .font(.subheadline.weight(.medium))
                            .monospacedDigit()
                            .foregroundStyle(Theme.pnl(change))
                    }
                }
                .frame(minHeight: 28)

                if points.count > 1 {
                    EquityChart(
                        points: points,
                        range: range,
                        tint: Theme.pnl(change) == Theme.textSecondary ? Theme.accent : Theme.pnl(change),
                        selectedPoint: $selectedPoint
                    )
                    .frame(height: 200)
                } else {
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(height: 1)
                        .frame(height: 200)
                }

                SegmentedControl(items: ChartRange.allCases, selection: $range) { $0.title }
            }
        }
    }

    private func tiles(valuation: PortfolioValuation) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            tile("Guthaben", PriceFormatter.money(valuation.cash), Theme.textPrimary)
            tile("Investiert", PriceFormatter.money(valuation.positionsValue), Theme.textPrimary)
            tile("Unrealisiert", PriceFormatter.money(valuation.unrealizedPnL, signed: true), Theme.pnl(valuation.unrealizedPnL))
            tile("Realisiert", PriceFormatter.money(valuation.realizedPnL, signed: true), Theme.pnl(valuation.realizedPnL))
        }
    }

    private func tile(_ title: String, _ value: String, _ color: Color) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(color)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
    }

    private func positionsCard(valuation: PortfolioValuation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Positionen")
                .font(.title3.weight(.bold))
                .padding(.horizontal, 6)
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(valuation.positions) { row in
                        NavigationLink(value: row.holding.instrument) {
                            positionRow(row)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                        }
                        .buttonStyle(.plain)
                        if row.id != valuation.positions.last?.id {
                            StatDivider().padding(.leading, 68)
                        }
                    }
                }
            }
        }
    }

    private func positionRow(_ row: PositionValuation) -> some View {
        HStack(spacing: 12) {
            AssetIcon(instrument: row.holding.instrument)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.holding.instrument.symbol)
                    .font(.headline)
                Text("\(PriceFormatter.holding(row.holding.quantity, assetClass: row.holding.instrument.assetClass)) \(row.holding.instrument.symbol)")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(PriceFormatter.money(row.value))
                    .font(.headline)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("\(PriceFormatter.money(row.unrealizedPnL, signed: true)) \(PriceFormatter.percent(row.unrealizedFraction))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.pnl(row.unrealizedPnL))
                    .monospacedDigit()
            }
        }
        .contentShape(.rect)
    }

    private func equityPoints(for valuation: PortfolioValuation) -> [EquityPoint] {
        let now = Date()
        let cutoff = range == .max ? Date.distantPast : now.addingTimeInterval(-range.duration)
        var points = snapshots
            .filter { $0.time >= cutoff }
            .map { EquityPoint(time: $0.time, value: $0.equity.doubleValue) }
        points.append(EquityPoint(time: now, value: valuation.equity.doubleValue))
        return points
    }
}
