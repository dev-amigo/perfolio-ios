import SwiftUI

struct PerFolioShellView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    var onLogout: (() -> Void)?
    @State private var selectedTab: Tab = .dashboard
    
    enum Tab: Int {
        case dashboard = 0
        case wallet = 1
        case borrow = 2
        case loans = 3
        case activity = 4
    }
    
    var body: some View {
        ZStack {
            // Background
            themeManager.perfolioTheme.primaryBackground
                .ignoresSafeArea()
            
            // Phase 3-4: Dashboard + Wallet + Borrow tabs + Active Loans
            TabView(selection: $selectedTab) {
                PerFolioDashboardView(
                    onLogout: onLogout,
                    onNavigateToTab: { destination in
                        navigateToTab(destination)
                    }
                )
                .tabItem {
                    Label("Dashboard", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.dashboard)
                
                DepositBuyView()
                    .tabItem {
                        Label("Wallet", systemImage: "wallet.bifold")
                    }
                    .tag(Tab.wallet)
                
                BorrowView()
                    .tabItem {
                        Label("Borrow", systemImage: "banknote.fill")
                    }
                    .tag(Tab.borrow)
                
                ActiveLoansView()
                    .tabItem {
                        Label("Loans", systemImage: "list.bullet.rectangle")
                    }
                    .tag(Tab.loans)
                
                ActivityView()
                    .tabItem {
                        Label("Activity", systemImage: "clock.arrow.circlepath")
                    }
                    .tag(Tab.activity)
            }
            .tint(themeManager.perfolioTheme.tintColor)
        }
    }
    
    // MARK: - Navigation Helper
    
    private func navigateToTab(_ destination: String) {
        withAnimation {
            switch destination.lowercased() {
            case "wallet":
                selectedTab = .wallet
            case "borrow":
                selectedTab = .borrow
            case "loans":
                selectedTab = .loans
            case "dashboard":
                selectedTab = .dashboard
            default:
                AppLogger.log("⚠️ Unknown navigation destination: \(destination)", category: "shell")
            }
        }
        HapticManager.shared.light()
    }
}

#Preview {
    PerFolioShellView()
        .environmentObject(ThemeManager())
}


