import SwiftUI

struct PerFolioDashboardView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showCopiedToast = false
    @State private var showLogoutAlert = false
    var onLogout: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Golden card with 20px padding
                    goldenHeroCard
                        .padding(.horizontal, 20)
                    
                    // Other cards with standard padding
                    VStack(spacing: 24) {
                        walletConnectionCard
                        yourGoldHoldingsCard
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
            }
            .background(themeManager.perfolioTheme.primaryBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showLogoutAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Logout")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("PerFolio")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                }
            }
            .alert("Logout", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    handleLogout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            // Load wallet address from storage
            if let savedAddress = UserDefaults.standard.string(forKey: "userWalletAddress") {
                AppLogger.log("Loading saved wallet address: \(savedAddress)", category: "dashboard")
                viewModel.setWalletAddress(savedAddress)
            } else {
                AppLogger.log("⚠️ No wallet address found in storage. User may need to re-login.", category: "dashboard")
            }
        }
    }
    
    private func handleLogout() {
        // Clear stored data
        UserDefaults.standard.removeObject(forKey: "userWalletAddress")
        UserDefaults.standard.removeObject(forKey: "userWalletId")
        UserDefaults.standard.removeObject(forKey: "privyUserId")
        UserDefaults.standard.removeObject(forKey: "privyAccessToken")
        
        AppLogger.log("User logged out, cleared stored data", category: "auth")
        
        // Navigate back to landing
        onLogout?()
    }
    
    // MARK: - Golden Hero Card
    
    private var goldenHeroCard: some View {
        PerFolioCard(style: .gradient, padding: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Gold Portfolio")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                if case .loading = viewModel.loadingState {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading...")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                } else {
                    Text(viewModel.totalPortfolioValue)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
        }
    }
    
    // MARK: - Wallet Connection Card
    
    private var walletConnectionCard: some View {
        PerFolioCard {
            VStack(spacing: 16) {
                HStack {
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    
                    Text("Wallet")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    
                    Spacer()
                    
                    // Connection status badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.walletBadgeColor)
                            .frame(width: 8, height: 8)
                        
                        Text(viewModel.walletBadgeText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(themeManager.perfolioTheme.primaryBackground)
                    )
                }
                
                if viewModel.isWalletConnected {
                    Divider()
                        .background(themeManager.perfolioTheme.border)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Deposit Address")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                            
                            Text(viewModel.truncatedAddress)
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        }
                        
                        Spacer()
                        
                        Button {
                            viewModel.copyAddressToClipboard()
                            withAnimation {
                                showCopiedToast = true
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    showCopiedToast = false
                                }
                            }
                        } label: {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(themeManager.perfolioTheme.tintColor)
                                .padding(10)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeManager.perfolioTheme.primaryBackground)
                                )
                        }
                    }
                }
            }
        }
    }
    
    private var copiedToast: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(themeManager.perfolioTheme.success)
            
            Text("Address copied!")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.perfolioTheme.secondaryBackground)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        )
        .padding(.top, 60)
    }
    
    // MARK: - Your Gold Holdings Card
    
    private var yourGoldHoldingsCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    PerFolioSectionHeader(
                        icon: "bitcoinsign.circle.fill",
                        title: "Your Gold Holdings"
                    )
                    
                    Spacer()
                    
                    if case .loading = viewModel.loadingState {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: themeManager.perfolioTheme.tintColor))
                            .scaleEffect(0.8)
                    } else if case .failed = viewModel.loadingState {
                        Button {
                            viewModel.refreshBalances()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        }
                    }
                }
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                // Balance rows
                PerFolioBalanceRow(
                    tokenSymbol: "PAXG",
                    tokenAmount: viewModel.paxgFormattedBalance,
                    usdValue: viewModel.paxgUSDValue
                )
                
                PerFolioBalanceRow(
                    tokenSymbol: "USDT",
                    tokenAmount: viewModel.usdtFormattedBalance,
                    usdValue: viewModel.usdtUSDValue
                )
                
                if case .failed(let error) = viewModel.loadingState {
                    PerFolioInfoBanner(
                        "Failed to load balances: \(error.localizedDescription)",
                        style: .danger
                    )
                }
            }
        }
    }
}

#Preview {
    PerFolioDashboardView()
        .environmentObject(ThemeManager())
}
