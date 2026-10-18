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
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: .capsule)
        .animation(.snappy(duration: 0.25), value: fraction)
    }
}
