import SwiftUI

struct AssetIcon: View {
    let instrument: Instrument
    var size: CGFloat = 40

    var body: some View {
        Text(String(instrument.symbol.prefix(instrument.symbol.count > 3 ? 2 : 3)))
            .font(.system(size: size * 0.30, weight: .semibold))
            .foregroundStyle(Theme.textPrimary)
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .frame(width: size, height: size)
            .background(Theme.surfaceRaised, in: .circle)
            .accessibilityHidden(true)
    }
}
