import SwiftUI

struct SectionHeader: View {
    let title: String
    var detail: String?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        layout {
            Text(title)
                .font(Typography.section)
                .foregroundStyle(Theme.textPrimary)
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            if let detail {
                Text(detail)
                    .font(Typography.label)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                    .minimumScaleFactor(0.85)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityAddTraits(.isHeader)
    }
}
