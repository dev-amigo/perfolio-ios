import SwiftUI
import Combine

/// ViewModel for managing onboarding timeline state
@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var isExpanded: Bool = true
    @Published var hasDepositedUSDC: Bool = false
    @Published var hasSwappedToPAXG: Bool = false
    @Published var hasBorrowed: Bool = false
    @Published var hasVisitedLoans: Bool = false
    @Published var hasWithdrawn: Bool = false
    
    private let activityService = ActivityService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Load completion status from activities
        Task {
            await loadCompletionStatus()
        }
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
    
    struct TimelineStep {
        let number: Int
        let title: String
        let description: String
        let actionTitle: String
        let isCompleted: Bool
        let action: () -> Void
    }
    
    func getSteps(navigationHandler: @escaping (String) -> Void) -> [TimelineStep] {
        [
            TimelineStep(
                number: 1,
                title: "Deposit USDC",
                description: "Buy USDC with INR using UPI or card via OnMeta. Instant deposit to your wallet.",
                actionTitle: "Go to Deposit",
                isCompleted: hasDepositedUSDC,
                action: { navigationHandler("wallet") }
            ),
            TimelineStep(
                number: 2,
                title: "Swap to PAXG",
                description: "Convert USDC to PAXG (tokenized gold) at best rates via DEX aggregator.",
                actionTitle: "Go to Swap",
                isCompleted: hasSwappedToPAXG,
                action: { navigationHandler("wallet") }
            ),
            TimelineStep(
                number: 3,
                title: "Borrow USDC",
                description: "Use PAXG as collateral to borrow USDC instantly via Fluid Protocol at low interest rates.",
                actionTitle: "Go to Borrow",
                isCompleted: hasBorrowed,
                action: { navigationHandler("borrow") }
            ),
            TimelineStep(
                number: 4,
                title: "Manage Active Loans",
                description: "View and manage your active loans. Repay debt, add collateral, or withdraw excess collateral.",
                actionTitle: "View Loans",
                isCompleted: hasVisitedLoans,
                action: { 
                    navigationHandler("loans")
                    markLoansVisited()
                }
            ),
            TimelineStep(
                number: 5,
                title: "Withdraw to Bank",
                description: "Convert USDC back to INR and withdraw directly to your bank account via Transak.",
                actionTitle: "Go to Withdraw",
                isCompleted: hasWithdrawn,
                action: { navigationHandler("wallet") }
            )
        ]
    }
}

