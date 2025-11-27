import Foundation

/// Investment return calculations for the calculator widget
/// All amounts are in the user's selected currency
struct InvestmentCalculation {
    let investmentAmount: Decimal      // Amount in user's currency
    let dailyReturn: Decimal           // Daily return in user's currency
    let weeklyReturn: Decimal          // Weekly return in user's currency
    let monthlyReturn: Decimal         // Monthly return in user's currency
    let yearlyReturn: Decimal          // Yearly return in user's currency
    let dailyPercentage: Decimal       // Daily return as percentage
    let weeklyPercentage: Decimal      // Weekly return as percentage
    let monthlyPercentage: Decimal     // Monthly return as percentage
    let yearlyPercentage: Decimal      // Yearly return as percentage
    
    /// Calculate investment returns based on APY
    /// 
    /// **CALCULATION METHODOLOGY:**
    /// Uses simple interest calculation for DeFi lending returns
    /// Formula: Return = Principal × (APY / Time Periods in Year)
    /// 
    /// **EXAMPLE with 8% APY on ₹10,000:**
    /// - Daily: ₹10,000 × (0.08 / 365) = ₹2.19 per day (0.022% daily)
    /// - Weekly: ₹10,000 × (0.08 / 52) = ₹15.38 per week (0.154% weekly)
    /// - Monthly: ₹10,000 × (0.08 / 12) = ₹66.67 per month (0.667% monthly)
    /// - Yearly: ₹10,000 × 0.08 = ₹800 per year (8% annually)
    /// 
    /// - Parameters:
    ///   - amount: Investment amount in user's currency (e.g., ₹10000, $1000, €900)
    ///   - apy: Annual Percentage Yield as decimal (0.08 = 8%)
    /// - Returns: InvestmentCalculation with all returns in same currency as input
    static func calculate(amount: Decimal, apy: Decimal) -> InvestmentCalculation {
        // Break down APY into different time periods
        // 
        // Daily Rate: APY / 365 days
        // Weekly Rate: APY / 52 weeks  
        // Monthly Rate: APY / 12 months
        // Yearly Rate: APY (unchanged)
        
        let dailyRate = apy / Decimal(365)           // e.g., 0.08 / 365 = 0.000219
        let weeklyRate = apy / Decimal(52)           // e.g., 0.08 / 52 = 0.001538
        let monthlyRate = apy / Decimal(12)          // e.g., 0.08 / 12 = 0.006667
        let yearlyRate = apy                         // e.g., 0.08
        
        // Calculate returns by multiplying principal by rate
        let dailyReturn = amount * dailyRate         // e.g., ₹10000 × 0.000219 = ₹2.19
        let weeklyReturn = amount * weeklyRate       // e.g., ₹10000 × 0.001538 = ₹15.38
        let monthlyReturn = amount * monthlyRate     // e.g., ₹10000 × 0.006667 = ₹66.67
        let yearlyReturn = amount * yearlyRate       // e.g., ₹10000 × 0.08 = ₹800
        
        // Convert rates to percentages for display
        let dailyPercentage = dailyRate * 100        // e.g., 0.000219 × 100 = 0.022%
        let weeklyPercentage = weeklyRate * 100      // e.g., 0.001538 × 100 = 0.154%
        let monthlyPercentage = monthlyRate * 100    // e.g., 0.006667 × 100 = 0.667%
        let yearlyPercentage = yearlyRate * 100      // e.g., 0.08 × 100 = 8%
        
        return InvestmentCalculation(
            investmentAmount: amount,
            dailyReturn: dailyReturn,
            weeklyReturn: weeklyReturn,
            monthlyReturn: monthlyReturn,
            yearlyReturn: yearlyReturn,
            dailyPercentage: dailyPercentage,
            weeklyPercentage: weeklyPercentage,
            monthlyPercentage: monthlyPercentage,
            yearlyPercentage: yearlyPercentage
        )
    }
    
    /// Format return amount in user's currency
    func formatReturn(_ amount: Decimal, in currency: String) -> String {
        // Use CurrencyService for LIVE rates, not static Currency.getCurrency()
        guard let curr = CurrencyService.shared.getCurrency(code: currency) else {
            return "\(amount)"
        }
        return curr.format(amount)
    }
    
    /// Format percentage with sign
    func formatPercentage(_ percentage: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        
        return formatter.string(from: (percentage / 100) as NSDecimalNumber) ?? "\(percentage)%"
    }
}

