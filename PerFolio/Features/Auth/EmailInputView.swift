import SwiftUI

struct EmailInputView: View {
    @Binding var email: String
    let onContinue: () -> Void
    let isLoading: Bool
    
    @FocusState private var isEmailFocused: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    
    private var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    var body: some View {
        ZStack {
            themeManager.perfolioTheme.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                Image(systemName: "circle.grid.cross.fill")
                    .font(.system(size: 80))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                
                // Title and Subtitle
                VStack(spacing: 12) {
                    Text("Welcome to PerFolio")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    
                    Text("Deposit cash, buy gold, and get instant loans")
                        .font(.system(size: 16, design: .rounded))
                        .lineLimit(3)
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                
                // Email Input Section
                VStack(spacing: 20) {
                    Text("Enter your email")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Simple text field with dark background
                    HStack(spacing: 12) {
                        TextField("", text: $email, prompt: Text("your@email.com").foregroundColor(.gray.opacity(0.5)))
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled(true)
                            .focused($isEmailFocused)
                            .submitLabel(.continue)
                            .onChange(of: email) { oldValue, newValue in
                                // Trim whitespace and normalize
                                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmed != newValue {
                                    email = trimmed
                                }
                            }
                            .onSubmit {
                                if isValidEmail && !isLoading {
                                    onContinue()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.8))
                            )
                        
                        if !email.isEmpty {
                            Image(systemName: isValidEmail ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(isValidEmail ? themeManager.perfolioTheme.success : themeManager.perfolioTheme.danger)
                                .padding(.trailing, 16)
                        }
                    }
                    
                    // Email validation hint
                    if !email.isEmpty && !isValidEmail {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                            Text("Please enter a valid email address")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(themeManager.perfolioTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)
                
                // Continue Button
                PerFolioButton(
                    isLoading ? "Sending code..." : "Continue",
                    isLoading: isLoading,
                    isDisabled: !isValidEmail
                ) {
                    onContinue()
                }
                .padding(.horizontal, 24)
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isEmailFocused = true
            }
        }
    }
}

#Preview {
    EmailInputView(
        email: .constant(""),
        onContinue: {},
        isLoading: false
    )
    .environmentObject(ThemeManager())
}

