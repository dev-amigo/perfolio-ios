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
        let jwksURL = URL(string: bundle.object(forInfoDictionaryKey: "AGPrivyJWKSURL") as? String ?? "")
            ?? EnvironmentConfiguration.development.privyJWKSURL

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
        apiBaseURL: URL(string: "https://dev-api.amigogold.com")!,
        privyAppID: "cmhvskgil00nvky0cb6rjejrs",
        privyAppClientID: "client-WY6SX56F52MtzFqDzgL6jxdNAfpyL3kdY77zMdG4FgS2J",
        deepLinkScheme: "amigogold-dev",
        privyJWKSURL: URL(string: "https://auth.privy.io/api/v1/apps/cmhvskgil00nvky0cb6rjejrs/jwks.json")!,
        defaultOAuthProvider: "google",
        featureFlags: [.enableVerboseLogging],
        networkHeaders: [
            "X-Client": "AmigoGoldDev",
            "Accept": "application/json"
        ]
    )

    static let production = EnvironmentConfiguration(
        environment: .production,
        apiBaseURL: URL(string: "https://api.amigogold.com")!,
        privyAppID: "cmhvskgil00nvky0cb6rjejrs",
        privyAppClientID: "client-WY6SX56F52MtzFqDzgL6jxdNAfpyL3kdY77zMdG4FgS2J",
        deepLinkScheme: "amigogold",
        privyJWKSURL: URL(string: "https://auth.privy.io/api/v1/apps/cmhvskgil00nvky0cb6rjejrs/jwks.json")!,
        defaultOAuthProvider: "google",
        featureFlags: [],
        networkHeaders: [
            "X-Client": "AmigoGold",
            "Accept": "application/json"
        ]
    )
}
