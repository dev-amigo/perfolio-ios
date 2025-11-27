import SwiftUI

/// Simplified dashboard view designed for non-technical users
struct MomDashboardView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel: MomDashboardViewModel
    
    var onNavigateToDeposit: (() -> Void)?
    
    init(dashboardViewModel: DashboardViewModel, onNavigateToDeposit: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: MomDashboardViewModel(dashboardViewModel: dashboardViewModel))
        self.onNavigateToDeposit = onNavigateToDeposit
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 1. Total Holdings (Big Number with Breakdown)
                TotalHoldingsCard(
                    totalValue: viewModel.totalHoldingsInUserCurrency,
                    paxgValue: viewModel.paxgValueUserCurrency,
                    usdcValue: viewModel.usdcValueUserCurrency,
                    changeAmount: viewModel.totalHoldingsChangeAmount,
                    changePercent: viewModel.totalHoldingsChangePercent,
                    currency: UserPreferences.defaultCurrency
                )
                .environmentObject(themeManager)
                
                // 2. Investment Calculator (What-if widget)
                InvestmentCalculatorCard(
                    investmentAmount: $viewModel.investmentAmount,
                    calculation: viewModel.investmentCalculation,
                    currency: UserPreferences.defaultCurrency,
                    onDeposit: handleDeposit
                )
                .environmentObject(themeManager)
                
                // 3. Profit/Loss Tracker (Daily/Weekly/Monthly)
                ProfitLossCard(
                    today: viewModel.todayProfitLoss,
                    week: viewModel.weekProfitLoss,
                    month: viewModel.monthProfitLoss,
                    overall: viewModel.overallProfitLoss,
                    overallPercent: viewModel.overallProfitLossPercent,
                    currency: UserPreferences.defaultCurrency
                )
                .environmentObject(themeManager)
                
                // 4. Asset Breakdown (PAXG + USDC details)
                AssetBreakdownCard(
                    paxgAmount: viewModel.paxgAmount,
                    paxgValueUSD: viewModel.paxgValueUSD,
                    paxgValueLocal: viewModel.paxgValueUserCurrency,
                    usdcAmount: viewModel.usdcAmount,
                    usdcValueLocal: viewModel.usdcValueUserCurrency,
                    currency: UserPreferences.defaultCurrency
                )
                .environmentObject(themeManager)
                
                // Reset baseline button (for testing/debugging)
                if viewModel.overallProfitLoss != 0 {
                    Button {
                        HapticManager.shared.light()
                        viewModel.resetBaseline()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                            Text("Reset Baseline")
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(themeManager.perfolioTheme.primaryBackground)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
        .background(themeManager.perfolioTheme.primaryBackground)
        .refreshable {
            await viewModel.refreshData()
        }
        .task {
            // Load data when view appears
            // This fetches:
            // 1. Real USDC/PAXG balances from blockchain
            // 2. Live PAXG price from oracle
            // 3. Live currency conversion rates from CoinGecko
            // 4. Calculates profit/loss vs baseline
            await viewModel.loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .currencyDidChange)) { notification in
            // Automatically refresh when currency changes in Settings
            if let newCurrency = notification.userInfo?["newCurrency"] as? String {
                AppLogger.log("💱 Mom Dashboard View received currency change to: \(newCurrency)", category: "mom-dashboard")
                Task {
                    await viewModel.loadData()
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeManager.perfolioTheme.primaryBackground.opacity(0.8))
            }
        }
    }
    
    private func handleDeposit() {
        HapticManager.shared.success()
        onNavigateToDeposit?()
        AppLogger.log("🎯 Navigating to deposit with amount: \(viewModel.investmentAmount)", category: "mom-dashboard")
    }
}

