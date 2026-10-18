import Foundation
import Observation

enum PadKey: Hashable {
    case digit(Int)
    case separator
    case delete
}

@MainActor
@Observable
final class OrderTicketModel {
    enum InputMode: String, CaseIterable, Identifiable {
        case amount
        case quantity

        var id: String { rawValue }

        var title: String {
            switch self {
            case .amount: "Betrag"
            case .quantity: "Menge"
            }
        }
    }

    struct Receipt: Equatable {
        let side: OrderSide
        let quantity: Decimal
        let price: Decimal
        let total: Decimal
        let fee: Decimal
    }

    enum Phase: Equatable {
        case editing
        case filled(Receipt)
    }

    let instrument: Instrument
    var side: OrderSide
    var mode: InputMode = .amount
    var text = ""
    var phase: Phase = .editing
    var errorMessage: String?

    init(instrument: Instrument, side: OrderSide) {
        self.instrument = instrument
        self.side = side
    }

    var enteredValue: Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    private var maximumDecimals: Int {
        mode == .amount ? 2 : instrument.assetClass.quantityScale
    }

    func press(_ key: PadKey) {
        var next = text
        switch key {
        case .digit(let digit):
            next = next == "0" ? "\(digit)" : next + "\(digit)"
        case .separator:
            if next.isEmpty {
                next = "0."
            } else if !next.contains(".") {
                next += "."
            }
        case .delete:
            if !next.isEmpty {
                next.removeLast()
            }
        }
        guard isValid(next) else { return }
        text = next
        errorMessage = nil
    }

    func switchSide(to newSide: OrderSide) {
        guard newSide != side else { return }
        side = newSide
        text = ""
        errorMessage = nil
    }

    func switchMode(to newMode: InputMode) {
        guard newMode != mode else { return }
        mode = newMode
        text = ""
        errorMessage = nil
    }

    func applyFraction(_ fraction: Decimal, cash: Decimal, held: Decimal) {
        errorMessage = nil
        switch side {
        case .buy:
            mode = .amount
            let budget = (cash * fraction).rounded(scale: 2, mode: .down)
            text = budget > 0 ? "\(budget)" : ""
        case .sell:
            mode = .quantity
            let quantity = (held * fraction).rounded(scale: instrument.assetClass.quantityScale, mode: .down)
            text = quantity > 0 ? "\(quantity)" : ""
        }
    }

    func resolvedQuantity(trading: TradingService, quote: Quote?) -> Decimal {
        let value = enteredValue
        guard value > 0 else { return 0 }
        switch mode {
        case .quantity:
            return value
        case .amount:
            guard let quote else { return 0 }
            let scale = instrument.assetClass.quantityScale
            switch side {
            case .sell:
                guard quote.bid > 0 else { return 0 }
                return (value / quote.bid).rounded(scale: scale, mode: .down)
            case .buy:
                return fitBuyQuantity(budget: value, quote: quote, trading: trading)
            }
        }
    }

    func submit(trading: TradingService, recorder: EquityCurveRecorder, quote: Quote?) {
        let quantity = resolvedQuantity(trading: trading, quote: quote)
        do {
            let fill = try trading.execute(
                OrderRequest(instrumentID: instrument.id, side: side, quantity: quantity),
                instrument: instrument
            )
            recorder.record(force: true)
            phase = .filled(
                Receipt(
                    side: side,
                    quantity: fill.quantity,
                    price: fill.executionPrice,
                    total: fill.total,
                    fee: fill.fee
                )
            )
        } catch let rejection as TradeRejection {
            errorMessage = rejection.message
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isValid(_ candidate: String) -> Bool {
        guard candidate.count <= 12 else { return false }
        if let dot = candidate.firstIndex(of: ".") {
            let decimals = candidate.distance(from: dot, to: candidate.endIndex) - 1
            return decimals <= maximumDecimals
        }
        return true
    }

    private func fitBuyQuantity(budget: Decimal, quote: Quote, trading: TradingService) -> Decimal {
        guard quote.ask > 0 else { return 0 }
        let scale = instrument.assetClass.quantityScale
        let step = Decimal(sign: .plus, exponent: -scale, significand: 1)
        var quantity = (budget / quote.ask).rounded(scale: scale, mode: .down)
        for _ in 0..<8 {
            guard quantity > 0 else { return 0 }
            let request = OrderRequest(instrumentID: instrument.id, side: .buy, quantity: quantity)
            guard let preview = trading.evaluate(request, instrument: instrument).preview, preview.total > budget else {
                return quantity
            }
            let scaled = (quantity * budget / preview.total).rounded(scale: scale, mode: .down)
            quantity = scaled < quantity ? scaled : quantity - step
        }
        return max(quantity, 0)
    }
}
