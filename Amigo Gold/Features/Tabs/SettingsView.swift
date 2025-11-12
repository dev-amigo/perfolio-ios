import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var biometricEnabled = true

    var body: some View {
        NavigationStack {
            List {
                profileSection
                securitySection
                legalSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .background(themeManager.palette.background)
        }
    }

    private var profileSection: some View {
        Section("Profile") {
            HStack(spacing: 16) {
                Circle()
                    .fill(themeManager.palette.foreground.opacity(0.2))
                    .frame(width: 54, height: 54)
                    .overlay(
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(themeManager.palette.foreground)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ava Nakamoto")
                        .font(.headline)
                    Text("ava@amigogold.com")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.palette.subdued)
                }
            }

            NavigationLink("Manage Privy Sessions") {}
            NavigationLink("Notification Preferences") {}
        }
    }

    private var securitySection: some View {
        Section("Security") {
            Toggle(isOn: $biometricEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Biometric Login")
                    Text("Use Face ID / Touch ID for quick auth")
                        .font(.caption)
                        .foregroundStyle(themeManager.palette.subdued)
                }
            }
            Button("View Recovery Phrase") {}
            Button("Device Trust Settings") {}
        }
    }

    private var legalSection: some View {
        Section("Legal") {
            Link(destination: URL(string: "https://amigogold.com/privacy")!) {
                Text("Privacy Policy")
            }
            Link(destination: URL(string: "https://amigogold.com/terms")!) {
                Text("Terms of Service")
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
}
