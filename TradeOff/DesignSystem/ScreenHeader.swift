import SwiftUI

struct ScreenHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(Typography.screenTitle)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.leading, Theme.screenPadding)
        .padding(.trailing, Theme.screenPadding - 10)
        .frame(minHeight: 56)
    }
}

struct HeaderIconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct TopBarActions: View {
    @State private var showConnection = false
    @State private var showSettings = false

    var body: some View {
        HStack(spacing: 0) {
            ConnectionDot { showConnection = true }
            HeaderIconButton(systemName: "gearshape", label: "Einstellungen") { showSettings = true }
        }
        .sheet(isPresented: $showConnection) {
            ConnectionSheet()
        }
        .sheet(isPresented: $showSettings) {
            SettingsScreen()
        }
    }
}
