import Foundation
import SwiftUI
import Combine

@MainActor
final class DashboardViewModel: ObservableObject {
    enum LoadingState {
        case idle
        case loading
        case loaded
        case failed(Error)
    }
    
    @Published var walletAddress: String?
    @Published var paxgBalance: TokenBalance?
    @Published var usdcBalance: TokenBalance?
    @Published var loadingState: LoadingState = .idle
    @Published var borrowPositions: [BorrowPosition] = []
    @Published var priceHistory: [PricePoint] = []
    @Published var currentPAXGPrice: Decimal = 2400
    
    private let web3Client: Web3Client
    private let erc20Contract: ERC20Contract
    private let fluidPositionsService: FluidPositionsService
    private let priceOracleService: PriceOracleService
    
    init(
        web3Client: Web3Client = Web3Client(),
        erc20Contract: ERC20Contract? = nil,
        fluidPositionsService: FluidPositionsService? = nil,
        priceOracleService: PriceOracleService? = nil
    ) {
        self.web3Client = web3Client
        self.erc20Contract = erc20Contract ?? ERC20Contract(web3Client: web3Client)
        self.fluidPositionsService = fluidPositionsService ?? FluidPositionsService(web3Client: web3Client)
        self.priceOracleService = priceOracleService ?? PriceOracleService()
    }
    
    var isWalletConnected: Bool {
        walletAddress != nil
    }
    
    var walletBadgeText: String {
        isWalletConnected ? "Connected" : "Not Connected"
    }
    
    var walletBadgeColor: Color {
        isWalletConnected ? .green : .gray
    }
    
    var truncatedAddress: String {
        guard let address = walletAddress else {
            return "No wallet"
        }
        
        let start = String(address.prefix(6))
        let end = String(address.suffix(4))
        return "\(start)...\(end)"
    }
    
    func setWalletAddress(_ address: String) {
        self.walletAddress = address
        AppLogger.log("Wallet address set: \(address)", category: "dashboard")
        
        // Automatically fetch balances when wallet is set
        Task {
            await fetchBalances()
        }
    }
    
    func fetchBalances() async {
        guard let address = walletAddress else {
            AppLogger.log("No wallet address to fetch balances for", category: "dashboard")
            return
        }
        
        loadingState = .loading
        
        do {
            AppLogger.log("Fetching balances for \(address)", category: "dashboard")
            
            let balances = try await erc20Contract.balancesOf(
                tokens: [.paxg, .usdc],
                address: address
            )
            
            // Update balances
            for balance in balances {
                switch balance.symbol {
                case "PAXG":
                    self.paxgBalance = balance
                case "USDC":
                    self.usdcBalance = balance
                default:
                    break
                }
            }
            
            loadingState = .loaded
            AppLogger.log("Balances fetched successfully", category: "dashboard")
            
            // Also fetch borrow positions and price history
            await fetchBorrowPositions()
            await fetchPriceHistory()
        } catch {
            loadingState = .failed(error)
            AppLogger.log("Failed to fetch balances: \(error)", category: "dashboard")
        }
    }
    
    func copyAddressToClipboard() {
        guard let address = walletAddress else { return }
        
        #if os(iOS)
        UIPasteboard.general.string = address
        AppLogger.log("Address copied to clipboard", category: "dashboard")
        #endif
    }
    
    func refreshBalances() {
        Task {
            await fetchBalances()
        }
    }
    
    // MARK: - Formatted Values
    
    var paxgFormattedBalance: String {
        paxgBalance?.formattedBalance ?? "0.00"
    }
    
    var usdcFormattedBalance: String {
        usdcBalance?.formattedBalance ?? "0.00"
    }
    
