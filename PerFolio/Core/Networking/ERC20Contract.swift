import Foundation

public struct TokenBalance {
    public let address: String
    public let symbol: String
    public let decimals: Int
    public let rawBalance: String  // Hex string
    public let formattedBalance: String
    public let decimalBalance: Decimal
    
    public init(address: String, symbol: String, decimals: Int, rawBalance: String, formattedBalance: String, decimalBalance: Decimal) {
        self.address = address
        self.symbol = symbol
        self.decimals = decimals
        self.rawBalance = rawBalance
        self.formattedBalance = formattedBalance
        self.decimalBalance = decimalBalance
    }
    
    // Convenience init for tests
    public init(address: String, symbol: String, decimals: Int, balance: String, decimalBalance: Decimal) {
        self.address = address
        self.symbol = symbol
        self.decimals = decimals
        self.rawBalance = balance
        self.formattedBalance = CurrencyFormatter.formatToken(decimalBalance, symbol: symbol)
        self.decimalBalance = decimalBalance
    }
}

public actor ERC20Contract {
    // Contract addresses on Ethereum Mainnet
    public enum Token {
        case paxg
        case usdt
        case usdc  // NEW: For Fluid Protocol borrow
        
        public var address: String {
            switch self {
            case .paxg:
                return "0x45804880De22913dAFE09f4980848ECE6EcbAf78"
            case .usdt:
                return "0xdAC17F958D2ee523a2206206994597C13D831ec7"
            case .usdc:
                return "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
            }
        }
        
        public var symbol: String {
            switch self {
            case .paxg: return "PAXG"
            case .usdt: return "USDT"
            case .usdc: return "USDC"
            }
        }
        
        public var decimals: Int {
            switch self {
            case .paxg: return 18
            case .usdt: return 6
            case .usdc: return 6
            }
        }
    }
    
    private let web3Client: Web3Client
    
    init(web3Client: Web3Client = Web3Client()) {
        self.web3Client = web3Client
    }
    
    /// Get the balance of a token for an address
    func balanceOf(token: Token, address: String) async throws -> TokenBalance {
        // Encode the balanceOf(address) function call
        // Function selector: 0x70a08231 (first 4 bytes of keccak256("balanceOf(address)"))
        let functionSelector = "0x70a08231"
        
        // Pad address to 32 bytes (remove 0x prefix, pad left to 64 chars)
        let cleanAddress = address.replacingOccurrences(of: "0x", with: "")
        let paddedAddress = cleanAddress.paddingLeft(to: 64, with: "0")
        
        // Combine function selector and padded address
        let callData = functionSelector + paddedAddress
        
        AppLogger.log("Fetching \(token.symbol) balance for \(address)", category: "web3")
        
        // Make the eth_call
        let result = try await web3Client.ethCall(
            to: token.address,
            data: callData
        )
        
        // Parse the result (hex string representing uint256)
        let rawBalanceDecimal = try parseUint256(result)
        
        // Convert to decimal with proper decimals
        let decimalBalance = convertToDecimal(rawBalanceDecimal, decimals: token.decimals)
        
        // Format for display
        let formattedBalance = formatBalance(decimalBalance, decimals: token.decimals)
        
        AppLogger.log("\(token.symbol) balance: \(formattedBalance)", category: "web3")
        
        return TokenBalance(
            address: token.address,
            symbol: token.symbol,
            decimals: token.decimals,
            rawBalance: result,  // Store original hex string
            formattedBalance: formattedBalance,
            decimalBalance: decimalBalance
        )
    }
    
    /// Get balances for multiple tokens in parallel
    func balancesOf(tokens: [Token], address: String) async throws -> [TokenBalance] {
        return try await withThrowingTaskGroup(of: TokenBalance.self) { group in
            for token in tokens {
                group.addTask {
                    try await self.balanceOf(token: token, address: address)
                }
            }
            
            var balances: [TokenBalance] = []
            for try await balance in group {
                balances.append(balance)
            }
            return balances
        }
    }
    
    // MARK: - Helper Functions
    
    private func parseUint256(_ hexString: String) throws -> Decimal {
        let cleanHex = hexString.replacingOccurrences(of: "0x", with: "")
        
        // Convert hex to Decimal using manual calculation
        var result: Decimal = 0
        for char in cleanHex {
            if let digit = char.hexDigitValue {
                result = result * 16 + Decimal(digit)
            } else {
                throw Web3Error.decodingFailed
            }
        }
        
        return result
    }
    
    private func convertToDecimal(_ value: Decimal, decimals: Int) -> Decimal {
        let divisor = pow(Decimal(10), decimals)
        return value / divisor
    }
    
    private func formatBalance(_ balance: Decimal, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = decimals <= 6 ? 2 : 4  // Stablecoins: 2 decimals, PAXG: 4 decimals
        formatter.groupingSeparator = ","
        
        return formatter.string(from: balance as NSDecimalNumber) ?? "0"
    }
}

// MARK: - String Extension

extension String {
    func paddingLeft(to length: Int, with character: Character) -> String {
        let padLength = length - self.count
        if padLength <= 0 {
            return self
        }
        return String(repeating: character, count: padLength) + self
    }
}
