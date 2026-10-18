import SwiftUI

struct StatRow: View {
    let title: String
    let value: String
    var valueColor: Color = Theme.textPrimary
    var compact = false

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.subheadline)
        .padding(.vertical, compact ? 6 : 10)
    }
}

struct StatDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 0.5)
    }
}
