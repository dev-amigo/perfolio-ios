import SwiftUI

struct WithdrawView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                WithdrawSectionContent()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(themeManager.perfolioTheme.primaryBackground.ignoresSafeArea())
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Withdraw")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            
            Text("Cash out your crypto to your bank account")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // All other UI lives in WithdrawSectionContent
}

struct WithdrawSectionContent: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = WithdrawViewModel()
    @State private var showingTransakWidget = false
    @State private var transakURL: URL?
    @State private var errorMessage: String?
    @State private var showingError = false
    
    var body: some View {
        VStack(spacing: 24) {
            withdrawCard
            withdrawalInfoCard
        }
        .sheet(isPresented: $showingTransakWidget) {
            if let url = transakURL {
                SafariView(url: url) {
                    handleTransakDismiss()
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .alert("Balance Error", isPresented: .constant(isError)) {
            Button("Retry") {
                Task {
                    await viewModel.loadBalance()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            if case .error(let message) = viewModel.viewState {
                Text(message)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .currencyDidChange)) { notification in
            // Automatically refresh when currency changes in Settings
            if let newCurrency = notification.userInfo?["newCurrency"] as? String {
                AppLogger.log("💱 Withdraw View received currency change to: \(newCurrency)", category: "withdraw")
                Task {
                    await viewModel.fetchConversionRate()
                }
            }
        }
    }
    
    private var isError: Bool {
        if case .error = viewModel.viewState {
            return true
        }
        return false
    }
    
    private func handleTransakDismiss() {
        // Store amount before dismissing
        let withdrawAmount = viewModel.usdcAmount
        
        showingTransakWidget = false
        transakURL = nil
        
        // Refresh balance after widget closes
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)  // Wait 2 seconds
            let oldBalance = viewModel.usdcBalance
            await viewModel.loadBalance()
            
            // Check if balance decreased (withdrawal likely successful)
            if viewModel.usdcBalance < oldBalance {
                // Log withdrawal activity
                if let amount = Decimal(string: withdrawAmount) {
                    ActivityService.shared.logWithdraw(
                        amount: amount,
                        currency: "USDC"
                    )
                    AppLogger.log("✅ Withdrawal logged to activity", category: "withdraw")
                }
            }
        }
    }
    
    private func startWithdrawal() {
        // Validate first
        let validation = viewModel.validateAndProceed()
        guard validation.isValid else {
            errorMessage = validation.errorMessage
            showingError = true
            return
        }
        
        // Build Transak URL
        do {
            transakURL = try viewModel.buildTransakURL()
            showingTransakWidget = true
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private var withdrawCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 20) {
                PerFolioSectionHeader(
                    icon: "arrow.up.circle.fill",
                    title: "Cash Out to Bank Account",
                    subtitle: "Convert USDC to \(viewModel.userCurrency) and transfer to your bank"
                )
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                availableBalanceSection
                
                PerFolioInputField(
                    label: "Withdraw Amount",
                    text: $viewModel.usdcAmount,
                    trailingText: "USDC",
                    presetValues: ["50%", "Max"],
                    onPresetTap: { preset in
                        viewModel.setPresetAmount(preset)
                    }
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Receive Currency")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    
                    HStack {
                        Text(viewModel.currencySymbol)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        Text(viewModel.userCurrency)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                    }
                    .padding(12)
                    .background(themeManager.perfolioTheme.primaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                estimateBreakdown
                
                // Validation message
                if !viewModel.usdcAmount.isEmpty {
                    let validation = viewModel.validateAndProceed()
                    if !validation.isValid, let error = validation.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(themeManager.perfolioTheme.warning)
                            Text(error)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.warning)
                        }
                        .padding(12)
                        .background(themeManager.perfolioTheme.warning.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                
                PerFolioButton(
                    "START WITHDRAWAL",
                    style: viewModel.isValidAmount ? .primary : .disabled,
                    isDisabled: !viewModel.isValidAmount
                ) {
                    startWithdrawal()
                }
            }
        }
    }
    
    private var availableBalanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Balance")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                
                if viewModel.viewState == .loading {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Loading...")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.formattedUSDCBalance)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        Text(viewModel.usdcBalanceInUserCurrency)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(themeManager.perfolioTheme.primaryBackground)
            )
        }
    }
    
    private var estimateBreakdown: some View {
        VStack(spacing: 8) {
            PerFolioMetricRow(label: "You'll receive", value: viewModel.estimatedReceiveAmount)
            PerFolioMetricRow(label: "Provider fee", value: "\(viewModel.providerFeeAmount) (~2.5%)")
        }
        .padding(12)
        .background(themeManager.perfolioTheme.primaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private var withdrawalInfoCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Withdrawal Information")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                
                VStack(alignment: .leading, spacing: 16) {
                    infoRow(
                        icon: "clock.fill",
                        title: "Processing Time",
                        description: "Bank transfers typically take 1-2 business days"
                    )
                    
                    Divider()
                        .background(themeManager.perfolioTheme.border)
                    
                    infoRow(
                        icon: "banknote.fill",
                        title: "Fees",
                        description: "Provider fees: 2-3% • Bank fees may apply"
                    )
                    
                    Divider()
                        .background(themeManager.perfolioTheme.border)
                    
                    infoRow(
                        icon: "checkmark.shield.fill",
                        title: "Security",
                        description: "All withdrawals are processed via secure payment partners"
                    )
                }
                
                PerFolioInfoBanner(
                    "You'll be redirected to our payment partner to complete the withdrawal"
                )
            }
        }
    }
    
    private func infoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(themeManager.perfolioTheme.tintColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WithdrawView()
        .environmentObject(ThemeManager())
}
