import Foundation
import Combine

@MainActor
final class ActiveLoansViewModel: ObservableObject {
    enum ViewState {
        case loading
        case empty
        case ready
        case error(String)
    }
    
    struct SummaryStats {
        let totalLoans: Int
        let totalCollateral: Decimal
        let totalDebt: Decimal
        let totalCollateralUSD: Decimal
        
        var totalCollateralDisplay: String {
            "\(Self.formatDecimal(totalCollateral, maxDecimals: 6)) PAXG"
        }
        
        var totalDebtDisplay: String {
            Self.formatUSD(totalDebt)
        }
        
        var collateralUSDDisplay: String {
            Self.formatUSD(totalCollateralUSD)
        }
        
        private static func formatDecimal(_ value: Decimal, maxDecimals: Int) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = maxDecimals
            formatter.minimumFractionDigits = 0
            return formatter.string(from: value as NSDecimalNumber) ?? "0"
        }
        
        private static func formatUSD(_ value: Decimal) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.currencyCode = "USD"
            formatter.maximumFractionDigits = 2
            return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
        }
    }
    
    @Published private(set) var viewState: ViewState = .loading
    @Published private(set) var positions: [BorrowPosition] = []
    @Published private(set) var summary = SummaryStats(totalLoans: 0, totalCollateral: 0, totalDebt: 0, totalCollateralUSD: 0)
    
    private let positionsService: FluidPositionsService
    private var hasLoaded = false
    
    init(positionsService: FluidPositionsService? = nil) {
        self.positionsService = positionsService ?? FluidPositionsService()
    }
    
    func onAppear() {
        guard !hasLoaded else { return }
        hasLoaded = true
        Task { await loadPositions() }
    }
    
    func reload() {
        Task { await loadPositions() }
    }
    
    private func loadPositions() async {
        guard let wallet = UserDefaults.standard.string(forKey: "userWalletAddress") else {
            viewState = .error("Please log in to view your active loans.")
            return
        }
        
        viewState = .loading
        
        do {
            let fetchedPositions = try await positionsService.fetchPositions(for: wallet)
            positions = fetchedPositions
            summary = SummaryStats(
                totalLoans: fetchedPositions.count,
                totalCollateral: fetchedPositions.reduce(0) { $0 + $1.collateralAmount },
                totalDebt: fetchedPositions.reduce(0) { $0 + $1.borrowAmount },
                totalCollateralUSD: fetchedPositions.reduce(0) { $0 + $1.collateralValueUSD }
            )
            viewState = fetchedPositions.isEmpty ? .empty : .ready
        } catch {
            AppLogger.log("❌ Failed to load positions: \(error)", category: "borrow")
            viewState = .error("Unable to load active loans. Please try again.")
        }
    }
    
}
