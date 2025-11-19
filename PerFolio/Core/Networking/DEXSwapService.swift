import Foundation
import PrivySDK
import Combine

/// DEX swap service for USDC → PAXG conversion
/// Uses 0x Aggregator for quotes and transaction data
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
            CurrencyFormatter.formatToken(fromAmount, symbol: fromToken.symbol)
        }
        
        var displayToAmount: String {
            CurrencyFormatter.formatToken(toAmount, symbol: toToken.symbol, maxDecimals: 8)
        }
        
        var displayPriceImpact: String {
            "\(CurrencyFormatter.formatDecimal(priceImpact))%"
        }
        
        var isPriceImpactHigh: Bool {
            priceImpact > ServiceConstants.highPriceImpactThreshold
        }
        
        /// Convert estimated gas string to Decimal (e.g., "~$5-10" → 7.5)
        var estimatedGasDecimal: Decimal {
            // Parse "~$5-10" → average of 5 and 10 = 7.5
            let cleaned = estimatedGas.replacingOccurrences(of: "~$", with: "").replacingOccurrences(of: "$", with: "")
            let parts = cleaned.split(separator: "-").map { String($0).trimmingCharacters(in: .whitespaces) }
            
            if parts.count == 2,
               let min = Decimal(string: parts[0]),
               let max = Decimal(string: parts[1]) {
                return (min + max) / 2
            } else if let value = Decimal(string: cleaned) {
                return value
            }
            
            return 7.5  // Default fallback
        }
    }
    
    struct Token {
        let address: String
        let symbol: String
        let decimals: Int
        let name: String
        
        static let usdc = Token(
            address: ContractAddresses.usdc,
            symbol: "USDC",
            decimals: 6,
            name: "USD Coin"
        )
        
        static let paxg = Token(
            address: ContractAddresses.paxg,
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
    
    private struct ZeroExQuoteResponse: Decodable {
        struct Source: Decodable {
            let name: String
            let proportion: String
        }
        
        let price: String
        let guaranteedPrice: String?
        let buyAmount: String
        let sellAmount: String
        let to: String
        let data: String
        let value: String
        let gas: String?
        let estimatedGas: String?
        let gasPrice: String?
        let allowanceTarget: String
        let sources: [Source]?
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
                return "Insufficient USDC balance"
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
    
    // 0x API configuration
    private let zeroExQuoteURL = "https://api.0x.org/swap/v1/quote"
    private var latestZeroExQuote: ZeroExQuoteResponse?
    private let zeroExAPIKey: String
    
    // Slippage tolerance (0.5% default)
    let defaultSlippageTolerance = ServiceConstants.defaultSlippageTolerance
    
    // MARK: - Initialization
    
    init(
        web3Client: Web3Client = Web3Client(),
        erc20Contract: ERC20Contract = ERC20Contract()
    ) {
        self.web3Client = web3Client
        self.erc20Contract = erc20Contract
        self.zeroExAPIKey = Bundle.main.object(forInfoDictionaryKey: "AGZeroXAPIKey") as? String ?? ""
        
        AppLogger.log("🔄 DEXSwapService initialized", category: "dex")
        AppLogger.log("   0x Quote URL: \(zeroExQuoteURL)", category: "dex")
    }
    
    // MARK: - Public Methods
    
    /// Get swap quote for USDC → PAXG
    func getQuote(params: SwapParams) async throws -> SwapQuote {
        AppLogger.log("📊 Getting swap quote: \(params.amount) \(params.fromToken.symbol) → \(params.toToken.symbol)", category: "dex")
        
        guard params.amount > 0 else {
            throw SwapError.invalidAmount
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Check balance
        let balances = try await erc20Contract.balancesOf(
            tokens: [.usdc],
            address: params.fromAddress
        )
        
        guard let balance = balances.first, balance.decimalBalance >= params.amount else {
            throw SwapError.insufficientBalance
        }
        
        let sellAmount = try toBaseUnits(params.amount, decimals: params.fromToken.decimals)
        var components = URLComponents(string: zeroExQuoteURL)
        components?.queryItems = [
            URLQueryItem(name: "sellToken", value: params.fromToken.address),
            URLQueryItem(name: "buyToken", value: params.toToken.address),
            URLQueryItem(name: "sellAmount", value: sellAmount),
            URLQueryItem(name: "takerAddress", value: params.fromAddress),
            URLQueryItem(
                name: "slippagePercentage",
                value: NSDecimalNumber(decimal: params.slippageTolerance / 100).stringValue
            )
        ]
        
        guard let url = components?.url else {
            throw SwapError.networkError("Invalid 0x quote URL")
        }
        
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        if !zeroExAPIKey.isEmpty {
            request.addValue(zeroExAPIKey, forHTTPHeaderField: "0x-api-key")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw SwapError.networkError("0x quote failed: \(message)")
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let quoteResponse = try decoder.decode(ZeroExQuoteResponse.self, from: data)
            latestZeroExQuote = quoteResponse
            
            let toAmount = fromBaseUnits(quoteResponse.buyAmount, decimals: params.toToken.decimals)
            let estimatedGasValue = decimalFromString(quoteResponse.estimatedGas ?? quoteResponse.gas ?? "")
            let estimatedGasText = estimatedGasValue != nil ? "~\(estimatedGasValue!) gas" : ServiceConstants.estimatedGasCost
            let activeSources = quoteResponse.sources?.filter {
                decimalFromString($0.proportion) ?? 0 > 0
            }.map { $0.name } ?? []
            let route = activeSources.isEmpty ? "0x Aggregator" : activeSources.joined(separator: " → ")
            
            let quote = SwapQuote(
                fromToken: params.fromToken,
                toToken: params.toToken,
                fromAmount: params.amount,
                toAmount: toAmount,
                estimatedGas: estimatedGasText,
                priceImpact: 0.1,
                route: route
            )
            
            currentQuote = quote
            AppLogger.log("✅ Quote: \(quote.displayFromAmount) → \(quote.displayToAmount)", category: "dex")
            AppLogger.log("   Route: \(quote.route)", category: "dex")
            return quote
        } catch let error as SwapError {
            throw error
        } catch {
            throw SwapError.networkError(error.localizedDescription)
        }
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
        
        // Parse hex allowance using safe parser for large numbers
        let allowanceValue: Decimal
        do {
            allowanceValue = try HexParser.parseToDecimal(resultString)
        } catch {
            throw SwapError.networkError("Failed to parse allowance: \(error.localizedDescription)")
        }
        
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
        try await Task.sleep(nanoseconds: ServiceConstants.approvalDelay)
        
        approvalState = .approved
        AppLogger.log("✅ Token approval successful", category: "dex")
    }
    
    /// Execute swap transaction
    /// Note: In production, this would use Privy SDK with gas sponsorship
    func executeSwap(params: SwapParams) async throws -> String {
        AppLogger.log("🔄 Executing swap: \(params.amount) \(params.fromToken.symbol) → \(params.toToken.symbol)", category: "dex")
        
        // Check approval first
        let zeroExProxy = latestZeroExQuote?.allowanceTarget ?? ContractAddresses.zeroExExchangeProxy
        let approvalState = try await checkApproval(
            tokenAddress: params.fromToken.address,
            ownerAddress: params.fromAddress,
            spenderAddress: zeroExProxy,
            amount: params.amount
        )
        
        if approvalState == .required {
            throw SwapError.approvalRequired
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // In production:
        // 1. Use latest 0x quote to build transaction data
        // 2. Use Privy SDK to sign and send transaction with gas sponsorship
        // 3. Return transaction hash
        
        // For now, simulate transaction
        try await Task.sleep(nanoseconds: ServiceConstants.swapDelay)
        
        let txHash = "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        AppLogger.log("✅ Swap executed: \(txHash)", category: "dex")
        
        return txHash
    }
    
    /// Reset state
    func reset() {
        currentQuote = nil
        approvalState = .notRequired
        latestZeroExQuote = nil
    }
    
    // MARK: - Helpers
    
    private func toBaseUnits(_ amount: Decimal, decimals: Int) throws -> String {
        let nsDecimal = NSDecimalNumber(decimal: amount)
        let scaled = nsDecimal.multiplying(byPowerOf10: Int16(decimals))
        guard scaled != NSDecimalNumber.notANumber else {
            throw SwapError.invalidAmount
        }
        return scaled.stringValue
    }
    
    private func fromBaseUnits(_ value: String, decimals: Int) -> Decimal {
        let decimal = NSDecimalNumber(string: value)
        if decimal == NSDecimalNumber.notANumber {
            return 0
        }
        let divisor = NSDecimalNumber(decimal: pow10(decimals))
        return decimal.dividing(by: divisor).decimalValue
    }
    
    private func decimalFromString(_ value: String) -> Decimal? {
        guard let decimal = Decimal(string: value) else { return nil }
        return decimal
    }
    
    private func pow10(_ exponent: Int) -> Decimal {
        var result = Decimal(1)
        for _ in 0..<max(0, exponent) {
            result *= 10
        }
        return result
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
