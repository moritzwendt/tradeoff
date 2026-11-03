import SwiftUI

struct FilterChips<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    let isSelected = selection == item
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            selection = item
                        }
                    } label: {
                        Text(title(item))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.black : Theme.textSecondary)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(isSelected ? Color.white.opacity(0.92) : Theme.surface, in: .capsule)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, Theme.screenPadding)
        }
        .scrollIndicators(.hidden)
        .haptic(.selection, trigger: selection)
    }
}
