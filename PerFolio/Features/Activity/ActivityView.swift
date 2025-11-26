import SwiftUI

/// Activity tab showing all user transactions with search and filter
struct ActivityView: View {
    @StateObject private var viewModel = ActivityViewModel()
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var showFilterSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.perfolioTheme.primaryBackground.ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.activities.isEmpty {
                    loadingView
                } else if viewModel.activities.isEmpty {
                    emptyStateView
                } else {
                    activityList
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $viewModel.searchText, prompt: "Search activities...")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    filterButton
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                filterSheet
            }
            .refreshable {
                await viewModel.refreshActivities()
            }
        }
    }
    
    // MARK: - Activity List
    
    private var activityList: some View {
        ScrollView {
            LazyVStack(spacing: 20, pinnedViews: [.sectionHeaders]) {
                ForEach(viewModel.sortedDates, id: \.self) { date in
                    Section {
                        if let activities = viewModel.groupedActivities[date] {
                            ForEach(activities, id: \.id) { activity in
                                ActivityRowView(activity: activity)
                                    .environmentObject(themeManager)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            viewModel.deleteActivity(activity)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        
                                        if let txHash = activity.txHash {
                                            Button {
                                                if let url = URL(string: "https://etherscan.io/tx/\(txHash)") {
                                                    UIApplication.shared.open(url)
                                                }
                                            } label: {
                                                Label("View on Etherscan", systemImage: "arrow.up.right.square")
                                            }
                                        }
                                    }
                            }
                        }
                    } header: {
                        sectionHeader(text: viewModel.sectionHeader(for: date))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(themeManager.perfolioTheme.primaryBackground)
    }
    
    // MARK: - Filter Button
    
    private var filterButton: some View {
        Button {
            HapticManager.shared.light()
            showFilterSheet = true
        } label: {
            ZStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                
                if viewModel.selectedFilter != nil {
                    Circle()
                        .fill(themeManager.perfolioTheme.danger)
                        .frame(width: 8, height: 8)
                        .offset(x: 10, y: -10)
                }
            }
        }
    }
    
    // MARK: - Filter Sheet
    
    private var filterSheet: some View {
        NavigationStack {
            List {
                Section("Filter by Type") {
                    Button {
                        viewModel.clearFilter()
                        showFilterSheet = false
                    } label: {
                        HStack {
                            Text("All Activities")
                            Spacer()
                            if viewModel.selectedFilter == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                            }
                        }
                    }
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    
                    ForEach(UserActivity.ActivityType.allCases, id: \.self) { type in
                        Button {
                            viewModel.setFilter(type)
                            showFilterSheet = false
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: type.icon)
                                    .foregroundStyle(Color(hex: type.color))
                                
                                Text(type.displayName)
                                
                                Spacer()
                                
                                if viewModel.selectedFilter == type {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                                }
                            }
                        }
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    }
                }
            }
            .navigationTitle("Filter Activities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showFilterSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundStyle(themeManager.perfolioTheme.textTertiary)
            
            Text(viewModel.searchText.isEmpty ? "No Activities Yet" : "No Results Found")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            
            Text(viewModel.searchText.isEmpty ? 
                 "Your transaction history will appear here" :
                 "Try adjusting your search")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(themeManager.perfolioTheme.tintColor)
            
            Text("Loading activities...")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
        }
    }
}

// MARK: - Preview
#Preview {
    ActivityView()
        .environmentObject(ThemeManager.shared)
}

