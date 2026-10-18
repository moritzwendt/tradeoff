import Foundation
import Testing
@testable import Candle

struct DecimalHelpersTests {
    @Test func roundsLargePricesToCents() {
        #expect(TestSupport.decimal("68250.126").marketRounded() == TestSupport.decimal("68250.13"))
    }

    @Test func roundsTinyPricesToFourSignificantDigits() {
        #expect(TestSupport.decimal("0.000021456789").marketRounded() == TestSupport.decimal("0.00002146"))
    }

    @Test func roundsDownByScale() {
        #expect(TestSupport.decimal("1.239").rounded(scale: 2, mode: .down) == TestSupport.decimal("1.23"))
    }

    @Test func convertsDoubleWithScale() {
        #expect(Decimal(0.1, scale: 4) == TestSupport.decimal("0.1"))
    }

    @Test func zeroSurvivesSignificantDigitRounding() {
        #expect(Decimal(0).roundedToSignificantDigits(4) == 0)
    }
}
