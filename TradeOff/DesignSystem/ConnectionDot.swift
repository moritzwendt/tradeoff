import SwiftUI

struct ConnectionDot: View {
    @Environment(QuoteHub.self) private var hub
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let action: () -> Void
    @State private var pulse = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let state = hub.connectionState(at: context.date)
            Button(action: action) {
                Circle()
                    .fill(color(for: state))
                    .frame(width: 10, height: 10)
                    .opacity(state == .updating && pulse && !reduceMotion ? 0.35 : 1)
                    .animation(
                        state == .updating && !reduceMotion
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: pulse
                    )
                    .frame(width: 28, height: 28)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Verbindung")
            .accessibilityValue(title(for: state))
            .onAppear { pulse = true }
        }
    }

    private func color(for state: ConnectionState) -> Color {
        switch state {
        case .live: Theme.positive
        case .updating: Theme.textSecondary
        case .problem: Theme.negative
        }
    }

    private func title(for state: ConnectionState) -> String {
        switch state {
        case .live: "Live"
        case .updating: "Aktualisiert"
        case .problem: "Problem"
        }
    }
}
