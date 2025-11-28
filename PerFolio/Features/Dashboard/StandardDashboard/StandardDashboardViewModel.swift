import Foundation
import Combine

/// Safety status for loan ratio visualization
enum SafetyStatus {
    case verySafe   // 0-40%: Green
    case caution    // 40-70%: Yellow
    case warning    // 70-85%: Orange
    case danger     // 85%+: Red
    
    var displayText: String {
        switch self {
        case .verySafe: return "VERY SAFE"
        case .caution: return "CAUTION"
        case .warning: return "NEEDS ATTENTION"
        case .danger: return "DANGER"
        }
    }
    
    var message: String {
        switch self {
        case .verySafe:
            return "You are in a very safe zone. You can relax."
        case .caution:
            return "You are still safe but should monitor the gold price."
        case .warning:
            return "Consider adding gold or repaying some loan to stay safe."
        case .danger:
            return "Add gold NOW or repay loan to avoid liquidation."
        }
    }
}

/// Safety alert for display
struct SafetyAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let message: String
    
    enum AlertType {
        case info    // Green
        case caution // Yellow
        case warning // Red
    }
}

/// ViewModel for the Standard (loan safety focused) dashboard
@MainActor
final class StandardDashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // Collateral (Your Gold)
    @Published var paxgBalance: Decimal = 0
    @Published var collateralValueUserCurrency: String = "$0.00"
    @Published var todayChange: String = "$0.00"
    @Published var todayChangePercent: String = "0.00"
    @Published var isPositiveChange: Bool = true
    @Published var goldPriceUserCurrency: String = "$0.00"
    
    // Borrowing (Your Loan)
    @Published var borrowedAmount: String = "$0.00"
    @Published var totalOwed: String = "$0.00"
    @Published var interestRate: String = "0.00"
    
    // Safety
    @Published var loanRatio: Decimal = 0
    @Published var loanRatioPercent: String = "0"
    @Published var safetyStatus: SafetyStatus = .verySafe
    @Published var maxSafeLTV: String = "75"
    
    // Available to Borrow
    @Published var availableToBorrow: String = "$0.00"
    
    // Interest Insights
    @Published var dailyInterest: String = "$0.00"
    @Published var totalInterest: String = "$0.00"
    @Published var repayAmount: String = "$0.00"
    
    // Loading State
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let currencyService = CurrencyService.shared
    private let fluidVaultService = FluidVaultService()
    private let erc20Contract = ERC20Contract()
    private let notificationManager = NotificationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    private var paxgPriceUSD: Decimal = 0
    private var borrowedAmountUSD: Decimal = 0
    private var collateralValueUSD: Decimal = 0
    private var borrowAPY: Decimal = 0
    private var maxLTV: Decimal = 75
    
    // MARK: - Initialization
    
    init() {
        setupObservers()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Listen for currency changes
        NotificationCenter.default.publisher(for: .currencyDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // STEP 1: Get user wallet address
            guard let userAddress = UserDefaults.standard.string(forKey: "userWalletAddress") else {
                throw StandardDashboardError.noWalletAddress
            }
            
            // STEP 2: Initialize Fluid vault (config, price, APY)
            do {
                try await fluidVaultService.initialize()
                paxgPriceUSD = fluidVaultService.paxgPrice
                borrowAPY = fluidVaultService.currentAPY
                if let vaultConfig = fluidVaultService.vaultConfig {
                    maxLTV = vaultConfig.maxLTV
                }
                AppLogger.log("✅ Fluid vault initialized for Standard dashboard", category: "standard-dashboard")
            } catch {
                AppLogger.log("⚠️ Fluid init failed, using defaults: \(error.localizedDescription)", category: "standard-dashboard")
                // Use default values
                paxgPriceUSD = fluidVaultService.paxgPrice > 0 ? fluidVaultService.paxgPrice : 2734.0
                borrowAPY = fluidVaultService.currentAPY > 0 ? fluidVaultService.currentAPY : 4.89
                maxLTV = 75.0
            }
            
            // STEP 3: Fetch PAXG balance
            do {
                let balance = try await erc20Contract.balanceOf(token: .paxg, address: userAddress)
                paxgBalance = balance.decimalBalance
                AppLogger.log("💰 PAXG Balance: \(paxgBalance)", category: "standard-dashboard")
            } catch {
                AppLogger.log("❌ Failed to load PAXG balance: \(error.localizedDescription)", category: "standard-dashboard")
                paxgBalance = 0
            }
            
            // STEP 4: Calculate collateral value in USD
            collateralValueUSD = paxgBalance * paxgPriceUSD
            
            // STEP 5: Get borrow metrics (if any)
            // For now, we'll use placeholder values
            // TODO: Implement actual borrow metrics fetching when available
            borrowedAmountUSD = 0
            loanRatio = 0
            
            // STEP 6: Calculate interest
            calculateInterest()
            
            // STEP 7: Convert all values to user currency
            await convertToUserCurrency()
            
            // STEP 8: Calculate safety status
            updateSafetyStatus()
            
            // STEP 9: Generate alerts
            generateAlerts()
            
            isLoading = false
            
        } catch {
            AppLogger.log("❌ Failed to load Standard dashboard: \(error)", category: "standard-dashboard")
            errorMessage = error.localizedDescription
            isLoading = false
            
            // Show default values
            setDefaultValues()
        }
    }
    
    // MARK: - Calculations
    
    private func calculateInterest() {
        // Daily interest = borrowedAmount * (APY / 365)
        let dailyInterestUSD = borrowedAmountUSD * (borrowAPY / 365 / 100)
        
        // For now, assume total interest is 30 days worth (placeholder)
        // In production, you'd fetch actual accrued interest from contract
        let totalInterestUSD = dailyInterestUSD * 30
        
        // Store for conversion
        self.dailyInterest = currencyService.formatInUserCurrency(dailyInterestUSD)
        self.totalInterest = currencyService.formatInUserCurrency(totalInterestUSD)
        
        // Repay amount = borrowed + interest
        let repayAmountUSD = borrowedAmountUSD + totalInterestUSD
        self.repayAmount = currencyService.formatInUserCurrency(repayAmountUSD)
    }
    
    private func calculateAvailableToBorrow() -> Decimal {
        // Available = (collateralValue * maxLTV / 100) - currentBorrowed
        let maxBorrow = collateralValueUSD * (maxLTV / 100)
        let available = max(0, maxBorrow - borrowedAmountUSD)
        return available
    }
    
    private func updateSafetyStatus() {
        let ratio = loanRatio
        
        if ratio < 40 {
            safetyStatus = .verySafe
        } else if ratio < 70 {
            safetyStatus = .caution
        } else if ratio < 85 {
            safetyStatus = .warning
        } else {
            safetyStatus = .danger
        }
        
        loanRatioPercent = String(format: "%.0f", loanRatio as NSDecimalNumber)
        maxSafeLTV = String(format: "%.0f", maxLTV as NSDecimalNumber)
    }
    
    private func generateAlerts() {
        // Push alerts to NotificationManager instead of storing locally
        
        // Price movement alert (only if significant)
        if isPositiveChange && todayChange != "$0.00" {
            notificationManager.addPriceChangeAlert(
                message: "Your gold increased today by \(todayChange)",
                isPositive: true
            )
        } else if !isPositiveChange && todayChange != "$0.00" {
            notificationManager.addPriceChangeAlert(
                message: "Your gold decreased today by \(todayChange)",
                isPositive: false
            )
        }
        
        // Loan ratio alerts (only if user has loans)
        if borrowedAmountUSD > 0 {
            if loanRatio >= 70 {
                notificationManager.addSafetyAlert(
                    message: "Loan ratio is \(loanRatioPercent)%. Add gold or repay to avoid liquidation.",
                    priority: loanRatio >= 85 ? .urgent : .high
                )
            } else if loanRatio >= 40 {
                notificationManager.addSafetyAlert(
                    message: "Loan ratio reached \(loanRatioPercent)%. You are still safe but monitor the gold price.",
                    priority: .normal
                )
            }
        }
    }
    
    // MARK: - Currency Conversion
    
    private func convertToUserCurrency() async {
        let userCurrency = UserPreferences.defaultCurrency
        
        // Collateral value
        collateralValueUserCurrency = currencyService.formatInUserCurrency(collateralValueUSD)
        
        // Gold price
        goldPriceUserCurrency = currencyService.formatInUserCurrency(paxgPriceUSD)
        
        // Borrowed amount
        borrowedAmount = currencyService.formatInUserCurrency(borrowedAmountUSD)
        
        // Available to borrow
        let availableUSD = calculateAvailableToBorrow()
        availableToBorrow = currencyService.formatInUserCurrency(availableUSD)
        
        // Interest rate (just format as percentage)
        interestRate = String(format: "%.2f", borrowAPY as NSDecimalNumber)
        
        // Today's change (placeholder - in production, calculate from price history)
        let changeUSD: Decimal = 0 // TODO: Calculate from historical data
        todayChange = currencyService.formatInUserCurrency(abs(changeUSD))
        isPositiveChange = changeUSD >= 0
        todayChangePercent = "0.00"
    }
    
    private func setDefaultValues() {
        collateralValueUserCurrency = "$0.00"
        todayChange = "$0.00"
        todayChangePercent = "0.00"
        goldPriceUserCurrency = "$0.00"
        borrowedAmount = "$0.00"
        totalOwed = "$0.00"
        interestRate = "0.00"
        loanRatioPercent = "0"
        availableToBorrow = "$0.00"
        dailyInterest = "$0.00"
        totalInterest = "$0.00"
        repayAmount = "$0.00"
        safetyStatus = .verySafe
    }
}

// MARK: - Errors

enum StandardDashboardError: LocalizedError {
    case noWalletAddress
    case fetchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noWalletAddress:
            return "No wallet address found. Please connect your wallet."
        case .fetchFailed(let message):
            return "Failed to load dashboard: \(message)"
        }
    }
}

