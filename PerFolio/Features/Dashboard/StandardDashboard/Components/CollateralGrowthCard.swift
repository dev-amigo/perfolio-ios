import SwiftUI

/// Collateral Growth Card - Shows current gold and borrowing power
struct CollateralGrowthCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    let currentCollateral: String
    let paxgBalance: Decimal
    let availableToBorrow: String
    let onAddGold: () -> Void
    
    var body: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    
                    Text("Your Collateral")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    
                    Spacer()
                }
                
                // Info banner
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    
                    Text("More gold = More borrowing power")
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                }
                .padding(12)
                .background(themeManager.perfolioTheme.tintColor.opacity(0.1))
                .cornerRadius(10)
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                // Current Collateral
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Gold Collateral")
                        .font(.caption)
                        .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                    
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(currentCollateral)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        
                        Text("(\(formatDecimal(paxgBalance)) PAXG)")
                            .font(.system(size: 16))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                }
                
                // Borrowing Power
                VStack(alignment: .leading, spacing: 8) {
                    Text("You Can Borrow")
                        .font(.caption)
                        .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                    
                    Text(availableToBorrow)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.success)
                }
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                // Action
                Button {
                    HapticManager.shared.medium()
                    onAddGold()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                        
                        Text("Add More Gold to Increase Borrowing Power")
                            .font(.system(size: 15, weight: .semibold))
                        
                        Spacer()
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14))
                    }
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    .padding(14)
                    .background(themeManager.perfolioTheme.tintColor.opacity(0.15))
                    .cornerRadius(12)
                }
            }
            .padding(20)
        }
    }
    
    private func formatDecimal(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 4
        return formatter.string(from: value as NSDecimalNumber) ?? "0"
    }
}

#Preview {
    CollateralGrowthCard(
        currentCollateral: "₹3,485",
        paxgBalance: 0.001,
        availableToBorrow: "₹261.60",
        onAddGold: {}
    )
    .environmentObject(ThemeManager())
    .padding()
}

