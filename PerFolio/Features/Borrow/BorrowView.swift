import SwiftUI

/// Main borrow screen - deposit PAXG collateral and borrow USDC
struct BorrowView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = BorrowViewModel()
    
    var body: some View {
        ZStack {
            // Background
            themeManager.perfolioTheme.primaryBackground
                .ignoresSafeArea()
            
            // Content based on state
            switch viewModel.viewState {
            case .loading:
                loadingView
            case .error(let message):
                errorView(message)
            case .ready:
                readyView
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .sheet(isPresented: $viewModel.showingTransactionModal) {
            TransactionProgressView(state: viewModel.transactionState) {
                viewModel.resetTransaction()
            }
        }
        .sheet(isPresented: $viewModel.showingAPYChart) {
            APYChartView()
        }
    }
    
    // MARK: - Loading State
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            headerSection
            
            // Skeleton cards
            ForEach(0..<3) { _ in
                PerFolioCard {
                    VStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.perfolioTheme.border.opacity(0.3))
                            .frame(height: 60)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(themeManager.perfolioTheme.border.opacity(0.2))
                            .frame(height: 40)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    // MARK: - Error State
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            headerSection
            
            PerFolioCard {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    
                    Text("Failed to Load")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    
                    Text(message)
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    PerFolioButton("RETRY") {
                        Task {
                            await viewModel.loadInitialData()
                        }
                    }
                }
                .padding(.vertical, 20)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    // MARK: - Ready State
    
    private var readyView: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                balanceSection
                collateralInputCard
                borrowAmountCard
                quickLTVButtons
                
                if let metrics = viewModel.metrics {
                    riskMetricsCard(metrics)
                }
                
                infoBanner
                
                if let metrics = viewModel.metrics, metrics.isHighLTV || metrics.isUnsafeHealth {
                    warningBanner(metrics)
                }
                
                if let error = viewModel.validationError {
                    errorBanner(error)
                }
                
                borrowButton
                footerText
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Borrow USDC")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                
                Spacer()
            }
            
            Text("Deposit PAXG as collateral and borrow USDC instantly")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
        }
    }
    
    // MARK: - Balance Section
    
    private var balanceSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(themeManager.perfolioTheme.tintColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Available Balance")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                
                Text("\(formatDecimal(viewModel.paxgBalance, maxDecimals: 6)) PAXG")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            }
            
            Spacer()
            
            Text("≈ \(formatUSD(viewModel.paxgBalance * viewModel.paxgPrice))")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.tintColor)
        }
        .padding(16)
        .background(themeManager.perfolioTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    // MARK: - Collateral Input Card
    
    private var collateralInputCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Collateral Amount")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        Text("PAXG you want to deposit")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        viewModel.setCollateralToMax()
                    } label: {
                        Text("MAX")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.primaryBackground)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.perfolioTheme.buttonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                }
                
                HStack(spacing: 12) {
                    TextField("0.0", text: $viewModel.collateralAmount)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        .keyboardType(.decimalPad)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("PAXG")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        
                        if let collateral = Decimal(string: viewModel.collateralAmount), collateral > 0 {
                            Text("≈ \(formatUSD(collateral * viewModel.paxgPrice))")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        }
                    }
                }
                .padding(16)
                .background(themeManager.perfolioTheme.primaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
    
    // MARK: - Borrow Amount Card
    
    private var borrowAmountCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Borrow Amount")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        Text("USDC you want to borrow")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                    
                    Spacer()
                }
                
                HStack(spacing: 12) {
                    TextField("0.0", text: $viewModel.borrowAmount)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        .keyboardType(.decimalPad)
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("USDC")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        
                        if let metrics = viewModel.metrics {
                            Text("Max: \(formatUSD(metrics.maxBorrowableUSD))")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        }
                    }
                }
                .padding(16)
                .background(themeManager.perfolioTheme.primaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
    
    // MARK: - Quick LTV Buttons
    
    private var quickLTVButtons: some View {
        HStack(spacing: 12) {
            quickLTVButton(percentage: 25)
            quickLTVButton(percentage: 50)
            quickLTVButton(percentage: 70)
        }
    }
    
    private func quickLTVButton(percentage: Int) -> some View {
        Button {
            viewModel.setQuickLTV(Decimal(percentage))
        } label: {
            Text("\(percentage)% LTV")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(themeManager.perfolioTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    
    // MARK: - Risk Metrics Card
    
    private func riskMetricsCard(_ metrics: BorrowMetrics) -> some View {
        PerFolioCard {
            VStack(spacing: 16) {
                HStack {
                    Text("Risk Metrics")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    metricRow(
                        icon: "chart.bar.fill",
                        label: "Loan-to-Value",
                        value: "\(formatPercentage(metrics.currentLTV))",
                        status: metrics.ltvStatus,
                        color: ltvColor(metrics.currentLTV)
                    )
                    
                    metricRow(
                        icon: "heart.fill",
                        label: "Health Factor",
                        value: metrics.formattedHealthFactor,
                        status: metrics.healthStatus,
                        color: healthColor(metrics.healthFactor)
                    )
                    
                    metricRow(
                        icon: "exclamationmark.triangle.fill",
                        label: "Liquidation Price",
                        value: formatUSD(metrics.liquidationPrice),
                        status: "PAXG price alert",
                        color: themeManager.perfolioTheme.textSecondary
                    )
                    
                    Button {
                        viewModel.showAPYChart()
                    } label: {
                        HStack {
                            HStack(spacing: 10) {
                                Image(systemName: "percent")
                                    .font(.system(size: 16))
                                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Borrow APY")
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                                    Text("\(formatPercentage(viewModel.currentAPY))")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        }
                        .padding(12)
                        .background(themeManager.perfolioTheme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
    }
    
    private func metricRow(icon: String, label: String, value: String, status: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                Text(status)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(color)
            }
            
            Spacer()
            
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .padding(12)
        .background(themeManager.perfolioTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    // MARK: - Info Banner
    
    private var infoBanner: some View {
        PerFolioInfoBanner("One-step process: Approve PAXG → Deposit + Borrow. Your position is represented as an NFT.")
    }
    
    // MARK: - Warning Banner
    
    private func warningBanner(_ metrics: BorrowMetrics) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(metrics.isUnsafeHealth ? "⚠️ Low Health Factor" : "⚠️ High LTV")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                
                Text(metrics.isUnsafeHealth 
                     ? "Your position may be liquidated if PAXG price drops. Consider reducing borrow amount."
                     : "You're borrowing near the maximum limit. Reduce amount for safer position.")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.red)
            
            Text(message)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.red)
            
            Spacer()
        }
        .padding(16)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Borrow Button
    
    private var borrowButton: some View {
        PerFolioButton("BORROW USDC", isDisabled: viewModel.validationError != nil) {
            Task {
                await viewModel.executeBorrow()
            }
        }
    }
    
    // MARK: - Footer
    
    private var footerText: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 12))
                .foregroundStyle(themeManager.perfolioTheme.tintColor)
            Text("Powered by Fluid Protocol")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }
    
    // MARK: - Helpers
    
    private func formatDecimal(_ value: Decimal, maxDecimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxDecimals
        formatter.groupingSeparator = ","
        return formatter.string(from: value as NSDecimalNumber) ?? "0"
    }
    
    private func formatUSD(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
    
    private func formatPercentage(_ value: Decimal) -> String {
        return String(format: "%.1f%%", NSDecimalNumber(decimal: value).doubleValue)
    }
    
    private func ltvColor(_ ltv: Decimal) -> Color {
        if ltv < 50 {
            return .green
        } else if ltv < 70 {
            return .yellow
        } else {
            return .orange
        }
    }
    
    private func healthColor(_ hf: Decimal) -> Color {
        if hf.isInfinite || hf >= 2.0 {
            return .green
        } else if hf >= 1.5 {
            return .yellow
        } else if hf >= 1.0 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    BorrowView()
        .environmentObject(ThemeManager())
}

