import SwiftUI

/// Card showing breakdown of PAXG and USDC holdings
struct AssetBreakdownCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    let paxgAmount: Decimal
    let paxgValueUSD: Decimal
    let paxgValueLocal: Decimal
    let usdcAmount: Decimal
    let usdcValueLocal: Decimal
    let currency: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "bitcoinsign.circle.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                
                Text("Your Gold & Money")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            }
            
            // PAXG Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color(hex: "FFD700"))
                    
                    Text("Gold (PAXG)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                }
                
                // Amount in oz
                Text("\(formatAmount(paxgAmount)) oz")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.yellow)
                
                // Values
                VStack(spacing: 6) {
                    HStack {
                        Text("Worth in USD:")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        Spacer()
                        Text("$\(formatAmount(paxgValueUSD))")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    }
                    
                    HStack {
                        Text("Worth in \(currency):")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        Spacer()
                        Text(formatCurrency(paxgValueLocal))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.yellow)
                    }
                }
            }
            .padding(16)
            .background(Color.yellow.opacity(0.08))
            .cornerRadius(12)
            
            // USDC Section
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.green)
                    
                    Text("Cash (USDC)")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                }
                
                // Amount in USDC
                Text("$\(formatAmount(usdcAmount))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.green)
                
                // Value in local currency
                HStack {
                    Text("Worth in \(currency):")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    Spacer()
                    Text(formatCurrency(usdcValueLocal))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.green)
                }
            }
            .padding(16)
            .background(Color.green.opacity(0.08))
            .cornerRadius(12)
        }
        .padding(16)
        .background(themeManager.perfolioTheme.secondaryBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(themeManager.perfolioTheme.border, lineWidth: 1)
        )
    }
    
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(amount)"
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        guard let curr = Currency.getCurrency(code: currency) else {
            return "\(amount)"
        }
        return curr.format(amount)
    }
}

