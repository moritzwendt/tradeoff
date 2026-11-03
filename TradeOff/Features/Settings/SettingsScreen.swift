import SwiftData
import SwiftUI

enum SettingsRoute: Hashable {
    case account
    case trading
    case fees
    case appearance
    case sources
}

struct SettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(QuoteHub.self) private var hub
    @Environment(\.dismiss) private var dismiss
    @Query private var accounts: [AccountRecord]

    var body: some View {
        NavigationStack {
            SettingsPage(title: "Einstellungen", showsBack: false) {
                NavigationLink(value: SettingsRoute.account) {
                    accountCard
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.account")

                SettingsGroup {
                    NavigationLink(value: SettingsRoute.trading) {
                        SettingsRow(
                            systemName: "arrow.left.arrow.right",
                            title: "Handel",
                            value: settings.values.ignoreMarketHours ? "Ohne Marktzeiten" : "Marktzeiten"
                        )
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: SettingsRoute.fees) {
                        SettingsRow(
                            systemName: "percent",
                            title: "Gebühren",
                            value: settings.values.fees == .standard ? "Standard" : "Angepasst"
                        )
                    }
                    .buttonStyle(.plain)
                }

                SettingsGroup {
                    NavigationLink(value: SettingsRoute.appearance) {
                        SettingsRow(
                            systemName: "paintbrush",
                            title: "Darstellung",
                            value: settings.values.chartStyle.title
                        )
                    }
                    .buttonStyle(.plain)
                    NavigationLink(value: SettingsRoute.sources) {
                        SettingsRow(
                            systemName: "antenna.radiowaves.left.and.right",
                            title: "Datenquellen",
                            value: sourcesSummary
                        )
                    }
                    .buttonStyle(.plain)
                }

                SettingsGroup {
                    SettingsRow(systemName: "info.circle", title: "Version", value: appVersion, showsChevron: false)
                }
            }
            .overlay(alignment: .topTrailing) {
                HeaderIconButton(systemName: "xmark", label: "Schließen") { dismiss() }
                    .padding(.trailing, Theme.screenPadding - 10)
                    .padding(.top, 6)
            }
            .navigationDestination(for: SettingsRoute.self) { route in
                switch route {
                case .account: AccountSettingsScreen()
                case .trading: TradingSettingsScreen()
                case .fees: FeesScreen()
                case .appearance: AppearanceSettingsScreen()
                case .sources: DataSourcesScreen()
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private var accountCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Guthaben")
                    .font(Typography.label)
                    .foregroundStyle(Theme.textSecondary)
                Text(PriceFormatter.money(accounts.first?.cash ?? settings.values.startingBalance))
                    .font(Typography.section)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius, style: .continuous))
        .contentShape(.rect)
    }

    private var sourcesSummary: String {
        let ready = ProviderID.allCases.filter { hub.registry.availability(for: $0) == .ready }.count
        return "\(ready) von \(ProviderID.allCases.count) aktiv"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }
}

struct AccountSettingsScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppEnvironment.self) private var environment
    @Query private var accounts: [AccountRecord]
    @State private var confirmAccountReset = false
    @State private var confirmSettingsReset = false

    var body: some View {
        @Bindable var settings = settings
        SettingsPage(title: "Konto") {
            SettingsGroup {
                SettingsRow(
                    title: "Guthaben",
                    value: PriceFormatter.money(accounts.first?.cash ?? settings.values.startingBalance),
                    showsChevron: false
                )
                SettingsFieldRow(
                    title: "Startguthaben",
                    value: $settings.values.startingBalance,
                    suffix: "$",
                    maximumFractionDigits: 2
                )
            }
            SettingsGroup(footer: "Das Startguthaben gilt ab dem nächsten Zurücksetzen.") {
                SettingsActionRow(title: "Konto zurücksetzen", role: .destructive) {
                    confirmAccountReset = true
                }
                SettingsActionRow(title: "Einstellungen zurücksetzen", role: .destructive) {
                    confirmSettingsReset = true
                }
            }
        }
        .confirmationDialog("Konto zurücksetzen", isPresented: $confirmAccountReset, titleVisibility: .visible) {
            Button("Zurücksetzen", role: .destructive) {
                environment.resetAccount()
            }
        } message: {
            Text("Positionen und Verlauf werden gelöscht.")
        }
        .confirmationDialog("Einstellungen zurücksetzen", isPresented: $confirmSettingsReset, titleVisibility: .visible) {
            Button("Zurücksetzen", role: .destructive) {
                settings.reset()
            }
        }
    }
}

struct TradingSettingsScreen: View {
    @Environment(AppSettings.self) private var settings

