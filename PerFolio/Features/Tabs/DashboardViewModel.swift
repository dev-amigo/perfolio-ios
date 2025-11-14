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
    @Published var usdtBalance: TokenBalance?
    @Published var loadingState: LoadingState = .idle
    
    private let web3Client: Web3Client
    private let erc20Contract: ERC20Contract
    
    init(
        web3Client: Web3Client = Web3Client(),
        erc20Contract: ERC20Contract? = nil
    ) {
        self.web3Client = web3Client
        self.erc20Contract = erc20Contract ?? ERC20Contract(web3Client: web3Client)
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
            // Refresh Privy REST API client (in case wallet ID is now available)
            await web3Client.refreshPrivyClient()
            
            // Fetch balances
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
                tokens: [.paxg, .usdt],
                address: address
            )
            
            // Update balances
            for balance in balances {
                switch balance.symbol {
                case "PAXG":
                    self.paxgBalance = balance
                case "USDT":
                    self.usdtBalance = balance
                default:
                    break
                }
            }
            
            loadingState = .loaded
            AppLogger.log("Balances fetched successfully", category: "dashboard")
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
    
    var usdtFormattedBalance: String {
        usdtBalance?.formattedBalance ?? "0.00"
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
    
    var usdtUSDValue: String {
        // USDT is 1:1 with USD
        guard let balance = usdtBalance else { return "$0.00" }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: balance.decimalBalance as NSDecimalNumber) ?? "$0.00"
    }
    
    var totalPortfolioValue: String {
        guard let paxg = paxgBalance, let usdt = usdtBalance else {
            return "$0.00"
        }
        
        let goldPrice: Decimal = 2400
        let paxgValue = paxg.decimalBalance * goldPrice
        let totalValue = paxgValue + usdt.decimalBalance
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter.string(from: totalValue as NSDecimalNumber) ?? "$0.00"
    }
}

