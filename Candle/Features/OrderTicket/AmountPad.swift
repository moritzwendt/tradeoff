import SwiftUI

struct AmountPad: View {
    let onKey: (PadKey) -> Void

    private let rows: [[PadKey]] = [
        [.digit(1), .digit(2), .digit(3)],
        [.digit(4), .digit(5), .digit(6)],
        [.digit(7), .digit(8), .digit(9)],
        [.separator, .digit(0), .delete]
    ]

    var body: some View {
        VStack(spacing: 2) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(rows[row], id: \.self) { key in
                        Button {
                            onKey(key)
                        } label: {
                            label(for: key)
                                .frame(maxWidth: .infinity, minHeight: 46)
                                .contentShape(.rect)
                        }
                        .buttonStyle(PadButtonStyle())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func label(for key: PadKey) -> some View {
        switch key {
        case .digit(let digit):
            Text("\(digit)")
                .font(.system(size: 28, weight: .medium, design: .rounded))
        case .separator:
            Text(Locale.current.decimalSeparator ?? ".")
                .font(.system(size: 28, weight: .medium, design: .rounded))
        case .delete:
            Image(systemName: "delete.left")
                .font(.system(size: 22, weight: .regular))
                .accessibilityLabel("Löschen")
        }
    }
}

private struct PadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Theme.textPrimary)
            .opacity(configuration.isPressed ? 0.45 : 1)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.snappy(duration: 0.12), value: configuration.isPressed)
    }
}
