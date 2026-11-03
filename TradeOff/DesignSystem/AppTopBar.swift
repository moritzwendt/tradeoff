import SwiftUI

private struct AppTopBar: ViewModifier {
    @State private var showConnection = false
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ConnectionDot { showConnection = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .accessibilityLabel("Einstellungen")
                }
            }
            .sheet(isPresented: $showConnection) {
                ConnectionSheet()
            }
            .sheet(isPresented: $showSettings) {
                SettingsScreen()
            }
    }
}

extension View {
    func appTopBar() -> some View {
        modifier(AppTopBar())
    }
}
