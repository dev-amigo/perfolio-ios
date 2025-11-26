import SwiftUI
import TipKit

/// Game Center-style onboarding timeline view for all users with tutorial tips
struct OnboardingTimelineView: View {
    @ObservedObject var onboardingViewModel: OnboardingViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Callback for navigation
    var onNavigate: ((String) -> Void)?
    
    // Tutorial tips (sequential with rules)
    let depositTip = DepositUSDCTip()
    let swapTip = SwapToPAXGTip()
    let borrowTip = BorrowUSDCTip()
    let loansTip = ManageLoansTip()
    let withdrawTip = WithdrawBankTip()
    
    // Manual info tips (always available)
    let depositInfoTip = DepositInfoTip()
    let swapInfoTip = SwapInfoTip()
    let borrowInfoTip = BorrowInfoTip()
    let loansInfoTip = LoansInfoTip()
    let withdrawInfoTip = WithdrawInfoTip()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - Always visible
            headerView
                .onTapGesture {
                    onboardingViewModel.toggleExpanded()
                }
            
            // Expandable content
            if onboardingViewModel.isExpanded {
                timelineContent
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95, anchor: .top).combined(with: .opacity),
                        removal: .scale(scale: 0.95, anchor: .top).combined(with: .opacity)
                    ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            themeManager.perfolioTheme.secondaryBackground,
                            themeManager.perfolioTheme.secondaryBackground.opacity(0.95),
                            Color(hex: "D4AF37").opacity(0.15) // Golden tint
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(hex: "D4AF37").opacity(0.3), lineWidth: 1.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // Icon with golden tint
            ZStack {
                Circle()
                    .fill(Color(hex: "D4AF37").opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(Color(hex: "D4AF37"))
            }
            
            // Title and progress
            VStack(alignment: .leading, spacing: 4) {
                Text("Get Started")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                
                Text("\(onboardingViewModel.completedStepsCount) of \(onboardingViewModel.totalSteps) steps completed")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            }
            
            Spacer()
            
            // Progress circle and chevron
            HStack(spacing: 12) {
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                        .frame(width: 32, height: 32)
                    
                    Circle()
                        .trim(from: 0, to: onboardingViewModel.progressPercentage)
                        .stroke(Color(hex: "D4AF37"), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 32, height: 32)
                        .rotationEffect(.degrees(-90))
                    
                    if onboardingViewModel.allStepsCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(themeManager.perfolioTheme.success)
                    }
                }
                
