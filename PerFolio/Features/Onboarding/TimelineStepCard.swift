import SwiftUI

/// Individual timeline step card with completion status and action button
struct TimelineStepCard: View {
    let stepNumber: Int
    let title: String
    let description: String
    let actionTitle: String
    let isCompleted: Bool
    let action: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step indicator
            ZStack {
                Circle()
                    .fill(isCompleted ? themeManager.perfolioTheme.success : themeManager.perfolioTheme.secondaryBackground)
                    .frame(width: 40, height: 40)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(stepNumber)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                
                // Description
                Text(description)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    .lineSpacing(4)
                
                // Action button
                if !isCompleted {
                    Button {
                        HapticManager.shared.light()
                        action()
                    } label: {
                        HStack(spacing: 6) {
                            Text(actionTitle)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeManager.perfolioTheme.tintColor.opacity(0.15))
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.perfolioTheme.secondaryBackground)
        )
        .opacity(isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        TimelineStepCard(
            stepNumber: 1,
            title: "Deposit USDC",
            description: "Buy USDC with INR using UPI or card via OnMeta. Instant deposit to your wallet.",
            actionTitle: "Go to Deposit",
            isCompleted: false
        ) {
            print("Navigate to deposit")
        }
        
        TimelineStepCard(
            stepNumber: 2,
            title: "Swap to PAXG",
            description: "Convert USDC to PAXG (tokenized gold) at best rates via DEX.",
            actionTitle: "Go to Swap",
            isCompleted: true
        ) {
            print("Navigate to swap")
        }
    }
    .padding()
    .background(Color.black)
    .environmentObject(ThemeManager.shared)
}

