import SwiftUI
import Combine

@MainActor
final class WithdrawViewModel: ObservableObject {
    
    // MARK: - Types
    
    enum ViewState: Equatable {
        case loading
        case ready
        case error(String)
        
        static func == (lhs: ViewState, rhs: ViewState) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading),
                 (.ready, .ready):
                return true
            case (.error(let lhsMsg), .error(let rhsMsg)):
                return lhsMsg == rhsMsg
            default:
                return false
            }
        }
    }
    
    // MARK: - Published Properties
    
    @Published var usdcAmount: String = ""
    @Published var usdcBalance: Decimal = 0
    @Published var viewState: ViewState = .loading
    @Published var userCurrency: String = UserPreferences.defaultCurrency
    @Published var conversionRate: Decimal = 83.00  // Live rate from API
    
    // Fee configuration
    private let providerFeePercentage: Decimal = 0.025  // 2.5%
    
    // MARK: - Private Properties
    
    private let erc20Contract: ERC20Contract
    private let transakService: TransakService
    private let currencyService = CurrencyService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var walletAddress: String? {
        UserDefaults.standard.string(forKey: "userWalletAddress")
    }
    
    // MARK: - Computed Properties
    
    var formattedUSDCBalance: String {
        CurrencyFormatter.formatToken(usdcBalance, symbol: "USDC")
    }
    
    var usdcBalanceInUserCurrency: String {
        let value = usdcBalance * conversionRate
        return formatCurrency(value)
    }
    
    var estimatedReceiveAmount: String {
        guard let amount = Decimal(string: usdcAmount), amount > 0 else {
            return "≈ \(currencySymbol)0.00"
        }
        
        let grossAmount = amount * conversionRate
        let fee = grossAmount * providerFeePercentage
        let netAmount = grossAmount - fee
        
        return formatCurrency(netAmount)
    }
    
    var providerFeeAmount: String {
        guard let amount = Decimal(string: usdcAmount), amount > 0 else {
            return "\(currencySymbol)0.00"
        }
        
        let grossAmount = amount * conversionRate
        let fee = grossAmount * providerFeePercentage
        
        return formatCurrency(fee)
    }
    
    var currencySymbol: String {
        // Use CurrencyService which has LIVE rates, not static Currency.getCurrency()
        currencyService.getCurrency(code: userCurrency)?.symbol ?? "$"
    }
    
    var currencyName: String {
        // Use CurrencyService which has LIVE rates, not static Currency.getCurrency()
        currencyService.getCurrency(code: userCurrency)?.name ?? "USD"
    }
    
    func formatCurrency(_ amount: Decimal) -> String {
        // Use CurrencyService which has LIVE rates, not static Currency.getCurrency()
        guard let currency = currencyService.getCurrency(code: userCurrency) else {
            return "\(amount)"
        }
        return currency.format(amount)
    }
    
    var isValidAmount: Bool {
        guard let amount = Decimal(string: usdcAmount) else {
            return false
        }
        return amount > 0 && amount <= usdcBalance
    }
    
    // MARK: - Initialization
    
    nonisolated init(
        erc20Contract: ERC20Contract = ERC20Contract(),
        transakService: TransakService = TransakService()
    ) {
        self.erc20Contract = erc20Contract
        self.transakService = transakService
        
        Task { @MainActor in
            AppLogger.log("💸 WithdrawViewModel initialized", category: "withdraw")
            await self.loadBalance()
            await self.fetchConversionRate()
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
                    AppLogger.log("💱 Withdraw detected currency change to: \(newCurrency)", category: "withdraw")
                    self.userCurrency = newCurrency
                    
                    // CRITICAL: Force refresh rates from API, then fetch conversion
                    Task {
                        do {
                            try await self.currencyService.fetchLiveExchangeRates()
                            AppLogger.log("✅ Forced rate refresh for Withdraw currency change", category: "withdraw")
                        } catch {
                            AppLogger.log("⚠️ Rate refresh failed, using cached: \(error.localizedDescription)", category: "withdraw")
                        }
                        
                        await self.fetchConversionRate()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Currency Conversion
    
    func fetchConversionRate() async {
        do {
            // Get LIVE conversion rate from CurrencyService
            // This uses the updated supportedCurrencies array with fresh rates
            conversionRate = try await currencyService.getConversionRate(
                from: "USD",
                to: userCurrency
            )
            
            AppLogger.log("""
                💱 Withdraw conversion rate updated (LIVE):
                - Currency: \(userCurrency)
                - Rate: 1 USD = \(conversionRate) \(userCurrency)
                - Source: CoinGecko API
                """, category: "withdraw")
            
        } catch {
            AppLogger.log("⚠️ Failed to fetch conversion rate: \(error.localizedDescription)", category: "withdraw")
            // Keep existing rate as fallback
        }
    }
    
    // MARK: - Public Methods
    
    func loadBalance() async {
        guard let walletAddress = walletAddress else {
            AppLogger.log("⚠️ No wallet address available", category: "withdraw")
            viewState = .error("Wallet address not available")
            return
        }
        
        viewState = .loading
        
        do {
            let balances = try await erc20Contract.balancesOf(
                tokens: [.usdc],
                address: walletAddress
            )
            
            if let usdcBalance = balances.first(where: { $0.symbol == "USDC" }) {
                self.usdcBalance = usdcBalance.decimalBalance
                viewState = .ready
                AppLogger.log("✅ USDC balance loaded: \(usdcBalance.decimalBalance)", category: "withdraw")
            } else {
                viewState = .error("Failed to fetch USDC balance")
            }
        } catch {
            viewState = .error("Failed to load balance: \(error.localizedDescription)")
            AppLogger.log("❌ Failed to load USDC balance: \(error.localizedDescription)", category: "withdraw")
        }
    }
    
    func setPresetAmount(_ preset: String) {
        guard usdcBalance > 0 else {
            usdcAmount = ""
            return
        }
        
        let amount: Decimal
        switch preset {
        case "50%":
            amount = usdcBalance * 0.5
        case "Max":
            amount = usdcBalance
        default:
            return
        }
        
        usdcAmount = String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)
        AppLogger.log("📝 Set withdraw amount to \(preset): \(usdcAmount) USDC", category: "withdraw")
    }
    
    func validateAndProceed() -> (isValid: Bool, errorMessage: String?) {
        guard let amount = Decimal(string: usdcAmount) else {
            return (false, "Please enter a valid amount")
        }
        
        if amount <= 0 {
            return (false, "Amount must be greater than 0")
        }
        
        if amount > usdcBalance {
            return (false, "Insufficient USDC balance")
        }
        
        // Transak minimum is ~$10
        if amount < 10 {
            return (false, "Minimum withdrawal is 10 USDC")
        }
        
        return (true, nil)
    }
    
    /// Build Transak widget URL for withdrawal
    func buildTransakURL() throws -> URL {
        AppLogger.log("🌐 Building Transak URL for withdrawal", category: "withdraw")
        AppLogger.log("   Amount: \(usdcAmount) USDC", category: "withdraw")
        
        return try transakService.buildWithdrawURL(
            cryptoAmount: usdcAmount,
            cryptoCurrency: "USDC",
            fiatCurrency: "INR"
        )
    }
}

