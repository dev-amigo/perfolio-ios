import Foundation
import SwiftData

/// User activity model for tracking all app actions
@Model
final class UserActivity {
    @Attribute(.unique) var id: UUID
    var type: ActivityType
    var amount: Decimal
    var tokenSymbol: String
    var timestamp: Date
    var status: ActivityStatus
    var txHash: String?
    var activityDescription: String
    var fromToken: String?  // For swaps
    var toToken: String?    // For swaps
    var metadata: String?   // JSON string for additional data
    
    init(
        id: UUID = UUID(),
        type: ActivityType,
        amount: Decimal,
        tokenSymbol: String,
        timestamp: Date = Date(),
        status: ActivityStatus = .completed,
        txHash: String? = nil,
        activityDescription: String,
        fromToken: String? = nil,
        toToken: String? = nil,
        metadata: String? = nil
    ) {
        self.id = id
        self.type = type
        self.amount = amount
        self.tokenSymbol = tokenSymbol
        self.timestamp = timestamp
        self.status = status
        self.txHash = txHash
        self.activityDescription = activityDescription
        self.fromToken = fromToken
        self.toToken = toToken
        self.metadata = metadata
    }
}

// MARK: - Activity Type
extension UserActivity {
    enum ActivityType: String, Codable, CaseIterable {
        case deposit = "deposit"
        case swap = "swap"
        case borrow = "borrow"
        case repay = "repay"
        case addCollateral = "add_collateral"
        case withdraw = "withdraw"
        case loanClose = "loan_close"
        case withdrawCollateral = "withdraw_collateral"
        
        var displayName: String {
            switch self {
            case .deposit: return "Deposit"
            case .swap: return "Swap"
            case .borrow: return "Borrow"
            case .repay: return "Repay"
            case .addCollateral: return "Add Collateral"
            case .withdraw: return "Withdraw"
            case .loanClose: return "Close Loan"
            case .withdrawCollateral: return "Withdraw Collateral"
            }
        }
        
        var icon: String {
            switch self {
            case .deposit: return "arrow.down.circle.fill"
            case .swap: return "arrow.triangle.2.circlepath"
            case .borrow: return "dollarsign.circle.fill"
            case .repay: return "creditcard.fill"
            case .addCollateral: return "plus.circle.fill"
            case .withdraw: return "arrow.up.circle.fill"
            case .loanClose: return "checkmark.circle.fill"
            case .withdrawCollateral: return "minus.circle.fill"
            }
        }
        
        var color: String {
            switch self {
            case .deposit: return "#4CAF50"  // Green
            case .swap: return "#2196F3"     // Blue
            case .borrow: return "#FF9800"   // Orange
            case .repay: return "#9C27B0"    // Purple
            case .addCollateral: return "#00BCD4"  // Cyan
            case .withdraw: return "#F44336" // Red
            case .loanClose: return "#4CAF50" // Green
            case .withdrawCollateral: return "#FF5722" // Deep Orange
            }
        }
    }
    
    enum ActivityStatus: String, Codable {
        case pending = "pending"
        case completed = "completed"
        case failed = "failed"
        
        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .completed: return "Completed"
            case .failed: return "Failed"
            }
        }
        
        var icon: String {
            switch self {
            case .pending: return "clock.fill"
            case .completed: return "checkmark.circle.fill"
            case .failed: return "xmark.circle.fill"
            }
        }
    }
}

// MARK: - Helpers
extension UserActivity {
    /// Get formatted amount with token symbol
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 6
        
        let amountStr = formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "0"
        return "\(amountStr) \(tokenSymbol)"
    }
    
    /// Get formatted timestamp
    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
    
    /// Get detailed timestamp
    var detailedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    /// Check if activity is for swap
    var isSwap: Bool {
        type == .swap
    }
    
    /// Get swap description if applicable
    var swapDescription: String? {
        guard isSwap, let from = fromToken, let to = toToken else { return nil }
        return "\(from) → \(to)"
    }
}

