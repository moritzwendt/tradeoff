import SwiftUI

struct AssetIcon: View {
    let instrument: Instrument
    var size: CGFloat = 40

    var body: some View {
        let tint = Theme.tint(for: instrument.assetClass)
        Text(String(instrument.symbol.prefix(2)))
            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.95), tint.opacity(0.45)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .circle
            )
            .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5))
    }
}
