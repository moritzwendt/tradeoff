import Foundation

enum ProviderError: Error, Equatable, Sendable {
    case notImplemented(ProviderID)
    case missingAPIKey(ProviderID)
    case rateLimited(ProviderID, retryAfter: TimeInterval?)
    case invalidResponse(ProviderID)
    case unknownInstrument(InstrumentID)
    case resourceMissing(String)
}

extension ProviderError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notImplemented(let id): "\(id.displayName) ist nicht verbunden"
        case .missingAPIKey(let id): "\(id.displayName) braucht einen API Key"
        case .rateLimited(let id, _): "\(id.displayName) Limit erreicht"
        case .invalidResponse(let id): "\(id.displayName) lieferte eine ungültige Antwort"
        case .unknownInstrument: "Unbekanntes Instrument"
        case .resourceMissing(let name): "Ressource \(name) fehlt"
        }
    }
}
