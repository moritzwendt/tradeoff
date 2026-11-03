import Foundation
@testable import TradeOff

final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL] = []
    private var headerStorage: [[String: String]] = []

    func append(_ url: URL) {
        lock.withLock { storage.append(url) }
    }

    func append(headers: [String: String]) {
        lock.withLock { headerStorage.append(headers) }
    }

    var headers: [[String: String]] {
        lock.withLock { headerStorage }
    }

    var urls: [URL] {
        lock.withLock { storage }
    }
}

struct StubResponse: Sendable {
    var status: Int = 200
    var body: String = ""
    var headers: [String: String] = [:]
}

struct StubTransport: HTTPTransport {
    let log = RequestLog()
    let handler: @Sendable (URL) throws -> StubResponse

    init(handler: @escaping @Sendable (URL) throws -> StubResponse) {
        self.handler = handler
    }

    init(body: String, status: Int = 200) {
        self.init { _ in StubResponse(status: status, body: body) }
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else { throw URLError(.badURL) }
        log.append(url)
        log.append(headers: request.allHTTPHeaderFields ?? [:])
        let result = try handler(url)
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: result.status,
            httpVersion: nil,
            headerFields: result.headers
        ) else {
            throw URLError(.badServerResponse)
        }
        return (Data(result.body.utf8), response)
    }
}

enum FixedClock {
    static let epoch = Date(timeIntervalSince1970: 1_800_000_000)
}
