import SwiftUI

/// Flexible notification row supporting all types of content
struct NotificationRowView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let notification: AppNotification
    let onTap: () -> Void
    let onActionTap: (() -> Void)?
    
    var body: some View {
        Button {
            HapticManager.shared.light()
            onTap()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                // Icon (always visible)
                Image(systemName: notification.displayIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(notification.getIconColor(theme: themeManager.perfolioTheme))
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title (optional)
                    if let title = notification.title {
                        Text(title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    }
                    
                    // Message (always visible)
                    Text(notification.message)
                        .font(.system(size: 15))
                        .foregroundStyle(notification.isRead ? themeManager.perfolioTheme.textSecondary : themeManager.perfolioTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Image (optional)
                    if let imageName = notification.imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .cornerRadius(12)
                    }
                    
                    // Action Button (optional)
                    if let action = notification.actionButton, let onActionTap = onActionTap {
                        Button {
                            HapticManager.shared.medium()
                            onActionTap()
                        } label: {
                            Text(action.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(
                                    action.style == .danger ? themeManager.perfolioTheme.danger :
                                    action.style == .primary ? .white :
                                    themeManager.perfolioTheme.tintColor
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(
                                    action.style == .danger ? themeManager.perfolioTheme.danger.opacity(0.2) :
                                    action.style == .primary ? themeManager.perfolioTheme.tintColor :
                                    themeManager.perfolioTheme.tintColor.opacity(0.15)
                                )
                                .cornerRadius(10)
                        }
                    }
                    
                    // Timestamp
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                        Text(notification.timeAgo)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                }
                
                Spacer(minLength: 0)
                
                // Unread indicator
                if !notification.isRead {
                    Circle()
                        .fill(themeManager.perfolioTheme.tintColor)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .background(
                notification.isRead ? Color.clear : themeManager.perfolioTheme.tintColor.opacity(0.05)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 0) {
        // Text with icon
        NotificationRowView(
            notification: AppNotification(
                type: .info,
                message: "Your gold increased today by ₹320",
                icon: "checkmark.circle.fill",
                iconColor: "green"
            ),
            onTap: {},
            onActionTap: nil
        )
        
        Divider()
        
        // Text with icon and title
        NotificationRowView(
            notification: AppNotification(
                type: .safety,
                title: "Loan Safety Alert",
                message: "Your loan ratio is at 74%. Consider adding gold or repaying.",
                icon: "exclamationmark.triangle.fill",
                iconColor: "orange"
            ),
            onTap: {},
            onActionTap: nil
        )
        
        Divider()
        
        // With action button
        NotificationRowView(
            notification: AppNotification(
                type: .transaction,
                title: "Transaction Complete",
                message: "Successfully borrowed 500 USDC",
                icon: "checkmark.circle.fill",
                iconColor: "green",
                actionButton: NotificationAction(
                    title: "View Details",
                    destination: "transactions",
                    style: .primary
                )
            ),
            onTap: {},
            onActionTap: {}
        )
        
        Divider()
        
        // Unread notification
        NotificationRowView(
            notification: AppNotification(
                type: .priceChange,
                title: "Price Alert",
                message: "Gold price increased by 5% today!",
                icon: "arrow.up.circle.fill",
                iconColor: "green",
                isRead: false
            ),
            onTap: {},
            onActionTap: nil
        )
    }
    .environmentObject(ThemeManager())
}

