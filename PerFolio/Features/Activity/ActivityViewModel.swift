import SwiftUI
import Combine

/// ViewModel for managing activity list and search
@MainActor
final class ActivityViewModel: ObservableObject {
    @Published var activities: [UserActivity] = []
    @Published var groupedActivities: [Date: [UserActivity]] = [:]
    @Published var searchText: String = ""
    @Published var isLoading = false
    @Published var selectedFilter: UserActivity.ActivityType? = nil
    
    private let activityService = ActivityService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupSearchBinding()
        Task {
            await loadActivities()
        }
    }
    
    // MARK: - Setup
    
    private func setupSearchBinding() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { @MainActor in
                    await self?.performSearch(query: query)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Loading
    
    func loadActivities() async {
        isLoading = true
        defer { isLoading = false }
        
        if let filter = selectedFilter {
            activities = await activityService.fetchActivities(ofType: filter)
        } else {
            await activityService.fetchRecentActivities(limit: 100)
            activities = activityService.activities
        }
        
        groupActivitiesByDate()
        AppLogger.log("📊 Loaded \(activities.count) activities", category: "activity")
    }
    
    func refreshActivities() async {
        await loadActivities()
    }
    
    // MARK: - Search
    
    private func performSearch(query: String) async {
        if query.isEmpty {
            await loadActivities()
        } else {
            isLoading = true
            defer { isLoading = false }
            
            activities = await activityService.searchActivities(query: query)
            groupActivitiesByDate()
            AppLogger.log("🔍 Search results: \(activities.count) activities", category: "activity")
        }
    }
    
    // MARK: - Filtering
    
    func setFilter(_ type: UserActivity.ActivityType?) {
        selectedFilter = type
        Task {
            await loadActivities()
        }
    }
    
    func clearFilter() {
        selectedFilter = nil
        Task {
            await loadActivities()
        }
    }
    
    // MARK: - Grouping
    
    private func groupActivitiesByDate() {
        let calendar = Calendar.current
        groupedActivities = Dictionary(grouping: activities) { activity in
            calendar.startOfDay(for: activity.timestamp)
        }
    }
    
    // Get sorted dates for section headers
    var sortedDates: [Date] {
        groupedActivities.keys.sorted(by: >)
    }
    
    // Get section header text for date
    func sectionHeader(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    // MARK: - Actions
    
    func deleteActivity(_ activity: UserActivity) {
        activityService.deleteActivity(id: activity.id)
        Task {
            await loadActivities()
        }
    }
}

