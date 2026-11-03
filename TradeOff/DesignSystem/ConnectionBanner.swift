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
                    Text(summary(providers))
                        .font(Typography.rowDetail)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Erneut") {
                        hub.reconnect()
                    }
                    .font(Typography.value)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 44)
                    .background(Theme.surfaceRaised, in: .capsule)
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius, style: .continuous))
                .transition(.opacity)
            }
        }
    }

    private func summary(_ providers: [ProviderID]) -> String {
        guard providers.count == 1, let provider = providers.first else {
            return "Probleme bei \(providers.count) Datenquellen"
        }
        return hub.message(for: provider) ?? provider.displayName
    }
}
