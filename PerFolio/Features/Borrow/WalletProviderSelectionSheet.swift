import SwiftUI

/// Sheet for selecting wallet provider before executing borrow transaction
/// Only shown in DEBUG builds when dev mode is enabled
struct WalletProviderSelectionSheet: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @Binding var selectedProvider: WalletProvider
    let onProceed: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Provider Options
                    VStack(spacing: 12) {
                        ForEach(WalletProvider.allCases.filter { $0.isAvailable }) { provider in
                            providerCard(provider)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Warning Banner
                    warningBanner
                    
                    // Proceed Button
                    proceedButton
                }
                .padding(.vertical, 24)
            }
            .background(themeManager.perfolioTheme.primaryBackground)
            .navigationTitle("Select Wallet Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.shared.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "wallet.pass.fill")
                .font(.system(size: 48))
                .foregroundStyle(themeManager.perfolioTheme.tintColor)
                .symbolRenderingMode(.hierarchical)
            
            Text("Choose Transaction Method")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            
            Text("Select which wallet provider to use for signing this transaction")
                .font(.system(size: 15))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }
    
    // MARK: - Provider Card
    
    private func providerCard(_ provider: WalletProvider) -> some View {
        Button {
            HapticManager.shared.medium()
            selectedProvider = provider
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Icon
                    Image(systemName: provider.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 44, height: 44)
                    
                    // Info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(provider.displayName)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                            
                            if let badge = provider.badge {
                                Text(badge)
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        provider == .privyEmbedded 
                                            ? themeManager.perfolioTheme.success.opacity(0.2)
                                            : Color.orange.opacity(0.2)
                                    )
                                    .foregroundStyle(
                                        provider == .privyEmbedded
                                            ? themeManager.perfolioTheme.success
                                            : Color.orange
                                    )
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(provider.description)
                            .font(.system(size: 14))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    // Selection Indicator
                    Image(systemName: selectedProvider == provider ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(selectedProvider == provider ? themeManager.perfolioTheme.tintColor : themeManager.perfolioTheme.textTertiary)
                        .symbolRenderingMode(.hierarchical)
                }
                .padding(16)
                
                // Provider-specific note
                Divider()
                    .background(themeManager.perfolioTheme.border)
                
                HStack(spacing: 8) {
                    Image(systemName: provider == .privyEmbedded ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(provider == .privyEmbedded ? themeManager.perfolioTheme.success : Color.orange)
                    
                    Text(provider == .privyEmbedded 
                        ? "Recommended for production use" 
                        : "For testing only - requires ETH for gas")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(provider == .privyEmbedded ? themeManager.perfolioTheme.success : Color.orange)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background((provider == .privyEmbedded ? themeManager.perfolioTheme.success : Color.orange).opacity(0.1))
            }
            .background(themeManager.perfolioTheme.secondaryBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selectedProvider == provider ? themeManager.perfolioTheme.tintColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Warning Banner
    
    private var warningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Developer Mode")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                
                Text("These options are for testing only and not available in production builds.")
                    .font(.system(size: 12))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Proceed Button
    
    private var proceedButton: some View {
        Button {
            HapticManager.shared.success()
            selectedProvider.select()  // Save to preferences
            dismiss()
            onProceed()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 18))
                
                Text("Proceed with \(selectedProvider.displayName)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(themeManager.perfolioTheme.buttonBackground)
            .cornerRadius(16)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    WalletProviderSelectionSheet(
        selectedProvider: .constant(.privyEmbedded),
        onProceed: {}
    )
    .environmentObject(ThemeManager())
}
#endif

