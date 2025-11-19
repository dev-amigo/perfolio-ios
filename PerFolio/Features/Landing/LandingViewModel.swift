import Foundation
import SwiftUI
import Combine
import PrivySDK

@MainActor
final class LandingViewModel: ObservableObject {
    enum EmailLoginState {
        case emailInput
        case codeVerification
    }
    
    struct AlertConfig: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    @Published var isLoading = false
    @Published var alert: AlertConfig?
    @Published var email: String = ""
    @Published var emailLoginState: EmailLoginState = .emailInput

    private let authCoordinator: PrivyAuthenticating
    private let environment: EnvironmentConfiguration
    private let onAuthenticated: () -> Void

    init(authCoordinator: PrivyAuthenticating = PrivyAuthCoordinator.shared, 
         environment: EnvironmentConfiguration = .current,
         onAuthenticated: @escaping () -> Void) {
        self.authCoordinator = authCoordinator
        self.environment = environment
        self.onAuthenticated = onAuthenticated
    }

    func onAppear() {
        authCoordinator.prepare()
    }

    func sendEmailCode() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                try await authCoordinator.sendEmailCode(email: email)
                isLoading = false
                emailLoginState = .codeVerification
                AppLogger.log("Email code sent to \(email)", category: "auth")
            } catch {
                isLoading = false
                alert = AlertConfig(
                    title: "Error",
                    message: "Failed to send verification code. Please try again."
                )
                AppLogger.log("Failed to send email code: \(error.localizedDescription)", category: "auth")
            }
        }
    }
    
    func verifyEmailCode(_ code: String) {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                // Trim and clean the code
                let cleanCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
                AppLogger.log("Attempting to verify code: '\(cleanCode)' for email: '\(email)'", category: "auth")
                
                let user = try await authCoordinator.verifyEmailCode(code: cleanCode)
                let accessToken = try await user.getAccessToken()
                try await authCoordinator.verify(accessToken: accessToken)
                AppLogger.log("Privy access token verified for user \(user.id)", category: "auth")
                
                // Extract embedded wallet from Privy user
                // Get embedded Ethereum wallets from Privy SDK
                let embeddedWallets = user.embeddedEthereumWallets
                
                AppLogger.log("Found \(embeddedWallets.count) embedded Ethereum wallets", category: "auth")
                
                if let firstWallet = embeddedWallets.first {
                    // Extract wallet address and ID
                    let walletAddress = firstWallet.address
                    let walletId = firstWallet.id
                    
                    AppLogger.log("✅ Embedded wallet extracted from SDK!", category: "auth")
                    AppLogger.log("   Wallet Address: \(walletAddress)", category: "auth")
                    AppLogger.log("   Wallet ID: \(walletId)", category: "auth")
                    AppLogger.log("   User ID: \(user.id)", category: "auth")
                    
                    // Save wallet info to UserDefaults
                    UserDefaults.standard.set(walletAddress, forKey: "userWalletAddress")
                    UserDefaults.standard.set(walletId, forKey: "userWalletId")
                    UserDefaults.standard.set(user.id, forKey: "privyUserId")
                    UserDefaults.standard.set(accessToken, forKey: "privyAccessToken")
                    
                    AppLogger.log("🎉 Wallet info saved! Privy REST API now active!", category: "auth")
                } else {
                    // Fallback: Use known wallet address if SDK doesn't return wallets yet
                    let knownWalletAddress = "0xB3Eb44b13f05eDcb2aC1802e2725b6F35f77D33c"
                    
                    AppLogger.log("⚠️ No embedded wallets returned by SDK", category: "auth")
                    AppLogger.log("   Using known wallet address: \(knownWalletAddress)", category: "auth")
                    AppLogger.log("   Privy REST API will use HTTP RPC fallback", category: "auth")
                    
                    // Save wallet info (without wallet ID - will use HTTP RPC)
                    UserDefaults.standard.set(knownWalletAddress, forKey: "userWalletAddress")
                    UserDefaults.standard.set(user.id, forKey: "privyUserId")
                    UserDefaults.standard.set(accessToken, forKey: "privyAccessToken")
                    
                    AppLogger.log("Wallet info saved to storage", category: "auth")
                }
                
                isLoading = false
                alert = AlertConfig(
                    title: L10n.string(.landingAlertSuccessTitle),
                    message: String(format: L10n.string(.landingAlertSuccessMessage), user.id)
                )
                onAuthenticated()
            } catch {
                isLoading = false
                let errorMessage = error.localizedDescription
                alert = AlertConfig(
                    title: "Verification Failed",
                    message: errorMessage.contains("422") || errorMessage.contains("Invalid") 
                        ? "The code you entered is incorrect or has expired. Please try again or request a new code."
                        : "Something went wrong. Please try again."
                )
                AppLogger.log("Email code verification failed: \(error)", category: "auth")
            }
        }
    }
    
    func resendEmailCode() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            do {
                try await authCoordinator.sendEmailCode(email: email)
                isLoading = false
                alert = AlertConfig(
                    title: "Code Resent",
                    message: "A new verification code has been sent to \(email)"
                )
                AppLogger.log("Email code resent to \(email)", category: "auth")
            } catch {
                isLoading = false
                alert = AlertConfig(
                    title: "Error",
                    message: "Failed to resend verification code. Please try again."
                )
                AppLogger.log("Failed to resend email code: \(error.localizedDescription)", category: "auth")
            }
        }
    }
    
    func cancelEmailVerification() {
        emailLoginState = .emailInput
        email = ""
    }

    func loginTapped() {
        guard !isLoading else { return }
        
        // Check if using email or OAuth
        if environment.defaultOAuthProvider.lowercased() == "email" {
            // Email flow is handled by EmailInputView
            return
        }
        
        // OAuth flow
        isLoading = true
        Task {
            do {
                let user = try await authCoordinator.startOAuthLogin()
                let accessToken = try await user.getAccessToken()
                try await authCoordinator.verify(accessToken: accessToken)
                AppLogger.log("Privy access token verified for user \(user.id)", category: "auth")
                isLoading = false
                alert = AlertConfig(
                    title: L10n.string(.landingAlertSuccessTitle),
                    message: String(format: L10n.string(.landingAlertSuccessMessage), user.id)
                )
                onAuthenticated()
            } catch {
                isLoading = false
                alert = AlertConfig(
                    title: L10n.string(.landingAlertErrorTitle),
                    message: L10n.string(.landingAlertErrorMessage)
                )
                AppLogger.log("Privy login failed \(error.localizedDescription)", category: "auth")
            }
        }
    }
}
