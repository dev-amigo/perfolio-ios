import SwiftUI
import TipKit

/// Individual timeline step - compact design with colored icons
struct TimelineStepCard: View {
    let title: String
    let description: String
    let actionTitle: String
    let isCompleted: Bool
    let stepColor: Color
    let stepIcon: String
    let tip: (any Tip)?
    let manualTip: (any Tip)?
    let onTipAction: ((String) -> Void)?
    let onInfoTap: (() -> Void)?
    let action: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showManualTip = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkmark - gray when incomplete, green when completed
            Image(systemName: isCompleted ? "checkmark.circle.fill" : "checkmark.circle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(isCompleted ? themeManager.perfolioTheme.success : Color.gray.opacity(0.4))
            
            VStack(alignment: .leading, spacing: 6) {
                // Title with colored icon
                HStack(spacing: 8) {
                    Image(systemName: stepIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(stepColor)
                    
                    Text(title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    
                    Spacer()
                }
                
                // Description
                Text(description)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Action button with info icon
                HStack(spacing: 8) {
                    Button {
                        HapticManager.shared.light()
                        action()
                    } label: {
                        HStack(spacing: 6) {
                            Text(actionTitle)
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(stepColor)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(stepColor.opacity(0.12))
                        )
                    }
                    .if(tip != nil) { view in
                        view.popoverTip(tip!, arrowEdge: .top) { action in
                            onTipAction?(action.id)
                        }
                    }
                    
                    // Info icon - always available for manual tip display
                    if manualTip != nil {
                        Button {
                            HapticManager.shared.light()
                            showManualTip = true
                            onInfoTap?()
                        } label: {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(themeManager.perfolioTheme.textSecondary.opacity(0.6))
                        }
                        .popover(isPresented: $showManualTip, arrowEdge: .top) {
                            if let tip = manualTip {
                                TipView(tip)
                                    .presentationCompactAdaptation(.popover)
                            }
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 12)
        .opacity(isCompleted ? 0.6 : 1.0)
    }
}

// MARK: - View Extension for Conditional Modifiers

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview
// Preview temporarily disabled due to Swift 6 Preview macro conflicts
// Uncomment when project migrates to Swift 6 or preview issues are resolved

