import SwiftUI

struct ConnectionBanner: View {
    @Environment(QuoteHub.self) private var hub

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let providers = hub.problems(at: context.date)
            if !providers.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(providers) { provider in
                            Text(hub.message(for: provider) ?? provider.displayName)
                                .font(.subheadline)
                                .foregroundStyle(Theme.textPrimary)
                        }
                    }
                    Spacer(minLength: 8)
                    Button("Erneut") {
                        hub.reconnect()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 36)
                    .background(Theme.surfaceRaised, in: .capsule)
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius, style: .continuous))
                .transition(.opacity)
            }
        }
    }
}