                // Expand/collapse chevron
                Image(systemName: onboardingViewModel.isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    .rotationEffect(.degrees(onboardingViewModel.isExpanded ? 0 : 180))
            }
        }
        .padding(16)
    }
    
    // MARK: - Timeline Content
    
    private var timelineContent: some View {
        VStack(spacing: 0) {
            // Divider
            Rectangle()
                .fill(Color(hex: "D4AF37").opacity(0.2))
                .frame(height: 1)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            
            // Steps with arrow separators and manual info tips only
            VStack(spacing: 0) {
                ForEach(Array(onboardingViewModel.getSteps(navigationHandler: handleNavigation).enumerated()), id: \.element.id) { index, step in
                    TimelineStepCard(
                        title: step.title,
                        description: step.description,
                        actionTitle: step.actionTitle,
                        isCompleted: step.isCompleted,
                        stepColor: step.color,
                        stepIcon: step.icon,
                        tip: nil, // Disabled automatic tutorial tips
                        manualTip: getManualTipForStep(index),
                        onTipAction: { actionId in
                            handleTipAction(actionId, stepIndex: index)
                        },
                        onInfoTap: {
                            handleInfoTap(stepIndex: index)
                        },
                        action: step.action
                    )
                    .environmentObject(themeManager)
                    
                    // Arrow separator (except after last step)
                    if index < onboardingViewModel.totalSteps - 1 {
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.down")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color.gray.opacity(0.3))
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(16)
        }
    }
    
    // MARK: - Navigation Handler
    
    private func handleNavigation(_ destination: String) {
        AppLogger.log("📍 Navigating to: \(destination)", category: "onboarding")
        onNavigate?(destination)
        
        // Collapse after navigation (only if tutorial is complete)
        if onboardingViewModel.isExpanded && onboardingViewModel.isTutorialComplete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onboardingViewModel.toggleExpanded()
            }
        }
    }
    
    // MARK: - Tip Helpers
    
    private func getTipForStep(_ index: Int) -> (any Tip)? {
        switch index {
        case 0: return depositTip
        case 1: return swapTip
        case 2: return borrowTip
        case 3: return loansTip
        case 4: return withdrawTip
        default: return nil
        }
    }
    
    private func getManualTipForStep(_ index: Int) -> (any Tip)? {
        switch index {
        case 0: return depositInfoTip
        case 1: return swapInfoTip
        case 2: return borrowInfoTip
        case 3: return loansInfoTip
        case 4: return withdrawInfoTip
        default: return nil
        }
    }
    
    private func handleInfoTap(stepIndex: Int) {
        HapticManager.shared.light()
        
        // Invalidate the tip so it can be shown again
        Task { @MainActor in
            switch stepIndex {
            case 0:
                await depositInfoTip.resetEligibility()
            case 1:
                await swapInfoTip.resetEligibility()
            case 2:
                await borrowInfoTip.resetEligibility()
            case 3:
                await loansInfoTip.resetEligibility()
            case 4:
                await withdrawInfoTip.resetEligibility()
            default:
                break
            }
        }
        
        AppLogger.log("ℹ️ Manual info tip invalidated for step \(stepIndex), will re-show", category: "onboarding")
    }
    
    private func handleTipAction(_ actionId: String, stepIndex: Int) {
        HapticManager.shared.medium()
        
        AppLogger.log("🔔 Tip action: \(actionId) at step \(stepIndex)", category: "onboarding")
        
        switch stepIndex {
        case 0: // Deposit tip
            if actionId == "next" {
                Task { @MainActor in
                    depositTip.invalidate(reason: .actionPerformed)
                    
                    // Small delay to ensure invalidation completes
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    
                    SwapToPAXGTip.hasSeenDepositTip = true
                    AppLogger.log("✅ Deposit tip completed, swap tip should appear now", category: "onboarding")
                }
            }
            
        case 1: // Swap tip
            if actionId == "next" {
                Task { @MainActor in
                    swapTip.invalidate(reason: .actionPerformed)
                    
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    
                    BorrowUSDCTip.hasSeenSwapTip = true
                    AppLogger.log("✅ Swap tip completed, borrow tip should appear now", category: "onboarding")
                }
            }
            
        case 2: // Borrow tip
            if actionId == "next" {
                Task { @MainActor in
                    borrowTip.invalidate(reason: .actionPerformed)
                    
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    
                    ManageLoansTip.hasSeenBorrowTip = true
                    AppLogger.log("✅ Borrow tip completed, loans tip should appear now", category: "onboarding")
                }
            }
            
        case 3: // Loans tip
            if actionId == "next" {
                Task { @MainActor in
                    loansTip.invalidate(reason: .actionPerformed)
                    
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    
                    WithdrawBankTip.hasSeenLoansTip = true
                    AppLogger.log("✅ Loans tip completed, withdraw tip should appear now", category: "onboarding")
                }
            }
            
        case 4: // Withdraw tip (last one)
            if actionId == "finish" {
                Task { @MainActor in
                    withdrawTip.invalidate(reason: .actionPerformed)
                    onboardingViewModel.completeTutorial()
                    AppLogger.log("🎉 Tutorial finished!", category: "onboarding")
                }
            }
            
        default:
            break
        }
    }
}

// Note: Color(hex:) extension already exists in PerFolioTheme.swift

