import Foundation

enum LoanAction: Identifiable {
    case payBack(BorrowPosition)
    case addCollateral(BorrowPosition)
    case withdrawCollateral(BorrowPosition)
    case close(BorrowPosition)
    
    var id: String {
        switch self {
        case .payBack(let position),
             .addCollateral(let position),
             .withdrawCollateral(let position),
             .close(let position):
            return position.id + title
        }
    }
    
    var title: String {
        switch self {
        case .payBack:
            return "Pay Back Loan"
        case .addCollateral:
            return "Add More Gold"
        case .withdrawCollateral:
            return "Take Gold Back"
        case .close:
            return "Close Loan"
        }
    }
    
    var confirmTitle: String {
        switch self {
        case .close:
            return "Close Loan"
        case .payBack:
            return "Pay Back"
        case .addCollateral:
            return "Add Gold"
        case .withdrawCollateral:
            return "Withdraw"
        }
    }
    
    var description: String {
        switch self {
        case .payBack:
            return "Enter how much USDC you want to repay. You can pay the full balance or a partial amount."
        case .addCollateral:
            return "Add extra PAXG to make your loan safer and open up more borrowing room."
        case .withdrawCollateral:
            return "Withdraw a portion of your locked PAXG if your health factor is in a safe range."
        case .close:
            return "Repay the remaining balance and withdraw all collateral in a single workflow."
        }
    }
    
    var requiresAmount: Bool {
        switch self {
        case .close:
            return false
        case .payBack, .addCollateral, .withdrawCollateral:
            return true
        }
    }
    
    var unit: String {
        switch self {
        case .payBack:
            return "USDC"
        case .addCollateral, .withdrawCollateral, .close:
            return "PAXG"
        }
    }
    
    var defaultAmountText: String {
        switch self {
        case .payBack(let position):
            return format(position.borrowAmount, decimals: 2)
        case .withdrawCollateral(let position):
            return format(position.collateralAmount, decimals: 6)
        case .addCollateral, .close:
            return ""
        }
    }
    
    private func format(_ value: Decimal, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: value as NSDecimalNumber) ?? ""
    }
}
