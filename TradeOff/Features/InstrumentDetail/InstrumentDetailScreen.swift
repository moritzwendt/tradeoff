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
        let change = model.rangeChange(in: candles) ?? quote.map { (value: $0.change, fraction: $0.changeFraction) }

        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header(quote: quote, selected: selected, change: change)
                chartSection(candles: candles, selected: selected, change: change)
                statsSection(quote: quote)
                if let position = positions.first {
                    positionSection(position: position, quote: quote)
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
                        .foregroundStyle(Theme.textPrimary)
                }
                .accessibilityLabel(watchEntries.isEmpty ? "Zur Watchlist" : "Von Watchlist entfernen")
            }
        }
        .toolbarVisibility(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
        .overlay(alignment: .top) {
            ConnectionBanner()
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 4)
        }
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
        let subtitle = [instrument.assetClass.singularTitle, instrument.network].compactMap { $0 }.joined(separator: " · ")
        let price = selected?.close ?? quote?.last
        return VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(instrument.name)
                    .font(Typography.section)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Text(subtitle)
                        if instrument.assetClass.calendarKind == .usEquities {
                            MarketSessionBadge(session: session)
                        }
                    }
                    Text(subtitle)
                }
                .font(Typography.rowDetail)
                .foregroundStyle(Theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Group {
                    if let price {
                        PriceText(value: price, font: Typography.display)
                            .foregroundStyle(Theme.textPrimary)
                    } else {
                        Text("000,00 $")
                            .font(Typography.display)
                            .placeholder(true)
                    }
                }
                .minimumScaleFactor(0.6)

                HStack(spacing: 8) {
                    if let selected {
                        Text(TimeFormat.detail(selected.time, range: model.range))
                            .foregroundStyle(Theme.textSecondary)
                    } else if let change {
                        Text(PriceFormatter.change(change.value))
                        Text(PriceFormatter.percent(change.fraction))
                    } else {
                        Text("+0,00 $  +0,00 %")
                            .placeholder(true)
                    }
                }
                .font(Typography.value)
                .monospacedDigit()
                .foregroundStyle(selected == nil && change != nil ? Theme.pnl(change?.value ?? 0) : Theme.textSecondary)
                .frame(minHeight: 22, alignment: .leading)
            }
        }
    }

    private func chartSection(candles: [Candlestick], selected: Candlestick?, change: (value: Decimal, fraction: Decimal)?) -> some View {
        @Bindable var bindableModel = model
        let tint = Theme.pnl(change?.value ?? 0)
        let color = tint == Theme.textSecondary ? Theme.textPrimary : tint
        return VStack(spacing: 12) {
            HStack {
                if let selected, settings.values.chartStyle == .candles {
                    CandleInfoRow(candle: selected)
                } else {
                    Spacer(minLength: 0)
                }
                ChartStyleToggle()
            }
            .frame(minHeight: 34)

            ZStack {
                if candles.isEmpty {
                    if model.loadFailed {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(Typography.display)
                                .foregroundStyle(Theme.textTertiary)
                            Text("Verlauf nicht verfügbar")
                                .font(Typography.value)
                                .foregroundStyle(Theme.textSecondary)
                            Button("Erneut laden") {
                                Task { await model.load(using: hub) }
                            }
                            .font(Typography.labelStrong)
                            .foregroundStyle(Theme.textPrimary)
                            .padding(.horizontal, 16)
                            .frame(minHeight: 44)
                            .background(Theme.surfaceRaised, in: .capsule)
                            .buttonStyle(.plain)
                        }
                    } else {
                        ChartPlaceholder(values: hub.sparklines[instrument.id])
                            .appearsAfter(.milliseconds(150))
                    }
                } else {
                    PriceChart(
                        candles: candles,
                        style: settings.values.chartStyle,
                        range: model.range,
                        tint: color,
                        selectedIndex: $bindableModel.selectedIndex
                    )
                    .transition(.opacity)
                }
            }
            .frame(height: 260)
            .animation(.easeOut(duration: 0.25), value: candles.isEmpty)

            SegmentedControl(items: ChartRange.allCases, selection: $bindableModel.range) { $0.title }
        }
    }

    private func statsSection(quote: Quote?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Kennzahlen")
            Card {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 18) {
                    if let quote {
                        ForEach(stats(for: quote), id: \.0) { stat in
                            statCell(stat.0, stat.1)
                        }
                    } else {
                        ForEach(["Geld", "Brief", "Spread", "Hoch 24h", "Tief 24h", "Vor 24h"], id: \.self) { title in
                            statCell(title, "000,00 $").placeholder(true)
                        }
                    }
                }
            }
        }
    }

    private func stats(for quote: Quote) -> [(String, String)] {
        var items: [(String, String)] = [
            ("Geld", PriceFormatter.price(quote.bid)),
            ("Brief", PriceFormatter.price(quote.ask)),
            ("Spread", PriceFormatter.percent(quote.spreadFraction, signed: false))
        ]
        if let high = quote.dayHigh, let low = quote.dayLow {
            items.append(("Hoch 24h", PriceFormatter.price(high)))
            items.append(("Tief 24h", PriceFormatter.price(low)))
        }
        items.append(("Vor 24h", PriceFormatter.price(quote.previousClose)))
        if let liquidity = quote.liquidityUSD {
            items.append(("Liquidität", PriceFormatter.compactMoney(liquidity)))
        }
        items.append(("Quelle", quote.source.displayName))
        return items
    }

    private func statCell(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(Typography.label)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(Typography.value)
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func positionSection(position: PositionRecord, quote: Quote?) -> some View {
        let price = quote?.bid ?? position.averageCost
        let value = (position.quantity * price).rounded(scale: 2)
        let cost = (position.quantity * position.averageCost).rounded(scale: 2)
        let pnl = value - cost
        let fraction = cost > 0 ? pnl / cost : 0
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Position")
            Card {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], alignment: .leading, spacing: 18) {
                    statCell("Menge", PriceFormatter.quantity(position.quantity, assetClass: instrument.assetClass))
                    statCell("Einstand", PriceFormatter.price(position.averageCost))
                    statCell("Wert", PriceFormatter.money(value))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gewinn und Verlust")
                            .font(Typography.label)
                            .foregroundStyle(Theme.textSecondary)
                        Text("\(PriceFormatter.money(pnl, signed: true)) \(PriceFormatter.percent(fraction))")
                            .font(Typography.value)
                            .monospacedDigit()
                            .foregroundStyle(Theme.pnl(pnl))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Theme.separator)
                .frame(height: 0.5)
            HStack(spacing: 12) {
                if !positions.isEmpty {
                    Button(OrderSide.sell.title) {
                        ticketSide = .sell
                    }
                    .buttonStyle(.filled(Theme.surfaceRaised, foreground: Theme.negative))
                }
                Button(OrderSide.buy.title) {
                    ticketSide = .buy
                }
                .buttonStyle(.filled(Theme.positive))
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(Theme.background)
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
                .font(Typography.labelStrong)
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
        }
        .frame(width: 96)
        .padding(2)
        .background(Theme.surface, in: .capsule)
        .accessibilityLabel("Chartstil")
    }
}
