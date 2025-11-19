import SwiftUI

struct DepositBuyView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var viewModel = DepositBuyViewModel()
    @State private var isDepositExpanded = false
    @State private var isWithdrawExpanded = false
    @State private var isSwapExpanded = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                // Expandable Section 1: Deposit (Fiat → PAXG)
                ExpandableSection(
                    icon: "arrow.down.circle.fill",
                    title: "Deposit",
                    subtitle: "Buy gold with fiat currency",
                    isExpanded: $isDepositExpanded
                ) {
                    depositContent
                }
                
                // Expandable Section 2: Withdraw (PAXG → Fiat)
                ExpandableSection(
                    icon: "arrow.up.circle.fill",
                    title: "Withdraw",
                    subtitle: "Cash out to your bank account",
                    isExpanded: $isWithdrawExpanded
                ) {
                    withdrawPlaceholder
                }
                
                // Expandable Section 3: Swap (USDT → PAXG)
                ExpandableSection(
                    icon: "arrow.2.squarepath",
                    title: "Swap",
                    subtitle: "Convert USDT to PAXG",
                    isExpanded: $isSwapExpanded
                ) {
                    swapContent
                }
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
            Text("Wallet")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            
            Text("Manage your gold and funds")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Section Content
    
    private var depositContent: some View {
        VStack(spacing: 16) {
            // Simple Fiat → USDT flow
            if viewModel.viewState == .quote, let quote = viewModel.currentQuote {
                simpleUSDTQuoteCard(quote)
            } else {
                buyFiatToUSDTCard
            }
            
            // How It Works
            howItWorksCard
        }
    }
    
    private var swapContent: some View {
        VStack(spacing: 16) {
            // USDT → PAXG swap (for existing USDT holders)
            goldPurchaseCard
        }
    }
    
    // MARK: - Withdraw Placeholder
    
    private var withdrawPlaceholder: some View {
        PerFolioCard {
            VStack(spacing: 16) {
                Image(systemName: "banknote.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(themeManager.perfolioTheme.tintColor.opacity(0.5))
                
                Text("Withdrawal Feature")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                
                Text("Cash out your PAXG to your bank account or UPI. Coming soon in Milestone 5.")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                VStack(alignment: .leading, spacing: 12) {
                    featureItem(icon: "globe", text: "Support for 10+ currencies")
                    featureItem(icon: "building.columns", text: "Bank transfer & UPI support")
                    featureItem(icon: "checkmark.shield", text: "Secure & compliant via Transak")
                }
            }
            .padding(8)
        }
    }
    
    private func featureItem(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(themeManager.perfolioTheme.tintColor)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            Spacer()
        }
    }
    
    // MARK: - Currency Helper
    
    private func currencyIcon(for currency: FiatCurrency) -> String {
        switch currency {
        case .inr: return "indianrupeesign"
        case .usd, .aud, .cad, .sgd: return "dollarsign"
        case .eur: return "eurosign"
        case .gbp: return "sterlingsign"
        case .jpy: return "yensign"
        case .chf: return "francsign"
        case .aed: return "bitcoinsign"  // Using as placeholder for dirham
        }
    }
    
    // MARK: - Buy Gold with Fiat (Unified Flow)
    
    private var buyFiatToUSDTCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 20) {
                PerFolioSectionHeader(
                    icon: "\(currencyIcon(for: viewModel.selectedFiatCurrency)).circle.fill",
                    title: "Deposit with \(viewModel.selectedFiatCurrency.rawValue)",
                    subtitle: "Buy USDT with your local currency"
                )
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                // Currency selector (now dynamic!)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fiat Currency")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    
                    CurrencyPicker(selectedCurrency: $viewModel.selectedFiatCurrency)
                }
                
                // Amount input with dynamic presets
                PerFolioInputField(
                    label: "Amount",
                    text: $viewModel.inrAmount,
                    leadingIcon: currencyIcon(for: viewModel.selectedFiatCurrency),
                    presetValues: viewModel.selectedFiatCurrency.presetValues
                )
                
                // Payment method selector
                paymentMethodSelector
                
                // Get Quote button
                PerFolioButton(
                    viewModel.viewState == .processing ? "CALCULATING..." : "GET QUOTE",
                    isDisabled: viewModel.viewState == .processing
                ) {
                    Task {
                        await viewModel.getQuote()
                    }
                }
                
                // Info banner with dynamic limits and provider
                VStack(spacing: 8) {
                    PerFolioInfoBanner(
                        "Min: \(viewModel.selectedFiatCurrency.format(viewModel.selectedFiatCurrency.minDepositAmount)) • " +
                        "Max: \(viewModel.selectedFiatCurrency.format(viewModel.selectedFiatCurrency.maxDepositAmount))"
                    )
                    
                    // Powered by branding
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        Text("Powered by \(viewModel.selectedFiatCurrency.preferredProvider.name)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }
    
    // MARK: - Simple USDT Quote Card (Fiat → USDT)
    
    private func simpleUSDTQuoteCard(_ quote: OnMetaService.Quote) -> some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Deposit Quote")
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
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                            .font(.system(size: 24))
                    }
                }
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                // You'll receive - Big USDT number
                VStack(spacing: 8) {
                    Text("You'll Receive")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(CurrencyFormatter.formatDecimal(quote.usdtAmount))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        Text("USDT")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("≈ \(quote.displayInrAmount)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(themeManager.perfolioTheme.buttonBackground.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                // Quote details
                VStack(spacing: 12) {
                    simpleQuoteRow(label: "Exchange Rate", value: quote.displayRate, icon: "chart.line.uptrend.xyaxis")
                    simpleQuoteRow(label: "Provider Fee", value: quote.displayFee, icon: "creditcard")
                    simpleQuoteRow(label: "You Pay", value: quote.displayInrAmount, icon: "dollarsign.circle.fill")
                }
                
                // Estimated time
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    Text("Estimated Time: \(quote.estimatedTime)")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                }
                .padding(12)
                .background(themeManager.perfolioTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                // Proceed button
                PerFolioButton("PROCEED TO PAYMENT") {
                    viewModel.proceedToPayment()
                }
                
                // Info banner
                PerFolioInfoBanner("You'll be redirected to \(viewModel.selectedFiatCurrency.preferredProvider.name)'s secure payment page")
                
                // Branding
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    Text("Powered by \(viewModel.selectedFiatCurrency.preferredProvider.name)")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
    
    private func simpleQuoteRow(label: String, value: String, icon: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            }
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
        }
    }
    
    // MARK: - Unified Quote Card (DEPRECATED - Saved for Phase 4)
    
    private func unifiedQuoteCard(_ quote: UnifiedDepositQuote) -> some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 20) {
                // Header with close button
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Gold Purchase Quote")
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
                
                // Main conversion display
                HStack(alignment: .center, spacing: 16) {
                    // You Pay
                    VStack(alignment: .leading, spacing: 4) {
                        Text("You Pay")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        Text(quote.displayFiatAmount)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    }
                    
                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    
                    // You Receive (PAXG - highlighted)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("You Receive")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        Text(quote.displayPaxgAmount)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    }
                }
                .padding(16)
                .background(
                    themeManager.perfolioTheme.goldenBoxGradient.opacity(0.1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // Quote details
                VStack(spacing: 12) {
                    quoteDetailRow(
                        label: "Effective Rate",
                        value: quote.displayEffectiveRate,
                        icon: "chart.line.uptrend.xyaxis"
                    )
                    quoteDetailRow(
                        label: "Total Fees",
                        value: "\(quote.displayTotalFees) (\(quote.displayFeePercentage))",
                        icon: "dollarsign.circle"
                    )
                    quoteDetailRow(
                        label: "Estimated Time",
                        value: quote.estimatedTime,
                        icon: "clock"
                    )
                }
                
                // Breakdown (collapsible)
                DisclosureGroup("View Breakdown") {
                    VStack(spacing: 12) {
                        ForEach(quote.breakdown, id: \.number) { step in
                            breakdownStepRow(step: step)
                        }
                    }
                    .padding(.top, 12)
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                .tint(themeManager.perfolioTheme.tintColor)
                
                // Warnings (if any)
                if !quote.warnings.isEmpty {
                    ForEach(quote.warnings, id: \.self) { warning in
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(themeManager.perfolioTheme.warning)
                            Text(warning)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.warning)
                        }
                        .padding(12)
                        .background(themeManager.perfolioTheme.warning.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                
                // Proceed button
                PerFolioButton("PROCEED TO PAYMENT") {
                    viewModel.proceedToPayment()
                }
                
                // Info banner
                PerFolioInfoBanner("You'll be redirected to \(quote.fiatCurrency.preferredProvider.name)'s secure payment page")
            }
        }
    }
    
    private func quoteDetailRow(label: String, value: String, icon: String) -> some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            }
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
        }
    }
    
    private func breakdownStepRow(step: UnifiedDepositQuote.BreakdownStep) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Step number
                Text(step.number)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(themeManager.perfolioTheme.tintColor))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    Text(step.description)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                }
                
                Spacer()
            }
            
            HStack {
                Text("Fee: \(step.fee)")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                Spacer()
                Text(step.provider)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
            }
            .padding(.leading, 32)
        }
    }
    
    // MARK: - Legacy Quote Card (for OnMeta only)
    
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
    
    // MARK: - Swap Module (USDT → PAXG)
    
    private var goldPurchaseCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 16) {
                PerFolioSectionHeader(
                    icon: "arrow.2.squarepath",
                    title: "Swap USDT to PAXG",
                    subtitle: "Convert your stablecoins to tokenized gold"
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
                
                // Info banner with provider branding
                VStack(spacing: 8) {
                    PerFolioInfoBanner(
                        "Swaps are instant and backed 1:1 by physical gold"
                    )
                    
                    // Powered by branding
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 12))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        Text("Powered by 1inch DEX")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
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
