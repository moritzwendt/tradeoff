import Foundation
import Testing
@testable import Candle

struct SplitMix64Tests {
    @Test func sameSeedProducesSameSequence() {
        var first = SplitMix64(seed: 42)
        var second = SplitMix64(seed: 42)
        for _ in 0..<50 {
            #expect(first.next() == second.next())
        }
    }

    @Test func differentSeedsAreNotShiftedCopiesOfEachOther() {
        var first = SplitMix64(seed: 11)
        var second = SplitMix64(seed: 37)
        let firstValues = (0..<200).map { _ in first.next() }
        let secondValues = (0..<20).map { _ in second.next() }
        for shift in 0..<150 {
            let window = Array(firstValues[shift..<(shift + 20)])
            #expect(window != secondValues)
        }
    }

    @Test func unitValuesStayInRange() {
        var generator = SplitMix64(seed: 7)
        for _ in 0..<1_000 {
            let value = generator.nextUnit()
            #expect(value >= 0 && value < 1)
        }
    }

    @Test func gaussianValuesHaveRoughlyZeroMeanAndUnitSpread() {
        var generator = SplitMix64(seed: 99)
        let values = (0..<20_000).map { _ in generator.nextGaussian() }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        #expect(abs(mean) < 0.05)
        #expect(abs(variance - 1) < 0.1)
    }
}
