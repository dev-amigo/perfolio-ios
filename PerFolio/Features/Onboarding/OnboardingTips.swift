import SwiftUI
import TipKit

// MARK: - Manual Info Tips (Always Available)

/// Manual tip for Deposit USDC - can be shown anytime
struct DepositInfoTip: Tip {
    var title: Text {
        Text("What is USDC?")
    }
    
    var message: Text? {
        Text("USDC (USD Coin) is a digital dollar - a stablecoin that's always worth $1. It's like digital cash you can use instantly across borders without bank delays or fees.")
    }
    
    var image: Image? {
        Image(systemName: "dollarsign.circle.fill")
    }
    
    var options: [TipOption] {
        [
            Tips.IgnoresDisplayFrequency(true)
        ]
    }
}

/// Manual tip for Swap to PAXG - can be shown anytime
struct SwapInfoTip: Tip {
    var title: Text {
        Text("What is PAXG?")
    }
    
    var message: Text? {
        Text("PAXG (Pax Gold) is tokenized physical gold. Each PAXG token represents 1 troy ounce of London Good Delivery gold stored in secure vaults. Own real gold, digitally!")
    }
    
    var image: Image? {
        Image(systemName: "sparkles")
    }
    
    var options: [TipOption] {
        [
            Tips.IgnoresDisplayFrequency(true)
        ]
    }
}

/// Manual tip for Borrow USDC - can be shown anytime
struct BorrowInfoTip: Tip {
    var title: Text {
        Text("How Borrowing Works")
    }
    
    var message: Text? {
        Text("Lock your PAXG as collateral to borrow USDC instantly. Your gold stays yours - you can unlock it anytime by repaying the loan. It's like a gold-backed credit line!")
    }
    
    var image: Image? {
        Image(systemName: "banknote.fill")
    }
    
    var options: [TipOption] {
        [
            Tips.IgnoresDisplayFrequency(true)
        ]
    }
}

/// Manual tip for Manage Loans - can be shown anytime
struct LoansInfoTip: Tip {
    var title: Text {
        Text("Monitor Your Loans")
    }
    
    var message: Text? {
        Text("Track your loan health, collateral ratio, and interest in real-time. Add more collateral to stay safe, or repay anytime. You're always in control of your position.")
    }
    
    var image: Image? {
        Image(systemName: "chart.line.uptrend.xyaxis")
    }
    
    var options: [TipOption] {
        [
            Tips.IgnoresDisplayFrequency(true)
        ]
    }
}

/// Manual tip for Withdraw - can be shown anytime
struct WithdrawInfoTip: Tip {
    var title: Text {
        Text("Cash Out to Your Bank")
    }
    
    var message: Text? {
        Text("Convert USDC back to INR and withdraw directly to your bank account in minutes. Seamless on/off ramp between crypto and traditional banking. Your funds, your way!")
    }
    
    var image: Image? {
        Image(systemName: "building.columns.fill")
    }
    
    var options: [TipOption] {
        [
            Tips.IgnoresDisplayFrequency(true)
        ]
    }
}

// MARK: - Onboarding Tutorial Tips

/// Tip for Deposit USDC button
struct DepositUSDCTip: Tip {
    var title: Text {
        Text("What is USDC?")
    }
    
    var message: Text? {
        Text("USDC (USD Coin) is a digital dollar - a stablecoin that's always worth $1. It's like digital cash you can use instantly across borders without bank delays or fees.")
    }
    
    var image: Image? {
        Image(systemName: "dollarsign.circle.fill")
    }
    
    var options: [TipOption] {
        [
            Tips.MaxDisplayCount(1)
        ]
    }
    
    var actions: [Action] {
        [
            Action(id: "next", title: "Next →")
        ]
    }
}

/// Tip for Swap to PAXG button
struct SwapToPAXGTip: Tip {
    @Parameter
    static var hasSeenDepositTip: Bool = false
    
    var title: Text {
        Text("What is PAXG?")
    }
    
    var message: Text? {
        Text("PAXG (Pax Gold) is tokenized physical gold. Each PAXG token represents 1 troy ounce of London Good Delivery gold stored in secure vaults. Own real gold, digitally!")
    }
    
    var image: Image? {
        Image(systemName: "sparkles")
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$hasSeenDepositTip) {
                $0 == true
            }
        ]
    }
    
    var options: [TipOption] {
        [
            Tips.MaxDisplayCount(1)
        ]
    }
    
    var actions: [Action] {
        [
            Action(id: "next", title: "Next →")
        ]
    }
}

/// Tip for Borrow USDC button
struct BorrowUSDCTip: Tip {
    @Parameter
    static var hasSeenSwapTip: Bool = false
    
    var title: Text {
        Text("How Borrowing Works")
    }
    
    var message: Text? {
        Text("Lock your PAXG as collateral to borrow USDC instantly. Your gold stays yours - you can unlock it anytime by repaying the loan. It's like a gold-backed credit line!")
    }
    
    var image: Image? {
        Image(systemName: "banknote.fill")
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$hasSeenSwapTip) {
                $0 == true
            }
        ]
    }
    
    var options: [TipOption] {
        [
            Tips.MaxDisplayCount(1)
        ]
    }
    
    var actions: [Action] {
        [
            Action(id: "next", title: "Next →")
        ]
    }
}

/// Tip for Manage Active Loans button
struct ManageLoansTip: Tip {
    @Parameter
    static var hasSeenBorrowTip: Bool = false
    
    var title: Text {
        Text("Monitor Your Loans")
    }
    
    var message: Text? {
        Text("Track your loan health, collateral ratio, and interest in real-time. Add more collateral to stay safe, or repay anytime. You're always in control of your position.")
    }
    
    var image: Image? {
        Image(systemName: "chart.line.uptrend.xyaxis")
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$hasSeenBorrowTip) {
                $0 == true
            }
        ]
    }
    
    var options: [TipOption] {
        [
            Tips.MaxDisplayCount(1)
        ]
    }
    
    var actions: [Action] {
        [
            Action(id: "next", title: "Next →")
        ]
    }
}

/// Tip for Withdraw button
struct WithdrawBankTip: Tip {
    @Parameter
    static var hasSeenLoansTip: Bool = false
    
    var title: Text {
        Text("Cash Out to Your Bank")
    }
    
    var message: Text? {
        Text("Convert USDC back to INR and withdraw directly to your bank account in minutes. Seamless on/off ramp between crypto and traditional banking. Your funds, your way!")
    }
    
    var image: Image? {
        Image(systemName: "building.columns.fill")
    }
    
    var rules: [Rule] {
        [
            #Rule(Self.$hasSeenLoansTip) {
                $0 == true
            }
        ]
    }
    
    var options: [TipOption] {
        [
            Tips.MaxDisplayCount(1)
        ]
    }
    
    var actions: [Action] {
        [
            Action(id: "finish", title: "Finish ✓")
        ]
    }
}

