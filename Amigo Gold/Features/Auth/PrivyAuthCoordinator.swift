import Foundation
import Privy

enum PrivyAuthError: Error {
    case notConfigured
}

@MainActor
protocol PrivyAuthenticating {
    func prepare()
    func startOAuthLogin() async throws -> any PrivyUser
    func verify(accessToken: String) async throws
}

@MainActor
final class PrivyAuthCoordinator: ObservableObject, PrivyAuthenticating {
    static let shared = PrivyAuthCoordinator()

    @Published private(set) var authState: AuthState = .notReady

    private var client: (any Privy)?
    private var authStreamTask: Task<Void, Never>?
    private let environment: EnvironmentConfiguration
    private let tokenVerifier: PrivyTokenVerifier

    init(environment: EnvironmentConfiguration = .current, tokenVerifier: PrivyTokenVerifier? = nil) {
        self.environment = environment
        if let verifier = tokenVerifier {
            self.tokenVerifier = verifier
        } else {
            self.tokenVerifier = PrivyTokenVerifier(configuration: environment)
        }
    }

    deinit {
        authStreamTask?.cancel()
    }

    func prepare() {
        guard client == nil else { return }
        let loggingConfig = PrivyLoggingConfig(
            logLevel: environment.featureFlags.contains(.enableVerboseLogging) ? .debug : .error,
            logMessage: { level, message in
                AppLogger.log("[Privy] \(message)", category: "\(level)")
            }
        )
        let privyConfig = PrivyConfig(
            appId: environment.privyAppID,
            appClientId: environment.privyAppClientID,
            loggingConfig: loggingConfig,
            customAuthConfig: nil
        )
        let client = PrivySdk.initialize(config: privyConfig)
        self.client = client
        observeAuthState(client: client)
    }

    func startOAuthLogin() async throws -> any PrivyUser {
        guard let client else { throw PrivyAuthError.notConfigured }
        let provider = provider(from: environment.defaultOAuthProvider)
        return try await client.oAuth.login(with: provider, appUrlScheme: environment.deepLinkScheme)
    }

    func verify(accessToken: String) async throws {
        try await tokenVerifier.verify(accessToken: accessToken)
    }

    private func observeAuthState(client: any Privy) {
        authStreamTask?.cancel()
        authStreamTask = Task { [weak self] in
            guard let self else { return }
            for await state in client.authStateStream {
                await MainActor.run {
                    self.authState = state
                }
            }
        }
    }

    private func provider(from string: String) -> OAuthProvider {
        switch string.lowercased() {
        case "apple":
            return .apple
        case "twitter":
            return .twitter
        case "discord":
            return .discord
        default:
            return .google
        }
    }
}
