import SwiftUI

struct SettingsPage<Content: View>: View {
    let title: String
    var showsBack = true
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                if showsBack {
                    HeaderIconButton(systemName: "chevron.left", label: "Zurück") { dismiss() }
                        .accessibilityIdentifier("settings.back")
                }
                Text(title)
                    .font(Typography.screenTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
            }
            .padding(.leading, showsBack ? Theme.screenPadding - 10 : Theme.screenPadding)
            .padding(.trailing, Theme.screenPadding)
            .frame(minHeight: 56)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    content
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(AppBackground())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct SettingsGroup<Content: View>: View {
    var title: String?
    var footer: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(Typography.labelStrong)
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 4)
                    .accessibilityAddTraits(.isHeader)
            }
            Group(subviews: content) { subviews in
                VStack(spacing: 0) {
                    ForEach(subviews) { subview in
                        subview
                        if subview.id != subviews.last?.id {
                            Rectangle()
                                .fill(Theme.separator)
                                .frame(height: 0.5)
                                .padding(.leading, 16)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(Theme.surface, in: .rect(cornerRadius: Theme.cornerRadius, style: .continuous))
            if let footer {
                Text(footer)
                    .font(Typography.label)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

struct SettingsIconTile: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(width: 30, height: 30)
            .background(Theme.surfaceRaised, in: .rect(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct SettingsRow: View {
    var systemName: String?
    let title: String
    var value: String?
    var showsChevron = true
    var tint: Color = Theme.textPrimary
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 12))
        HStack(spacing: 12) {
            if let systemName {
                SettingsIconTile(systemName: systemName)
            }
            layout {
                Text(title)
                    .font(Typography.rowDetail.weight(.medium))
                    .foregroundStyle(tint)
                if !typeSize.isAccessibilitySize {
                    Spacer(minLength: 8)
                }
                if let value {
                    Text(value)
                        .font(Typography.rowDetail)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.trailing)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .contentShape(.rect)
    }
}

struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(Typography.rowDetail.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
        }
        .tint(Theme.positive)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .haptic(.selection, trigger: isOn)
    }
}

struct SettingsChoiceRow<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(label(option)).tag(option)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(Typography.rowDetail.weight(.medium))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(label(selection))
                    .font(Typography.rowDetail)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.trailing)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(label(selection))
    }
}

struct SettingsFieldRow: View {
    let title: String
    @Binding var value: Decimal
    var suffix = ""
    var maximumFractionDigits = 2

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(Typography.rowDetail.weight(.medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            DecimalField(value: $value, suffix: suffix, maximumFractionDigits: maximumFractionDigits)
                .font(Typography.rowDetail)
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: 140)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 52)
        .accessibilityElement(children: .contain)
    }
}

struct SettingsActionRow: View {
    let title: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Text(title)
                .font(Typography.rowDetail.weight(.medium))
                .foregroundStyle(role == .destructive ? Theme.negative : Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minHeight: 52)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
