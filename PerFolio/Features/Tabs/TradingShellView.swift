import SwiftUI

struct TradingShellView: View {
    @SceneStorage("tradingShell.selectedTab") private var storedTabRawValue: Int = Tab.dashboard.rawValue
    enum Tab: Int, CaseIterable {
        case dashboard = 0
        case wallet = 1
        case settings = 2

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
    @State private var selection: Tab = .dashboard {
        didSet {
            storedTabRawValue = selection.rawValue
        }
    }
    @State private var isCompactSidebar = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                ZStack(alignment: .topTrailing) {
            LiquidGlassTabBar(
                selection: $selection,
                tabs: tabItems
            )
                    rightSidebar
                }
//                .tabViewBottomAccessory {
//                    Button {
//                        selection = .wallet
//                    } label: {
//                        Label("Quick Wallet", systemImage: "bolt.fill")
//                    }
//                }
//                .tabBarMinimizeBehavior(.onScrollDown)
            } else {
                legacyTabs
            }
        }
        .background(themeManager.palette.background.ignoresSafeArea())
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selection)
        .animation(.easeInOut(duration: 0.25), value: isCompactSidebar)
    }

    private var shouldShowSidebar: Bool {
        horizontalSizeClass == .regular
    }

    private var rightSidebar: some View {
        Group {
            if shouldShowSidebar {
                SearchSidebarView(isCompact: $isCompactSidebar)
                    .frame(width: isCompactSidebar ? 220 : 320)
                    .padding(.top, 24)
                    .padding(.trailing, 24)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
    }

    private var tabItems: [LiquidGlassTabBar<Tab>.TabItem<Tab>] {
        [
            LiquidGlassTabBar<Tab>.TabItem(id: .dashboard, title: Tab.dashboard.title, systemImage: Tab.dashboard.systemImage) {
                DashboardView()
            },
            LiquidGlassTabBar<Tab>.TabItem(id: .wallet, title: Tab.wallet.title, systemImage: Tab.wallet.systemImage) {
                WalletView()
            },
            LiquidGlassTabBar<Tab>.TabItem(id: .settings, title: Tab.settings.title, systemImage: Tab.settings.systemImage) {
                SettingsView()
            },
        ]
    }

    private var legacyTabs: some View {
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
            rightSidebar
        }
    }
}

#Preview {
    TradingShellView()
        .environmentObject(ThemeManager())
}
