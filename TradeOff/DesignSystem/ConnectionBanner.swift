import SwiftUI

struct ConnectionBanner: View {
    @Environment(QuoteHub.self) private var hub

    var body: some View {
        let providers = hub.degradedProviders
        if !providers.isEmpty {
            GlassCard(padding: 14, tint: Theme.negative.opacity(0.25)) {
                HStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.title3)
                        .foregroundStyle(Theme.negative)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(providers) { provider in
                            Text(hub.message(for: provider) ?? provider.displayName)
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    Spacer(minLength: 8)
                    Button("Erneut") {
                        hub.reconnect()
                    }
                    .buttonStyle(.glass)
                }
            }
            .transition(.opacity)
        }
    }
}
