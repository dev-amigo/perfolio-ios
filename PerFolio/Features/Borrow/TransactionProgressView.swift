import SwiftUI

/// Modal view showing transaction progress during borrow execution
struct TransactionProgressView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let state: BorrowViewModel.TransactionState
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            themeManager.perfolioTheme.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon or animation
                transactionIcon
                
                // Title and message
                VStack(spacing: 12) {
                    Text(titleText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text(messageText)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                // Progress indicator
                if case .checkingApproval = state,
                   case .approvingPAXG = state,
                   case .depositingAndBorrowing = state {
                    progressSteps
                }
                
                Spacer()
                
                // Action button (only for success/failed)
                if case .success = state {
                    PerFolioButton("DONE") {
                        onDismiss()
                    }
                    .padding(.horizontal, 20)
                } else if case .failed = state {
                    PerFolioButton("TRY AGAIN") {
                        onDismiss()
                    }
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 40)
        }
        .interactiveDismissDisabled(isProcessing)
    }
    
    // MARK: - Transaction Icon
    
    @ViewBuilder
    private var transactionIcon: some View {
        switch state {
        case .idle:
            EmptyView()
            
        case .checkingApproval, .approvingPAXG, .depositingAndBorrowing:
            ZStack {
                Circle()
                    .fill(themeManager.perfolioTheme.buttonBackground.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.perfolioTheme.tintColor))
                    .scaleEffect(2.0)
            }
            
        case .success:
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
            }
            
        case .failed:
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.red)
            }
        }
    }
    
    // MARK: - Progress Steps
    
    private var progressSteps: some View {
        VStack(spacing: 16) {
            stepRow(number: 1, title: "Checking Approval", isActive: isStep1Active, isCompleted: isStep1Completed)
            stepRow(number: 2, title: "Approving PAXG", isActive: isStep2Active, isCompleted: isStep2Completed)
            stepRow(number: 3, title: "Depositing & Borrowing", isActive: isStep3Active, isCompleted: isStep3Completed)
        }
        .padding(.horizontal, 40)
    }
    
    private func stepRow(number: Int, title: String, isActive: Bool, isCompleted: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : (isActive ? themeManager.perfolioTheme.buttonBackground : themeManager.perfolioTheme.border))
                    .frame(width: 32, height: 32)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                } else {
                    Text("\(number)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(isActive ? themeManager.perfolioTheme.primaryBackground : themeManager.perfolioTheme.textSecondary)
                }
            }
            
            Text(title)
                .font(.system(size: 15, weight: isActive ? .semibold : .regular, design: .rounded))
                .foregroundStyle(isActive ? themeManager.perfolioTheme.textPrimary : themeManager.perfolioTheme.textSecondary)
            
            Spacer()
            
            if isActive && !isCompleted {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: themeManager.perfolioTheme.tintColor))
                    .scaleEffect(0.8)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var titleText: String {
        switch state {
        case .idle:
            return ""
        case .checkingApproval:
            return "Checking Approval"
        case .approvingPAXG:
            return "Approving PAXG"
        case .depositingAndBorrowing:
            return "Creating Position"
        case .success(let positionId):
            return "Borrow Successful! 🎉"
        case .failed:
            return "Transaction Failed"
        }
    }
    
    private var messageText: String {
        switch state {
        case .idle:
            return ""
        case .checkingApproval:
            return "Verifying PAXG allowance..."
        case .approvingPAXG:
            return "Please confirm the approval transaction in your wallet"
        case .depositingAndBorrowing:
            return "Please confirm the deposit + borrow transaction in your wallet"
        case .success(let positionId):
            return "Your position NFT #\(positionId) has been created. USDC has been sent to your wallet."
        case .failed(let error):
            return error
        }
    }
    
    private var isProcessing: Bool {
        switch state {
        case .checkingApproval, .approvingPAXG, .depositingAndBorrowing:
            return true
        default:
            return false
        }
    }
    
    private var isStep1Active: Bool {
        if case .checkingApproval = state { return true }
        return false
    }
    
    private var isStep1Completed: Bool {
        switch state {
        case .approvingPAXG, .depositingAndBorrowing, .success:
            return true
        default:
            return false
        }
    }
    
    private var isStep2Active: Bool {
        if case .approvingPAXG = state { return true }
        return false
    }
    
    private var isStep2Completed: Bool {
        switch state {
        case .depositingAndBorrowing, .success:
            return true
        default:
            return false
        }
    }
    
    private var isStep3Active: Bool {
        if case .depositingAndBorrowing = state { return true }
        return false
    }
    
    private var isStep3Completed: Bool {
        if case .success = state { return true }
        return false
    }
}

// MARK: - Preview

#Preview {
    TransactionProgressView(
        state: .approvingPAXG,
        onDismiss: {}
    )
    .environmentObject(ThemeManager())
}

