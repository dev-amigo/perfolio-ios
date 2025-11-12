import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var privyCoordinator: PrivyAuthCoordinator
    @State private var route: Route = .splash

    var body: some View {
        ZStack {
            switch route {
            case .splash:
                SplashView { proceedToLanding() }
            case .landing:
                LandingView(authCoordinator: privyCoordinator) {
                    proceedToMain()
                }
            case .main:
                TradingShellView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: route)
    }

    private func proceedToLanding() {
        guard route == .splash else { return }
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
