import SwiftUI
import Combine
import SafariServices
import PrivySDK

@MainActor
final class DepositBuyViewModel: ObservableObject {
    
    // MARK: - Types
    
    enum ViewState: Equatable {
        case input
        case quote
        case processing
        case success
        case error(String)
        
        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.input, .input),
                 (.quote, .quote),
                 (.processing, .processing),
                 (.success, .success):
                return true
            case (.error(let lhsMsg), .error(let rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }
    }
    
    enum SwapState {
        case idle
        case needsApproval
        case approving
        case swapping
        case success(String) // transaction hash
        case error(String)
    }
    
    /// Quote converted to user's preferred currency for display
    struct QuoteInUserCurrency {
        let fiatAmount: Decimal          // Amount in user's currency
        let usdcAmount: Decimal          // USDC you'll receive
        let providerFee: Decimal         // Fee in user's currency
        let exchangeRate: Decimal        // 1 USDC = X user currency
        let currencyCode: String         // e.g., "EUR", "USD"
        let currencySymbol: String       // e.g., "€", "$"
        let estimatedTime: String
        
        var displayAmount: String {
            currencySymbol + CurrencyFormatter.formatDecimal(fiatAmount)
        }
        
        var displayUsdcAmount: String {
            CurrencyFormatter.formatDecimal(usdcAmount)
        }
        
        var displayFee: String {
            currencySymbol + CurrencyFormatter.formatDecimal(providerFee)
        }
        
        var displayRate: String {
            "1 USDC = \(currencySymbol)\(CurrencyFormatter.formatDecimal(exchangeRate))"
        }
    }
    
    // MARK: - Published Properties
    
    // Currency & Amount
    @Published var selectedFiatCurrency: FiatCurrency = .default
    @Published var inrAmount: String = ""  // Renamed to fiatAmount in future
    @Published var selectedPaymentMethod: PaymentMethod = .upi
    @Published var viewState: ViewState = .input
    @Published var currentQuote: OnMetaService.Quote?
    @Published var unifiedQuote: UnifiedDepositQuote?  // NEW: Unified Fiat → PAXG quote
    
    // Quote display in user's currency
    @Published var quoteInUserCurrency: QuoteInUserCurrency?
    
    // Swap-related
    @Published var usdcAmount: String = ""
    @Published var swapState: SwapState = .idle
    @Published var swapQuote: DEXSwapService.SwapQuote?
    @Published var slippageTolerance: Decimal = 0.5 // 0.5%
    @Published var goldPrice: Decimal = 0
    @Published var usdcBalance: Decimal = 0
    @Published var paxgBalance: Decimal = 0
    
    // Safari view
    @Published var showingSafariView = false
    @Published var safariURL: URL?
    
    // Alerts
    @Published var showingError = false
    @Published var errorMessage = ""
    
    // Currency Conversion
    @Published var userCurrency: String = UserPreferences.defaultCurrency
    @Published var usdcValueInUserCurrency: Decimal = 0
    @Published var paxgValueInUserCurrency: Decimal = 0
    @Published var estimatedPAXGInUserCurrency: Decimal = 0
    
    // MARK: - Private Properties
    
    private let onMetaService: OnMetaService
    private let dexSwapService: DEXSwapService
    private let erc20Contract: ERC20Contract
    private let currencyService = CurrencyService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var walletAddress: String? {
        UserDefaults.standard.string(forKey: "userWalletAddress")
    }
    
    // MARK: - Initialization
    
    nonisolated init(
        onMetaService: OnMetaService? = nil,
        dexSwapService: DEXSwapService? = nil,
        erc20Contract: ERC20Contract = ERC20Contract()
    ) {
        self.onMetaService = onMetaService ?? OnMetaService()
        self.erc20Contract = erc20Contract
        self.dexSwapService = dexSwapService ?? DEXSwapService()
        
        // Load initial balances on main actor
        Task { @MainActor in
            AppLogger.log("💰 DepositBuyViewModel initialized", category: "depositbuy")
            await self.loadBalances()
            await self.fetchGoldPrice()
            self.setupObservers()
        }
    }
    
    // MARK: - Observers
    
