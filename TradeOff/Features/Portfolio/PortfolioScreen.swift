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
            VStack(spacing: 0) {
                ScreenHeader(title: "Portfolio") { TopBarActions() }
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        headerSection(valuation: current, points: points)
                        overview(valuation: current)
                        if current.positions.isEmpty {
                            ContentUnavailableView("Keine Positionen", systemImage: "chart.pie")
                                .padding(.top, 8)
                        } else {
                            positionsSection(valuation: current)
                            AllocationCard(valuation: current)
                        }
                    }
                    .padding(.horizontal, Theme.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.hidden)
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

    private func headerSection(valuation: PortfolioValuation, points: [EquityPoint]) -> some View {
        let first = points.first?.value ?? 0
        let last = points.last?.value ?? 0
        let hasHistory = points.count > 1 && first > 0
        let change = hasHistory ? Decimal(last - first) : valuation.totalReturn
        let fraction = hasHistory ? Decimal((last - first) / first) : valuation.totalReturnFraction
        let displayed = selectedPoint.map { Decimal($0.value, scale: 2) } ?? valuation.equity
        let color = Theme.pnl(change) == Theme.textSecondary ? Theme.textPrimary : Theme.pnl(change)

        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Gesamtwert")
                    .font(Typography.rowDetail)
                    .foregroundStyle(Theme.textSecondary)
                Text(PriceFormatter.money(displayed))
                    .font(Typography.display)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .contentTransition(.numericText(value: displayed.doubleValue))
                    .animation(.snappy(duration: 0.25), value: displayed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                HStack(spacing: 8) {
                    if let selectedPoint {
                        Text(TimeFormat.detail(selectedPoint.time, range: range))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        Text(PriceFormatter.money(change, signed: true))
                        Text(PriceFormatter.percent(fraction))
                    }
                }
                .font(Typography.value)
                .monospacedDigit()
                .foregroundStyle(selectedPoint == nil ? Theme.pnl(change) : Theme.textSecondary)
                .frame(minHeight: 22)
            }

            if points.count > 1 {
                EquityChart(points: points, range: range, tint: color, selectedPoint: $selectedPoint)
                    .frame(height: 200)
                SegmentedControl(items: ChartRange.allCases, selection: $range) { $0.title }
            }
        }
    }

    private func overview(valuation: PortfolioValuation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Übersicht")
            Card {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 18) {
                    stat("Guthaben", PriceFormatter.money(valuation.cash), Theme.textPrimary)
                    stat("Investiert", PriceFormatter.money(valuation.positionsValue), Theme.textPrimary)
                    stat("Unrealisiert", PriceFormatter.money(valuation.unrealizedPnL, signed: true), Theme.pnl(valuation.unrealizedPnL))
                    stat("Realisiert", PriceFormatter.money(valuation.realizedPnL, signed: true), Theme.pnl(valuation.realizedPnL))
                }
            }
        }
    }

    private func stat(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Typography.label)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(Typography.rowTitle)
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func positionsSection(valuation: PortfolioValuation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionHeader(title: "Positionen")
                .padding(.bottom, 8)
            VStack(spacing: 0) {
                ForEach(valuation.positions) { row in
                    NavigationLink(value: row.holding.instrument) {
                        positionRow(row)
                    }
                    .buttonStyle(.plain)
                    if row.id != valuation.positions.last?.id {
                        StatDivider().padding(.leading, 52)
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
                    .font(Typography.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(PriceFormatter.holding(row.holding.quantity, assetClass: row.holding.instrument.assetClass)) \(row.holding.instrument.symbol)")
                    .font(Typography.rowDetail)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(PriceFormatter.money(row.value))
                    .font(Typography.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("\(PriceFormatter.money(row.unrealizedPnL, signed: true)) \(PriceFormatter.percent(row.unrealizedFraction))")
                    .font(Typography.labelStrong)
                    .foregroundStyle(Theme.pnl(row.unrealizedPnL))
                    .monospacedDigit()
            }
        }
        .frame(minHeight: Theme.rowHeight)
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
