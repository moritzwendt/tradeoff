import Foundation
@testable import Candle

extension TestSupport {
    static func model(
        ignoreMarketHours: Bool = true,
        maxQuoteAge: TimeInterval = 30
    ) -> ExecutionModel {
        ExecutionModel(
            fees: .standard,
            maxQuoteAge: maxQuoteAge,
            minimumNotional: 1,
            ignoreMarketHours: ignoreMarketHours
        )
    }
}