    private func setupObservers() {
        // Listen for currency changes from Settings
        NotificationCenter.default.publisher(for: .currencyDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                if let newCurrency = notification.userInfo?["newCurrency"] as? String {
                    AppLogger.log("💱 Wallet detected currency change to: \(newCurrency)", category: "depositbuy")
                    self.userCurrency = newCurrency
                    
                    // Update deposit currency if supported
                    if let fiatCurrency = FiatCurrency.from(code: newCurrency) {
                        self.selectedFiatCurrency = fiatCurrency
                        AppLogger.log("✅ Deposit currency updated to: \(fiatCurrency.displayName)", category: "depositbuy")
                    }
                    
                    // CRITICAL: Force refresh rates from API, then update conversions
                    Task {
                        do {
                            try await self.currencyService.fetchLiveExchangeRates()
                            AppLogger.log("✅ Forced rate refresh for Wallet currency change", category: "depositbuy")
                        } catch {
                            AppLogger.log("⚠️ Rate refresh failed, using cached: \(error.localizedDescription)", category: "depositbuy")
                        }
                        
                        await self.updateCurrencyConversions()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Update estimated PAXG value when USDC amount changes
        $usdcAmount
            .combineLatest($goldPrice)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _, _ in
                guard let self = self else { return }
                Task {
                    await self.updateEstimatedPAXGValue()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Currency Conversion
    
    func updateCurrencyConversions() async {
        do {
            let conversionRate = try await currencyService.getConversionRate(
                from: "USD",
                to: userCurrency
            )
            
            // Convert USDC balance
            usdcValueInUserCurrency = usdcBalance * conversionRate
            
            // Convert PAXG balance (PAXG price is in USD)
            paxgValueInUserCurrency = (paxgBalance * goldPrice) * conversionRate
            
            // Convert estimated PAXG from swap
            if let estimatedAmount = Decimal(string: estimatedPAXGAmount) {
                estimatedPAXGInUserCurrency = (estimatedAmount * goldPrice) * conversionRate
            }
            
            AppLogger.log("""
                💱 Currency conversions updated:
                - User Currency: \(userCurrency)
                - USDC: $\(usdcBalance) = \(formatCurrency(usdcValueInUserCurrency))
                - PAXG: \(paxgBalance) oz = \(formatCurrency(paxgValueInUserCurrency))
                """, category: "depositbuy")
            
        } catch {
            AppLogger.log("⚠️ Failed to update currency conversions: \(error.localizedDescription)", category: "depositbuy")
        }
    }
    
    func formatCurrency(_ amount: Decimal) -> String {
        guard let currency = Currency.getCurrency(code: userCurrency) else {
            return "\(amount)"
        }
        return currency.format(amount)
    }
    
    private func updateEstimatedPAXGValue() async {
        guard let amount = Decimal(string: usdcAmount), goldPrice > 0 else {
            estimatedPAXGInUserCurrency = 0
            return
        }
        
        do {
            let paxgAmount = amount / goldPrice
            let paxgValueUSD = paxgAmount * goldPrice
            
            let conversionRate = try await currencyService.getConversionRate(
                from: "USD",
                to: userCurrency
            )
            
            estimatedPAXGInUserCurrency = paxgValueUSD * conversionRate
        } catch {
            AppLogger.log("⚠️ Failed to update estimated PAXG value: \(error.localizedDescription)", category: "depositbuy")
        }
    }
    
    // MARK: - OnMeta (INR → USDC) Methods
    
    func getQuote() async {
        guard onMetaService.validateAmount(inrAmount) else {
            showError("Please enter a valid amount between ₹500 and ₹100,000")
            return
        }
        
        viewState = .processing
        
        do {
            let quote = try await onMetaService.getQuote(inrAmount: inrAmount)
            currentQuote = quote
            
            // Convert quote to user's currency for display
            await convertQuoteToUserCurrency(quote)
            
            viewState = .quote
            AppLogger.log("✅ Quote received: \(quote.displayUsdcAmount)", category: "depositbuy")
        } catch {
            viewState = .error(error.localizedDescription)
            showError(error.localizedDescription)
            AppLogger.log("❌ Quote failed: \(error.localizedDescription)", category: "depositbuy")
        }
    }
    
    /// Convert OnMeta quote (in INR) to user's selected currency
    private func convertQuoteToUserCurrency(_ quote: OnMetaService.Quote) async {
        // If user's currency is already INR, no conversion needed
        if userCurrency == "INR" {
            quoteInUserCurrency = QuoteInUserCurrency(
                fiatAmount: quote.inrAmount,
                usdcAmount: quote.usdcAmount,
                providerFee: quote.providerFee,
                exchangeRate: quote.exchangeRate,
                currencyCode: "INR",
                currencySymbol: "₹",
                estimatedTime: quote.estimatedTime
            )
            return
        }
        
        // Convert INR values to user's currency
        do {
            let conversionRate = try await currencyService.getConversionRate(from: "INR", to: userCurrency)
            
            let convertedAmount = quote.inrAmount * conversionRate
            let convertedFee = quote.providerFee * conversionRate
            let convertedRate = quote.exchangeRate * conversionRate
            
            guard let currency = currencyService.getCurrency(code: userCurrency) else {
                // Fallback to INR if currency not found
                quoteInUserCurrency = nil
                return
            }
            
            quoteInUserCurrency = QuoteInUserCurrency(
                fiatAmount: convertedAmount,
                usdcAmount: quote.usdcAmount,
                providerFee: convertedFee,
                exchangeRate: convertedRate,
                currencyCode: userCurrency,
                currencySymbol: currency.symbol,
                estimatedTime: quote.estimatedTime
            )
            
            AppLogger.log("""
                💱 Quote converted to \(userCurrency):
                - Amount: \(convertedAmount) \(userCurrency) (was ₹\(quote.inrAmount))
                - Rate: 1 USDC = \(convertedRate) \(userCurrency)
                - Conversion Rate: 1 INR = \(conversionRate) \(userCurrency)
                """, category: "depositbuy")
            
        } catch {
            AppLogger.log("⚠️ Failed to convert quote to \(userCurrency): \(error.localizedDescription)", category: "depositbuy")
            // Fallback: don't set quoteInUserCurrency, view will use original INR quote
            quoteInUserCurrency = nil
        }
    }
    
    // MARK: - Unified Deposit Quote (Fiat → PAXG)
    
    /// Get unified quote that chains Fiat → USDC → PAXG
        /// Shows user final PAXG amount they'll receive in one step
    func getUnifiedDepositQuote() async {
        // Validate amount using currency-aware validation
        guard let fiatAmount = selectedFiatCurrency.parse(inrAmount),
              selectedFiatCurrency.validate(fiatAmount) else {
            let errorMsg = selectedFiatCurrency.validationError(for: selectedFiatCurrency.parse(inrAmount) ?? 0)
            showError(errorMsg)
            return
        }
        
        viewState = .processing
        
        do {
            // Step 1: Get OnMeta quote (Fiat → USDC)
            AppLogger.log("🔗 Step 1/2: Getting OnMeta quote...", category: "depositbuy")
            let onMetaQuote = try await onMetaService.getQuote(inrAmount: inrAmount)
            AppLogger.log("✅ OnMeta: \(selectedFiatCurrency.format(fiatAmount)) → \(onMetaQuote.displayUsdcAmount)", category: "depositbuy")
            
            // Step 2: Get DEX quote (USDC → PAXG)
            AppLogger.log("🔗 Step 2/2: Getting DEX quote...", category: "depositbuy")
            let dexParams = DEXSwapService.SwapParams(
                fromToken: .usdc,
                toToken: .paxg,
                amount: onMetaQuote.usdcAmount,
                slippageTolerance: slippageTolerance,
                fromAddress: walletAddress ?? ""
            )
            let dexQuote = try await dexSwapService.getQuote(params: dexParams)
            AppLogger.log("✅ DEX: \(dexQuote.displayFromAmount) → \(dexQuote.displayToAmount)", category: "depositbuy")
            
            // Step 3: Combine into unified quote
            let unified = UnifiedDepositQuote.from(
                fiatCurrency: selectedFiatCurrency,
                fiatAmount: fiatAmount,
                onMetaQuote: onMetaQuote,
                dexQuote: dexQuote
            )
            
            unifiedQuote = unified
            currentQuote = onMetaQuote  // Keep for compatibility
            viewState = .quote
            
            AppLogger.log("🎉 Unified quote complete:", category: "depositbuy")
            AppLogger.log("   Input: \(unified.displayFiatAmount)", category: "depositbuy")
            AppLogger.log("   Output: \(unified.displayPaxgAmount)", category: "depositbuy")
            AppLogger.log("   Effective rate: \(unified.displayEffectiveRate)", category: "depositbuy")
            AppLogger.log("   Total fees: \(unified.displayTotalFees) (\(unified.displayFeePercentage))", category: "depositbuy")
            
        } catch {
            viewState = .error(error.localizedDescription)
            showError(error.localizedDescription)
            AppLogger.log("❌ Unified quote failed: \(error.localizedDescription)", category: "depositbuy")
        }
    }
    
    func proceedToPayment() {
        guard let walletAddress = walletAddress else {
            showError("Wallet address not available")
            return
        }
        
        do {
            let url = try onMetaService.buildWidgetURL(
                walletAddress: walletAddress,
                inrAmount: inrAmount
            )
            safariURL = url
            showingSafariView = true
            AppLogger.log("🌐 Opening OnMeta widget", category: "depositbuy")
        } catch {
            showError(error.localizedDescription)
            AppLogger.log("❌ Failed to build widget URL: \(error.localizedDescription)", category: "depositbuy")
        }
    }
    
    func handleSafariDismiss() {
        showingSafariView = false
        safariURL = nil
        
        // Refresh balances after potential deposit
        AppLogger.log("🔄 Safari dismissed, refreshing balances...", category: "depositbuy")
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // Wait 2s for transaction
            await loadBalances()
            
            // Check if USDC balance increased
            if usdcBalance > 0 {
                viewState = .success
                AppLogger.log("✅ USDC balance updated: \(usdcBalance)", category: "depositbuy")
                
                // Log deposit activity
                if let quote = currentQuote {
                    ActivityService.shared.logDeposit(
                        amount: quote.usdcAmount,
                        currency: "USDC"
                    )
                }
            }
        }
    }
    
    func resetOnMetaFlow() {
        inrAmount = ""
        currentQuote = nil
        viewState = .input
        onMetaService.reset()
    }
    
    // MARK: - DEX Swap (USDC → PAXG) Methods
    
    func getSwapQuote() async {
        guard let walletAddress = walletAddress else {
            showError("Wallet address not available")
            return
        }
        
        guard let amount = Decimal(string: usdcAmount), amount > 0 else {
            showError("Please enter a valid USDC amount")
            return
        }
        
        guard amount <= usdcBalance else {
            showError("Insufficient USDC balance")
            return
        }
        
        swapState = .idle
        
        do {
            let params = DEXSwapService.SwapParams(
                fromToken: .usdc,
                toToken: .paxg,
                amount: amount,
                slippageTolerance: slippageTolerance,
                fromAddress: walletAddress
            )
            
            let quote = try await dexSwapService.getQuote(params: params)
            swapQuote = quote
            
            // Check if approval is needed
            let approvalState = try await dexSwapService.checkApproval(
                tokenAddress: DEXSwapService.Token.usdc.address,
                ownerAddress: walletAddress,
                spenderAddress: ContractAddresses.zeroExExchangeProxy,
                amount: amount
            )
            
            if approvalState == .required {
                swapState = .needsApproval
            }
            
            AppLogger.log("✅ Swap quote: \(quote.displayFromAmount) → \(quote.displayToAmount)", category: "depositbuy")
        } catch {
            swapState = .error(error.localizedDescription)
            showError(error.localizedDescription)
            AppLogger.log("❌ Swap quote failed: \(error.localizedDescription)", category: "depositbuy")
        }
    }
    
    func approveUSDC() async {
        guard let walletAddress = walletAddress else {
            showError("Wallet address not available")
            return
        }
        
        guard let amount = Decimal(string: usdcAmount) else {
            showError("Invalid amount")
            return
        }
        
        swapState = .approving
        
        do {
            try await dexSwapService.approveToken(
                tokenAddress: DEXSwapService.Token.usdc.address,
                spenderAddress: ContractAddresses.zeroExExchangeProxy,
                amount: amount
            )
            AppLogger.log("✅ USDC approved for swap", category: "depositbuy")
            
            // Proceed to swap automatically
            await executeSwap()
        } catch {
            swapState = .error(error.localizedDescription)
            showError(error.localizedDescription)
            AppLogger.log("❌ Approval failed: \(error.localizedDescription)", category: "depositbuy")
        }
    }
    
    func executeSwap() async {
        guard let walletAddress = walletAddress else {
            showError("Wallet address not available")
            return
        }
        
        guard let amount = Decimal(string: usdcAmount) else {
            showError("Invalid amount")
            return
        }
        
        swapState = .swapping
        
        do {
            let params = DEXSwapService.SwapParams(
                fromToken: .usdc,
                toToken: .paxg,
                amount: amount,
                slippageTolerance: slippageTolerance,
                fromAddress: walletAddress
            )
            
            let txHash = try await dexSwapService.executeSwap(params: params)
            swapState = .success(txHash)
            
            AppLogger.log("✅ Swap executed: \(txHash)", category: "depositbuy")
            
            // Log swap activity
            if let quote = swapQuote {
                ActivityService.shared.logSwap(
                    fromAmount: quote.fromAmount,
                    fromToken: quote.fromToken.symbol,
                    toAmount: quote.toAmount,
                    toToken: quote.toToken.symbol,
                    txHash: txHash
                )
            }
            
            // Refresh balances
            try? await Task.sleep(nanoseconds: ServiceConstants.balanceRefreshDelay)
            await loadBalances()
        } catch {
            swapState = .error(error.localizedDescription)
            showError(error.localizedDescription)
            AppLogger.log("❌ Swap failed: \(error.localizedDescription)", category: "depositbuy")
        }
    }
    
    func resetSwapFlow() {
        usdcAmount = ""
        swapQuote = nil
        swapState = .idle
        dexSwapService.reset()
    }
    
    // MARK: - Balance & Price Methods
    
    func loadBalances() async {
        guard let walletAddress = walletAddress else { return }
        
        do {
            let balances = try await erc20Contract.balancesOf(
                tokens: [.usdc, .paxg],
                address: walletAddress
            )
            
            usdcBalance = balances.first(where: { $0.symbol == "USDC" })?.decimalBalance ?? 0
            paxgBalance = balances.first(where: { $0.symbol == "PAXG" })?.decimalBalance ?? 0
            
            AppLogger.log("💰 Balances: USDC=\(usdcBalance), PAXG=\(paxgBalance)", category: "depositbuy")
            
            // Update currency conversions after loading balances
            await updateCurrencyConversions()
        } catch {
            AppLogger.log("❌ Failed to load balances: \(error.localizedDescription)", category: "depositbuy")
        }
    }
    
    func fetchGoldPrice() async {
        // In production, fetch from CoinGecko or price oracle
        // For now, use a static price
        goldPrice = ServiceConstants.goldPriceUSD
        AppLogger.log("💰 Gold price: $\(goldPrice)", category: "depositbuy")
        
        // Update currency conversions after getting price
        await updateCurrencyConversions()
    }
    
    // MARK: - Helper Methods
    
    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
    
    func dismissError() {
        showingError = false
        errorMessage = ""
    }
    
    // MARK: - Computed Properties
    
    var formattedUSDCBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        return formatter.string(from: usdcBalance as NSNumber) ?? "0.00"
    }
    
    var formattedPAXGBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 8
        return formatter.string(from: paxgBalance as NSNumber) ?? "0.0000"
    }
    
    var formattedGoldPrice: String {
        CurrencyFormatter.formatUSD(goldPrice)
    }
    
    var estimatedPAXGAmount: String {
        guard let amount = Decimal(string: usdcAmount), goldPrice > 0 else {
            return "0.0000"
        }
        let paxgAmount = amount / goldPrice
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 4
        formatter.maximumFractionDigits = 8
        return formatter.string(from: paxgAmount as NSNumber) ?? "0.0000"
    }
}

// MARK: - Payment Method Enum

enum PaymentMethod: String, CaseIterable {
    case upi = "UPI"
    case bankTransfer = "Bank Transfer"
    case card = "Card"
}
