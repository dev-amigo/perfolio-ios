import SwiftUI

/// Reusable expandable section component for Wallet view
/// Provides smooth expand/collapse animation with header and content
struct ExpandableSection<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 16) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(themeManager.perfolioTheme.tintColor.opacity(0.15))
                        )
                    
                    // Title & Subtitle
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Chevron indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(20)
                .background(themeManager.perfolioTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isExpanded ? themeManager.perfolioTheme.tintColor.opacity(0.3) : Color.clear,
                            lineWidth: 2
                        )
                )
            }
            .buttonStyle(.plain)
            
            // Content (expandable)
            if isExpanded {
                content()
                    .transition(.asymmetric(
                        insertion: .push(from: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
                    .padding(.top, 12)
            }
        }
    }
}

#Preview {
    struct PreviewContainer: View {
        @State private var isExpanded1 = true
        @State private var isExpanded2 = false
        
        var body: some View {
            ScrollView {
                VStack(spacing: 16) {
                    ExpandableSection(
                        icon: "arrow.down.circle.fill",
                        title: "Deposit",
                        subtitle: "Buy gold with fiat currency",
                        isExpanded: $isExpanded1
                    ) {
                        VStack(spacing: 12) {
                            Text("Deposit content here")
                                .foregroundStyle(.white)
                            Text("This section is expanded")
                                .foregroundStyle(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    ExpandableSection(
                        icon: "arrow.up.circle.fill",
                        title: "Withdraw",
                        subtitle: "Cash out to your bank account",
                        isExpanded: $isExpanded2
                    ) {
                        VStack(spacing: 12) {
                            Text("Withdraw content here")
                                .foregroundStyle(.white)
                            Text("This section is collapsed by default")
                                .foregroundStyle(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(20)
            }
            .background(Color.black.ignoresSafeArea())
            .environmentObject(ThemeManager())
        }
    }
    
    return PreviewContainer()
}

