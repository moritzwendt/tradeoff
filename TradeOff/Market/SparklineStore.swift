import Foundation

struct SparklineStore: Sendable {
    static let pointLimit = 48

    let url: URL

    static var standard: SparklineStore {
        SparklineStore(url: URL.cachesDirectory.appending(path: "sparklines.json"))
    }

    func load() -> [InstrumentID: [Double]] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        return (try? JSONDecoder().decode([InstrumentID: [Double]].self, from: data)) ?? [:]
    }

    func save(_ values: [InstrumentID: [Double]]) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func downsample(_ values: [Double], limit: Int = pointLimit) -> [Double] {
        guard limit > 1, values.count > limit else { return values }
        let step = Double(values.count - 1) / Double(limit - 1)
        return (0..<limit).map { values[Int((Double($0) * step).rounded())] }
    }
}
