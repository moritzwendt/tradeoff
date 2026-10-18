import SwiftUI

struct FillDetailSheet: View {
    let fill: FillRecord

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    HStack(spacing: 12) {
                        AssetIcon(instrument: fill.instrument, size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(fill.instrument.name)
                                .font(.title3.weight(.semibold))
                            Text("\(fill.side.pastTitle) \(fill.instrument.symbol)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(fill.side == .buy ? Theme.positive : Theme.negative)
                        }
                        Spacer()
                        QualityBadge(quality: fill.quality)
                    }

                    GlassCard {
                        VStack(spacing: 0) {
                            StatRow(title: "Menge", value: PriceFormatter.quantity(fill.quantity, assetClass: fill.instrument.assetClass))
                            StatDivider()
                            StatRow(title: "Ausführungskurs", value: PriceFormatter.price(fill.executionPrice))
                            StatDivider()
                            StatRow(title: fill.side == .buy ? "Brief" : "Geld", value: PriceFormatter.price(fill.referencePrice))
                            StatDivider()
                            StatRow(title: "Spread", value: PriceFormatter.percent(fill.spreadFraction, signed: false))
                            if fill.slippageCost > 0 {
                                StatDivider()
                                StatRow(title: "Slippage", value: PriceFormatter.money(fill.slippageCost), valueColor: Theme.simulation)
                            }
                            StatDivider()
                            StatRow(title: "Gebühr", value: PriceFormatter.money(fill.fee))
                            StatDivider()
                            StatRow(title: "Gesamt", value: PriceFormatter.money(fill.total))
                        }
                    }

                    GlassCard {
                        VStack(spacing: 0) {
                            if fill.side == .sell {
                                StatRow(
                                    title: "Realisiert",
                                    value: PriceFormatter.money(fill.realizedPnL, signed: true),
                                    valueColor: Theme.pnl(fill.realizedPnL)
                                )
                                StatDivider()
                            }
                            StatRow(title: "Guthaben danach", value: PriceFormatter.money(fill.cashAfter))
                            StatDivider()
                            StatRow(title: "Zeit", value: TimeFormat.timestamp(fill.timestamp))
                            StatDivider()
                            StatRow(title: "Quelle", value: fill.instrument.provider.displayName)
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
