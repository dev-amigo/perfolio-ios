import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SettingsViewModel()
    var onLogout: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            List {
                // User Profile Section
                userProfileSection
                
                // App Settings Section
                appSettingsSection
                
                // Support & Legal Section
                supportLegalSection
                
                // Libraries Section
                librariesSection
                
                // Logout Section
                logoutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(themeManager.perfolioTheme.primaryBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.shared.light()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingSafari) {
                if let url = viewModel.safariURL {
                    SafariView(url: url) {}
                }
            }
            .alert("Logout", isPresented: $viewModel.showingLogoutConfirmation) {
                Button("Cancel", role: .cancel) {
                    HapticManager.shared.light()
                }
                Button("Logout", role: .destructive) {
                    HapticManager.shared.heavy()
                    viewModel.logout()
                    dismiss()
                    onLogout?()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                versionFooter
            }
        }
    }
    
    // MARK: - User Profile Section
    
    private var userProfileSection: some View {
        Section {
            HStack(spacing: 16) {
                // Profile Icon
                Circle()
                    .fill(themeManager.perfolioTheme.tintColor.opacity(0.15))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                            .symbolRenderingMode(.hierarchical)
                    )
                
                // User Info
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.userEmail)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        .lineLimit(1)
                    
                    if let walletAddress = viewModel.walletAddress {
                        HStack(spacing: 6) {
                            Text(viewModel.truncatedAddress(walletAddress))
                                .font(.system(size: 13, weight: .regular, design: .monospaced))
                                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                            
                            Button {
                                HapticManager.shared.light()
                                viewModel.copyAddress(walletAddress)
                            } label: {
                                Image(systemName: viewModel.addressCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .font(.system(size: 12))
                                    .foregroundStyle(viewModel.addressCopied ? .green : themeManager.perfolioTheme.tintColor)
                                    .symbolRenderingMode(.hierarchical)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
            .listRowBackground(themeManager.perfolioTheme.secondaryBackground)
        }
    }
    
    // MARK: - App Settings Section
    
    private var appSettingsSection: some View {
        Section {
            // Dark Mode (always on)
            HStack(spacing: 12) {
                Image(systemName: "moon.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 28, alignment: .center)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dark Mode")
                        .font(.system(size: 17, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    Text("Always enabled")
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
                    .disabled(true)
                    .tint(themeManager.perfolioTheme.tintColor)
            }
            .listRowBackground(themeManager.perfolioTheme.secondaryBackground)
            
            // Haptic Feedback
            HStack(spacing: 12) {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 28, alignment: .center)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Haptic Feedback")
                        .font(.system(size: 17, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    Text("Vibration on interactions")
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.isHapticEnabled)
                    .labelsHidden()
                    .tint(themeManager.perfolioTheme.tintColor)
                    .onChange(of: viewModel.isHapticEnabled) { _, newValue in
                        if newValue {
                            HapticManager.shared.medium()
                        }
                    }
            }
            .listRowBackground(themeManager.perfolioTheme.secondaryBackground)
            
            // Sound Effects
            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(viewModel.isHapticEnabled ? themeManager.perfolioTheme.tintColor : themeManager.perfolioTheme.textTertiary)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 28, alignment: .center)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sound Effects")
                        .font(.system(size: 17, design: .rounded))
                        .foregroundStyle(viewModel.isHapticEnabled ? themeManager.perfolioTheme.textPrimary : themeManager.perfolioTheme.textTertiary)
                    Text("Audio feedback on haptics")
                        .font(.system(size: 13))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $viewModel.isSoundEnabled)
                    .labelsHidden()
                    .disabled(!viewModel.isHapticEnabled)
                    .tint(themeManager.perfolioTheme.tintColor)
                    .onChange(of: viewModel.isSoundEnabled) { _, newValue in
                        if newValue {
                            HapticManager.shared.medium()
                        }
                    }
            }
            .listRowBackground(themeManager.perfolioTheme.secondaryBackground)
        } header: {
            Text("App Settings")
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
        }
    }
    
    // MARK: - Support & Legal Section
    
    private var supportLegalSection: some View {
        Section {
            // Email Support
            Button {
                HapticManager.shared.light()
                viewModel.openEmail()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 28, alignment: .center)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Email Support")
                            .font(.system(size: 17, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        Text("support@perfolio.com")
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                }
            }
            .listRowBackground(themeManager.perfolioTheme.secondaryBackground)
            
            // Terms of Service
            Button {
                HapticManager.shared.light()
                viewModel.openTermsOfService()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 28, alignment: .center)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Terms of Service")
                            .font(.system(size: 17, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        Text("Read our terms")
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                }
            }
            .listRowBackground(themeManager.perfolioTheme.secondaryBackground)
            
            // Privacy Policy
            Button {
                HapticManager.shared.light()
                viewModel.openPrivacyPolicy()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 28, alignment: .center)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Privacy Policy")
                            .font(.system(size: 17, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        Text("Your data privacy")
                            .font(.system(size: 13))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                }
            }
            .listRowBackground(themeManager.perfolioTheme.secondaryBackground)
        } header: {
            Text("Support & Legal")
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
        }
    }
    
    // MARK: - Libraries Section
    
    private var librariesSection: some View {
        Section {
            ForEach(viewModel.libraries) { library in
                Button {
                    if library.licenseURL != nil {
                        HapticManager.shared.light()
                        viewModel.openLibraryLicense(library)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 28, alignment: .center)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(library.name)
                                .font(.system(size: 17, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                            Text(library.version)
                                .font(.system(size: 13))
                                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        if library.licenseURL != nil {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                        }
                    }
                }
                .disabled(library.licenseURL == nil)
                .listRowBackground(themeManager.perfolioTheme.secondaryBackground)
            }
        } header: {
            Text("Libraries & Dependencies")
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
        }
    }
    
    // MARK: - Logout Section
    
    private var logoutSection: some View {
        Section {
            Button {
                HapticManager.shared.medium()
                viewModel.showLogoutConfirmation()
            } label: {
                HStack {
                    Spacer()
                    
                    Label("Logout", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(Color.red)
        }
    }
    
    // MARK: - Version Footer
    
    private var versionFooter: some View {
        VStack(spacing: 4) {
            Text("Version \(viewModel.appVersion) (\(viewModel.buildNumber))")
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textTertiary)
            
            Text("Made with ❤️ in India")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textTertiary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(themeManager.perfolioTheme.primaryBackground.opacity(0.95))
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
}
