import SwiftUI

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppEnvironment.self) private var environment
    @Environment(QuoteHub.self) private var hub
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            List {
                Section("Konto") {
                    LabeledContent("Startguthaben") {
                        DecimalField(value: $settings.values.startingBalance, suffix: "$", maximumFractionDigits: 2)
                    }
                    Button("Konto zurücksetzen", role: .destructive) {
                        confirmReset = true
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Handel") {
                    Toggle("Marktzeiten ignorieren", isOn: $settings.values.ignoreMarketHours)
                        .tint(Theme.positive)
                    Stepper(value: $settings.values.maxQuoteAge, in: 5...300, step: 5) {
                        LabeledContent("Max. Kursalter", value: PriceFormatter.seconds(settings.values.maxQuoteAge))
                    }
                    NavigationLink("Gebühren") {
                        FeesScreen(values: $settings.values, classes: activeClasses)
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Darstellung") {
                    Picker("Chartstil", selection: $settings.values.chartStyle) {
                        ForEach(ChartStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    Toggle("Haptik", isOn: $settings.values.hapticsEnabled)
                        .tint(Theme.positive)
                }
                .listRowBackground(Theme.surface)

                Section("Datenquellen") {
                    ForEach(ProviderID.allCases) { provider in
                        sourceRow(provider)
                    }
                }
                .listRowBackground(Theme.surface)

                Section("Info") {
                    LabeledContent("Version", value: appVersion)
                    Button("Einstellungen zurücksetzen") {
                        settings.reset()
                    }
                }
                .listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                }
            }
            .confirmationDialog("Konto zurücksetzen", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Zurücksetzen", role: .destructive) {
                    environment.resetAccount()
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var activeClasses: [AssetClass] {
        AssetClass.allCases.filter { hub.registry.activeAssetClasses.contains($0) }
    }

    private func sourceRow(_ provider: ProviderID) -> some View {
        let availability = hub.registry.availability(for: provider)
        let isReady = availability == .ready
        let status = hub.statuses[provider]
        return HStack(spacing: 10) {
            Text(provider.displayName)
            Spacer(minLength: 8)
            Circle()
                .fill(color(isReady: isReady, status: status))
                .frame(width: 8, height: 8)
            Text(text(availability: availability, status: status))
                .foregroundStyle(Theme.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }

    private func color(isReady: Bool, status: ProviderStatus?) -> Color {
        guard isReady else { return Theme.textTertiary }
        switch status {
        case .reconnecting: return Theme.warning
        case .failed: return Theme.negative
        case .connecting, .idle: return Theme.textSecondary
        default: return Theme.positive
        }
    }

    private func text(availability: ProviderAvailability, status: ProviderStatus?) -> String {
        guard availability == .ready else { return availability.title }
        switch status {
        case .reconnecting: return "Neuaufbau"
        case .failed: return "Fehler"
        case .connecting: return "Verbindet"
        default: return "Aktiv"
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}

struct FeesScreen: View {
    @Binding var values: SettingsValues
    let classes: [AssetClass]

    var body: some View {
        List {
            ForEach(classes) { assetClass in
                Section(assetClass.singularTitle) {
                    LabeledContent("Anteil") {
                        DecimalField(value: percentBinding(assetClass), suffix: "%", maximumFractionDigits: 3)
                    }
                    LabeledContent("Pauschale") {
                        DecimalField(value: flatBinding(assetClass), suffix: "$", maximumFractionDigits: 2)
                    }
                }
                .listRowBackground(Theme.surface)
            }
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackground())
        .navigationTitle("Gebühren")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func percentBinding(_ assetClass: AssetClass) -> Binding<Decimal> {
        Binding(
            get: { values.fees.rule(for: assetClass).percent * 100 },
            set: { newValue in
                var rule = values.fees.rule(for: assetClass)
                rule.percent = newValue / 100
                values.fees.setRule(rule, for: assetClass)
            }
        )
    }

    private func flatBinding(_ assetClass: AssetClass) -> Binding<Decimal> {
        Binding(
            get: { values.fees.rule(for: assetClass).flat },
            set: { newValue in
                var rule = values.fees.rule(for: assetClass)
                rule.flat = newValue
                values.fees.setRule(rule, for: assetClass)
            }
        )
    }
}
