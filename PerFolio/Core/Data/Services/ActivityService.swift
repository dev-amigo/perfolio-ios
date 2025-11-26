import Foundation
import SwiftData

/// Service for managing user activities with SwiftData
@MainActor
final class ActivityService: ObservableObject {
    static let shared = ActivityService()
    
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?
    
    @Published var activities: [UserActivity] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private init() {
        setupModelContainer()
    }
    
    // MARK: - Setup
    
    private func setupModelContainer() {
        do {
            let schema = Schema([UserActivity.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = ModelContext(modelContainer!)
            
            AppLogger.log("✅ ActivityService initialized with SwiftData", category: "activity")
        } catch {
            AppLogger.log("❌ Failed to initialize SwiftData: \(error.localizedDescription)", category: "activity")
            self.error = error
        }
    }
    
    // MARK: - Create
    
    /// Log a new activity
    func logActivity(
        type: UserActivity.ActivityType,
        amount: Decimal,
        tokenSymbol: String,
        status: UserActivity.ActivityStatus = .completed,
        txHash: String? = nil,
        description: String,
        fromToken: String? = nil,
        toToken: String? = nil,
        metadata: String? = nil
    ) {
        guard let context = modelContext else {
            AppLogger.log("❌ ModelContext not available", category: "activity")
            return
        }
        
        let activity = UserActivity(
            type: type,
            amount: amount,
            tokenSymbol: tokenSymbol,
            status: status,
            txHash: txHash,
            activityDescription: description,
            fromToken: fromToken,
            toToken: toToken,
            metadata: metadata
        )
        
        context.insert(activity)
        
        do {
            try context.save()
            AppLogger.log("✅ Activity logged: \(type.displayName) - \(amount) \(tokenSymbol)", category: "activity")
            
            // Refresh activities list
            Task {
                await fetchRecentActivities()
            }
        } catch {
            AppLogger.log("❌ Failed to save activity: \(error.localizedDescription)", category: "activity")
            self.error = error
        }
    }
    
    // MARK: - Read
    
    /// Fetch all activities sorted by timestamp (newest first)
    func fetchAllActivities() async {
        guard let context = modelContext else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let descriptor = FetchDescriptor<UserActivity>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            activities = try context.fetch(descriptor)
            AppLogger.log("📊 Fetched \(activities.count) activities", category: "activity")
        } catch {
            AppLogger.log("❌ Failed to fetch activities: \(error.localizedDescription)", category: "activity")
            self.error = error
        }
    }
    
    /// Fetch recent activities (last 50)
    func fetchRecentActivities(limit: Int = 50) async {
        guard let context = modelContext else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            var descriptor = FetchDescriptor<UserActivity>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            descriptor.fetchLimit = limit
            
            activities = try context.fetch(descriptor)
            AppLogger.log("📊 Fetched \(activities.count) recent activities", category: "activity")
        } catch {
            AppLogger.log("❌ Failed to fetch recent activities: \(error.localizedDescription)", category: "activity")
            self.error = error
        }
    }
    
    /// Fetch activities by type
    func fetchActivities(ofType type: UserActivity.ActivityType) async -> [UserActivity] {
        guard let context = modelContext else { return [] }
        
        do {
            let descriptor = FetchDescriptor<UserActivity>(
                predicate: #Predicate { $0.type == type },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            return try context.fetch(descriptor)
        } catch {
            AppLogger.log("❌ Failed to fetch activities by type: \(error.localizedDescription)", category: "activity")
            return []
        }
    }
    
    /// Search activities by description or token
    func searchActivities(query: String) async -> [UserActivity] {
        guard let context = modelContext else { return [] }
        guard !query.isEmpty else {
            return activities
        }
        
        do {
            let descriptor = FetchDescriptor<UserActivity>(
                predicate: #Predicate { activity in
                    activity.activityDescription.localizedStandardContains(query) ||
                    activity.tokenSymbol.localizedStandardContains(query)
                },
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            return try context.fetch(descriptor)
        } catch {
            AppLogger.log("❌ Failed to search activities: \(error.localizedDescription)", category: "activity")
            return []
        }
    }
    
    /// Get activities grouped by date
    func fetchActivitiesGroupedByDate() async -> [Date: [UserActivity]] {
        guard let context = modelContext else { return [:] }
        
        do {
            let descriptor = FetchDescriptor<UserActivity>(
                sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
            )
            let allActivities = try context.fetch(descriptor)
            
            // Group by date (ignoring time)
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: allActivities) { activity in
                calendar.startOfDay(for: activity.timestamp)
            }
            
            return grouped
        } catch {
            AppLogger.log("❌ Failed to group activities: \(error.localizedDescription)", category: "activity")
            return [:]
        }
    }
    
