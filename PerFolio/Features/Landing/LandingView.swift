import SwiftUI

struct LandingView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel: LandingViewModel
    private let configuration: EnvironmentConfiguration

    private let onAuthenticated: () -> Void

    init(
        configuration: EnvironmentConfiguration = .current,
        authCoordinator: PrivyAuthenticating = PrivyAuthCoordinator.shared,
        onAuthenticated: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.onAuthenticated = onAuthenticated
        _viewModel = StateObject(wrappedValue: LandingViewModel(authCoordinator: authCoordinator, onAuthenticated: onAuthenticated))
    }

    var body: some View {
        Group {
            if configuration.defaultOAuthProvider.lowercased() == "email" {
                emailLoginFlow
            } else {
                oauthLoginView
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .alert(item: $viewModel.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var emailLoginFlow: some View {
        Group {
            switch viewModel.emailLoginState {
            case .emailInput:
                EmailInputView(
                    email: $viewModel.email,
                    onContinue: viewModel.sendEmailCode,
                    isLoading: viewModel.isLoading
                )
                .background(themeManager.perfolioTheme.primaryBackground.ignoresSafeArea())
                
            case .codeVerification:
                EmailVerificationView(
                    email: viewModel.email,
                    onCodeEntered: viewModel.verifyEmailCode,
                    onCancel: viewModel.cancelEmailVerification,
                    onResendCode: viewModel.resendEmailCode
                )
            }
        }
    }
    
    private var oauthLoginView: some View {
        VStack(spacing: 32) {
            environmentBadge
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            PerFolioCard(style: .secondary) {
                VStack(spacing: 24) {
                    // Gold icon
                    Image(systemName: "circle.grid.cross.fill")
                        .symbolRenderingMode(.hierarchical)
                        .font(.system(size: 64, weight: .regular, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        .padding(20)
                        .background(
                            Circle()
                                .fill(themeManager.perfolioTheme.tintColor.opacity(0.15))
                        )
                    
                    VStack(spacing: 12) {
                        Text(L10n.text(.landingTitle))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                            .multilineTextAlignment(.center)
                        
                        Text(L10n.text(.landingSubtitle))
                            .font(.system(size: 16, weight: .regular, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                }
            }

            PerFolioButton(
                viewModel.isLoading ? "Opening Privy..." : "Login with Privy",
                style: .primary,
                isLoading: viewModel.isLoading,
                action: viewModel.loginTapped
            )

            Spacer()

            footer
        }
        .padding(24)
        .background(themeManager.perfolioTheme.primaryBackground.ignoresSafeArea())
    }

    private var environmentBadge: some View {
        Group {
            if configuration.environment == .development {
                Text(L10n.text(.landingEnvironmentBadge))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .foregroundStyle(themeManager.perfolioTheme.primaryBackground)
                    .background(themeManager.perfolioTheme.tintColor)
                    .clipShape(Capsule())
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(configuration.environment.displayName)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            Text(configuration.apiBaseURL.absoluteString)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textTertiary)
        }
    }
}

#Preview {
    LandingView(configuration: .development, authCoordinator: PrivyAuthCoordinator(environment: .development)) {}
        .environmentObject(ThemeManager())
}
