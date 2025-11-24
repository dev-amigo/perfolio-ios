import SwiftUI

struct EmailVerificationView: View {
    let email: String
    let onCodeEntered: (String) -> Void
    let onCancel: () -> Void
    let onResendCode: () -> Void
    let isLoading: Bool
    
    @State private var code: String = ""
    @FocusState private var isCodeFocused: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    
    private var digits: [String] {
        var result = code.map { String($0) }
        while result.count < 6 {
            result.append("")
        }
        return Array(result.prefix(6))
    }
    
    var body: some View {
        ZStack {
            themeManager.perfolioTheme.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar with Back Button
                HStack {
                    Button(action: {
                        HapticManager.shared.light()
                        onCancel()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                            .padding(12)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 20)
                        
                        // Icon
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 60))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        
                        // Title and Instructions
                        VStack(spacing: 12) {
                            Text("Check your email")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                            
                            Text("We sent a verification code to")
                                .font(.system(size: 16, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                            
                            Text(email)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        
                        // OTP Input Section
                        VStack(spacing: 24) {
                            Text("Enter 6-digit code")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                            
                            // Individual digit boxes
                            ZStack {
                                // Hidden text field for iOS OTP support
                                TextField("", text: $code)
                                    .keyboardType(.numberPad)
                                    .textContentType(.oneTimeCode)
                                    .focused($isCodeFocused)
                                    .opacity(0.01)
                                    .frame(width: 1, height: 1)
                                    .onChange(of: code) { oldValue, newValue in
                                        // Only allow digits
                                        let filtered = newValue.filter { $0.isNumber }
                                        if filtered != newValue {
                                            code = filtered
                                        }
                                        // Limit to 6 digits
                                        if code.count > 6 {
                                            code = String(code.prefix(6))
                                        }
                                        // Auto-submit when 6 digits entered
                                        if code.count == 6 && !isLoading {
                                            isCodeFocused = false
                                            HapticManager.shared.medium()
                                            onCodeEntered(code)
                                        }
                                    }
                                
                                // Visual digit boxes
                                HStack(spacing: 12) {
                                    ForEach(0..<6, id: \.self) { index in
                                        DigitBox(
                                            digit: digits[index],
                                            isFilled: index < code.count,
                                            theme: themeManager.perfolioTheme
                                        )
                                        .onTapGesture {
                                            isCodeFocused = true
                                        }
                                    }
                                }
                            }
                            
                            // Code counter
                            Text("\(code.count)/6")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                        }
                        .padding(.horizontal, 24)
                        
                        // Actions
                        VStack(spacing: 16) {
                            PerFolioButton(
                                isLoading ? "Verifying..." : "Verify Code",
                                isLoading: isLoading,
                                isDisabled: code.count != 6 || isLoading
                            ) {
                                HapticManager.shared.medium()
                                onCodeEntered(code)
                            }
                            
                            Button(action: {
                                HapticManager.shared.medium()
                                onResendCode()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Resend code")
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(themeManager.perfolioTheme.tintColor)
                                .padding(.vertical, 12)
                            }
                        }
                        .padding(.horizontal, 24)
                        
                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isCodeFocused = true
            }
        }
    }
}

// Individual digit box component
struct DigitBox: View {
    let digit: String
    let isFilled: Bool
    let theme: PerFolioTheme
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(theme.secondaryBackground)
                .frame(width: 48, height: 64)
            
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isFilled ? theme.tintColor : theme.border, lineWidth: 2)
                .frame(width: 48, height: 64)
            
            Text(digit.isEmpty ? "" : digit)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(theme.tintColor)
        }
    }
}

#Preview {
    EmailVerificationView(
        email: "user@example.com",
        onCodeEntered: { _ in },
        onCancel: {},
        onResendCode: {},
        isLoading: false
    )
    .environmentObject(ThemeManager())
}

