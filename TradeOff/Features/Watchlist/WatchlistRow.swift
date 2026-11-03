import SwiftUI

struct WatchlistRow: View {
    let instrument: Instrument
    @Environment(QuoteHub.self) private var hub
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let quote = hub.quote(for: instrument.id)
        let trend = Theme.pnl(quote?.change ?? 0)
        let values = sparkValues(quote: quote)

        HStack(spacing: 12) {
            AssetIcon(instrument: instrument)
            VStack(alignment: .leading, spacing: 2) {
                Text(instrument.symbol)
                    .font(Typography.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(instrument.name)
                    .font(Typography.rowDetail)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !typeSize.isAccessibilitySize {
                sparkline(values: values, color: trend == Theme.textSecondary ? Theme.textSecondary : trend)
                    .frame(width: 56, height: 28)
            }
            priceColumn(quote: quote)
        }
        .frame(minHeight: Theme.rowHeight)
        .padding(.vertical, typeSize.isAccessibilitySize ? 12 : 0)
        .contentShape(.rect)
        .task { await hub.loadSparkline(for: instrument) }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func sparkline(values: [Double], color: Color) -> some View {
        ZStack {
            if values.count > 1 {
                Sparkline(values: values, color: color)
                    .transition(.opacity)
            } else {
                Capsule()
                    .fill(Theme.surfaceRaised)
                    .frame(height: 2)
                    .shimmering()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: values.count > 1)
    }

    private func priceColumn(quote: Quote?) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let quote {
                PriceText(value: quote.last, font: Typography.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
                ChangeText(fraction: quote.changeFraction, font: Typography.rowDetail)
            } else {
                Text("000,00 $")
                    .font(Typography.rowTitle)
                    .placeholder(true)
                Text("+0,00 %")
                    .font(Typography.rowDetail)
                    .placeholder(true)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .animation(.easeOut(duration: 0.25), value: quote == nil)
    }

    private func sparkValues(quote: Quote?) -> [Double] {
        let base = hub.sparklines[instrument.id] ?? []
        guard let quote, !base.isEmpty else { return base }
        return base + [quote.last.doubleValue]
    }
}
