import SwiftUI

struct PriceText: View {
    let value: Decimal
    var font: Font = .headline

    var body: some View {
        Text(PriceFormatter.price(value))
            .font(font)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .contentTransition(.numericText(value: value.doubleValue))
            .animation(.snappy(duration: 0.25), value: value)
    }
}
