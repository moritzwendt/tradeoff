import Foundation

struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    mutating func nextUnit() -> Double {
        Double(next() >> 11) / 9_007_199_254_740_992
    }

    mutating func nextGaussian() -> Double {
        let first = max(nextUnit(), 1e-12)
        let second = nextUnit()
        return (-2 * log(first)).squareRoot() * cos(2 * .pi * second)
    }
}
