import SwiftUI

struct PerFolioDashboardView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = DashboardViewModel()
    @State private var collateralAmount: String = ""
    @State private var borrowAmount: String = ""
    @State private var showCopiedToast = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                goldenHeroCard
                walletConnectionCard
                yourGoldHoldingsCard
                getInstantLoanCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(themeManager.perfolioTheme.primaryBackground.ignoresSafeArea())
        .overlay(alignment: .top) {
            if showCopiedToast {
                copiedToast
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .onAppear {
            // TODO: Get wallet address from user session/profile
            // For testing, you can set a demo address:
            // viewModel.setWalletAddress("0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
        }
    }
    
    // MARK: - Golden Hero Card
    
    private var goldenHeroCard: some View {
        PerFolioCard(style: .gradient, padding: 24) {
            VStack(alignment: .leading, spacing: 16) {
                portfolioHeader
                chartPlaceholder
                PerFolioButton("BUY GOLD") {
                    // Will be implemented in Phase 4
                }
            }
        }
    }
    
    private var portfolioHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Gold Portfolio")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if case .loading = viewModel.loadingState {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(viewModel.totalPortfolioValue)
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                
                // TODO: Calculate 24h change
                // Text("+0.0%")
                //     .font(.system(size: 16, weight: .semibold, design: .rounded))
                //     .foregroundStyle(themeManager.perfolioTheme.success)
            }
        }
    }
    
    private var chartPlaceholder: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let points: [CGFloat] = [0.6, 0.4, 0.5, 0.3, 0.4, 0.2, 0.3, 0.1]
                    
                    path.move(to: CGPoint(x: 0, y: height * points[0]))
                    for (index, point) in points.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(points.count - 1)
                        let y = height * point
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .frame(height: 80)
            
            Text("24H Price Movement")
                .font(.caption)
                .foregroundStyle(Color.white.opacity(0.7))
        }
        .padding(.vertical, 8)
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
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                // Action buttons
                HStack(spacing: 12) {
                    PerFolioButton("Deposit", style: .primary) {
                        // Will be implemented in Phase 4
                    }
                    
                    PerFolioButton("Buy", style: .secondary) {
                        // Will be implemented in Phase 4
                    }
                }
            }
        }
    }
    
    // MARK: - Get Instant Loan Card
    
    private var getInstantLoanCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 16) {
                PerFolioSectionHeader(
                    icon: "banknote.fill",
                    title: "Get Instant Loan",
                    subtitle: "Borrow USDT against your PAXG collateral"
                )
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                // Input fields
                PerFolioInputField(
                    label: "PAXG Collateral",
                    text: $collateralAmount,
                    trailingText: "PAXG",
                    presetValues: ["25%", "50%", "75%", "100%"]
                )
                
                PerFolioInputField(
                    label: "USDT to Borrow",
                    text: $borrowAmount,
                    trailingText: "USDT"
                )
                
                // Loan metrics
                VStack(spacing: 8) {
                    PerFolioMetricRow(label: "LTV", value: "0%")
                    PerFolioMetricRow(label: "Health Factor", value: "∞")
                }
                .padding(12)
                .background(themeManager.perfolioTheme.primaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // Borrow button
                PerFolioButton("BORROW USDT", style: .disabled, isDisabled: true) {
                    // Will be implemented in Phase 3
                }
            }
        }
    }
}

#Preview {
    PerFolioDashboardView()
        .environmentObject(ThemeManager())
}
