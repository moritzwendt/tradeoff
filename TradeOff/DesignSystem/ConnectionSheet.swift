import SwiftUI

struct ConnectionSheet: View {
    @Environment(QuoteHub.self) private var hub
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(hub.registry.all.filter { $0.availability == .ready }, id: \.id) { provider in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(color(for: provider.id))
                                .frame(width: 8, height: 8)
                            Text(provider.id.displayName)
                            Spacer(minLength: 8)
                            Text(statusText(for: provider.id))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .listRowBackground(Theme.surface)
                    }
                }
                Section {
                    Button("Erneut verbinden") {
                        hub.reconnect()
                        dismiss()
                    }
                    .listRowBackground(Theme.surface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Verbindung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func status(for id: ProviderID) -> ProviderStatus {
        hub.statuses[id] ?? .idle
    }

    private func color(for id: ProviderID) -> Color {
        switch status(for: id) {
        case .live: Theme.positive
        case .idle, .connecting: Theme.textTertiary
        case .reconnecting: Theme.warning
        case .failed: Theme.negative
        }
    }

    private func statusText(for id: ProviderID) -> String {
        switch status(for: id) {
        case .live: "Verbunden"
        case .idle: "Pausiert"
        case .connecting: "Verbindet"
        case .reconnecting: "Neuaufbau"
        case .failed(let text): text
        }
    }
}
