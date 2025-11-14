import Foundation

struct EnvironmentConfiguration: Equatable {
    struct FeatureFlags: OptionSet {
        let rawValue: Int

        init(rawValue: Int) {
            self.rawValue = rawValue
        }

        static let enableVerboseLogging = FeatureFlags(rawValue: 1 << 0)
        static let mockPrivy = FeatureFlags(rawValue: 1 << 1)
    }

    let environment: AppEnvironment
    let apiBaseURL: URL
    let privyAppID: String
    let privyAppClientID: String
    let deepLinkScheme: String
    let privyJWKSURL: URL
    let defaultOAuthProvider: String
    let featureFlags: FeatureFlags
    let networkHeaders: [String: String]

    static var current: EnvironmentConfiguration {
        let bundle = Bundle.main
        let environment = AppEnvironment.resolve(from: bundle)
        let apiBaseURL = URL(string: bundle.object(forInfoDictionaryKey: "AGAPIBaseURL") as? String ?? "") ?? EnvironmentConfiguration.development.apiBaseURL
        let privyAppID = bundle.object(forInfoDictionaryKey: "AGPrivyAppID") as? String ?? ""
        let privyClientID = bundle.object(forInfoDictionaryKey: "AGPrivyClientID") as? String ?? ""
        let deepLinkScheme = bundle.object(forInfoDictionaryKey: "AGDeepLinkScheme") as? String ?? "amigogold"
        let defaultOAuthProvider = bundle.object(forInfoDictionaryKey: "AGDefaultOAuthProvider") as? String ?? "google"
        let jwksURLString = bundle.object(forInfoDictionaryKey: "AGPrivyJWKSURL") as? String ?? ""
        let jwksURL = URL(string: jwksURLString) ?? EnvironmentConfiguration.development.privyJWKSURL

        AppLogger.log("🔧 Environment Config Loaded:", category: "config")
        AppLogger.log("  - Environment: \(environment.displayName)", category: "config")
        AppLogger.log("  - API Base URL: \(apiBaseURL.absoluteString)", category: "config")
        AppLogger.log("  - Privy App ID: \(privyAppID)", category: "config")
        AppLogger.log("  - JWKS URL String: '\(jwksURLString)'", category: "config")
        AppLogger.log("  - JWKS URL: \(jwksURL.absoluteString)", category: "config")
        AppLogger.log("  - Deep Link Scheme: \(deepLinkScheme)", category: "config")
        AppLogger.log("  - OAuth Provider: \(defaultOAuthProvider)", category: "config")

        return EnvironmentConfiguration(
            environment: environment,
            apiBaseURL: apiBaseURL,
            privyAppID: privyAppID,
            privyAppClientID: privyClientID,
            deepLinkScheme: deepLinkScheme,
            privyJWKSURL: jwksURL,
            defaultOAuthProvider: defaultOAuthProvider,
            featureFlags: environment == .development ? [.enableVerboseLogging] : [],
            networkHeaders: [
                "X-Client": "AmigoGold-\(environment.displayName)",
                "Accept": "application/json"
            ]
        )
    }

    static let development = EnvironmentConfiguration(
        environment: .development,
        apiBaseURL: URL(string: "https://perfolio.ai")!,
        privyAppID: "cmhenc7hj004ijy0c311hbf2z",
        privyAppClientID: "client-WY6STfJ4XQDcAbqTXDZZ4buZZPMDma37uaohXSTE77Dqq",
        deepLinkScheme: "perfolio-dev",
        privyJWKSURL: URL(string: "https://auth.privy.io/api/v1/apps/cmhenc7hj004ijy0c311hbf2z/jwks.json")!,
        defaultOAuthProvider: "email",
        featureFlags: [.enableVerboseLogging],
        networkHeaders: [
            "X-Client": "PerFolioDev",
            "Accept": "application/json"
        ]
    )

    static let production = EnvironmentConfiguration(
        environment: .production,
        apiBaseURL: URL(string: "https://perfolio.ai")!,
        privyAppID: "cmhenc7hj004ijy0c311hbf2z",
        privyAppClientID: "client-WY6STfJ4XQDcAbqTXDZZ4buZZPMDma37uaohXSTE77Dqq",
        deepLinkScheme: "perfolio",
        privyJWKSURL: URL(string: "https://auth.privy.io/api/v1/apps/cmhenc7hj004ijy0c311hbf2z/jwks.json")!,
        defaultOAuthProvider: "email",
        featureFlags: [],
        networkHeaders: [
            "X-Client": "PerFolio",
            "Accept": "application/json"
        ]
    )
}
