import SwiftUI

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.accent.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 460
            )
            RadialGradient(
                colors: [Color(red: 0.20, green: 0.80, blue: 0.65).opacity(0.09), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}
