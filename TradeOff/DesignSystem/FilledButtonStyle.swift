import SwiftUI

struct FilledButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color = .black

    func makeBody(configuration: Configuration) -> some View {
        FilledButtonBody(configuration: configuration, fill: fill, foreground: foreground)
    }
}

private struct FilledButtonBody: View {
    @Environment(\.isEnabled) private var isEnabled
    let configuration: ButtonStyleConfiguration
    let fill: Color
    let foreground: Color

    var body: some View {
        configuration.label
            .font(Typography.rowTitle)
            .foregroundStyle(isEnabled ? foreground : Theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isEnabled ? fill : Theme.surfaceRaised, in: .capsule)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(.capsule)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == FilledButtonStyle {
    static func filled(_ fill: Color, foreground: Color = .black) -> FilledButtonStyle {
        FilledButtonStyle(fill: fill, foreground: foreground)
    }
}
