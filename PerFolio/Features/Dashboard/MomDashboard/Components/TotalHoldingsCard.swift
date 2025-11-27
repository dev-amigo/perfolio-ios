import SwiftUI

/// Large card showing total portfolio value in user's currency
struct TotalHoldingsCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    let totalValue: Decimal
    let paxgValue: Decimal
    let usdcValue: Decimal
    let changeAmount: Decimal
    let changePercent: Decimal
    let currency: String
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Your Total Value")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            
            // Big Number
            Text(formatCurrency(totalValue))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            
            // Breakdown: PAXG + USDC
            HStack(spacing: 12) {
                // PAXG Value (Left)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PAXG")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                    Text(formatCurrency(paxgValue))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "D0B070"), Color(hex: "B88A3C")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
                
                // Plus sign
                Text("+")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                
                // USDC Value (Right)
                VStack(alignment: .leading, spacing: 2) {
                    Text("USDC")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                    Text(formatCurrency(usdcValue))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.blue.opacity(0.9))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(themeManager.perfolioTheme.primaryBackground.opacity(0.5))
            .cornerRadius(10)
            
            // Change indicator
            if changeAmount != 0 || changePercent != 0 {
                HStack(spacing: 8) {
                    Image(systemName: changeAmount >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .font(.system(size: 18))
                    
                    Text("\(changeAmount >= 0 ? "+" : "")\(formatCurrency(abs(changeAmount)))")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    
                    Text("(\(formatPercentage(changePercent)))")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                }
                .foregroundStyle(changeAmount >= 0 ? themeManager.perfolioTheme.success : themeManager.perfolioTheme.danger)
                
                Text("overall")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textTertiary)
            } else {
                Text("Starting baseline")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                colors: [
                    Color.purple.opacity(0.15),
                    Color.blue.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(themeManager.perfolioTheme.secondaryBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        // Use CurrencyService for LIVE rates, not static Currency.getCurrency()
        guard let curr = CurrencyService.shared.getCurrency(code: currency) else {
            return "\(amount)"
        }
        return curr.format(amount)
    }
    
    private func formatPercentage(_ percent: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        
        return formatter.string(from: (percent / 100) as NSDecimalNumber) ?? "\(percent)%"
    }
}

