import SwiftUI

/// Safety Alerts Card - Color-coded warning banners
struct SafetyAlertsCard: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    let alerts: [SafetyAlert]
    
    var body: some View {
        if !alerts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                // Section Header
                HStack(spacing: 8) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    
                    Text("Alerts")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    
                    Spacer()
                }
                .padding(.top, 8)
                
                // Alerts List (Simple Rows)
                VStack(spacing: 12) {
                    ForEach(alerts) { alert in
                        alertRow(alert)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func alertRow(_ alert: SafetyAlert) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alertIcon(for: alert.type))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(alertColor(for: alert.type))
            
            Text(alert.message)
                .font(.system(size: 15))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Helper Functions
    
    private func alertColor(for type: SafetyAlert.AlertType) -> Color {
        switch type {
        case .info:
            return themeManager.perfolioTheme.success
        case .caution:
            return Color.yellow
        case .warning:
            return themeManager.perfolioTheme.danger
        }
    }
    
    private func alertIcon(for type: SafetyAlert.AlertType) -> String {
        switch type {
        case .info:
            return "checkmark.circle.fill"
        case .caution:
            return "exclamationmark.triangle.fill"
        case .warning:
            return "xmark.octagon.fill"
        }
    }
}

#Preview {
    SafetyAlertsCard(
        alerts: [
            SafetyAlert(
                type: .info,
                message: "Your gold increased today by ₹320"
            ),
            SafetyAlert(
                type: .caution,
                message: "Loan ratio reached 55%. You are still safe but monitor the gold price."
            ),
            SafetyAlert(
                type: .warning,
                message: "Loan ratio is 82%. Add gold or repay to avoid liquidation."
            )
        ]
    )
    .environmentObject(ThemeManager())
    .padding()
}

