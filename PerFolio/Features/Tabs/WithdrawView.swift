import SwiftUI

struct WithdrawView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                WithdrawSectionContent()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(themeManager.perfolioTheme.primaryBackground.ignoresSafeArea())
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Withdraw")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            
            Text("Cash out your crypto to your bank account")
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // All other UI lives in WithdrawSectionContent
}

struct WithdrawSectionContent: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var usdcAmount: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            withdrawCard
            withdrawalInfoCard
        }
    }
    
    private var withdrawCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 20) {
                PerFolioSectionHeader(
                    icon: "arrow.up.circle.fill",
                    title: "Cash Out to Bank Account",
                    subtitle: "Convert USDC to INR and transfer to your bank"
                )
                
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                availableBalanceSection
                
                PerFolioInputField(
                    label: "Withdraw Amount",
                    text: $usdcAmount,
                    trailingText: "USDC",
                    presetValues: ["50%", "Max"]
                )
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Receive Currency")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    
                    HStack {
                        Image(systemName: "indianrupeesign")
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        Text("INR")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        Spacer()
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                    }
                    .padding(12)
                    .background(themeManager.perfolioTheme.primaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                
                estimateBreakdown
                
                PerFolioButton("START OFF-RAMP (COMING SOON)", style: .disabled, isDisabled: true) { }
            }
        }
    }
    
    private var availableBalanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Available Balance")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            
            HStack {
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("0.00 USDC")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    Text("≈ ₹0.00")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(themeManager.perfolioTheme.primaryBackground)
            )
        }
    }
    
    private var estimateBreakdown: some View {
        VStack(spacing: 8) {
            PerFolioMetricRow(label: "You'll receive", value: "≈ ₹0.00")
            PerFolioMetricRow(label: "Provider fee", value: "~2-3%")
        }
        .padding(12)
        .background(themeManager.perfolioTheme.primaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private var withdrawalInfoCard: some View {
        PerFolioCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Withdrawal Information")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                
                VStack(alignment: .leading, spacing: 16) {
                    infoRow(
                        icon: "clock.fill",
                        title: "Processing Time",
                        description: "Bank transfers typically take 1-2 business days"
                    )
                    
                    Divider()
                        .background(themeManager.perfolioTheme.border)
                    
                    infoRow(
                        icon: "indianrupeesign.circle.fill",
                        title: "Fees",
                        description: "Provider fees: 2-3% • Bank fees may apply"
                    )
                    
                    Divider()
                        .background(themeManager.perfolioTheme.border)
                    
                    infoRow(
                        icon: "checkmark.shield.fill",
                        title: "Security",
                        description: "All withdrawals are processed via secure payment partners"
                    )
                }
                
                PerFolioInfoBanner(
                    "You'll be redirected to our payment partner to complete the withdrawal"
                )
            }
        }
    }
    
    private func infoRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(themeManager.perfolioTheme.tintColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WithdrawView()
        .environmentObject(ThemeManager())
}
