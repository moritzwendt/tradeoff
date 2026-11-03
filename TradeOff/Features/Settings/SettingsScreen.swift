import SwiftUI

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppEnvironment.self) private var environment
    @Environment(QuoteHub.self) private var hub
    @State private var confirmReset = false

    var body: some View {
        @Bindable var settings = settings

        NavigationStack {
            Form {
                AccountSection(values: $settings.values) { confirmReset = true }
                FeesSection(values: $settings.values)
                TradingSection(values: $settings.values)
                DisplaySection(values: $settings.values)
                providersSection
                resetSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .background(AppBackground())
            .navigationTitle("Einstellungen")
            .confirmationDialog("Konto zurücksetzen", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Zurücksetzen", role: .destructive) {
                    environment.resetAccount()
                }
            }
        }
    }

    private var providersSection: some View {
        Section("Datenquellen") {
            ForEach(ProviderID.allCases) { provider in
                let availability = hub.registry.availability(for: provider)
                HStack {
                    Text(provider.displayName)
                    Spacer()
                    Text(availability.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(availability == .ready ? Theme.positive : Theme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            (availability == .ready ? Theme.positive : Color.white).opacity(0.12),
                            in: .capsule
                        )
                }
            }
        }
        .listRowBackground(Theme.fill)
    }

    private var resetSection: some View {
        Section {
            Button("Einstellungen zurücksetzen") {
                settings.reset()
            }
        }
        .listRowBackground(Theme.fill)
    }

    private var aboutSection: some View {
        Section("Info") {
            LabeledContent("Version", value: appVersion)
        }
        .listRowBackground(Theme.fill)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}

private struct AccountSection: View {
    @Binding var values: SettingsValues
    let onReset: () -> Void

    var body: some View {
        Section("Konto") {
            LabeledContent("Startguthaben") {
                DecimalField(value: $values.startingBalance, suffix: "$", maximumFractionDigits: 2)
            }
            Button("Konto zurücksetzen", role: .destructive, action: onReset)
        }
        .listRowBackground(Theme.fill)
    }
}

private struct FeesSection: View {
    @Binding var values: SettingsValues

    var body: some View {
        Section("Gebühren Anteil") {
            ForEach(AssetClass.allCases) { assetClass in
                LabeledContent(assetClass.singularTitle) {
                    DecimalField(value: percentBinding(assetClass), suffix: "%", maximumFractionDigits: 3)
                }
            }
        }
        .listRowBackground(Theme.fill)

        Section("Gebühren Pauschale") {
            ForEach(AssetClass.allCases) { assetClass in
                LabeledContent(assetClass.singularTitle) {
                    DecimalField(value: flatBinding(assetClass), suffix: "$", maximumFractionDigits: 2)
                }
            }
        }
        .listRowBackground(Theme.fill)
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

private struct TradingSection: View {
    @Binding var values: SettingsValues

    var body: some View {
        Section("Handel") {
            Toggle("Marktzeiten ignorieren", isOn: $values.ignoreMarketHours)
            Stepper(value: $values.maxQuoteAge, in: 5...300, step: 5) {
                LabeledContent("Max. Kursalter", value: PriceFormatter.seconds(values.maxQuoteAge))
            }
        }
        .listRowBackground(Theme.fill)
    }
}

private struct DisplaySection: View {
    @Binding var values: SettingsValues

    var body: some View {
        Section("Darstellung") {
            Picker("Chartstil", selection: $values.chartStyle) {
                ForEach(ChartStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            Toggle("Haptik", isOn: $values.hapticsEnabled)
        }
        .listRowBackground(Theme.fill)
    }
}
