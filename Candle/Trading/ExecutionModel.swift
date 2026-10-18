import Foundation

struct ExecutionEvaluation: Equatable, Sendable {
    let preview: ExecutionPreview?
    let rejection: TradeRejection?

    var isExecutable: Bool {
        preview != nil && rejection == nil
    }
}

struct ExecutionModel: Sendable {
    var fees: FeeSchedule
    var maxQuoteAge: TimeInterval
    var minimumNotional: Decimal
    var ignoreMarketHours: Bool
    var calendars = MarketCalendars()

    func evaluate(
        _ request: OrderRequest,
        instrument: Instrument,
        quote: Quote?,
        cash: Decimal,
        heldQuantity: Decimal,
        now: Date
    ) -> ExecutionEvaluation {
        guard let quote else {
            return ExecutionEvaluation(preview: nil, rejection: .noQuote)
        }

        let assetClass = instrument.assetClass
        let quantity = request.quantity.rounded(scale: assetClass.quantityScale, mode: .down)
        guard quantity > 0 else {
            return ExecutionEvaluation(preview: nil, rejection: .invalidQuantity)
        }

        let reference = request.side == .buy ? quote.ask : quote.bid
        let notional = quantity * reference

        var slippage = SlippageModel.none
        if assetClass.usesPoolSlippage {
            guard let liquidity = quote.liquidityUSD, liquidity > 0 else {
                return ExecutionEvaluation(preview: nil, rejection: .noLiquidityData)
            }
            slippage = .constantProduct(liquidityUSD: liquidity)
        }

        let fraction = slippage.fraction(side: request.side, notional: notional)
        let factor = request.side == .buy ? 1 + fraction : 1 - fraction
        let executionPrice = (reference * factor).roundedToSignificantDigits(10)
        let gross = (quantity * executionPrice).rounded(scale: 2)
        let slippageCost = (quantity * abs(executionPrice - reference)).rounded(scale: 2)
        let fee = fees.fee(for: gross, assetClass: assetClass)
        let total = request.side == .buy ? gross + fee : gross - fee

        let preview = ExecutionPreview(
            side: request.side,
            quantity: quantity,
            referencePrice: reference,
            executionPrice: executionPrice,
            slippageFraction: fraction,
            slippageCost: slippageCost,
            gross: gross,
            fee: fee,
            total: total,
            spreadFraction: quote.spreadFraction,
            quality: quote.quality,
            isSyntheticSpread: quote.isSyntheticSpread,
            quoteTimestamp: quote.timestamp
        )

        return ExecutionEvaluation(
            preview: preview,
            rejection: rejection(
                for: request,
                instrument: instrument,
                quote: quote,
                preview: preview,
                cash: cash,
                heldQuantity: heldQuantity,
                now: now
            )
        )
    }

    private func rejection(
        for request: OrderRequest,
        instrument: Instrument,
        quote: Quote,
        preview: ExecutionPreview,
        cash: Decimal,
        heldQuantity: Decimal,
        now: Date
    ) -> TradeRejection? {
        if !ignoreMarketHours {
            let session = calendars.session(for: instrument.assetClass, at: now)
            if !session.isOpen { return .marketClosed(session) }
        }

        let age = quote.age(at: now)
        if age > maxQuoteAge { return .staleQuote(age: age) }

        if preview.gross < minimumNotional { return .belowMinimum(minimumNotional) }

        switch request.side {
        case .buy:
            if preview.total > cash {
                return .insufficientFunds(required: preview.total, available: cash)
            }
        case .sell:
            if preview.quantity > heldQuantity {
                return .insufficientPosition(held: heldQuantity)
            }
        }
        return nil
    }
}
