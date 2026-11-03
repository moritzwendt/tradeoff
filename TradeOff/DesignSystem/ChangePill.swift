import SwiftUI

struct ChangePill: View {
    let fraction: Decimal

    var body: some View {
        let color = Theme.pnl(fraction)
        HStack(spacing: 3) {
            Image(systemName: fraction >= 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 9, weight: .bold))
            Text(PriceFormatter.percent(fraction))
                .monospacedDigit()
                .contentTransition(.numericText(value: fraction.doubleValue))
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(color)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.14), in: .rect(cornerRadius: 8, style: .continuous))
        .animation(.snappy(duration: 0.25), value: fraction)
    }
}

struct ChangeText: View {
    let fraction: Decimal
    var font: Font = .subheadline.weight(.medium)

    var body: some View {
        Text(PriceFormatter.percent(fraction))
            .font(font)
            .monospacedDigit()
            .foregroundStyle(Theme.pnl(fraction))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .contentTransition(.numericText(value: fraction.doubleValue))
            .animation(.snappy(duration: 0.25), value: fraction)
    }
}
