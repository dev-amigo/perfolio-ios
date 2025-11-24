import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var currentPage = 0
    let onComplete: () -> Void
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "circle.grid.cross.fill",
            title: "Welcome to PerFolio",
            subtitle: "Your digital gold vault with instant liquidity"
        ),
        OnboardingPage(
            icon: "creditcard.fill",
            title: "Buy Digital Gold",
            subtitle: "Deposit cash via UPI and convert to tokenized gold (PAXG)"
        ),
        OnboardingPage(
            icon: "arrow.left.arrow.right",
            title: "Instant Swaps",
            subtitle: "Seamlessly swap between USDC and gold tokens anytime"
        ),
        OnboardingPage(
            icon: "shield.checkered",
            title: "Secure Gold Loans",
            subtitle: "Borrow USDC instantly against your gold with competitive rates"
        )
    ]
    
    var body: some View {
        ZStack {
            themeManager.perfolioTheme.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    if currentPage < pages.count - 1 {
                        Button {
                            HapticManager.shared.light()
                            onComplete()
                        } label: {
                            HStack(spacing: 8) {
                                Text("Skip")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(themeManager.perfolioTheme.tintColor.opacity(0.15))
                            )
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .frame(height: 60)
                
                // Pages
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? themeManager.perfolioTheme.tintColor : themeManager.perfolioTheme.textTertiary.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == index ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.vertical, 24)
                
                // Getting Started button (only on last page)
                if currentPage == pages.count - 1 {
                    PerFolioButton("Get Started") {
                        HapticManager.shared.heavy()
                        onComplete()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Spacer()
                        .frame(height: 100)
                }
            }
        }
        .onChange(of: currentPage) { _, _ in
            HapticManager.shared.selection()
        }
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
}

// MARK: - Onboarding Page View

struct OnboardingPageView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(themeManager.perfolioTheme.tintColor.opacity(0.15))
                    .frame(width: 160, height: 160)
                
                Circle()
                    .fill(themeManager.perfolioTheme.tintColor.opacity(0.08))
                    .frame(width: 200, height: 200)
                
                Image(systemName: page.icon)
                    .font(.system(size: 80, weight: .regular))
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.bottom, 20)
            
            // Title
            Text(page.title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            // Subtitle
            Text(page.subtitle)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    OnboardingView(onComplete: {})
        .environmentObject(ThemeManager())
}

