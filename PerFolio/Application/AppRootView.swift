import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var privyCoordinator: PrivyAuthCoordinator
    @State private var route: Route = .splash

    var body: some View {
        ZStack {
            switch route {
            case .splash:
                SplashView { checkAuthAndProceed() }
            case .onboarding:
                OnboardingView {
                    proceedToLanding()
                }
            case .landing:
                LandingView(authCoordinator: privyCoordinator) {
                    proceedToMain()
                }
            case .main:
                PerFolioShellView(onLogout: {
                    proceedToLanding()
                })
            }
        }
        .animation(.easeInOut(duration: 0.35), value: route)
        .onAppear {
            privyCoordinator.prepare()
        }
    }

    private func checkAuthAndProceed() {
        // Check if onboarding was completed
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        if !hasCompletedOnboarding {
            // First time user, show onboarding
            AppLogger.log("👋 First time user, showing onboarding", category: "app")
            route = .onboarding
            return
        }
        
        // Check if user has an active session
        let hasWalletAddress = UserDefaults.standard.string(forKey: "userWalletAddress") != nil
        let hasAccessToken = UserDefaults.standard.string(forKey: "privyAccessToken") != nil
        
        if hasWalletAddress && hasAccessToken {
            // User is already logged in, go directly to dashboard
            AppLogger.log("✅ Active session found, skipping login", category: "auth")
            route = .main
        } else {
            // No active session, show landing page
            AppLogger.log("ℹ️ No active session, showing landing page", category: "auth")
            route = .landing
        }
    }

    private func proceedToLanding() {
        // Mark onboarding as completed if coming from onboarding
        if route == .onboarding {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            AppLogger.log("✅ Onboarding completed", category: "app")
        }
        route = .landing
    }

    private func proceedToMain() {
        guard route != .main else { return }
        route = .main
    }

    private enum Route {
        case splash
        case onboarding
        case landing
        case main
    }
}

#Preview {
    AppRootView()
        .environmentObject(ThemeManager())
        .environmentObject(PrivyAuthCoordinator(environment: .development))
}
