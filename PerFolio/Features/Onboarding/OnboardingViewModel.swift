import SwiftUI
import SwiftData
import Combine

/// ViewModel for managing onboarding timeline state
@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var isExpanded: Bool = false // Start collapsed
    @Published var hasDepositedUSDC: Bool = false
    @Published var hasSwappedToPAXG: Bool = false
    @Published var hasBorrowed: Bool = false
    @Published var hasVisitedLoans: Bool = false
    @Published var hasWithdrawn: Bool = false
    
    private let activityService = ActivityService.shared
    private var cancellables = Set<AnyCancellable>()
    private var dashboardViewModel: DashboardViewModel?
    
    init() {}
    
    // MARK: - Setup
    
    func setup(modelContext: ModelContext, dashboardViewModel: DashboardViewModel) {
        self.dashboardViewModel = dashboardViewModel
        
        // Observe dashboard balances and positions for real-time updates
        observeDashboardChanges()
        
        // Load initial completion status
        Task {
            await loadCompletionStatus()
        }
    }
    
    private func observeDashboardChanges() {
        guard let dashboardViewModel = dashboardViewModel else { return }
        
        // Observe balance changes to update deposit/swap completion
        dashboardViewModel.$usdcBalance
            .combineLatest(dashboardViewModel.$paxgBalance)
            .sink { [weak self] usdc, paxg in
                self?.hasDepositedUSDC = (usdc?.decimalBalance ?? 0) > 0
                self?.hasSwappedToPAXG = (paxg?.decimalBalance ?? 0) > 0
            }
            .store(in: &cancellables)
        
        // Observe borrow positions to update borrow completion
        dashboardViewModel.$borrowPositions
            .sink { [weak self] positions in
                self?.hasBorrowed = !positions.isEmpty
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Computed Properties
    
    var allStepsCompleted: Bool {
        hasDepositedUSDC && hasSwappedToPAXG && hasBorrowed
    }
    
    var completedStepsCount: Int {
        var count = 0
        if hasDepositedUSDC { count += 1 }
        if hasSwappedToPAXG { count += 1 }
        if hasBorrowed { count += 1 }
        if hasVisitedLoans { count += 1 }
        if hasWithdrawn { count += 1 }
        return count
    }
    
    var totalSteps: Int { 5 }
    
    var progressPercentage: Double {
        Double(completedStepsCount) / Double(totalSteps)
    }
    
    // MARK: - Methods
    
    func loadCompletionStatus() async {
        // Check activities to determine completion
        hasDepositedUSDC = await activityService.hasCompletedActivity(type: .deposit)
        hasSwappedToPAXG = await activityService.hasCompletedActivity(type: .swap)
        hasBorrowed = await activityService.hasCompletedActivity(type: .borrow)
        hasWithdrawn = await activityService.hasCompletedActivity(type: .withdraw)
        
        // hasVisitedLoans is tracked separately (no activity type for just viewing)
        hasVisitedLoans = UserDefaults.standard.bool(forKey: "hasVisitedLoansTab")
        
        AppLogger.log("📊 Onboarding progress: \(completedStepsCount)/\(totalSteps)", category: "onboarding")
    }
    
    func toggleExpanded() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded.toggle()
        }
        HapticManager.shared.light()
    }
    
    func markLoansVisited() {
        hasVisitedLoans = true
        UserDefaults.standard.set(true, forKey: "hasVisitedLoansTab")
    }
    
    // MARK: - Step Definitions
    
    struct TimelineStep: Identifiable {
        let id = UUID()
        let title: String
        let description: String
        let actionTitle: String
        let isCompleted: Bool
        let color: Color
        let icon: String
        let action: () -> Void
    }
    
    func getSteps(navigationHandler: @escaping (String) -> Void) -> [TimelineStep] {
        [
            TimelineStep(
                title: "Deposit USDC",
                description: "Buy USDC with INR using UPI or card via OnMeta. Instant deposit to your wallet.",
                actionTitle: "Go to Deposit",
                isCompleted: self.hasDepositedUSDC,
                color: Color.green,
                icon: "arrow.down.circle.fill",
                action: { navigationHandler("wallet") }
            ),
            TimelineStep(
                title: "Swap to PAXG",
                description: "Convert USDC to PAXG (tokenized gold) at best rates via DEX aggregator.",
                actionTitle: "Go to Swap",
                isCompleted: self.hasSwappedToPAXG,
                color: Color.blue,
                icon: "arrow.left.arrow.right.circle.fill",
                action: { navigationHandler("wallet") }
            ),
            TimelineStep(
                title: "Borrow USDC",
                description: "Use PAXG as collateral to borrow USDC instantly via Fluid Protocol at low interest rates.",
                actionTitle: "Go to Borrow",
                isCompleted: self.hasBorrowed,
                color: Color.yellow,
                icon: "banknote.fill",
                action: { navigationHandler("borrow") }
            ),
            TimelineStep(
                title: "Manage Active Loans",
                description: "View and manage your active loans. Repay debt, add collateral, or withdraw excess collateral.",
                actionTitle: "View Loans",
                isCompleted: self.hasVisitedLoans,
                color: Color(hex: "D4AF37"), // Golden
                icon: "list.bullet.rectangle.fill",
                action: { [weak self] in
                    navigationHandler("loans")
                    self?.markLoansVisited()
                }
            ),
            TimelineStep(
                title: "Withdraw to Bank",
                description: "Convert USDC back to INR and withdraw directly to your bank account via Transak.",
                actionTitle: "Go to Withdraw",
                isCompleted: self.hasWithdrawn,
                color: Color.green,
                icon: "arrow.up.circle.fill",
                action: { navigationHandler("wallet") }
            )
        ]
    }
}

