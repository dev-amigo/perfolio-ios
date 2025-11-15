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
    
    // MARK: - Published Properties
    
    // Currency & Amount
    @Published var selectedFiatCurrency: FiatCurrency = .default
    @Published var inrAmount: String = ""  // Renamed to fiatAmount in future
    @Published var selectedPaymentMethod: PaymentMethod = .upi
    @Published var viewState: ViewState = .input
    @Published var currentQuote: OnMetaService.Quote?
    
    // Swap-related
    @Published var usdtAmount: String = ""
    @Published var swapState: SwapState = .idle
    @Published var swapQuote: DEXSwapService.SwapQuote?
    @Published var slippageTolerance: Decimal = 0.5 // 0.5%
    @Published var goldPrice: Decimal = 0
    @Published var usdtBalance: Decimal = 0
    @Published var paxgBalance: Decimal = 0
    
    // Safari view
    @Published var showingSafariView = false
    @Published var safariURL: URL?
    
    // Alerts
    @Published var showingError = false
    @Published var errorMessage = ""
    
    // MARK: - Private Properties
    
    private let onMetaService: OnMetaService
    private let dexSwapService: DEXSwapService
    private let erc20Contract: ERC20Contract
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
        }
    }
    
    // MARK: - OnMeta (INR → USDT) Methods
    
    func getQuote() async {
        guard onMetaService.validateAmount(inrAmount) else {
            showError("Please enter a valid amount between ₹500 and ₹100,000")
            return
        }
        
        viewState = .processing
        
        do {
            let quote = try await onMetaService.getQuote(inrAmount: inrAmount)
            currentQuote = quote
            viewState = .quote
            AppLogger.log("✅ Quote received: \(quote.displayUsdtAmount)", category: "depositbuy")
        } catch {
            viewState = .error(error.localizedDescription)
            showError(error.localizedDescription)
            AppLogger.log("❌ Quote failed: \(error.localizedDescription)", category: "depositbuy")
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
            
            // Check if USDT balance increased
            if usdtBalance > 0 {
                viewState = .success
                AppLogger.log("✅ USDT balance updated: \(usdtBalance)", category: "depositbuy")
            }
        }
    }
    
    func resetOnMetaFlow() {
        inrAmount = ""
        currentQuote = nil
        viewState = .input
        onMetaService.reset()
    }
    
    // MARK: - DEX Swap (USDT → PAXG) Methods
    
    func getSwapQuote() async {
        guard let walletAddress = walletAddress else {
            showError("Wallet address not available")
            return
        }
        
        guard let amount = Decimal(string: usdtAmount), amount > 0 else {
            showError("Please enter a valid USDT amount")
            return
        }
        
        guard amount <= usdtBalance else {
            showError("Insufficient USDT balance")
            return
        }
        
        swapState = .idle
        
        do {
            let params = DEXSwapService.SwapParams(
                fromToken: .usdt,
                toToken: .paxg,
                amount: amount,
                slippageTolerance: slippageTolerance,
                fromAddress: walletAddress
            )
            
            let quote = try await dexSwapService.getQuote(params: params)
            swapQuote = quote
            
            // Check if approval is needed
            let approvalState = try await dexSwapService.checkApproval(
                tokenAddress: DEXSwapService.Token.usdt.address,
                ownerAddress: walletAddress,
                spenderAddress: ContractAddresses.oneInchRouterV6,
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
    
    func approveUSDT() async {
        guard let walletAddress = walletAddress else {
            showError("Wallet address not available")
            return
        }
        
        guard let amount = Decimal(string: usdtAmount) else {
            showError("Invalid amount")
            return
        }
        
        swapState = .approving
        
        do {
            try await dexSwapService.approveToken(
                tokenAddress: DEXSwapService.Token.usdt.address,
                spenderAddress: ContractAddresses.oneInchRouterV6,
                amount: amount
            )
            AppLogger.log("✅ USDT approved for swap", category: "depositbuy")
            
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
        
        guard let amount = Decimal(string: usdtAmount) else {
            showError("Invalid amount")
            return
        }
        
        swapState = .swapping
        
        do {
            let params = DEXSwapService.SwapParams(
                fromToken: .usdt,
                toToken: .paxg,
                amount: amount,
                slippageTolerance: slippageTolerance,
                fromAddress: walletAddress
            )
            
            let txHash = try await dexSwapService.executeSwap(params: params)
            swapState = .success(txHash)
            
            AppLogger.log("✅ Swap executed: \(txHash)", category: "depositbuy")
            
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
        usdtAmount = ""
        swapQuote = nil
        swapState = .idle
        dexSwapService.reset()
    }
    
    // MARK: - Balance & Price Methods
    
    func loadBalances() async {
        guard let walletAddress = walletAddress else { return }
        
        do {
            let balances = try await erc20Contract.balancesOf(
                tokens: [.usdt, .paxg],
                address: walletAddress
            )
            
            usdtBalance = balances.first(where: { $0.symbol == "USDT" })?.decimalBalance ?? 0
            paxgBalance = balances.first(where: { $0.symbol == "PAXG" })?.decimalBalance ?? 0
            
            AppLogger.log("💰 Balances: USDT=\(usdtBalance), PAXG=\(paxgBalance)", category: "depositbuy")
        } catch {
            AppLogger.log("❌ Failed to load balances: \(error.localizedDescription)", category: "depositbuy")
        }
    }
    
    func fetchGoldPrice() async {
        // In production, fetch from CoinGecko or price oracle
        // For now, use a static price
        goldPrice = ServiceConstants.goldPriceUSDT
        AppLogger.log("💰 Gold price: $\(goldPrice)", category: "depositbuy")
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
    
    var formattedUSDTBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        return formatter.string(from: usdtBalance as NSNumber) ?? "0.00"
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
        guard let amount = Decimal(string: usdtAmount), goldPrice > 0 else {
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

