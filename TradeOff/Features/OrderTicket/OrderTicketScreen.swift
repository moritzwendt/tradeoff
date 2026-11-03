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

    private var sideForeground: Color {
        model.side == .buy ? .black : .white
    }

    var body: some View {
        ZStack {
            AppBackground()
            switch model.phase {
            case .editing:
                editor
            case .reviewing:
                review
            case .filled(let receipt):
                FilledView(receipt: receipt, instrument: instrument) { dismiss() }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { hub.pin(instrument) }
        .onDisappear { hub.unpin(instrument) }
    }

    private struct Context {
        let quote: Quote?
        let quantity: Decimal
        let evaluation: ExecutionEvaluation
        let cash: Decimal
        let held: Decimal
    }

    private func context() -> Context {
        let quote = hub.quote(for: instrument.id)
        let quantity = model.resolvedQuantity(trading: trading, quote: quote)
        let evaluation = trading.evaluate(
            OrderRequest(instrumentID: instrument.id, side: model.side, quantity: quantity),
            instrument: instrument
        )
        return Context(
            quote: quote,
            quantity: quantity,
            evaluation: evaluation,
            cash: accounts.first?.cash ?? 0,
            held: positions.first?.quantity ?? 0
        )
    }

    private var editor: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            let keyHeight = min(56, max(44, (proxy.size.height - (compact ? 330 : 470)) / 4))
            let state = context()
            VStack(spacing: 0) {
                titleBar(quote: state.quote)
                    .padding(.top, 20)
                SegmentedControl(items: OrderSide.allCases, selection: Binding(
                    get: { model.side },
                    set: { model.switchSide(to: $0) }
                )) { $0.title }
                .padding(4)
                .background(Theme.surface, in: .capsule)
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 12)

                Spacer(minLength: 8)
                amountBlock(state: state, compact: compact)
                Spacer(minLength: 8)

                quickChips(state: state)
                    .padding(.horizontal, Theme.screenPadding)

                messageLine(state.evaluation)
                    .padding(.vertical, 6)

                AmountPad(keyHeight: keyHeight) { model.press($0) }
                    .padding(.horizontal, Theme.screenPadding)

                Button("Weiter") {
                    model.review()
                }
                .buttonStyle(.filled(sideColor, foreground: sideForeground))
                .disabled(!state.evaluation.isExecutable)
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 8)
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .haptic(.selection, trigger: model.text)
        .haptic(.error, trigger: model.errorMessage)
    }

    private func titleBar(quote: Quote?) -> some View {
        HStack(spacing: 12) {
            AssetIcon(instrument: instrument, size: 36)
            VStack(alignment: .leading, spacing: 0) {
                Text(instrument.symbol)
                    .font(Typography.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text(instrument.name)
                    .font(Typography.label)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if let quote {
                PriceText(value: quote.last, font: Typography.rowTitle)
                    .foregroundStyle(Theme.textPrimary)
            } else {
                Text("000,00 $")
                    .font(Typography.rowTitle)
                    .placeholder(true)
            }
        }
        .padding(.horizontal, Theme.screenPadding)
        .frame(minHeight: 44)
    }

    private func amountBlock(state: Context, compact: Bool) -> some View {
        let primary: String
        let secondary: String
        switch model.mode {
        case .amount:
            primary = "$\(PriceFormatter.input(model.text))"
            secondary = state.evaluation.preview.map {
                "≈ \(PriceFormatter.quantity($0.quantity, assetClass: instrument.assetClass)) \(instrument.symbol)"
            } ?? availableText(state)
        case .quantity:
            primary = "\(PriceFormatter.input(model.text)) \(instrument.symbol)"
            secondary = state.evaluation.preview.map { "≈ \(PriceFormatter.money($0.gross))" } ?? availableText(state)
        }

        return VStack(spacing: 6) {
            Text(primary)
                .font(.system(size: compact ? 44 : 56, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(model.text.isEmpty ? Theme.textTertiary : Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .contentTransition(.numericText())
                .animation(.snappy(duration: 0.15), value: model.text)
            Text(secondary)
                .font(Typography.rowDetail)
                .foregroundStyle(Theme.textSecondary)
                .monospacedDigit()
                .lineLimit(1)
            Button {
                model.switchMode(to: model.mode == .amount ? .quantity : .amount)
            } label: {
                Label(
                    model.mode == .amount ? "Menge eingeben" : "Betrag eingeben",
                    systemImage: "arrow.left.arrow.right"
                )
                .font(Typography.labelStrong)
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Theme.screenPadding)
    }

    private func availableText(_ state: Context) -> String {
        switch model.side {
        case .buy: "Verfügbar \(PriceFormatter.money(state.cash))"
        case .sell: "Bestand \(PriceFormatter.quantity(state.held, assetClass: instrument.assetClass)) \(instrument.symbol)"
        }
    }

    private func quickChips(state: Context) -> some View {
        let options: [(String, Decimal)] = [
            ("25 %", Decimal(sign: .plus, exponent: -2, significand: 25)),
            ("50 %", Decimal(sign: .plus, exponent: -2, significand: 50)),
            ("75 %", Decimal(sign: .plus, exponent: -2, significand: 75)),
            ("Max", 1)
        ]
        return HStack(spacing: 8) {
            ForEach(options, id: \.0) { option in
                Button {
                    model.applyFraction(option.1, cash: state.cash, held: state.held)
                } label: {
                    Text(option.0)
                        .font(Typography.labelStrong)
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Theme.surface, in: .capsule)
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func messageLine(_ evaluation: ExecutionEvaluation) -> some View {
        HStack(spacing: 6) {
            if let message = visibleMessage(evaluation) {
                Image(systemName: "exclamationmark.circle.fill")
                Text(message)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .font(Typography.labelStrong)
        .foregroundStyle(Theme.negative)
        .frame(maxWidth: .infinity, minHeight: 20)
        .padding(.horizontal, Theme.screenPadding)
        .animation(.easeOut(duration: 0.15), value: visibleMessage(evaluation))
    }

    private func visibleMessage(_ evaluation: ExecutionEvaluation) -> String? {
        if let message = model.errorMessage { return message }
        guard !model.text.isEmpty else { return nil }
        return evaluation.rejection?.message
    }

    private var review: some View {
        let state = context()
        let preview = state.evaluation.preview
        let cashAfter: Decimal? = preview.map { model.side == .buy ? state.cash - $0.total : state.cash + $0.total }
        return VStack(spacing: 0) {
            HStack {
                Button {
                    model.backToEditing()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Zurück")
                    }
                    .font(Typography.button)
                    .foregroundStyle(Theme.textPrimary)
                    .frame(minHeight: 44)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("ticket.back")
                Spacer()
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 12) {
                        AssetIcon(instrument: instrument, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(instrument.symbol) \(model.side.title.lowercased())")
                                .font(Typography.section)
                                .foregroundStyle(Theme.textPrimary)
                            Text(instrument.name)
                                .font(Typography.rowDetail)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    if let preview {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(model.side == .buy ? "Gesamtkosten" : "Erlös")
                                .font(Typography.label)
                                .foregroundStyle(Theme.textSecondary)
                            Text(PriceFormatter.money(preview.total))
                                .font(Typography.display)
                                .monospacedDigit()
                                .foregroundStyle(Theme.textPrimary)
                                .minimumScaleFactor(0.6)
                                .lineLimit(1)
                                .contentTransition(.numericText())
                        }
                        Card {
                            VStack(spacing: 0) {
                                StatRow(title: "Menge", value: "\(PriceFormatter.quantity(preview.quantity, assetClass: instrument.assetClass)) \(instrument.symbol)")
                                StatDivider()
                                StatRow(title: model.side == .buy ? "Brief" : "Geld", value: PriceFormatter.price(preview.referencePrice))
                                if preview.slippageFraction > 0 {
                                    StatDivider()
                                    StatRow(
                                        title: "Slippage",
                                        value: "\(PriceFormatter.percent(preview.slippageFraction, signed: false)) (\(PriceFormatter.money(preview.slippageCost)))",
                                        valueColor: Theme.warning
                                    )
                                }
                                StatDivider()
                                StatRow(title: "Gebühr", value: PriceFormatter.money(preview.fee))
                                if let cashAfter {
                                    StatDivider()
                                    StatRow(title: "Guthaben danach", value: PriceFormatter.money(cashAfter))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 8) {
                messageLine(state.evaluation)
                Button("\(instrument.symbol) \(model.side.title.lowercased()) bestätigen") {
                    model.submit(trading: trading, recorder: environment.recorder, quote: state.quote)
                }
                .buttonStyle(.filled(sideColor, foreground: sideForeground))
                .disabled(!state.evaluation.isExecutable)
                .padding(.horizontal, Theme.screenPadding)
            }
            .padding(.bottom, 8)
        }
        .haptic(.error, trigger: model.errorMessage)
    }
}

private struct FilledView: View {
    let receipt: OrderTicketModel.Receipt
    let instrument: Instrument
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(Theme.positive)
                .symbolEffect(.bounce, value: receipt)
            VStack(spacing: 6) {
                Text(receipt.side.pastTitle)
                    .font(Typography.screenTitle)
                    .foregroundStyle(Theme.textPrimary)
                Text("\(PriceFormatter.quantity(receipt.quantity, assetClass: instrument.assetClass)) \(instrument.symbol)")
                    .font(Typography.section)
                    .monospacedDigit()
                    .foregroundStyle(Theme.textPrimary)
                Text(PriceFormatter.price(receipt.price))
                    .font(Typography.rowDetail)
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
            Card {
                VStack(spacing: 0) {
                    StatRow(title: "Gebühr", value: PriceFormatter.money(receipt.fee))
                    StatDivider()
                    StatRow(title: "Gesamt", value: PriceFormatter.money(receipt.total))
                }
            }
            .padding(.horizontal, Theme.screenPadding)
            Spacer()
            Button("Fertig") { onDone() }
                .buttonStyle(.filled(Color.white.opacity(0.92)))
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 8)
        }
        .haptic(.success, trigger: receipt)
        .task {
            try? await Task.sleep(for: .seconds(4))
            onDone()
        }
    }
}
