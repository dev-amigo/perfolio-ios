import SwiftUI

/// Standard Dashboard - Loan safety focused, mom-friendly interface
struct StandardDashboardView: View {
    @StateObject private var viewModel = StandardDashboardViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    var onNavigateToTab: ((String) -> Void)?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(errorMessage)
                } else {
                    contentView
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(themeManager.perfolioTheme.primaryBackground.ignoresSafeArea())
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .currencyDidChange)) { _ in
            Task {
                await viewModel.loadData()
            }
        }
        .refreshable {
            await viewModel.loadData()
        }
    }
    
    // MARK: - Content View
    
    @ViewBuilder
    private var contentView: some View {
        VStack(spacing: 20) {
            // Section 1: Collateral Overview (Your Gold)
            CollateralOverviewCard(
                paxgBalance: viewModel.paxgBalance,
                totalValue: viewModel.collateralValueUserCurrency,
                todayChange: viewModel.todayChange,
                todayChangePercent: viewModel.todayChangePercent,
                isPositiveChange: viewModel.isPositiveChange,
                goldPrice: viewModel.goldPriceUserCurrency
            )
            
            // Section 2: Collateral Growth & Borrowing Power
            CollateralGrowthCard(
                currentCollateral: viewModel.collateralValueUserCurrency,
                paxgBalance: viewModel.paxgBalance,
                availableToBorrow: viewModel.availableToBorrow,
                onAddGold: {
                    onNavigateToTab?("wallet")
                }
            )
            
            // Section 3: Borrowing Overview (Your Loan) - Only if user has borrowed
            if viewModel.borrowedAmount != "$0.00" {
                BorrowingOverviewCard(
                    borrowedAmount: viewModel.borrowedAmount,
                    totalOwed: viewModel.totalOwed,
                    interestRate: viewModel.interestRate,
                    onRepayTap: {
                        onNavigateToTab?("wallet")
                    }
                )
            }
            
            // Section 4: Loan Safety - Only if user has borrowed
            if viewModel.borrowedAmount != "$0.00" {
                LoanSafetyCard(
                    loanRatioPercent: viewModel.loanRatioPercent,
                    safetyStatus: viewModel.safetyStatus,
                    maxSafeLTV: viewModel.maxSafeLTV
                )
            }
            
            // Section 5: Available to Borrow
            AvailableToBorrowCard(
                availableAmount: viewModel.availableToBorrow,
                onBorrowTap: {
                    onNavigateToTab?("loans")
                }
            )
            
            // Section 6: Quick Actions
            sectionHeader(title: "Quick Actions", icon: "bolt.fill")
            
            QuickActionsCard(
                onBorrowMore: {
                    onNavigateToTab?("loans")
                },
                onAddGold: {
                    onNavigateToTab?("wallet")
                },
                onRepayLoan: {
                    onNavigateToTab?("wallet")
                }
            )
            
            // Bottom spacing
            Color.clear.frame(height: 20)
        }
    }
    
    // MARK: - Section Header
    
    @ViewBuilder
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(themeManager.perfolioTheme.tintColor)
            
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(themeManager.perfolioTheme.tintColor)
            
            Text("Loading your loan safety dashboard...")
                .font(.system(size: 16))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Error View
    
    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(themeManager.perfolioTheme.danger)
                .symbolRenderingMode(.hierarchical)
            
            Text("Unable to Load Dashboard")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            PerFolioButton("Retry") {
                Task {
                    await viewModel.loadData()
                }
            }
            .padding(.horizontal, 60)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

#Preview {
    StandardDashboardView()
        .environmentObject(ThemeManager())
}

