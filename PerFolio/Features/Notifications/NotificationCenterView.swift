import SwiftUI

/// Notification Center - Shows all app notifications and alerts
struct NotificationCenterView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedFilter: NotificationType? = nil
    var onNavigateToTab: ((String) -> Void)?
    
    var filteredNotifications: [AppNotification] {
        if let filter = selectedFilter {
            return notificationManager.notifications.filter { $0.type == filter }
        }
        return notificationManager.notifications
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.perfolioTheme.primaryBackground.ignoresSafeArea()
                
                if notificationManager.notifications.isEmpty {
                    emptyStateView
                } else {
                    contentView
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
                
                if !notificationManager.notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                HapticManager.shared.light()
                                notificationManager.markAllAsRead()
                            } label: {
                                Label("Mark All Read", systemImage: "checkmark.circle")
                            }
                            
                            Button(role: .destructive) {
                                HapticManager.shared.medium()
                                notificationManager.clearAll()
                            } label: {
                                Label("Clear All", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(themeManager.perfolioTheme.tintColor)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Content View
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Filter chips (if needed in future)
                // filterSection
                
                // Notifications list
                LazyVStack(spacing: 0) {
                    ForEach(filteredNotifications) { notification in
                        VStack(spacing: 0) {
                            NotificationRowView(
                                notification: notification,
                                onTap: {
                                    notificationManager.markAsRead(notification.id)
                                },
                                onActionTap: notification.actionButton != nil ? {
                                    handleAction(notification)
                                } : nil
                            )
                            
                            Divider()
                                .background(themeManager.perfolioTheme.border)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 60))
                .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                .symbolRenderingMode(.hierarchical)
            
            Text("No Notifications")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            
            Text("You're all caught up! New notifications will appear here.")
                .font(.system(size: 15))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Action Handler
    
    private func handleAction(_ notification: AppNotification) {
        guard let action = notification.actionButton else { return }
        
        // Mark as read
        notificationManager.markAsRead(notification.id)
        
        // Close notification center
        dismiss()
        
        // Navigate to destination
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onNavigateToTab?(action.destination)
        }
    }
}

#Preview {
    NotificationCenterView()
        .environmentObject(ThemeManager())
}

