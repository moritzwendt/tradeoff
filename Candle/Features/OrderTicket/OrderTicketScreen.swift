import SwiftData
import SwiftUI

struct OrderTicketScreen: View {
    let instrument: Instrument
    @State private var model: OrderTicketModel
    @Environment(\.dismiss) private var dismiss
    @Environment(QuoteHub.self) private var hub
    @Environment(TradingService.self) private var trading
    @Environment(AppEnvironment.self) private var environment
    @Query private var positions: [PositionRecord]
    @Query private var accounts: [AccountRecord]

    init(instrument: Instrument, side: OrderSide) {
        self.instrument = instrument
        _model = State(initialValue: OrderTicketModel(instrument: instrument, side: side))
        let id = instrument.id
        _positions = Query(filter: #Predicate<PositionRecord> { $0.instrumentID == id })
    }

    private var sideColor: Color {
        model.side == .buy ? Theme.positive : Theme.negative
    }

    var body: some View {
        ZStack {
            AppBackground()
            if case .filled(let receipt) = model.phase {
                FilledView(receipt: receipt, instrument: instrument, color: sideColor) {
                    dismiss()
                }
            } else {
                editor
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { hub.pin(instrument) }
        .onDisappear { hub.unpin(instrument) }
    }

    private var editor: some View {
        let quote = hub.quote(for: instrument.id)
        let quantity = model.resolvedQuantity(trading: trading, quote: quote)
        let evaluation = trading.evaluate(
            OrderRequest(instrumentID: instrument.id, side: model.side, quantity: quantity),
            instrument: instrument
        )
        let cash = accounts.first?.cash ?? 0
        let held = positions.first?.quantity ?? 0

        return VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    header(quote: quote)
                    amountDisplay(preview: evaluation.preview)
                    quickChips(cash: cash, held: held)
                    breakdown(evaluation: evaluation, cash: cash, held: held)
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 24)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 10) {
                AmountPad { model.press($0) }
                confirmButton(evaluation: evaluation, quote: quote)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.bottom, 8)
        }
        .haptic(.selection, trigger: model.text)
        .haptic(.error, trigger: model.errorMessage)
    }

    private func header(quote: Quote?) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                AssetIcon(instrument: instrument, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(instrument.symbol)
                        .font(.headline)
                    Text(instrument.name)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if let quote {
                    PriceText(value: quote.last, font: .title3.weight(.semibold))
                }
            }

            @Bindable var bindable = model
            SegmentedControl(items: OrderSide.allCases, selection: Binding(
                get: { model.side },
                set: { model.switchSide(to: $0) }
            )) { $0.title }
        }
    }

    private func amountDisplay(preview: ExecutionPreview?) -> some View {
        let primary: String
        let secondary: String
        switch model.mode {
        case .amount:
            primary = "$\(PriceFormatter.input(model.text))"
            secondary = preview.map { "≈ \(PriceFormatter.quantity($0.quantity, assetClass: instrument.assetClass)) \(instrument.symbol)" } ?? " "
        case .quantity:
            primary = "\(PriceFormatter.input(model.text)) \(instrument.symbol)"
            secondary = preview.map { "≈ \(PriceFormatter.money($0.gross))" } ?? " "
        }

        return VStack(spacing: 6) {
            Text(primary)
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(model.text.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.15), value: model.text)
            Text(secondary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
            Button {
                model.switchMode(to: model.mode == .amount ? .quantity : .amount)
            } label: {
                Label(model.mode == .amount ? OrderTicketModel.InputMode.quantity.title : OrderTicketModel.InputMode.amount.title, systemImage: "arrow.left.arrow.right")
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .frame(maxWidth: .infinity)
    }

    private func quickChips(cash: Decimal, held: Decimal) -> some View {
        let options: [(String, Decimal)] = [
            ("25 %", Decimal(sign: .plus, exponent: -2, significand: 25)),
            ("50 %", Decimal(sign: .plus, exponent: -2, significand: 50)),
            ("75 %", Decimal(sign: .plus, exponent: -2, significand: 75)),
            ("Max", 1)
        ]
        return GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(options, id: \.0) { option in
                    Button {
                        model.applyFraction(option.1, cash: cash, held: held)
                    } label: {
                        Text(option.0)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
        }
    }

    private func breakdown(evaluation: ExecutionEvaluation, cash: Decimal, held: Decimal) -> some View {
        GlassCard {
            VStack(spacing: 0) {
                if let preview = evaluation.preview {
                    StatRow(title: model.side == .buy ? "Brief" : "Geld", value: PriceFormatter.price(preview.referencePrice), compact: true)
                    StatDivider()
                    if preview.slippageFraction > 0 {
                        StatRow(
                            title: "Slippage",
                            value: "\(PriceFormatter.percent(preview.slippageFraction, signed: false)) (\(PriceFormatter.money(preview.slippageCost)))",
                            valueColor: Theme.simulation,
                            compact: true
                        )
                        StatDivider()
                    }
                    StatRow(title: "Gebühr", value: PriceFormatter.money(preview.fee), compact: true)
                    StatDivider()
                    StatRow(title: "Gesamt", value: PriceFormatter.money(preview.total), compact: true)
                    StatDivider()
                }
                StatRow(
                    title: model.side == .buy ? "Guthaben" : "Bestand",
                    value: model.side == .buy
                        ? PriceFormatter.money(cash)
                        : "\(PriceFormatter.quantity(held, assetClass: instrument.assetClass)) \(instrument.symbol)",
                    compact: true
                )
                if let message = visibleMessage(evaluation) {
                    StatDivider()
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(message)
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.negative)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func visibleMessage(_ evaluation: ExecutionEvaluation) -> String? {
        if let message = model.errorMessage { return message }
        guard !model.text.isEmpty else { return nil }
        return evaluation.rejection?.message
    }

    private func confirmButton(evaluation: ExecutionEvaluation, quote: Quote?) -> some View {
        Button {
            model.submit(trading: trading, recorder: environment.recorder, quote: quote)
        } label: {
            Text("\(instrument.symbol) \(model.side.title.lowercased())")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.glassProminent)
        .tint(sideColor)
        .disabled(!evaluation.isExecutable)
    }
}

private struct FilledView: View {
    let receipt: OrderTicketModel.Receipt
    let instrument: Instrument
    let color: Color
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 84))
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: receipt)
            VStack(spacing: 6) {
                Text(receipt.side.pastTitle)
                    .font(.title.weight(.bold))
                Text("\(PriceFormatter.quantity(receipt.quantity, assetClass: instrument.assetClass)) \(instrument.symbol)")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text(PriceFormatter.price(receipt.price))
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
            GlassCard {
                VStack(spacing: 0) {
                    StatRow(title: "Gebühr", value: PriceFormatter.money(receipt.fee))
                    StatDivider()
                    StatRow(title: "Gesamt", value: PriceFormatter.money(receipt.total))
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            Button("Fertig") { onDone() }
                .buttonStyle(.glassProminent)
                .tint(color)
                .controlSize(.large)
        }
        .padding()
        .haptic(.success, trigger: receipt)
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            onDone()
        }
    }
}
