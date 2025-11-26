import SwiftUI

/// Individual activity row displaying transaction details
struct ActivityRowView: View {
    let activity: UserActivity
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color(hex: activity.type.color).opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: activity.type.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color(hex: activity.type.color))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(activity.type.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    
                    Spacer()
                    
                    // Amount
                    Text(activity.isSwap && activity.toToken != nil ? 
                         "+\(activity.formattedAmount)" : activity.formattedAmount)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                }
                
                HStack {
                    // Description or swap info
                    if activity.isSwap, let swapDesc = activity.swapDescription {
                        Text(swapDesc)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    } else {
                        Text(activity.activityDescription)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    // Timestamp
                    Text(activity.formattedTimestamp)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                }
                
                // Status indicator (if not completed)
                if activity.status != .completed {
                    HStack(spacing: 4) {
                        Image(systemName: activity.status.icon)
                            .font(.system(size: 10))
                        Text(activity.status.displayName)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(activity.status == .failed ? 
                                   themeManager.perfolioTheme.danger : themeManager.perfolioTheme.warning)
                }
            }
        }
        .padding(16)
        .background(themeManager.perfolioTheme.secondaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - Preview
// Preview temporarily disabled due to Swift 6 Preview macro conflicts
// Uncomment when project migrates to Swift 6 or preview issues are resolved

