import Foundation

protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}

struct HTTPClient: Sendable {
    static let defaultPenalty: TimeInterval = 30

    let provider: ProviderID
    let transport: any HTTPTransport
    let limiter: RateLimiter?
    let headers: [String: String]

    init(
        provider: ProviderID,
        transport: any HTTPTransport = URLSessionTransport(),
        limiter: RateLimiter? = nil,
        headers: [String: String] = [:]
    ) {
        self.provider = provider
        self.transport = transport
        self.limiter = limiter
        self.headers = headers
    }

    func get(
        _ base: String,
        path: String,
        query: [URLQueryItem] = [],
        cost: Int = 1,
        timeout: TimeInterval = 15
    ) async throws -> Data {
        guard var components = URLComponents(string: base + path) else {
            throw ProviderError.invalidResponse(provider)
        }
        if !query.isEmpty {
            components.queryItems = query
        }
        guard let url = components.url else {
            throw ProviderError.invalidResponse(provider)
        }

        try await limiter?.acquire(cost: cost)

        var request = URLRequest(url: url, timeoutInterval: timeout)
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport.send(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw ProviderError.network(provider)
        }

        switch response.statusCode {
        case 200..<300:
            return data
        case 401, 403:
            throw ProviderError.accessDenied(provider)
        case 418, 429:
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap { TimeInterval($0) }
            await limiter?.penalize(for: retryAfter ?? Self.defaultPenalty)
            throw ProviderError.rateLimited(provider, retryAfter: retryAfter)
        default:
            throw ProviderError.invalidResponse(provider)
        }
    }
}
