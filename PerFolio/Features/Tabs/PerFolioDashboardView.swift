import SwiftUI
import SwiftData

struct PerFolioDashboardView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var onboardingViewModel = OnboardingViewModel()
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var showCopiedToast = false
    @State private var showSettings = false
    @State private var showNotifications = false
    @State private var selectedTab: String = "dashboard"
    var onLogout: (() -> Void)?
    var onNavigateToTab: ((String) -> Void)?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Show onboarding timeline for ALL users at the top (collapsed by default)
                    onboardingSection
                    
                    // Dashboard type toggle
                    dashboardTypeToggle
                    
                    // Conditional dashboard display
                    switch viewModel.selectedDashboardType {
                    case .regular:
                        regularDashboardContent
                    case .standard:
                        StandardDashboardView(onNavigateToTab: onNavigateToTab)
                    case .simplified:
                        momDashboardContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(themeManager.perfolioTheme.primaryBackground.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.shared.light()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("PerFolio")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.shared.light()
                        showNotifications = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(themeManager.perfolioTheme.tintColor)
                            
                            if notificationManager.unreadCount > 0 {
                                ZStack {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 16, height: 16)
                                    
                                    Text("\(min(notificationManager.unreadCount, 9))")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .offset(x: 8, y: -8)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(onLogout: onLogout)
            }
            .sheet(isPresented: $showNotifications) {
                NotificationCenterView(onNavigateToTab: onNavigateToTab)
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
            
            // Set up onboarding timeline
            onboardingViewModel.setup(modelContext: modelContext, dashboardViewModel: viewModel)
        }
        .onReceive(NotificationCenter.default.publisher(for: .currencyDidChange)) { notification in
            // Force UI refresh when currency changes
            // The computed properties will automatically use the new currency
            if let newCurrency = notification.userInfo?["newCurrency"] as? String {
                AppLogger.log("💱 Dashboard detected currency change to: \(newCurrency)", category: "dashboard")
                
                // Trigger a refresh of CurrencyService rates
                Task {
                    do {
                        try await CurrencyService.shared.fetchLiveExchangeRates()
                        AppLogger.log("✅ Dashboard refreshed currency rates", category: "dashboard")
                    } catch {
                        AppLogger.log("⚠️ Dashboard rate refresh failed: \(error.localizedDescription)", category: "dashboard")
                    }
                }
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
    
    // MARK: - Onboarding Section
    
    private var onboardingSection: some View {
        OnboardingTimelineView(
            onboardingViewModel: onboardingViewModel,
            onNavigate: { tab in
                handleOnboardingNavigation(tab)
            }
        )
        .environmentObject(themeManager)
    }
    
    private var regularDashboardContent: some View {
        VStack(spacing: 24) {
            goldenHeroCard
            walletConnectionCard
            yourGoldHoldingsCard
            statisticsSection
            paxgPriceChartSection
        }
    }
    
    private func handleOnboardingNavigation(_ destination: String) {
        AppLogger.log("📍 Dashboard navigating to: \(destination)", category: "dashboard")
        onNavigateToTab?(destination)
    }
    
    // MARK: - Golden Hero Card (Portfolio Overview)
    
    private var goldenHeroCard: some View {
        PerFolioCard(style: .gradient) {
            VStack(alignment: .leading, spacing: 16) {
                // Title
                Text("Your Portfolio")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                
                if case .loading = viewModel.loadingState {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Loading...")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        // Main Section: Gold (PAXG) Value
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.yellow)
                                Text("Gold (PAXG)")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            
                            Text(viewModel.goldPortfolioValue)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        
                        // Divider
                        Rectangle()
                            .fill(.white.opacity(0.2))
                            .frame(height: 1)
                            .padding(.vertical, 4)
                        
                        // Secondary Section: Total Portfolio (PAXG + USDC)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "chart.pie.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                                Text("Total Portfolio")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                Text("(PAXG + USDC)")
                                    .font(.system(size: 11, weight: .regular, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            
                            Text(viewModel.totalPortfolioValueInUserCurrency)
                                .font(.system(size: 24, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .id(UserPreferences.defaultCurrency)  // Force refresh when currency changes
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
                            HapticManager.shared.light()
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
                            HapticManager.shared.medium()
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
                
                // Balance rows (now shows in user's default currency)
                PerFolioBalanceRow(
                    tokenSymbol: "PAXG",
                    tokenAmount: viewModel.paxgFormattedBalance,
                    usdValue: viewModel.paxgValueInUserCurrency
                )
                
                PerFolioBalanceRow(
                    tokenSymbol: "USDC",
                    tokenAmount: viewModel.usdcFormattedBalance,
                    usdValue: viewModel.usdcValueInUserCurrency
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
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            PerFolioSectionHeader(
                icon: "chart.bar.fill",
                title: "Your Statistics"
            )
            
            // Statistics Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statisticCard(
                    icon: "chart.bar.fill",
                    title: "TOTAL\nCOLLATERAL",
                    value: viewModel.totalCollateral,
                    subtitle: viewModel.totalCollateralUSD
                )
                
                statisticCard(
                    icon: "arrow.up.circle.fill",
                    title: "TOTAL\nBORROWED",
                    value: viewModel.totalBorrowed,
                    subtitle: viewModel.totalBorrowedUSD
                )
                
                statisticCard(
                    icon: "shield.checkered.fill",
                    title: "WEIGHTED\nHEALTH FACTOR",
                    value: viewModel.healthFactor,
                    subtitle: viewModel.healthStatus,
                    healthColor: viewModel.healthStatusColor
                )
                
                statisticCard(
                    icon: "percent",
                    title: "CURRENT\nBORROW APY",
                    value: viewModel.borrowAPY,
                    subtitle: "Max LTV: \(viewModel.maxLTV)"
                )
            }
            
            // Vault Configuration
            PerFolioCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("VAULT CONFIGURATION")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    
                    VStack(spacing: 20) {
                        HStack(alignment: .top) {
                            vaultInfoItem(title: "Liquidation Threshold", value: viewModel.liquidationThreshold)
                            Spacer()
                            vaultInfoItem(title: "Liquidation Penalty", value: viewModel.liquidationPenalty)
                        }
                        
                        HStack(alignment: .top) {
                            vaultInfoItem(title: "PAXG Current Price", value: viewModel.paxgCurrentPrice)
                            Spacer()
                            vaultInfoItem(title: "Active Positions", value: viewModel.activePositions)
                        }
                    }
                }
            }
        }
    }
    
    private func statisticCard(icon: String, title: String, value: String, subtitle: String, healthColor: Color? = nil) -> some View {
        PerFolioCard(style: .secondary) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    
                    Text(title)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(healthColor ?? themeManager.perfolioTheme.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func vaultInfoItem(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            }
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - PAXG Price Chart Section
    
    private var paxgPriceChartSection: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    
                    Text("PAXG Price (90 Days)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                }
                
                // Current Price
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(viewModel.paxgCurrentPriceFormatted)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    
                    Text(viewModel.paxgPriceChange)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(viewModel.priceChangeColor)
                }
                
                // Chart
                if !viewModel.priceHistory.isEmpty {
                    PAXGPriceChartView(data: viewModel.priceHistory)
                        .frame(height: 200)
                } else {
                    HStack {
                        Spacer()
                        ProgressView()
                        Text("Loading price data...")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        Spacer()
                    }
                    .frame(height: 200)
                }
            }
        }
    }
    
    // MARK: - Dashboard Type Toggle
    
    private var dashboardTypeToggle: some View {
        HStack {
            Spacer()
            
            Picker("Dashboard Type", selection: $viewModel.selectedDashboardType) {
                ForEach(DashboardType.allCases, id: \.self) { type in
                    Text(type.displayName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 280) // Increased to fit 3 options
            .onChange(of: viewModel.selectedDashboardType) { _, newValue in
                HapticManager.shared.light()
                UserPreferences.preferredDashboard = newValue
                AppLogger.log("📱 Dashboard type changed to: \(newValue.displayName)", category: "dashboard")
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Mom Dashboard Content
    
    private var momDashboardContent: some View {
        MomDashboardView(
            dashboardViewModel: viewModel,
            onNavigateToDeposit: {
                // Navigate to Wallet tab (Deposit section)
                onNavigateToTab?("wallet")
            }
        )
        .environmentObject(themeManager)
    }
}

#Preview {
    PerFolioDashboardView()
        .environmentObject(ThemeManager())
}
