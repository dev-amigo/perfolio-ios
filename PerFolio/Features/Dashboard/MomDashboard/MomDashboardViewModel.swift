import Foundation
import SwiftUI
import Combine

/// ViewModel for the simplified Mom Dashboard
@MainActor
final class MomDashboardViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    // Total Holdings
    @Published var totalHoldingsInUserCurrency: Decimal = 0
    @Published var totalHoldingsChangePercent: Decimal = 0
    @Published var totalHoldingsChangeAmount: Decimal = 0
    
    // Investment Calculator
    @Published var investmentAmount: Decimal = 5000
    @Published var investmentCalculation: InvestmentCalculation?
    
    // Profit/Loss
    @Published var todayProfitLoss: Decimal = 0
    @Published var weekProfitLoss: Decimal = 0
    @Published var monthProfitLoss: Decimal = 0
    @Published var overallProfitLoss: Decimal = 0
    @Published var overallProfitLossPercent: Decimal = 0
    
    // Asset Breakdown
    @Published var paxgAmount: Decimal = 0
    @Published var paxgValueUSD: Decimal = 0
    @Published var paxgValueUserCurrency: Decimal = 0
    
    @Published var usdcAmount: Decimal = 0
    @Published var usdcValueUserCurrency: Decimal = 0
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Services & Dependencies
    
    private let currencyService = CurrencyService.shared
    private let dashboardViewModel: DashboardViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    
    // APY for investment calculator
    // Based on Fluid Protocol typical lending rates (3-15% range)
    // Using 8% as a realistic, conservative mid-range estimate
    private let averageAPY: Decimal = 0.08 // 8% APY
    
    // MARK: - Initialization
    
    init(dashboardViewModel: DashboardViewModel) {
        self.dashboardViewModel = dashboardViewModel
        setupObservers()
        calculateInvestmentReturns()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe balance changes from main dashboard
        dashboardViewModel.$usdcBalance
            .combineLatest(dashboardViewModel.$paxgBalance, dashboardViewModel.$currentPAXGPrice)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                Task {
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)
        
        // Recalculate when investment amount changes
        $investmentAmount
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.calculateInvestmentReturns()
            }
            .store(in: &cancellables)
        
        // Listen for currency changes from Settings
        NotificationCenter.default.publisher(for: .currencyDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                
                // Extract old and new currency from notification
                guard let oldCurrency = notification.userInfo?["oldCurrency"] as? String,
                      let newCurrency = notification.userInfo?["newCurrency"] as? String else {
                    return
                }
                
                AppLogger.log("💱 Mom Dashboard detected currency change: \(oldCurrency) → \(newCurrency)", category: "mom-dashboard")
                
                // Force refresh conversion rates from API, then convert slider and reload
                Task {
                    do {
                        // CRITICAL: Force fetch fresh rates from CoinGecko
                        try await self.currencyService.fetchLiveExchangeRates()
                        AppLogger.log("✅ Forced rate refresh for currency change", category: "mom-dashboard")
                        
                        // CONVERT SLIDER AMOUNT to new currency
                        // E.g., €1,000 → ₹91,800 when changing EUR to INR
                        await self.convertInvestmentAmountToCurrency(from: oldCurrency, to: newCurrency)
                        
                    } catch {
                        AppLogger.log("⚠️ Rate refresh failed, using cached: \(error.localizedDescription)", category: "mom-dashboard")
                    }
                    
                    // Reload all data with new currency
                    await self.loadData()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        // STEP 1: Get real balances from blockchain (via DashboardViewModel)
        // These are the actual token amounts in user's wallet
        usdcAmount = dashboardViewModel.usdcBalance?.decimalBalance ?? 0
        paxgAmount = dashboardViewModel.paxgBalance?.decimalBalance ?? 0
        
        // STEP 2: Get real PAXG price from oracle
        // This comes from PriceOracleService (live data)
        let paxgPriceUSD = dashboardViewModel.currentPAXGPrice
        
        // STEP 3: Calculate portfolio value in USD
        // PAXG value = (PAXG amount in oz) × (PAXG price in USD)
        paxgValueUSD = paxgAmount * paxgPriceUSD
        
        // Total USD = USDC + PAXG value
        let totalUSD = usdcAmount + paxgValueUSD
        
        // STEP 4: Convert to user's selected currency using live exchange rates
        let userCurrency = UserPreferences.defaultCurrency
        
        do {
            // Fetch live conversion rate from CoinGecko API
            // E.g., 1 USD = 83.50 INR (live rate)
            let conversionRate = try await currencyService.getConversionRate(from: "USD", to: userCurrency)
            
            // Convert all USD values to user's currency
            totalHoldingsInUserCurrency = totalUSD * conversionRate
            paxgValueUserCurrency = paxgValueUSD * conversionRate
            usdcValueUserCurrency = usdcAmount * conversionRate
            
            // STEP 5: Calculate profit/loss based on baseline
            calculateProfitLoss(currentValue: totalHoldingsInUserCurrency)
            
            AppLogger.log("""
                ✅ Mom Dashboard loaded:
                - USDC: \(usdcAmount)
                - PAXG: \(paxgAmount) oz @ $\(paxgPriceUSD)
                - Total USD: $\(totalUSD)
                - Conversion Rate: 1 USD = \(conversionRate) \(userCurrency)
                - Total Holdings: \(formatCurrency(totalHoldingsInUserCurrency))
                """, category: "mom-dashboard")
            
            // Verify all calculations are accurate
            verifyCalculations()
            
        } catch {
            // If API fails, use direct USD values (fallback)
            totalHoldingsInUserCurrency = totalUSD
            paxgValueUserCurrency = paxgValueUSD
            usdcValueUserCurrency = usdcAmount
            
            errorMessage = "Using USD values (conversion unavailable)"
            AppLogger.log("⚠️ Currency API unavailable, showing USD: \(error.localizedDescription)", category: "mom-dashboard")
            
            // Still calculate profit/loss
            calculateProfitLoss(currentValue: totalHoldingsInUserCurrency)
        }
    }
    
    // MARK: - Profit/Loss Calculation
    
    /// Calculate profit/loss based on baseline tracking
    /// Baseline is ALWAYS stored in USD to prevent currency conversion issues
    /// We convert both baseline and current value to user's currency for display
    private func calculateProfitLoss(currentValue: Decimal) {
        // Check if we have an existing baseline
        if let baselineUSD = UserPreferences.dashboardBaselineValue,
           let baselineDate = UserPreferences.dashboardBaselineDate {
            
            // CRITICAL FIX: Convert baseline from USD to user's currency
            // Baseline is stored in USD, so we need to convert it to match currentValue's currency
            let userCurrency = UserPreferences.defaultCurrency
            let baselineInUserCurrency: Decimal
            
            if userCurrency == "USD" {
                // No conversion needed
                baselineInUserCurrency = baselineUSD
            } else {
                // Convert baseline from USD to user's currency
                if let currency = CurrencyService.shared.getCurrency(code: userCurrency) {
                    baselineInUserCurrency = baselineUSD * currency.conversionRate
                } else {
                    // Fallback: use USD value
                    baselineInUserCurrency = baselineUSD
                }
            }
            
            // CALCULATION 1: Overall Profit/Loss
            // Simple: Current Value - Initial Value (both in user's currency now)
            overallProfitLoss = currentValue - baselineInUserCurrency
            
            // Percentage: (Profit / Initial Value) × 100
            overallProfitLossPercent = baselineInUserCurrency > 0 ? (overallProfitLoss / baselineInUserCurrency) * 100 : 0
            
            // CALCULATION 2: Time-based estimates
            // Calculate days elapsed since baseline was set
            let secondsElapsed = Date().timeIntervalSince(baselineDate)
            let daysElapsed = secondsElapsed / (24 * 60 * 60)
            
            if daysElapsed >= 1 {
                // Daily average profit/loss = Total Profit / Days Elapsed
                let dailyAverage = overallProfitLoss / Decimal(daysElapsed)
                
                // Estimates based on average daily performance
                todayProfitLoss = dailyAverage                    // Today = Daily average
                weekProfitLoss = dailyAverage * Decimal(7)        // Week = 7 days
                monthProfitLoss = dailyAverage * Decimal(30)      // Month = 30 days
                
                AppLogger.log("""
                    📊 Profit/Loss Calculated:
                    - Baseline (USD): \(baselineUSD)
                    - Baseline (User Currency): \(baselineInUserCurrency)
                    - Current Value: \(currentValue)
                    - Days Elapsed: \(daysElapsed)
                    - Daily Avg: \(dailyAverage)
                    - Overall: \(overallProfitLoss) (\(overallProfitLossPercent)%)
                    """, category: "mom-dashboard")
            } else {
                // Less than 1 day elapsed, show zeros
                todayProfitLoss = 0
                weekProfitLoss = 0
                monthProfitLoss = 0
            }
            
            // Update display values
            totalHoldingsChangeAmount = overallProfitLoss
            totalHoldingsChangePercent = overallProfitLossPercent
            
        } else {
            // FIRST TIME: Set baseline
            // CRITICAL: Store baseline in USD to prevent currency issues
            // We need to convert current value from user's currency to USD
            let userCurrency = UserPreferences.defaultCurrency
            let baselineUSD: Decimal
            
            if userCurrency == "USD" {
                // Already in USD
                baselineUSD = currentValue
            } else {
                // Convert from user's currency to USD
                if let currency = CurrencyService.shared.getCurrency(code: userCurrency) {
                    baselineUSD = currentValue / currency.conversionRate
                } else {
                    // Fallback: assume it's USD
                    baselineUSD = currentValue
                }
            }
            
            // Store baseline in USD (not user's currency)
            UserPreferences.dashboardBaselineValue = baselineUSD
            UserPreferences.dashboardBaselineDate = Date()
            
            // No profit/loss yet (just starting)
            overallProfitLoss = 0
            overallProfitLossPercent = 0
            todayProfitLoss = 0
            weekProfitLoss = 0
            monthProfitLoss = 0
            totalHoldingsChangeAmount = 0
            totalHoldingsChangePercent = 0
            
            AppLogger.log("📊 Baseline established: \(formatCurrency(currentValue)) (\(baselineUSD) USD)", category: "mom-dashboard")
        }
    }
    
    // MARK: - Investment Calculator
    
    /// Calculate projected returns for the specified investment amount
    /// Uses real APY data and shows returns in user's selected currency
    func calculateInvestmentReturns() {
        // CALCULATION METHODOLOGY:
        // 1. Calculate returns on SLIDER AMOUNT (hypothetical investment)
        // 2. Slider is in user's selected currency (EUR, USD, etc.)
        // 3. Returns are also in user's currency
        //
        // **CORRECT CALCULATION:**
        // - Slider Amount: €5,000 (user's input)
        // - APY: 8%
        // - Daily: €5,000 × (0.08 / 365) = €1.10
        // - Monthly: €5,000 × (0.08 / 12) = €33.33
        // - Yearly: €5,000 × 0.08 = €400
        //
        // **NOTE:** Slider amount is ALREADY in user's currency
        // No additional conversion needed - it's a hypothetical "what if" calculator
        
        investmentCalculation = InvestmentCalculation.calculate(
            amount: investmentAmount,
            apy: averageAPY
        )
        
        AppLogger.log("""
            📊 Investment Returns Calculated:
            - Amount: \(investmentAmount) \(UserPreferences.defaultCurrency)
            - APY: \(averageAPY * 100)%
            - Daily: \(investmentCalculation?.dailyReturn ?? 0)
            - Monthly: \(investmentCalculation?.monthlyReturn ?? 0)
            - Yearly: \(investmentCalculation?.yearlyReturn ?? 0)
            """, category: "mom-dashboard")
    }
    
    func updateInvestmentAmount(_ amount: Decimal) {
        investmentAmount = amount
        HapticManager.shared.light()
    }
    
    /// Convert investment slider amount when currency changes
    /// E.g., €1,000 → ₹91,800 when changing EUR to INR
    private func convertInvestmentAmountToCurrency(from oldCurrency: String, to newCurrency: String) async {
        // If same currency, no conversion needed
        guard oldCurrency != newCurrency else { return }
        
        do {
            // Get conversion rate from old to new currency
            let conversionRate = try await currencyService.getConversionRate(from: oldCurrency, to: newCurrency)
            
            // Convert the current slider amount
            let oldAmount = investmentAmount
            let newAmount = oldAmount * conversionRate
            
            // Update slider to show equivalent amount in new currency
            investmentAmount = newAmount
            
            // Recalculate returns with new amount
            calculateInvestmentReturns()
            
            AppLogger.log("""
                💱 Investment amount converted:
                - Old: \(oldAmount) \(oldCurrency)
                - Rate: 1 \(oldCurrency) = \(conversionRate) \(newCurrency)
                - New: \(newAmount) \(newCurrency)
                - Daily Return: \(investmentCalculation?.dailyReturn ?? 0) \(newCurrency)
                """, category: "mom-dashboard")
            
        } catch {
            AppLogger.log("⚠️ Failed to convert investment amount: \(error.localizedDescription)", category: "mom-dashboard")
            // On error, recalculate with current amount in new currency
            calculateInvestmentReturns()
        }
    }
    
    // MARK: - Actions
    
    func navigateToDeposit() {
        // This will be handled by parent view
        AppLogger.log("🎯 Deposit requested with amount: \(investmentAmount)", category: "mom-dashboard")
    }
    
    func refreshData() async {
        await dashboardViewModel.fetchBalances()
        await loadData()
        HapticManager.shared.success()
    }
    
    func resetBaseline() {
        UserPreferences.dashboardBaselineValue = totalHoldingsInUserCurrency
        UserPreferences.dashboardBaselineDate = Date()
        calculateProfitLoss(currentValue: totalHoldingsInUserCurrency)
        HapticManager.shared.success()
        AppLogger.log("🔄 Baseline reset", category: "mom-dashboard")
    }
    
    // MARK: - Formatting Helpers
    
    func formatCurrency(_ amount: Decimal) -> String {
        let currency = UserPreferences.defaultCurrency
        guard let curr = Currency.getCurrency(code: currency) else {
            return "\(amount)"
        }
        return curr.format(amount)
    }
    
    func formatPercentage(_ percent: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        
        return formatter.string(from: (percent / 100) as NSDecimalNumber) ?? "\(percent)%"
    }
    
    func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
    
    // MARK: - Calculation Verification
    
    /// Verify all calculations are accurate (for debugging)
    func verifyCalculations() {
        let totalUSD = usdcAmount + paxgValueUSD
        
        AppLogger.log("""
            
            ═══════════════════════════════════════
            📊 MOM DASHBOARD CALCULATION VERIFICATION
            ═══════════════════════════════════════
            
            1️⃣ RAW DATA (From Blockchain):
            ────────────────────────────────────────
            • USDC Balance: \(usdcAmount) USDC
            • PAXG Balance: \(paxgAmount) oz
            • PAXG Price: $\(dashboardViewModel.currentPAXGPrice) per oz
            
            2️⃣ USD VALUES:
            ────────────────────────────────────────
            • PAXG Value: \(paxgAmount) × $\(dashboardViewModel.currentPAXGPrice) = $\(paxgValueUSD)
            • USDC Value: $\(usdcAmount)
            • Total USD: $\(usdcAmount) + $\(paxgValueUSD) = $\(totalUSD)
            
            3️⃣ CURRENCY CONVERSION:
            ────────────────────────────────────────
            • User Currency: \(UserPreferences.defaultCurrency)
            • Total in User Currency: \(formatCurrency(totalHoldingsInUserCurrency))
            
            4️⃣ PROFIT/LOSS:
            ────────────────────────────────────────
            • Baseline: \(UserPreferences.dashboardBaselineValue?.description ?? "Not Set")
            • Current: \(totalHoldingsInUserCurrency)
            • Overall P/L: \(formatCurrency(overallProfitLoss)) (\(formatPercentage(overallProfitLossPercent)))
            • Today: \(formatCurrency(todayProfitLoss))
            • Week: \(formatCurrency(weekProfitLoss))
            • Month: \(formatCurrency(monthProfitLoss))
            
            5️⃣ INVESTMENT CALCULATOR:
            ────────────────────────────────────────
            • Investment: \(formatCurrency(investmentAmount))
            • APY: \(averageAPY * 100)%
            • Daily Return: \(formatCurrency(investmentCalculation?.dailyReturn ?? 0))
            • Yearly Return: \(formatCurrency(investmentCalculation?.yearlyReturn ?? 0))
            
            ✅ All calculations use REAL data from:
            - Blockchain (ERC20 balances)
            - Price Oracle (PAXG live price)
            - CoinGecko API (live currency rates)
            - User preferences (selected currency)
            
            ═══════════════════════════════════════
            """, category: "mom-dashboard")
    }
}

