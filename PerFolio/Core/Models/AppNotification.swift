import Foundation
import SwiftUI

/// Comprehensive notification model supporting all types of alerts
struct AppNotification: Identifiable, Codable {
    let id: String
    let type: NotificationType
    let title: String?
    let message: String
    let icon: String?
    let iconColor: String?
    let imageName: String?
    let imageURL: String?
    let actionButton: NotificationAction?
    let timestamp: Date
    var isRead: Bool
    let priority: NotificationPriority
    
    init(
        id: String = UUID().uuidString,
        type: NotificationType,
        title: String? = nil,
        message: String,
        icon: String? = nil,
        iconColor: String? = nil,
        imageName: String? = nil,
        imageURL: String? = nil,
        actionButton: NotificationAction? = nil,
        timestamp: Date = Date(),
        isRead: Bool = false,
        priority: NotificationPriority = .normal
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.message = message
        self.icon = icon
        self.iconColor = iconColor
        self.imageName = imageName
        self.imageURL = imageURL
        self.actionButton = actionButton
        self.timestamp = timestamp
        self.isRead = isRead
        self.priority = priority
    }
}

/// Notification type for categorization
enum NotificationType: String, Codable {
    case safety      // Loan safety alerts
    case priceChange // Gold price changes
    case transaction // Transaction updates
    case system      // System notifications
    case push        // Push notifications
    case info        // General info
    case warning     // Warnings
    case success     // Success messages
}

/// Notification priority for ordering
enum NotificationPriority: Int, Codable {
    case low = 0
    case normal = 1
    case high = 2
    case urgent = 3
}

/// Action button configuration
struct NotificationAction: Codable {
    let title: String
    let destination: String // Tab name or action identifier
    let style: ActionStyle
    
    enum ActionStyle: String, Codable {
        case primary
        case secondary
        case danger
    }
}

// MARK: - Helper Methods

extension AppNotification {
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    var displayIcon: String {
        if let icon = icon {
            return icon
        }
        
        // Default icons based on type
        switch type {
        case .safety:
            return "shield.fill"
        case .priceChange:
            return "chart.line.uptrend.xyaxis"
        case .transaction:
            return "arrow.left.arrow.right"
        case .system:
            return "gear"
        case .push:
            return "bell.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .success:
            return "checkmark.circle.fill"
        }
    }
    
    func getIconColor(theme: PerFolioTheme) -> Color {
        if let iconColor = iconColor {
            // Parse color string
            switch iconColor {
            case "green": return theme.success
            case "red": return theme.danger
            case "yellow": return Color.yellow
            case "orange": return Color.orange
            case "blue": return Color.blue
            case "purple": return Color.purple
            default: return theme.tintColor
            }
        }
        
        // Default colors based on type
        switch type {
        case .safety, .warning:
            return Color.orange
        case .priceChange:
            return theme.tintColor
        case .transaction, .info:
            return Color.blue
        case .system:
            return theme.textSecondary
        case .push:
            return theme.tintColor
        case .success:
            return theme.success
        }
    }
}

