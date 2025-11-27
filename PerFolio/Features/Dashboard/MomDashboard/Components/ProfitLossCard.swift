import SwiftUI

/// Card showing profit/loss for different time periods
struct ProfitLossCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    let today: Decimal
    let week: Decimal
    let month: Decimal
    let overall: Decimal
    let overallPercent: Decimal
    let currency: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                
                Text("Your Earnings")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            }
            
            // Profit/Loss rows
            VStack(spacing: 12) {
                ProfitRow(
                    period: "Today",
                    amount: today,
                    symbolName: today >= 0 ? "arrow.up.right" : "arrow.down.right",
                    currency: currency
                )
                
                ProfitRow(
                    period: "This Week",
                    amount: week,
                    symbolName: week >= 0 ? "arrow.up.right" : "arrow.down.right",
                    currency: currency
                )
                
                ProfitRow(
                    period: "This Month",
                    amount: month,
                    symbolName: month >= 0 ? "arrow.up.right" : "arrow.down.right",
                    currency: currency
                )
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                // Overall - highlighted
                ProfitRow(
                    period: "Overall",
                    amount: overall,
                    percentage: overallPercent,
                    symbolName: overall >= 0 ? "star.fill" : "arrow.down.right",
                    currency: currency,
                    isHighlighted: true
                )
            }
        }
        .padding(16)
        .background(themeManager.perfolioTheme.secondaryBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(themeManager.perfolioTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Profit Row

struct ProfitRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    let period: String
    let amount: Decimal
    var percentage: Decimal? = nil
    let symbolName: String
    let currency: String
    var isHighlighted: Bool = false
    
    private var isProfit: Bool {
        amount >= 0
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // SF Symbol
            Image(systemName: symbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isProfit ? themeManager.perfolioTheme.success : themeManager.perfolioTheme.danger)
                .frame(width: 28, height: 28)
            
            // Period
            Text(period)
                .font(.system(size: isHighlighted ? 17 : 15, weight: isHighlighted ? .bold : .semibold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            
            Spacer()
            
            // Amount
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(amount >= 0 ? "+" : "")\(formatCurrency(abs(amount)))")
                    .font(.system(size: isHighlighted ? 18 : 16, weight: .bold, design: .rounded))
                    .foregroundStyle(isProfit ? themeManager.perfolioTheme.success : themeManager.perfolioTheme.danger)
                
                if let percentage = percentage {
                    Text("(\(formatPercentage(percentage)))")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            isHighlighted ?
                (isProfit ? Color.green.opacity(0.1) : Color.red.opacity(0.1)) :
                Color.clear
        )
        .cornerRadius(12)
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        guard let curr = Currency.getCurrency(code: currency) else {
            return "\(amount)"
        }
        return curr.format(amount)
    }
    
    private func formatPercentage(_ percent: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.positivePrefix = "+"
        
        return formatter.string(from: (percent / 100) as NSDecimalNumber) ?? "\(percent)%"
    }
}