    var paxgUSDValue: String {
        // TODO: Fetch gold price from oracle/CoinGecko
        // For now, use approximate price of $2400/oz PAXG
        guard let balance = paxgBalance else { return "$0.00" }
        let goldPrice: Decimal = 2400
        let usdValue = balance.decimalBalance * goldPrice
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: usdValue as NSDecimalNumber) ?? "$0.00"
    }
    
    var usdcUSDValue: String {
        // USDC is 1:1 with USD
        guard let balance = usdcBalance else { return "$0.00" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: balance.decimalBalance as NSDecimalNumber) ?? "$0.00"
    }
    
    var totalPortfolioValue: String {
        guard let paxg = paxgBalance, let usdc = usdcBalance else {
            return "$0.00"
        }
        
        let goldPrice: Decimal = 2400
        let paxgValue = paxg.decimalBalance * goldPrice
        let totalValue = paxgValue + usdc.decimalBalance
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: totalValue as NSDecimalNumber) ?? "$0.00"
    }
    
    // MARK: - Statistics Computed Properties
    
    var totalCollateral: String {
        let total = borrowPositions.reduce(into: Decimal(0)) { $0 += $1.collateralAmount }
        return formatDecimal(total, maxDecimals: 4) + " PAXG"
    }
    
    var totalCollateralUSD: String {
        let total = borrowPositions.reduce(into: Decimal(0)) { $0 += $1.collateralValueUSD }
        return formatCurrency(total)
    }
    
    var totalBorrowed: String {
        let total = borrowPositions.reduce(into: Decimal(0)) { $0 += $1.debtAmount }
        return formatDecimal(total, maxDecimals: 2) + " USDT"
    }
    
    var totalBorrowedUSD: String {
        let total = borrowPositions.reduce(into: Decimal(0)) { $0 += $1.debtValueUSD }
        return formatCurrency(total)
    }
    
    var healthFactor: String {
        guard !borrowPositions.isEmpty else { return "N/A" }
        let avgHealth = borrowPositions.reduce(into: Decimal(0)) { $0 += $1.healthFactor } / Decimal(borrowPositions.count)
        return formatDecimal(avgHealth, maxDecimals: 2)
    }
    
    var healthStatus: String {
        guard !borrowPositions.isEmpty else { return "No Loans" }
        let avgHealth = borrowPositions.reduce(into: Decimal(0)) { $0 += $1.healthFactor } / Decimal(borrowPositions.count)
        if avgHealth >= 2.0 { return "Safe" }
        else if avgHealth >= 1.2 { return "Moderate" }
        else { return "At Risk" }
    }
    
    var healthStatusColor: Color {
        guard !borrowPositions.isEmpty else { return .gray }
        let avgHealth = borrowPositions.reduce(into: Decimal(0)) { $0 += $1.healthFactor } / Decimal(borrowPositions.count)
        if avgHealth >= 2.0 { return .green }
        else if avgHealth >= 1.2 { return .orange }
        else { return .red }
    }
    
    var borrowAPY: String {
        // Mock APY - in real app, fetch from Fluid Protocol
        return "5.44%"
    }
    
    var maxLTV: String {
        return "80%"
    }
    
    var liquidationThreshold: String {
        return "85%"
    }
    
    var liquidationPenalty: String {
        return "3.00%"
    }
    
    var paxgCurrentPrice: String {
        return formatCurrency(currentPAXGPrice)
    }
    
    var activePositions: String {
        return "\(borrowPositions.count)"
    }
    
    // MARK: - Price Chart Properties
    
    var paxgCurrentPriceFormatted: String {
        return formatCurrency(currentPAXGPrice)
    }
    
    var paxgPriceChange: String {
        guard priceHistory.count >= 2,
              let firstPrice = priceHistory.first?.price,
              let lastPrice = priceHistory.last?.price else {
            return "+0.00%"
        }
        
        let change = ((lastPrice - firstPrice) / firstPrice) * 100
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(formatDecimal(change, maxDecimals: 2))%"
    }
    
    var priceChangeColor: Color {
        guard priceHistory.count >= 2,
              let firstPrice = priceHistory.first?.price,
              let lastPrice = priceHistory.last?.price else {
            return .gray
        }
        return lastPrice >= firstPrice ? .green : .red
    }
    
    // MARK: - Helper Functions
    
    private func formatDecimal(_ value: Decimal, maxDecimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxDecimals
        formatter.groupingSeparator = ","
        return formatter.string(from: value as NSDecimalNumber) ?? "0"
    }
    
    private func formatCurrency(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: value as NSDecimalNumber) ?? "$0.00"
    }
    
    // MARK: - Data Fetching
    
    func fetchBorrowPositions() async {
        guard let address = walletAddress else { return }
        
        do {
            let positions = try await fluidPositionsService.fetchPositions(for: address)
            await MainActor.run {
                self.borrowPositions = positions
            }
            AppLogger.log("Fetched \(positions.count) borrow positions", category: "dashboard")
        } catch {
            AppLogger.log("Failed to fetch borrow positions: \(error)", category: "dashboard")
        }
    }
    
    func fetchPriceHistory() async {
        do {
            let price = try await priceOracleService.fetchPAXGPrice()
            await MainActor.run {
                self.currentPAXGPrice = price
                // Generate mock 90-day price history
                self.priceHistory = generateMockPriceHistory(currentPrice: price)
            }
            AppLogger.log("Fetched PAXG price: $\(price)", category: "dashboard")
        } catch {
            AppLogger.log("Failed to fetch PAXG price: \(error)", category: "dashboard")
        }
    }
    
    private func generateMockPriceHistory(currentPrice: Decimal) -> [PricePoint] {
        var points: [PricePoint] = []
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -90, to: endDate)!
        
        // Generate 90 data points
        for i in 0...89 {
            guard let date = calendar.date(byAdding: .day, value: i, to: startDate) else { continue }
            
            // Generate price with some variance (±20%)
            let variance = Decimal(Double.random(in: -0.2...0.2))
            let basePrice = currentPrice * (1 + variance)
            let price = max(basePrice, 1) // Ensure price stays positive
            
            points.append(PricePoint(date: date, price: price))
        }
        
        return points
    }
}

// MARK: - Price Point Model

struct PricePoint: Identifiable {
    let id = UUID()
    let date: Date
    let price: Decimal
}
