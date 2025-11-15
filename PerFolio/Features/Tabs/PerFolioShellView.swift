import SwiftUI

struct PerFolioShellView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    var onLogout: (() -> Void)?
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab: Int {
        case dashboard = 0
        case wallet = 1
    }
    
    var body: some View {
        ZStack {
            // Background
            themeManager.perfolioTheme.primaryBackground
                .ignoresSafeArea()
            
            // Phase 3: Dashboard + Deposit & Buy tabs
            TabView(selection: $selectedTab) {
                PerFolioDashboardView(onLogout: onLogout)
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(Tab.dashboard)
                
                DepositBuyView()
                    .tabItem {
                        Label("Wallet", systemImage: "wallet.bifold")
                    }
                    .tag(Tab.wallet)
            }
            .tint(themeManager.perfolioTheme.tintColor)
        }
    }
}

#Preview {
    PerFolioShellView()
        .environmentObject(ThemeManager())
}



