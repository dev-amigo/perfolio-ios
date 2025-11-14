import SwiftUI

struct DepositBuyView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = DepositBuyViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                // OnMeta INR → USDT
                if viewModel.viewState == .quote {
                    quoteCard
                } else {
                    buyWithINRCard
                }
                
                // DEX Swap USDT → PAXG
                goldPurchaseCard
                
                howItWorksCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(themeManager.perfolioTheme.primaryBackground.ignoresSafeArea())
        .sheet(isPresented: $viewModel.showingSafariView) {
            if let url = viewModel.safariURL {
                SafariView(url: url) {
                    viewModel.handleSafariDismiss()
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Deposit & Buy")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            
            Text("Fund your account and purchase gold")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Buy Crypto with INR
    
    private var buyWithINRCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 20) {
                PerFolioSectionHeader(
                    icon: "indianrupeesign.circle.fill",
                    title: "Buy Crypto with INR",
                    subtitle: "Use UPI, bank transfer, or card to purchase USDT"
                )
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                // Currency selectors (locked)
                lockedSelector(icon: "indianrupeesign", label: "Fiat Currency", value: "INR")
                lockedSelector(icon: "dollarsign.circle.fill", label: "Crypto", value: "USDT")
                
                // Amount input with presets
                PerFolioInputField(
                    label: "Amount",
                    text: $viewModel.inrAmount,
                    leadingIcon: "indianrupeesign",
                    presetValues: ["₹500", "₹1000", "₹5000", "₹10000"]
                )
                
                // Payment method selector
                paymentMethodSelector
                
                // Get Quote button
                PerFolioButton("GET QUOTE", isDisabled: viewModel.viewState == .processing) {
                    Task {
                        await viewModel.getQuote()
                    }
                }
                
                // Info banner
                PerFolioInfoBanner("Min: ₹500 • Max: ₹100,000")
            }
        }
    }
    
    private var quoteCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OnMeta Quote")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        Text("Review and proceed to payment")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        viewModel.resetOnMetaFlow()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                }
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                if let quote = viewModel.currentQuote {
                    VStack(spacing: 12) {
                        quoteRow(label: "You Pay", value: quote.displayInrAmount, isHighlight: true)
                        quoteRow(label: "Provider Fee", value: quote.displayFee)
                        quoteRow(label: "Exchange Rate", value: quote.displayRate)
                        quoteRow(label: "You Receive", value: quote.displayUsdtAmount, isHighlight: true)
                        
                        Divider()
                            .background(themeManager.perfolioTheme.border)
                        
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(themeManager.perfolioTheme.tintColor)
                            Text("Estimated Time: \(quote.estimatedTime)")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        }
                    }
                    
                    PerFolioButton("PROCEED TO PAYMENT") {
                        viewModel.proceedToPayment()
                    }
                    
                    PerFolioInfoBanner("You'll be redirected to OnMeta's secure payment page")
                }
            }
        }
    }
    
    private func lockedSelector(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                Text(value)
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
    }
    
    private var paymentMethodSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Payment Method")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            
            HStack(spacing: 8) {
                ForEach(PaymentMethod.allCases, id: \.self) { method in
                    PerFolioPresetButton(
                        method.rawValue,
                        isSelected: viewModel.selectedPaymentMethod == method
                    ) {
                        viewModel.selectedPaymentMethod = method
                    }
                }
            }
        }
    }
    
    private func quoteRow(label: String, value: String, isHighlight: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: isHighlight ? .bold : .semibold, design: .rounded))
                .foregroundStyle(isHighlight ? themeManager.perfolioTheme.tintColor : themeManager.perfolioTheme.textPrimary)
        }
    }
    
    // MARK: - Gold Purchase Module
    
    private var goldPurchaseCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 16) {
                PerFolioSectionHeader(
                    icon: "circle.grid.cross.fill",
                    title: "Buy Gold (PAXG)",
                    subtitle: "Convert your USDT to tokenized gold"
                )
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                // Balances row
                HStack(spacing: 16) {
                    balanceItem(symbol: "USDT", balance: viewModel.formattedUSDTBalance)
                    balanceItem(symbol: "PAXG", balance: viewModel.formattedPAXGBalance)
                }
                
                // Gold price display
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Gold Price")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        Text(viewModel.formattedGoldPrice + " / oz")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    }
                    Spacer()
                }
                .padding(12)
                .background(themeManager.perfolioTheme.primaryBackground.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // USDT amount input
                VStack(alignment: .leading, spacing: 8) {
                    Text("USDT Amount")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    
                    TextField("0.00", text: $viewModel.usdtAmount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        .padding(14)
                        .background(themeManager.perfolioTheme.primaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    
                    // Quick presets
                    HStack(spacing: 8) {
                        ForEach(["25%", "50%", "75%", "Max"], id: \.self) { preset in
                            PerFolioPresetButton(preset, isSelected: false) {
                                setUSDTPreset(preset)
                            }
                        }
                    }
                }
                
                // Estimated PAXG output
                if !viewModel.usdtAmount.isEmpty, viewModel.goldPrice > 0 {
                    HStack {
                        Text("You will receive")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        Spacer()
                        Text("~\(viewModel.estimatedPAXGAmount) PAXG")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    }
                    .padding(12)
                    .background(themeManager.perfolioTheme.goldenBoxGradient.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                // Swap button with state
                swapButton
                
                // Info banner
                PerFolioInfoBanner(
                    "Gold purchases are instant and backed 1:1 by physical gold"
                )
            }
        }
    }
    
    private func balanceItem(symbol: String, balance: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(symbol)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            Text(balance)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(themeManager.perfolioTheme.primaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private var swapButton: some View {
        Group {
            switch viewModel.swapState {
            case .idle:
                PerFolioButton("GET SWAP QUOTE") {
                    Task {
                        await viewModel.getSwapQuote()
                    }
                }
            case .needsApproval:
                PerFolioButton("APPROVE USDT") {
                    Task {
                        await viewModel.approveUSDT()
                    }
                }
            case .approving:
                PerFolioButton("APPROVING...", isDisabled: true) {
                    // No action
                }
            case .swapping:
                PerFolioButton("SWAPPING...", isDisabled: true) {
                    // No action
                }
            case .success(let txHash):
                VStack(spacing: 12) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(themeManager.perfolioTheme.success)
                        Text("Swap Successful!")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.success)
                    }
                    
                    Button {
                        if let url = URL(string: "https://etherscan.io/tx/\(txHash)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Text("View on Etherscan")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                            Image(systemName: "arrow.up.right.square")
                        }
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    }
                    
                    PerFolioButton("SWAP MORE") {
                        viewModel.resetSwapFlow()
                    }
                }
            case .error(let message):
                VStack(spacing: 12) {
                    Text(message)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.danger)
                    
                    PerFolioButton("TRY AGAIN") {
                        viewModel.resetSwapFlow()
                    }
                }
            }
        }
    }
    
    private func setUSDTPreset(_ preset: String) {
        guard viewModel.usdtBalance > 0 else { return }
        
        let amount: Decimal
        switch preset {
        case "25%":
            amount = viewModel.usdtBalance * 0.25
        case "50%":
            amount = viewModel.usdtBalance * 0.50
        case "75%":
            amount = viewModel.usdtBalance * 0.75
        case "Max":
            amount = viewModel.usdtBalance
        default:
            return
        }
        
        viewModel.usdtAmount = String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)
    }
    
    // MARK: - How It Works
    
    private var howItWorksCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("How It Works")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                
                VStack(alignment: .leading, spacing: 12) {
                    stepRow(number: "1", title: "Buy USDT", description: "Purchase USDT using INR via UPI or bank transfer")
                    stepRow(number: "2", title: "Swap for PAXG", description: "Convert USDT to tokenized gold (PAXG)")
                    stepRow(number: "3", title: "Use as Collateral", description: "Borrow against your gold holdings")
                }
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(themeManager.perfolioTheme.success)
                    Text("Powered by Privy & Ethereum")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                }
            }
        }
    }
    
    private func stepRow(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Circle().fill(themeManager.perfolioTheme.tintColor))
            
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
    DepositBuyView()
        .environmentObject(ThemeManager())
}
