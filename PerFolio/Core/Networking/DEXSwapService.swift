import Foundation
import PrivySDK
import Combine

/// DEX swap service for USDT → PAXG conversion
/// Uses 1inch API for best execution prices
final class DEXSwapService: ObservableObject {
    
    // MARK: - Types
    
    struct SwapQuote {
        let fromToken: Token
        let toToken: Token
        let fromAmount: Decimal
        let toAmount: Decimal
        let estimatedGas: String
        let priceImpact: Decimal
        let route: String
        
        var displayFromAmount: String {
            "\(formatDecimal(fromAmount)) \(fromToken.symbol)"
        }
        
        var displayToAmount: String {
            "\(formatDecimal(toAmount)) \(toToken.symbol)"
        }
        
        var displayPriceImpact: String {
            "\(formatDecimal(priceImpact))%"
        }
        
        var isPriceImpactHigh: Bool {
            priceImpact > 3.0 // > 3% is considered high
        }
        
        private func formatDecimal(_ value: Decimal) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 6
            return formatter.string(from: value as NSNumber) ?? "0"
        }
    }
    
    struct Token {
        let address: String
        let symbol: String
        let decimals: Int
        let name: String
        
        static let usdt = Token(
            address: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
            symbol: "USDT",
            decimals: 6,
            name: "Tether USD"
        )
        
        static let paxg = Token(
            address: "0x45804880De22913dAFE09f4980848ECE6EcbAf78",
            symbol: "PAXG",
            decimals: 18,
            name: "Paxos Gold"
        )
    }
    
    struct SwapParams {
        let fromToken: Token
        let toToken: Token
        let amount: Decimal
        let slippageTolerance: Decimal // e.g., 0.5 for 0.5%
        let fromAddress: String
    }
    
    enum SwapError: LocalizedError {
        case insufficientBalance
        case insufficientLiquidity
        case slippageTooHigh
        case approvalRequired
        case networkError(String)
        case invalidAmount
        
        var errorDescription: String? {
            switch self {
            case .insufficientBalance:
                return "Insufficient USDT balance"
            case .insufficientLiquidity:
                return "Insufficient liquidity for this swap"
            case .slippageTooHigh:
                return "Price impact is too high. Try a smaller amount."
            case .approvalRequired:
                return "Token approval required before swap"
            case .networkError(let message):
                return "Network error: \(message)"
            case .invalidAmount:
                return "Please enter a valid amount"
            }
        }
    }
    
    enum ApprovalState {
        case notRequired
        case required
        case pending
        case approved
    }
    
    // MARK: - Properties
    
    private let web3Client: Web3Client
    private let erc20Contract: ERC20Contract
    
    @Published var isLoading = false
    @Published var currentQuote: SwapQuote?
    @Published var approvalState: ApprovalState = .notRequired
    
    // 1inch API configuration
    private let oneInchBaseURL = "https://api.1inch.dev/swap/v6.0/1" // Ethereum Mainnet
    private let oneInchAPIKey: String
    
    // Slippage tolerance (0.5% default)
    let defaultSlippageTolerance: Decimal = 0.5
    
    // MARK: - Initialization
    
    init(
        web3Client: Web3Client = Web3Client(),
        erc20Contract: ERC20Contract = ERC20Contract(),
        oneInchAPIKey: String? = nil
    ) {
        self.web3Client = web3Client
        self.erc20Contract = erc20Contract
        
        // Get API key from Info.plist or use empty string for testing
        self.oneInchAPIKey = oneInchAPIKey ?? (Bundle.main.object(forInfoDictionaryKey: "AG1InchAPIKey") as? String ?? "")
        
        AppLogger.log("🔄 DEXSwapService initialized", category: "dex")
        AppLogger.log("   1inch API URL: \(oneInchBaseURL)", category: "dex")
    }
    
    // MARK: - Public Methods
    
    /// Get swap quote for USDT → PAXG
    func getQuote(params: SwapParams) async throws -> SwapQuote {
        AppLogger.log("📊 Getting swap quote: \(params.amount) \(params.fromToken.symbol) → \(params.toToken.symbol)", category: "dex")
        
        guard params.amount > 0 else {
            throw SwapError.invalidAmount
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Check balance (currently only USDT is supported)
        let balances = try await erc20Contract.balancesOf(
            tokens: [.usdt],
            address: params.fromAddress
        )
        
        guard let balance = balances.first, balance.decimalBalance >= params.amount else {
            throw SwapError.insufficientBalance
        }
        
        // In production, call 1inch API for real quote
        // For now, use simplified calculation based on approximate prices
        // USDT ≈ $1, PAXG ≈ $2000 (1 oz gold)
        let paxgPriceInUSDT: Decimal = 2000
        let toAmount = params.amount / paxgPriceInUSDT
        let priceImpact: Decimal = 0.1 // 0.1% for demo
        
        let quote = SwapQuote(
            fromToken: params.fromToken,
            toToken: params.toToken,
            fromAmount: params.amount,
            toAmount: toAmount,
            estimatedGas: "~$5-10",
            priceImpact: priceImpact,
            route: "USDT → WETH → PAXG (Uniswap V3)"
        )
        
        currentQuote = quote
        AppLogger.log("✅ Quote: \(quote.displayFromAmount) → \(quote.displayToAmount)", category: "dex")
        AppLogger.log("   Price Impact: \(quote.displayPriceImpact)", category: "dex")
        AppLogger.log("   Route: \(quote.route)", category: "dex")
        
        return quote
    }
    
    /// Check if token approval is needed for swap
    func checkApproval(
        tokenAddress: String,
        ownerAddress: String,
        spenderAddress: String,
        amount: Decimal
    ) async throws -> ApprovalState {
        AppLogger.log("🔍 Checking approval for \(tokenAddress)", category: "dex")
        
        // Build eth_call for allowance check
        let ownerPadded = String(ownerAddress.dropFirst(2)).paddingToLeft(upTo: 64, using: "0")
        let spenderPadded = String(spenderAddress.dropFirst(2)).paddingToLeft(upTo: 64, using: "0")
        let data = "0xdd62ed3e" + ownerPadded + spenderPadded // allowance(address,address)
        
        let result = try await web3Client.ethCall(to: tokenAddress, data: data)
        
        guard let resultString = result as? String else {
            throw SwapError.networkError("Invalid allowance response")
        }
        
        // Parse hex allowance
        let allowanceHex = resultString.replacingOccurrences(of: "0x", with: "")
        // Convert hex string to integer first, then to Decimal
        guard let allowanceInt = Int(allowanceHex, radix: 16) else {
            throw SwapError.networkError("Failed to parse allowance")
        }
        let allowanceValue = Decimal(allowanceInt)
        
        let state: ApprovalState = allowanceValue >= amount ? .approved : .required
        AppLogger.log("   Allowance: \(allowanceValue), Required: \(amount), State: \(state)", category: "dex")
        
        approvalState = state
        return state
    }
    
    /// Approve token spending
    /// Note: In production, this would use Privy SDK to sign and send the approval transaction
    func approveToken(
        tokenAddress: String,
        spenderAddress: String,
        amount: Decimal
    ) async throws {
        AppLogger.log("✍️ Approving \(tokenAddress) for spender \(spenderAddress)", category: "dex")
        
        approvalState = .pending
        
        // In production, build approval transaction data and use Privy to sign/send
        // For now, simulate approval
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2s delay
        
        approvalState = .approved
        AppLogger.log("✅ Token approval successful", category: "dex")
    }
    
    /// Execute swap transaction
    /// Note: In production, this would use Privy SDK with gas sponsorship
    func executeSwap(params: SwapParams) async throws -> String {
        AppLogger.log("🔄 Executing swap: \(params.amount) \(params.fromToken.symbol) → \(params.toToken.symbol)", category: "dex")
        
        // Check approval first
        let oneInchRouter = "0x111111125421ca6dc452d289314280a0f8842a65" // 1inch v6 router
        let approvalState = try await checkApproval(
            tokenAddress: params.fromToken.address,
            ownerAddress: params.fromAddress,
            spenderAddress: oneInchRouter,
            amount: params.amount
        )
        
        if approvalState == .required {
            throw SwapError.approvalRequired
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // In production:
        // 1. Get swap transaction data from 1inch API
        // 2. Use Privy SDK to sign and send transaction with gas sponsorship
        // 3. Return transaction hash
        
        // For now, simulate transaction
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3s delay
        
        let txHash = "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        AppLogger.log("✅ Swap executed: \(txHash)", category: "dex")
        
        return txHash
    }
    
    /// Reset state
    func reset() {
        currentQuote = nil
        approvalState = .notRequired
    }
}

// MARK: - String Extension

private extension String {
    func paddingToLeft(upTo length: Int, using element: String) -> String {
        let padCount = length - self.count
        guard padCount > 0 else { return self }
        return String(repeating: element, count: padCount) + self
    }
}

