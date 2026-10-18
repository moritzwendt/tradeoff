import SwiftUI

struct DecimalField: View {
    @Binding var value: Decimal
    var suffix = ""
    var maximumFractionDigits = 4
    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 4) {
            TextField("0", text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    if let parsed = Decimal(string: newValue, locale: .current) {
                        value = parsed
                    } else if newValue.isEmpty {
                        value = 0
                    }
                }
                .onChange(of: isFocused) { _, focused in
                    if !focused { text = formatted(value) }
                }
            if !suffix.isEmpty {
                Text(suffix)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .onAppear { text = formatted(value) }
    }

    private func formatted(_ number: Decimal) -> String {
        number.formatted(
            .number
                .precision(.fractionLength(0...maximumFractionDigits))
                .grouping(.never)
        )
    }
}