    // MARK: - Update
    
    /// Update activity status
    func updateActivityStatus(id: UUID, status: UserActivity.ActivityStatus) {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<UserActivity>(
                predicate: #Predicate { $0.id == id }
            )
            if let activity = try context.fetch(descriptor).first {
                activity.status = status
                try context.save()
                AppLogger.log("✅ Updated activity status: \(status.displayName)", category: "activity")
            }
        } catch {
            AppLogger.log("❌ Failed to update activity status: \(error.localizedDescription)", category: "activity")
        }
    }
    
    // MARK: - Delete
    
    /// Delete specific activity
    func deleteActivity(id: UUID) {
        guard let context = modelContext else { return }
        
        do {
            let descriptor = FetchDescriptor<UserActivity>(
                predicate: #Predicate { $0.id == id }
            )
            if let activity = try context.fetch(descriptor).first {
                context.delete(activity)
                try context.save()
                AppLogger.log("✅ Deleted activity", category: "activity")
                
                // Refresh list
                Task {
                    await fetchRecentActivities()
                }
            }
        } catch {
            AppLogger.log("❌ Failed to delete activity: \(error.localizedDescription)", category: "activity")
        }
    }
    
    /// Delete all activities
    func deleteAllActivities() {
        guard let context = modelContext else { return }
        
        do {
            try context.delete(model: UserActivity.self)
            try context.save()
            activities = []
            AppLogger.log("✅ Deleted all activities", category: "activity")
        } catch {
            AppLogger.log("❌ Failed to delete all activities: \(error.localizedDescription)", category: "activity")
        }
    }
    
    // MARK: - Analytics
    
    /// Get total count of activities
    func getTotalActivityCount() async -> Int {
        guard let context = modelContext else { return 0 }
        
        do {
            let descriptor = FetchDescriptor<UserActivity>()
            return try context.fetchCount(descriptor)
        } catch {
            return 0
        }
    }
    
    /// Check if user has completed specific activity type
    func hasCompletedActivity(type: UserActivity.ActivityType) async -> Bool {
        let activities = await fetchActivities(ofType: type)
        return activities.contains { $0.status == .completed }
    }
    
    /// Get activity count by type
    func getActivityCount(type: UserActivity.ActivityType) async -> Int {
        let activities = await fetchActivities(ofType: type)
        return activities.count
    }
}

// MARK: - Convenience Methods
extension ActivityService {
    /// Log a deposit activity
    func logDeposit(amount: Decimal, currency: String, txHash: String? = nil) {
        logActivity(
            type: .deposit,
            amount: amount,
            tokenSymbol: currency,
            txHash: txHash,
            description: "Deposited \(amount) \(currency) via OnMeta"
        )
    }
    
    /// Log a swap activity
    func logSwap(fromAmount: Decimal, fromToken: String, toAmount: Decimal, toToken: String, txHash: String? = nil) {
        logActivity(
            type: .swap,
            amount: toAmount,
            tokenSymbol: toToken,
            txHash: txHash,
            description: "Swapped \(fromAmount) \(fromToken) to \(toAmount) \(toToken)",
            fromToken: fromToken,
            toToken: toToken
        )
    }
    
    /// Log a borrow activity
    func logBorrow(amount: Decimal, collateral: Decimal, txHash: String? = nil) {
        logActivity(
            type: .borrow,
            amount: amount,
            tokenSymbol: "USDC",
            txHash: txHash,
            description: "Borrowed \(amount) USDC with \(collateral) PAXG collateral"
        )
    }
    
    /// Log a repay activity
    func logRepay(amount: Decimal, txHash: String? = nil) {
        logActivity(
            type: .repay,
            amount: amount,
            tokenSymbol: "USDC",
            txHash: txHash,
            description: "Repaid \(amount) USDC"
        )
    }
    
    /// Log a withdrawal activity
    func logWithdraw(amount: Decimal, currency: String, txHash: String? = nil) {
        logActivity(
            type: .withdraw,
            amount: amount,
            tokenSymbol: currency,
            txHash: txHash,
            description: "Withdrew \(amount) \(currency) to bank"
        )
    }
}

