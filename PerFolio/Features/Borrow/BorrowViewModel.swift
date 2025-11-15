import SwiftUI
import Combine

/// ViewModel for the Borrow screen
/// Manages state, calculations, and borrow execution
@MainActor
final class BorrowViewModel: ObservableObject {
    
    // MARK: - Input State
    
    @Published var collateralAmount: String = ""
    @Published var borrowAmount: String = ""
    
    // MARK: - Data State
    
    @Published var paxgBalance: Decimal = 0
    @Published var paxgPrice: Decimal = 0
    @Published var vaultConfig: VaultConfig?
    @Published var currentAPY: Decimal = 0
    
    // MARK: - Computed State
    
    @Published var metrics: BorrowMetrics?
    @Published var validationError: String?
    
    // MARK: - UI State
    
    @Published var viewState: ViewState = .loading
    @Published var transactionState: TransactionState = .idle
    @Published var showingTransactionModal = false
    @Published var showingAPYChart = false
    
    enum ViewState {
        case loading
        case ready
        case error(String)
    }
    
    enum TransactionState {
        case idle
        case checkingApproval
        case approvingPAXG
        case depositingAndBorrowing
        case success(positionId: String)
        case failed(String)
    }
    
    // MARK: - Dependencies
    
    private let fluidVaultService: FluidVaultService
    private let erc20Contract: ERC20Contract
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        fluidVaultService: FluidVaultService? = nil,
        erc20Contract: ERC20Contract? = nil
    ) {
        self.fluidVaultService = fluidVaultService ?? FluidVaultService()
        self.erc20Contract = erc20Contract ?? ERC20Contract()
    }
    
    func onAppear() {
        setupReactiveCalculations()
        Task {
            await loadInitialData()
        }
    }
    
    // MARK: - Load Initial Data
    
    func loadInitialData() async {
        viewState = .loading
        
        do {
            AppLogger.log("🔄 Loading borrow screen data...", category: "borrow")
            
            // 1. Initialize Fluid vault (config, price, APY)
            try await fluidVaultService.initialize()
            
            // 2. Extract data
            paxgPrice = fluidVaultService.paxgPrice
            vaultConfig = fluidVaultService.vaultConfig
            currentAPY = fluidVaultService.currentAPY
            
            // 3. Load user's PAXG balance
            await loadPAXGBalance()
            
            // 4. Auto-fill collateral with full balance (Binance-style UX)
            if paxgBalance > 0 {
                collateralAmount = formatDecimal(paxgBalance, maxDecimals: 6)
            }
            
            viewState = .ready
            AppLogger.log("✅ Borrow screen ready", category: "borrow")
            
        } catch {
            let errorMsg = "Failed to load borrow data: \(error.localizedDescription)"
            AppLogger.log("❌ \(errorMsg)", category: "borrow")
            viewState = .error(errorMsg)
        }
    }
    
    private func loadPAXGBalance() async {
        guard let walletAddress = UserDefaults.standard.string(forKey: "userWalletAddress") else {
            AppLogger.log("⚠️ No wallet address found", category: "borrow")
            return
        }
        
        do {
            let balance = try await erc20Contract.balanceOf(token: .paxg, address: walletAddress)
            paxgBalance = balance.decimalBalance
            AppLogger.log("💰 PAXG Balance: \(paxgBalance)", category: "borrow")
        } catch {
            AppLogger.log("❌ Failed to load PAXG balance: \(error.localizedDescription)", category: "borrow")
        }
    }
    
    // MARK: - Reactive Calculations
    
    private func setupReactiveCalculations() {
        // Update metrics whenever inputs change
        Publishers.CombineLatest($collateralAmount, $borrowAmount)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMetrics()
            }
            .store(in: &cancellables)
    }
    
    private func updateMetrics() {
        // Parse inputs
        guard let collateral = Decimal(string: collateralAmount),
              let borrow = Decimal(string: borrowAmount),
              collateral > 0, borrow > 0,
              let config = vaultConfig else {
            metrics = nil
            validationError = nil
            return
        }
        
        // Calculate metrics
        metrics = BorrowMetrics(
            collateralAmount: collateral,
            borrowAmount: borrow,
            paxgPrice: paxgPrice,
            vaultConfig: config
        )
        
        // Validate
        validationError = validate()
    }
    
    // MARK: - Quick Actions
    
    func setCollateralToMax() {
        collateralAmount = formatDecimal(paxgBalance, maxDecimals: 6)
        AppLogger.log("📝 Set collateral to max: \(collateralAmount) PAXG", category: "borrow")
    }
    
    func setQuickLTV(_ percentage: Decimal) {
        guard let collateral = Decimal(string: collateralAmount),
              collateral > 0 else {
            return
        }
        
        let collateralValue = collateral * paxgPrice
        let targetBorrow = collateralValue * (percentage / 100)
        borrowAmount = formatDecimal(targetBorrow, maxDecimals: 2)
        
        AppLogger.log("📝 Set LTV to \(percentage)%: \(borrowAmount) USDC", category: "borrow")
    }
    
    func showAPYChart() {
        showingAPYChart = true
    }
    
    // MARK: - Validation
    
    private func validate() -> String? {
        guard let collateral = Decimal(string: collateralAmount),
              let borrow = Decimal(string: borrowAmount) else {
            return nil
        }
        
        // Check balance
        if collateral > paxgBalance {
            return "Insufficient PAXG balance. Available: \(formatDecimal(paxgBalance, maxDecimals: 6)) PAXG"
        }
        
        // Check if metrics exist
        guard let metrics = metrics else {
            return "Invalid amounts"
        }
        
        // Check max borrow
        if borrow > metrics.maxBorrowableUSD {
            return "Maximum borrow is \(formatDecimal(metrics.maxBorrowableUSD, maxDecimals: 2)) USDC at \(vaultConfig?.maxLTV ?? 75)% LTV"
        }
        
        // Check health factor
        if metrics.isUnsafeHealth {
            return "Health factor too low (\(metrics.formattedHealthFactor)) - reduce loan or add collateral"
        }
        
        return nil  // Valid
    }
    
    // MARK: - Execute Borrow
    
    func executeBorrow() async {
        guard validationError == nil else {
            AppLogger.log("❌ Cannot execute: \(validationError ?? "Unknown error")", category: "borrow")
            return
        }
        
        guard let collateral = Decimal(string: collateralAmount),
              let borrow = Decimal(string: borrowAmount),
              let walletAddress = UserDefaults.standard.string(forKey: "userWalletAddress"),
              let vaultAddress = vaultConfig?.vaultAddress else {
            transactionState = .failed("Invalid request parameters")
            return
        }
        
        showingTransactionModal = true
        
        do {
            let request = BorrowRequest(
                collateralAmount: collateral,
                borrowAmount: borrow,
                userAddress: walletAddress,
                vaultAddress: vaultAddress
            )
            
            AppLogger.log("🚀 Executing borrow...", category: "borrow")
            
            transactionState = .checkingApproval
            await Task.sleep(1_000_000_000)  // 1 sec for UI
            
            transactionState = .approvingPAXG
            await Task.sleep(2_000_000_000)  // 2 sec for UI
            
            transactionState = .depositingAndBorrowing
            
            // Execute via FluidVaultService (Phase 5 - Privy integration)
            let positionId = try await fluidVaultService.executeBorrow(request: request)
            
            transactionState = .success(positionId: positionId)
            AppLogger.log("🎉 Borrow successful! Position: #\(positionId)", category: "borrow")
            
            // Refresh balance
            await loadPAXGBalance()
            
        } catch {
            let errorMsg = error.localizedDescription
            AppLogger.log("❌ Borrow failed: \(errorMsg)", category: "borrow")
            transactionState = .failed(errorMsg)
        }
    }
    
    func resetTransaction() {
        transactionState = .idle
        showingTransactionModal = false
    }
    
    // MARK: - Helpers
    
    private func formatDecimal(_ value: Decimal, maxDecimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxDecimals
        formatter.groupingSeparator = ""
        return formatter.string(from: value as NSDecimalNumber) ?? "0"
    }
}
