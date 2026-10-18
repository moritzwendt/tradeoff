import SwiftData
import SwiftUI

struct InstrumentDetailScreen: View {
    let instrument: Instrument
    @State private var model: InstrumentDetailModel
    @State private var ticketSide: OrderSide?
    @Environment(QuoteHub.self) private var hub
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
    @Query private var positions: [PositionRecord]
    @Query private var watchEntries: [WatchlistEntry]

    init(instrument: Instrument) {
        self.instrument = instrument
        _model = State(initialValue: InstrumentDetailModel(instrument: instrument))
        let id = instrument.id
        _positions = Query(filter: #Predicate<PositionRecord> { $0.instrumentID == id })
        _watchEntries = Query(filter: #Predicate<WatchlistEntry> { $0.instrumentID == id })
    }

    var body: some View {
        let quote = hub.quote(for: instrument.id)
        let candles = model.liveCandles(quote: quote)
        let selected = model.selectedIndex.flatMap { candles.indices.contains($0) ? candles[$0] : nil }
        let change = model.rangeChange(in: candles)

        ScrollView {
            VStack(spacing: 16) {
                header(quote: quote, selected: selected, change: change)
                chartCard(candles: candles, selected: selected, change: change)
                marketCard(quote: quote)
                if let position = positions.first {
                    positionCard(position: position, quote: quote)
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(AppBackground())
        .navigationTitle(instrument.symbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    toggleWatchlist()
                } label: {
                    Image(systemName: watchEntries.isEmpty ? "star" : "star.fill")
                }
                .accessibilityLabel(watchEntries.isEmpty ? "Zur Watchlist" : "Von Watchlist entfernen")
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .safeAreaBar(edge: .bottom) { actionBar }
        .sheet(item: $ticketSide) { side in
            OrderTicketScreen(instrument: instrument, side: side)
        }
        .task(id: model.range) { await model.load(using: hub) }
        .onAppear { hub.pin(instrument) }
        .onDisappear { hub.unpin(instrument) }
        .haptic(.selection, trigger: watchEntries.isEmpty)
    }

    private func header(quote: Quote?, selected: Candlestick?, change: (value: Decimal, fraction: Decimal)?) -> some View {
        let session = MarketCalendars().session(for: instrument.assetClass, at: Date())
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                AssetIcon(instrument: instrument, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(instrument.name)
                        .font(.title3.weight(.semibold))
                    Text(instrument.assetClass.singularTitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    if let quote {
                        QualityBadge(quality: quote.quality)
                    }
                    MarketSessionBadge(session: session)
                }
            }

            if let price = selected?.close ?? quote?.last {
                PriceText(value: price, font: .system(size: 46, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            } else {
                Text("0,00 $")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .redacted(reason: .placeholder)
            }

            HStack(spacing: 10) {
                if let selected {
                    Text(TimeFormat.detail(selected.time, range: model.range))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                } else if let change {
                    ChangePill(fraction: change.fraction)
                    Text(PriceFormatter.change(change.value))
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.pnl(change.value))
                }
            }
            .frame(minHeight: 28)
        }
        .padding(.horizontal, 4)
    }

    private func chartCard(candles: [Candlestick], selected: Candlestick?, change: (value: Decimal, fraction: Decimal)?) -> some View {
        @Bindable var bindableModel = model
        let tint = Theme.pnl(change?.value ?? 0) == Theme.textSecondary ? Theme.accent : Theme.pnl(change?.value ?? 0)
        return GlassCard(padding: 14) {
            VStack(spacing: 14) {
                HStack {
                    if let selected, settings.values.chartStyle == .candles {
                        CandleInfoRow(candle: selected)
                    } else {
                        Spacer(minLength: 0)
                    }
                    ChartStyleToggle()
                }
                .frame(minHeight: 36)

                ZStack {
                    if candles.isEmpty {
                        if model.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.largeTitle)
                                .foregroundStyle(Theme.textTertiary)
                        }
                    } else {
                        PriceChart(
                            candles: candles,
                            style: settings.values.chartStyle,
                            range: model.range,
                            tint: tint,
                            selectedIndex: $bindableModel.selectedIndex
                        )
                    }
                }
                .frame(height: 260)

                SegmentedControl(items: ChartRange.allCases, selection: $bindableModel.range) { $0.title }
            }
        }
    }

    private func marketCard(quote: Quote?) -> some View {
        GlassCard {
            VStack(spacing: 0) {
                if let quote {
                    StatRow(title: "Geld", value: PriceFormatter.price(quote.bid))
                    StatDivider()
                    StatRow(title: "Brief", value: PriceFormatter.price(quote.ask))
                    StatDivider()
                    StatRow(title: "Spread", value: PriceFormatter.percent(quote.spreadFraction, signed: false))
                    StatDivider()
                    StatRow(title: "Tageshoch", value: PriceFormatter.price(quote.dayHigh))
                    StatDivider()
                    StatRow(title: "Tagestief", value: PriceFormatter.price(quote.dayLow))
                    StatDivider()
                    StatRow(title: "Vortag", value: PriceFormatter.price(quote.previousClose))
                    if let liquidity = quote.liquidityUSD {
                        StatDivider()
                        StatRow(title: "Liquidität", value: PriceFormatter.compactMoney(liquidity))
                    }
                    StatDivider()
                    StatRow(title: "Quelle", value: quote.source.displayName)
                } else {
                    StatRow(title: "Geld", value: "0,00 $").redacted(reason: .placeholder)
                    StatDivider()
                    StatRow(title: "Brief", value: "0,00 $").redacted(reason: .placeholder)
                }
            }
        }
    }

    private func positionCard(position: PositionRecord, quote: Quote?) -> some View {
        let price = quote?.bid ?? position.averageCost
        let value = (position.quantity * price).rounded(scale: 2)
        let cost = (position.quantity * position.averageCost).rounded(scale: 2)
        let pnl = value - cost
        let fraction = cost > 0 ? pnl / cost : 0
        return GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text("Position")
                    .font(.headline)
                    .padding(.bottom, 4)
                StatRow(title: "Menge", value: PriceFormatter.quantity(position.quantity, assetClass: instrument.assetClass))
                StatDivider()
                StatRow(title: "Einstand", value: PriceFormatter.price(position.averageCost))
                StatDivider()
                StatRow(title: "Wert", value: PriceFormatter.money(value))
                StatDivider()
                StatRow(
                    title: "Gewinn und Verlust",
                    value: "\(PriceFormatter.money(pnl, signed: true))  \(PriceFormatter.percent(fraction))",
                    valueColor: Theme.pnl(pnl)
                )
            }
        }
    }

    private var actionBar: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    ticketSide = .sell
                } label: {
                    Text(OrderSide.sell.title)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.negative)
                .disabled(positions.isEmpty)

                Button {
                    ticketSide = .buy
                } label: {
                    Text(OrderSide.buy.title)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.positive)
            }
        }
        .padding(.horizontal, Theme.screenPadding)
        .padding(.bottom, 8)
    }

    private func toggleWatchlist() {
        if let entry = watchEntries.first {
            context.delete(entry)
        } else {
            let nextIndex = ((try? context.fetchCount(FetchDescriptor<WatchlistEntry>())) ?? 0)
            context.insert(WatchlistEntry(instrument: instrument, sortIndex: nextIndex))
        }
        try? context.save()
    }
}

private struct ChartStyleToggle: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        SegmentedControl(items: ChartStyle.allCases, selection: $settings.values.chartStyle) { style, isSelected in
            Image(systemName: style.systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
        }
        .frame(width: 96)
        .accessibilityLabel("Chartstil")
    }
}
