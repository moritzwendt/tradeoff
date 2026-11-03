import Testing
@testable import TradeOff

struct AppConfigTests {
    @Test func rejectsMissingValues() {
        #expect(AppConfig.sanitized(nil) == nil)
        #expect(AppConfig.sanitized(42) == nil)
    }

    @Test func rejectsEmptyAndWhitespaceValues() {
        #expect(AppConfig.sanitized("") == nil)
        #expect(AppConfig.sanitized("   ") == nil)
    }

    @Test func rejectsUnresolvedBuildVariables() {
        #expect(AppConfig.sanitized("$(FINNHUB_API_KEY)") == nil)
    }

    @Test func trimsValidValues() {
        #expect(AppConfig.sanitized("  abc123 ") == "abc123")
    }

    @Test func keysDefaultToNil() {
        let config = AppConfig(finnhubAPIKey: nil)
        #expect(config.finnhubAPIKey == nil)
        #expect(config.alpacaKeyID == nil)
        #expect(config.alpacaSecretKey == nil)
    }

    @Test func keepsProvidedKeys() {
        let config = AppConfig(finnhubAPIKey: "f", alpacaKeyID: "id", alpacaSecretKey: "secret")
        #expect(config.finnhubAPIKey == "f")
        #expect(config.alpacaKeyID == "id")
        #expect(config.alpacaSecretKey == "secret")
    }
}

