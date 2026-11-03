import SwiftUI

struct WatchlistRow: View {
    let instrument: Instrument
    @Environment(QuoteHub.self) private var hub

    var body: some View {
        let quote = hub.quote(for: instrument.id)
        let trend = Theme.pnl(quote?.change ?? 0)
        let values = sparkValues(quote: quote)

        HStack(spacing: 12) {
            AssetIcon(instrument: instrument)
            VStack(alignment: .leading, spacing: 2) {
                Text(instrument.symbol)
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Text(instrument.name)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            sparkline(values: values, color: trend == Theme.textSecondary ? Theme.textSecondary : trend)
                .frame(width: 56, height: 28)
            priceColumn(quote: quote)
                .frame(width: 92, alignment: .trailing)
        }
        .frame(minHeight: Theme.rowHeight)
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
                SkeletonBar(width: 56, height: 18)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.3), value: values.count > 1)
    }

    @ViewBuilder
    private func priceColumn(quote: Quote?) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            if let quote {
                PriceText(value: quote.last, font: .headline)
                    .foregroundStyle(Theme.textPrimary)
                ChangeText(fraction: quote.changeFraction)
            } else {
                SkeletonBar(width: 70, height: 16)
                SkeletonBar(width: 48, height: 12)
            }
        }
        .animation(.easeOut(duration: 0.25), value: quote == nil)
    }

    private func sparkValues(quote: Quote?) -> [Double] {
        let base = hub.sparklines[instrument.id] ?? []
        guard let quote, !base.isEmpty else { return base }
        return base + [quote.last.doubleValue]
    }
}
