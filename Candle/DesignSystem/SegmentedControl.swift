import SwiftUI

struct SegmentedControl<Item: Hashable & Identifiable, Label: View>: View {
    let items: [Item]
    @Binding var selection: Item
    @ViewBuilder var label: (Item, Bool) -> Label
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        selection = item
                    }
                } label: {
                    label(item, selection == item)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(.capsule)
                        .background {
                            if selection == item {
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassEffect(.regular, in: .capsule)
        .haptic(.selection, trigger: selection)
    }
}

extension SegmentedControl where Label == Text {
    init(items: [Item], selection: Binding<Item>, title: @escaping (Item) -> String) {
        self.items = items
        self._selection = selection
        self.label = { item, isSelected in
            Text(title(item))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isSelected ? Theme.textPrimary : Theme.textSecondary)
        }
    }
}
