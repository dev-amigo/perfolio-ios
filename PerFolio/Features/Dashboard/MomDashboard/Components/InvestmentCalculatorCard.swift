import SwiftUI

/// Investment calculator widget with slider and return projections
struct InvestmentCalculatorCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    @Binding var investmentAmount: Decimal
    let calculation: InvestmentCalculation?
    let currency: String
    let onDeposit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 24))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "D0B070"), Color(hex: "B88A3C")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Investment Calculator")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            }
            
            // Investment amount selector
            VStack(alignment: .leading, spacing: 12) {
                Text("If you invest in PAXG:")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                
                Text(formatCurrency(investmentAmount))
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "D0B070"), Color(hex: "B88A3C")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                // Slider with dynamic range based on currency
                // Range: 1,000 to 100,000 in user's currency
                // Step: 1,000 for smooth increments
                Slider(
                    value: Binding(
                        get: { 
                            // Convert Decimal to Double for slider
                            Double(truncating: investmentAmount as NSNumber) 
                        },
                        set: { newValue in
                            // Convert Double back to Decimal
                            // Round to nearest 1000 for clean values
                            let rounded = (newValue / 1000).rounded() * 1000
                            investmentAmount = Decimal(rounded)
                        }
                    ),
                    in: 1000...100000,
                    step: 1000
                )
                .tint(Color(hex: "D0B070"))
                .onChange(of: investmentAmount) { _, _ in
                    HapticManager.shared.light()
                }
                
                // Range labels showing min/max in user's currency
                HStack {
                    Text(formatCurrency(Decimal(1000)))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                    
                    Spacer()
                    
                    Text(formatCurrency(Decimal(100000)))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                }
            }
            
            // Projected returns
            if let calc = calculation {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Potential Returns:")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        .padding(.top, 8)
                    
                    VStack(spacing: 10) {
                        ReturnRow(
                            period: "Daily",
                            amount: calc.dailyReturn,
                            percentage: calc.dailyPercentage,
                            currency: currency
                        )
                        
                        ReturnRow(
                            period: "Weekly",
                            amount: calc.weeklyReturn,
                            percentage: calc.weeklyPercentage,
                            currency: currency
                        )
                        
                        ReturnRow(
                            period: "Monthly",
                            amount: calc.monthlyReturn,
                            percentage: calc.monthlyPercentage,
                            currency: currency
                        )
                        
                        ReturnRow(
                            period: "Yearly",
                            amount: calc.yearlyReturn,
                            percentage: calc.yearlyPercentage,
                            currency: currency,
                            isHighlighted: true
                        )
                    }
                }
                
                // Deposit button
                Button {
                    HapticManager.shared.medium()
                    onDeposit()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("Deposit \(formatCurrency(investmentAmount))")
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "D0B070"), Color(hex: "B88A3C")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .cornerRadius(14)
                }
                .padding(.top, 8)
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
    
    private func formatCurrency(_ amount: Decimal) -> String {
        guard let curr = Currency.getCurrency(code: currency) else {
            return "\(amount)"
        }
        return curr.format(amount)
    }
}

// MARK: - Return Row

struct ReturnRow: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    let period: String
    let amount: Decimal
    let percentage: Decimal
    let currency: String
    var isHighlighted: Bool = false
    
    var body: some View {
        HStack {
            // Period
            Text("• \(period):")
                .font(.system(size: 15, weight: isHighlighted ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isHighlighted ? themeManager.perfolioTheme.textPrimary : themeManager.perfolioTheme.textSecondary)
            
            Spacer()
            
            // Amount
            Text(formatCurrency(amount))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.success)
            
            // Percentage
            Text("(\(formatPercentage(percentage)))")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHighlighted ? themeManager.perfolioTheme.primaryBackground.opacity(0.5) : Color.clear)
        .cornerRadius(8)
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
        formatter.maximumFractionDigits = 2
        formatter.positivePrefix = "+"
        
        return formatter.string(from: (percent / 100) as NSDecimalNumber) ?? "\(percent)%"
    }
}

