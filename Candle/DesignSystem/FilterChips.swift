import SwiftUI

struct FilterChips<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        let isSelected = selection == item
                        Button {
                            withAnimation(.snappy(duration: 0.25)) {
                                selection = item
                            }
                        } label: {
                            Text(title(item))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            isSelected ? Glass.regular.tint(Theme.accent.opacity(0.45)).interactive() : Glass.regular.interactive(),
                            in: .capsule
                        )
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
            }
        }
        .scrollIndicators(.hidden)
        .haptic(.selection, trigger: selection)
    }
}
