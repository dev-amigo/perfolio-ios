import XCTest
@testable import PerFolio

final class LandingViewModelTests: XCTestCase {
    func testOnAppearCallsPrepare() async {
        let coordinator = PrivyAuthenticatorStub()
        let viewModel = await makeViewModel(coordinator: coordinator)

        await MainActor.run {
            viewModel.onAppear()
        }

        XCTAssertEqual(coordinator.prepareCallCount, 1)
    }

    func testSuccessfulLoginTriggersAlertAndCallback() async {
        let coordinator = PrivyAuthenticatorStub()
        coordinator.loginResult = .success(MockPrivyUser(id: "user-123", accessToken: "token-xyz"))

        let authenticatedExpectation = expectation(description: "Authenticated callback")
        let viewModel = await makeViewModel(coordinator: coordinator) {
            authenticatedExpectation.fulfill()
        }

        await MainActor.run {
            viewModel.loginTapped()
        }

        await fulfillment(of: [authenticatedExpectation], timeout: 1)

        await MainActor.run {
            XCTAssertFalse(viewModel.isLoading)
            XCTAssertEqual(viewModel.alert?.title, L10n.string(.landingAlertSuccessTitle))
        }
        XCTAssertEqual(coordinator.verifyTokens, ["token-xyz"])
    }

    func testFailedLoginShowsErrorAlert() async {
        let coordinator = PrivyAuthenticatorStub()
        coordinator.loginResult = .failure(MockError.loginFailed)

        let viewModel = await makeViewModel(coordinator: coordinator)

        await MainActor.run {
            viewModel.loginTapped()
        }

        try? await Task.sleep(nanoseconds: 100_000_000)

        await MainActor.run {
            XCTAssertFalse(viewModel.isLoading)
            XCTAssertEqual(viewModel.alert?.title, L10n.string(.landingAlertErrorTitle))
        }
        XCTAssertTrue(coordinator.verifyTokens.isEmpty)
    }
}

// MARK: - Helpers

private extension LandingViewModelTests {
    @MainActor
    func makeViewModel(
        coordinator: PrivyAuthenticatorStub,
        onAuthenticated: @escaping () -> Void = {}
    ) -> LandingViewModel {
        LandingViewModel(authCoordinator: coordinator, onAuthenticated: onAuthenticated)
    }
}

private final class PrivyAuthenticatorStub: PrivyAuthenticating {
    var prepareCallCount = 0
    var loginResult: Result<MockPrivyUser, Error> = .failure(MockError.unconfigured)
    var verifyError: Error?
    private(set) var verifyTokens: [String] = []

    func prepare() {
        prepareCallCount += 1
    }

    func startOAuthLogin() async throws -> any PrivyUser {
        try loginResult.get()
    }

    func verify(accessToken: String) async throws {
        verifyTokens.append(accessToken)
        if let verifyError {
            throw verifyError
        }
    }
}

private struct MockPrivyUser: PrivyUser {
    enum MockWalletError: Error {
        case unsupported
    }

    let id: String
    let accessToken: String

    var identityToken: String? { nil }
    var createdAt: Date? { nil }
    var linkedAccounts: [PrivySDK.LinkedAccount] { [] }
    var embeddedEthereumWallets: [any PrivySDK.EmbeddedEthereumWallet] { [] }
    var embeddedSolanaWallets: [any PrivySDK.EmbeddedSolanaWallet] { [] }

    func getAccessToken() async throws -> String {
        accessToken
    }

    func createEthereumWallet(allowAdditional: Bool, timeout: Swift.Duration) async throws -> any PrivySDK.EmbeddedEthereumWallet {
        throw MockWalletError.unsupported
    }

    func createSolanaWallet(allowAdditional: Bool, timeout: Swift.Duration) async throws -> any PrivySDK.EmbeddedSolanaWallet {
        throw MockWalletError.unsupported
    }

    func createEthereumWallet() async throws -> any PrivySDK.EmbeddedEthereumWallet {
        throw MockWalletError.unsupported
    }

    func createSolanaWallet() async throws -> any PrivySDK.EmbeddedSolanaWallet {
        throw MockWalletError.unsupported
    }

    func createEthereumWallet(allowAdditional: Bool) async throws -> any PrivySDK.EmbeddedEthereumWallet {
        throw MockWalletError.unsupported
    }

    func createSolanaWallet(allowAdditional: Bool) async throws -> any PrivySDK.EmbeddedSolanaWallet {
        throw MockWalletError.unsupported
    }

    func refresh() async throws {}
    func logout() {}
    func logout() async {}
}

private enum MockError: Error {
    case unconfigured
    case loginFailed
}
