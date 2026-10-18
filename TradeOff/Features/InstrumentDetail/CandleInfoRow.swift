import SwiftUI

struct CandleInfoRow: View {
    let candle: Candlestick

    var body: some View {
        HStack(spacing: 0) {
            cell("Eröffnung", candle.open)
            cell("Hoch", candle.high)
            cell("Tief", candle.low)
            cell("Schluss", candle.close)
        }
    }

    private func cell(_ title: String, _ value: Decimal) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
            Text(PriceFormatter.price(value))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
