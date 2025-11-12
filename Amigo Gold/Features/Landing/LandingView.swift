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
        VStack(spacing: 32) {
            environmentBadge
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            AGSurfaceCard {
                VStack(spacing: 20) {
                    AGIconStack(systemName: "lock.shield")
                    VStack(spacing: 12) {
                        Text(L10n.text(.landingTitle))
                            .font(themeManager.typography.title)
                            .multilineTextAlignment(.center)
                        Text(L10n.text(.landingSubtitle))
                            .font(themeManager.typography.subtitle)
                            .foregroundStyle(themeManager.palette.subdued)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal)
                }
            }

            AGPrimaryButton(
                title: viewModel.isLoading ? L10n.text(.landingCTALoading) : L10n.text(.landingCTA),
                isLoading: viewModel.isLoading,
                action: viewModel.loginTapped
            )

            Spacer()

            footer
        }
        .padding(24)
        .background(themeManager.palette.background.ignoresSafeArea())
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

    private var environmentBadge: some View {
        Group {
            if configuration.environment == .development {
                Text(L10n.text(.landingEnvironmentBadge))
                    .font(themeManager.typography.badge)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .foregroundStyle(themeManager.palette.background)
                    .background(themeManager.palette.foreground)
                    .clipShape(Capsule())
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Text(configuration.environment.displayName)
                .font(themeManager.typography.subtitle)
                .foregroundStyle(themeManager.palette.subdued)
            Text(configuration.apiBaseURL.absoluteString)
                .font(.caption)
                .foregroundStyle(themeManager.palette.subdued)
        }
    }
}

#Preview {
    LandingView(configuration: .development, authCoordinator: PrivyAuthCoordinator(environment: .development)) {}
        .environmentObject(ThemeManager())
}
