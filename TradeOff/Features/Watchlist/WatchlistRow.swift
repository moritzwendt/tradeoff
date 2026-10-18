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
                Text(instrument.name)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Sparkline(values: values, color: trend == Theme.textSecondary ? Theme.accent : trend)
                .frame(width: 52, height: 28)
            VStack(alignment: .trailing, spacing: 5) {
                if let quote {
                    PriceText(value: quote.last, font: .headline)
                    ChangePill(fraction: quote.changeFraction)
                } else {
                    Text("0,00 $")
                        .font(.headline)
                        .redacted(reason: .placeholder)
                    Text("0,00 %")
                        .font(.caption)
                        .redacted(reason: .placeholder)
                }
            }
            .frame(width: 112, alignment: .trailing)
        }
        .contentShape(.rect)
        .task { await hub.loadSparkline(for: instrument) }
    }

    private func sparkValues(quote: Quote?) -> [Double] {
        let base = hub.sparklines[instrument.id] ?? []
        guard let quote, !base.isEmpty else { return base }
        return base + [quote.last.doubleValue]
    }
}
