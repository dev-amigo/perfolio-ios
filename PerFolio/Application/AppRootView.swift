import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var privyCoordinator: PrivyAuthCoordinator
    @State private var route: Route = .splash

    var body: some View {
        ZStack {
            switch route {
            case .splash:
                SplashView { checkAuthAndProceed() }
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
        route = .landing
    }

    private func proceedToMain() {
        guard route != .main else { return }
        route = .main
    }

    private enum Route {
        case splash
        case landing
        case main
    }
}

#Preview {
    AppRootView()
        .environmentObject(ThemeManager())
        .environmentObject(PrivyAuthCoordinator(environment: .development))
}
