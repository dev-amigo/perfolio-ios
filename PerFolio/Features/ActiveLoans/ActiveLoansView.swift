import SwiftUI

struct ActiveLoansView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = ActiveLoansViewModel()
    @State private var expandedPositions: Set<String> = []
    @State private var pendingAction: LoanAction?
    
    var onPayBack: ((BorrowPosition) -> Void)?
    var onAddGold: ((BorrowPosition) -> Void)?
    var onWithdrawGold: ((BorrowPosition) -> Void)?
    var onCloseLoan: ((BorrowPosition) -> Void)?
    
    var body: some View {
        ZStack {
            themeManager.perfolioTheme.primaryBackground
                .ignoresSafeArea()
            
            switch viewModel.viewState {
            case .loading:
                loadingView
            case .error(let message):
                errorView(message)
            case .empty:
                emptyState
            case .ready:
                readyView
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .alert(item: $pendingAction) { action in
            Alert(
                title: Text(action.title),
                message: Text(action.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            headerSection
            PerFolioCard {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(themeManager.perfolioTheme.tintColor)
                    .frame(maxWidth: .infinity)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 24) {
            headerSection
            PerFolioCard {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    Text(message)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    PerFolioButton("RETRY") {
                        viewModel.reload()
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            headerSection
            PerFolioCard {
                VStack(spacing: 16) {
                    Image(systemName: "lock.open.trianglebadge.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    Text("No active loans yet")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    Text("Any loans you open will appear here with detailed stats and controls.")
                        .font(.system(size: 14, weight: .regular, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
    
    private var readyView: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                summaryCard
                
                ForEach(viewModel.positions) { position in
                    loanCard(for: position)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Active Loans")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            Text("View and manage every Fluid Protocol loan currently open.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var summaryCard: some View {
        PerFolioCard(style: .gradient) {
            VStack(alignment: .leading, spacing: 16) {
                summaryMetric(
                    title: "Active Loans",
                    value: "\(viewModel.summary.totalLoans)",
                    subtitle: viewModel.summary.totalLoans == 1 ? "loan in progress" : "loans in progress"
                )
                
                Divider().overlay(Color.white.opacity(0.2))
                
                summaryMetric(
                    title: "Gold You Put Up",
                    value: viewModel.summary.totalCollateralDisplay,
                    subtitle: "≈ \(viewModel.summary.collateralUSDDisplay)"
                )
                
                Divider().overlay(Color.white.opacity(0.2))
                
                summaryMetric(
                    title: "Money You Borrowed",
                    value: viewModel.summary.totalDebtDisplay,
                    subtitle: "Total to pay back"
                )
            }
        }
    }
    
    private func summaryMetric(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
        }
    }
    
    private func loanCard(for position: BorrowPosition) -> some View {
        let isExpanded = expandedPositions.contains(position.id)
        return PerFolioCard(style: .secondary, padding: 20) {
            VStack(spacing: 16) {
                Button {
                    withAnimation(.spring()) {
                        if isExpanded {
                            expandedPositions.remove(position.id)
                        } else {
                            expandedPositions.insert(position.id)
                        }
                    }
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 10) {
                                Text("Loan #\(position.nftId)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                                statusBadge(for: position.status)
                            }
                            Text("Started \(formatDate(position.createdAt))")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        }
                        
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Gold Locked")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                            Text(position.collateralDisplay)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        }
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                }
                
                collapseStats(for: position)
                
                if isExpanded {
                    Divider()
                        .overlay(themeManager.perfolioTheme.border)
                    expandedDetails(for: position)
                }
            }
        }
    }
    
    private func collapseStats(for position: BorrowPosition) -> some View {
        HStack(spacing: 12) {
            loanMetric(title: "How Much You Borrowed", value: "\(formatPercentage(position.currentLTV))")
            loanMetric(title: "Loan Safety Score", value: position.formattedHealthFactor)
            loanMetric(title: "Money You Borrowed", value: formatUSD(position.debtValueUSD))
        }
    }
    
    private func expandedDetails(for position: BorrowPosition) -> some View {
        VStack(spacing: 16) {
            HStack {
                Label("Healthy", systemImage: "heart.text.square.fill")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                Spacer()
                Button {
                    if let url = URL(string: "https://etherscan.io/address/\(position.vaultAddress)") {
                        openURL(url)
                    }
                } label: {
                    Label("View on Blockchain", systemImage: "arrow.up.right.square")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
            }
            
            VStack(spacing: 12) {
                infoRow(title: "What You Owe", value: "\(formatUSD(position.debtValueUSD))")
                infoRow(title: "Your Gold Locked", value: position.collateralDisplay)
                infoRow(title: "Your Gold Worth", value: formatUSD(position.collateralValueUSD))
                infoRow(title: "Danger Price", value: formatUSD(position.liquidationPrice))
                infoRow(title: "Can Borrow More", value: formatUSD(position.availableToBorrowUSD))
            }
            
            riskMeter(for: position)
            
            HStack(spacing: 12) {
                PerFolioButton("Pay Back Loan", style: .primary) {
                    handleAction(.payBack(position))
                }
                PerFolioButton("Add More Gold", style: .secondary) {
                    handleAction(.addCollateral(position))
                }
            }
            
            HStack(spacing: 12) {
                PerFolioButton("Take Gold Back", style: .secondary) {
                    handleAction(.withdrawCollateral(position))
                }
                PerFolioButton("Close Loan", style: .secondary) {
                    handleAction(.close(position))
                }
            }
        }
    }
    
    private func loanMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(themeManager.perfolioTheme.primaryBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
        }
        .padding(.vertical, 4)
    }
    
    private func riskMeter(for position: BorrowPosition) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Loan Risk Level")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.perfolioTheme.primaryBackground.opacity(0.8))
                    .frame(height: 12)
                RoundedRectangle(cornerRadius: 8)
                    .fill(LinearGradient(colors: [
                        .green, .yellow, .orange, .red
                    ], startPoint: .leading, endPoint: .trailing))
                    .frame(width: barWidth(for: position.currentLTV), height: 12)
            }
            
            HStack {
                Text("0% Safe")
                Spacer()
                Text("78% Caution")
                Spacer()
                Text("85% Warning")
                Spacer()
                Text("91% Danger")
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
        }
    }
    
    private func barWidth(for ltv: Decimal) -> CGFloat {
        let clamped = min(max(Double(truncating: ltv as NSNumber), 0), 100)
        return CGFloat(clamped / 100.0) * UIScreen.main.bounds.width * 0.7
    }
    
    private func statusBadge(for status: BorrowPosition.PositionStatus) -> some View {
        Text(status.displayName.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(badgeColor(for: status).opacity(0.15))
            .foregroundStyle(badgeColor(for: status))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    
    private func badgeColor(for status: BorrowPosition.PositionStatus) -> Color {
        switch status {
        case .safe: return .green
        case .warning: return .yellow
        case .danger: return .orange
        case .liquidated: return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatUSD(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
    
    private func formatPercentage(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        let percent = (value as NSDecimalNumber).doubleValue / 100
        return formatter.string(from: NSNumber(value: percent)) ?? "0%"
    }
}

// MARK: - Loan Actions

private enum LoanAction: Identifiable {
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
            return "Action Coming Soon"
        case .addCollateral:
            return "Add More Gold"
        case .withdrawCollateral:
            return "Take Gold Back"
        case .close:
            return "Close Loan"
        }
    }
    
    var message: String {
        switch self {
        case .payBack:
            return "Loan repayment is in progress. This button will connect you to the payback workflow once it ships."
        case .addCollateral:
            return "Adding collateral will be available shortly. Stay tuned!"
        case .withdrawCollateral:
            return "Withdrawing collateral is coming soon."
        case .close:
            return "Closing loans from the app is on our roadmap."
        }
    }
}

private extension ActiveLoansView {
    func handleAction(_ action: LoanAction) {
        switch action {
        case .payBack(let position):
            if let handler = onPayBack {
                handler(position)
                return
            }
        case .addCollateral(let position):
            if let handler = onAddGold {
                handler(position)
                return
            }
        case .withdrawCollateral(let position):
            if let handler = onWithdrawGold {
                handler(position)
                return
            }
        case .close(let position):
            if let handler = onCloseLoan {
                handler(position)
                return
            }
        }
        pendingAction = action
    }
}

#Preview {
    ActiveLoansView()
        .environmentObject(ThemeManager())
}
