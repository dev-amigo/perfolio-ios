import SwiftUI

struct TradingShellView: View {
    enum Tab: CaseIterable {
        case dashboard
        case wallet
        case settings

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .wallet: return "Wallet"
            case .settings: return "Settings"
            }
        }

        var systemImage: String {
            switch self {
            case .dashboard: return "chart.line.uptrend.xyaxis"
            case .wallet: return "wallet.pass"
            case .settings: return "gearshape"
            }
        }
    }

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selection: Tab = .dashboard
    @State private var isCompactSidebar = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $selection) {
                DashboardView()
                    .tag(Tab.dashboard)
                    .tabItem { Label(Tab.dashboard.title, systemImage: Tab.dashboard.systemImage) }
                WalletView()
                    .tag(Tab.wallet)
                    .tabItem { Label(Tab.wallet.title, systemImage: Tab.wallet.systemImage) }
                SettingsView()
                    .tag(Tab.settings)
                    .tabItem { Label(Tab.settings.title, systemImage: Tab.settings.systemImage) }
            }
            .tabViewStyle(.automatic)
            .toolbar(.hidden, for: .tabBar)

            if shouldShowSidebar {
                SearchSidebarView(isCompact: $isCompactSidebar)
                    .frame(width: isCompactSidebar ? 220 : 320)
                    .padding(.top, 24)
                    .padding(.trailing, 24)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            VStack {
                Spacer()
                LiquidGlassTabBar(
                    selection: $selection,
                    tabs: Tab.allCases.map { LiquidGlassTabBar.TabItem(id: $0, title: $0.title, systemImage: $0.systemImage) }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .background(themeManager.palette.background.ignoresSafeArea())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selection)
        .animation(.easeInOut(duration: 0.25), value: isCompactSidebar)
    }

    private var shouldShowSidebar: Bool {
        horizontalSizeClass == .regular
    }
}

#Preview {
    TradingShellView()
        .environmentObject(ThemeManager())
}
