import SwiftUI

enum Typography {
    static let display = Font.system(.largeTitle, design: .default, weight: .semibold)
    static let screenTitle = Font.system(.title, design: .default, weight: .bold)
    static let section = Font.system(.title3, design: .default, weight: .semibold)
    static let rowTitle = Font.system(.body, design: .default, weight: .semibold)
    static let rowDetail = Font.system(.subheadline, design: .default, weight: .regular)
    static let value = Font.system(.subheadline, design: .default, weight: .semibold)
    static let label = Font.system(.footnote, design: .default, weight: .regular)
    static let labelStrong = Font.system(.footnote, design: .default, weight: .semibold)
    static let axis = Font.system(.caption2, design: .default, weight: .regular)
    static let button = Font.system(.body, design: .default, weight: .semibold)
    static let amount = Font.system(size: 56, weight: .semibold)
}
