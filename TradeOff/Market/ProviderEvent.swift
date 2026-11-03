import Foundation

enum ProviderStatus: Equatable, Sendable {
    case idle
    case connecting
    case live
    case reconnecting
    case failed(String)

    var isDegraded: Bool {
        switch self {
        case .reconnecting, .failed: true
        case .idle, .connecting, .live: false
        }
    }
}

enum ProviderEvent: Equatable, Sendable {
    case quote(Quote)
    case status(ProviderStatus)
}