    private static let ages: [Double] = [10, 30, 60, 120, 300]

    var body: some View {
        @Bindable var settings = settings
        SettingsPage(title: "Handel") {
            SettingsGroup {
                SettingsToggleRow(title: "Marktzeiten ignorieren", isOn: $settings.values.ignoreMarketHours)
                SettingsChoiceRow(
                    title: "Maximales Kursalter",
                    selection: $settings.values.maxQuoteAge,
                    options: ageOptions,
                    label: { PriceFormatter.seconds($0) }
                )
            }
        }
    }

    private var ageOptions: [Double] {
        let current = settings.values.maxQuoteAge
        return Self.ages.contains(current) ? Self.ages : (Self.ages + [current]).sorted()
    }
}

struct AppearanceSettingsScreen: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        SettingsPage(title: "Darstellung") {
            SettingsGroup(title: "Chart") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Chartstil")
                        .font(Typography.rowDetail.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    SegmentedControl(items: ChartStyle.allCases, selection: $settings.values.chartStyle) { $0.title }
                        .padding(4)
                        .background(Theme.surfaceRaised.opacity(0.6), in: .capsule)
                }
                .padding(16)
            }
            SettingsGroup(title: "Märkte") {
                SettingsChoiceRow(
                    title: "Sortierung",
                    selection: $settings.values.watchlistSort,
                    options: WatchlistSort.allCases,
                    label: { $0.title }
                )
                SettingsToggleRow(title: "Nach Anlageklasse gruppieren", isOn: $settings.values.groupWatchlist)
            }
            SettingsGroup(title: "Rückmeldung") {
                SettingsToggleRow(title: "Haptik", isOn: $settings.values.hapticsEnabled)
            }
        }
    }
}

struct FeesScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(QuoteHub.self) private var hub

    private var classes: [AssetClass] {
        AssetClass.allCases.filter { hub.registry.activeAssetClasses.contains($0) }
    }

    var body: some View {
        SettingsPage(title: "Gebühren") {
            ForEach(classes) { assetClass in
                SettingsGroup(title: assetClass.singularTitle) {
                    SettingsFieldRow(
                        title: "Anteil",
                        value: percentBinding(assetClass),
                        suffix: "%",
                        maximumFractionDigits: 3
                    )
                    SettingsFieldRow(
                        title: "Pauschale",
                        value: flatBinding(assetClass),
                        suffix: "$",
                        maximumFractionDigits: 2
                    )
                }
            }
            if settings.values.fees != .standard {
                SettingsGroup {
                    SettingsActionRow(title: "Standard wiederherstellen") {
                        settings.values.fees = .standard
                    }
                }
            }
        }
    }

    private func percentBinding(_ assetClass: AssetClass) -> Binding<Decimal> {
        Binding(
            get: { settings.values.fees.rule(for: assetClass).percent * 100 },
            set: { newValue in
                var rule = settings.values.fees.rule(for: assetClass)
                rule.percent = newValue / 100
                settings.values.fees.setRule(rule, for: assetClass)
            }
        )
    }

    private func flatBinding(_ assetClass: AssetClass) -> Binding<Decimal> {
        Binding(
            get: { settings.values.fees.rule(for: assetClass).flat },
            set: { newValue in
                var rule = settings.values.fees.rule(for: assetClass)
                rule.flat = newValue
                settings.values.fees.setRule(rule, for: assetClass)
            }
        )
    }
}

struct DataSourcesScreen: View {
    @Environment(QuoteHub.self) private var hub
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        SettingsPage(title: "Datenquellen") {
            SettingsGroup {
                ForEach(ProviderID.allCases) { provider in
                    sourceRow(provider)
                }
            }
            SettingsGroup {
                SettingsActionRow(title: "Erneut verbinden") {
                    hub.reconnect()
                }
            }
        }
    }

    private func sourceRow(_ provider: ProviderID) -> some View {
        let availability = hub.registry.availability(for: provider)
        let isReady = availability == .ready
        let status = hub.statuses[provider]
        let classes = hub.registry.provider(for: provider)?.capabilities.supportedAssetClasses
            .sorted { $0.rawValue < $1.rawValue }
            .map(\.title)
            .joined(separator: ", ")
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.displayName)
                    .font(Typography.rowDetail.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                if let classes, !classes.isEmpty {
                    Text(classes)
                        .font(Typography.label)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(maxWidth: typeSize.isAccessibilitySize ? nil : .infinity, alignment: .leading)
            HStack(spacing: 6) {
                Circle()
                    .fill(color(isReady: isReady, status: status))
                    .frame(width: 8, height: 8)
                Text(text(availability: availability, status: status))
                    .font(Typography.rowDetail)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
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
}
