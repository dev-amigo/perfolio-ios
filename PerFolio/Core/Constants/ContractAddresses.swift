import Foundation

/// Ethereum mainnet contract addresses and constants
enum ContractAddresses {
    
    // MARK: - ERC20 Tokens
    
    /// USDT (Tether USD) on Ethereum Mainnet
    static let usdt = "0xdAC17F958D2ee523a2206206994597C13D831ec7"
    
    /// PAXG (Paxos Gold) on Ethereum Mainnet
    static let paxg = "0x45804880De22913dAFE09f4980848ECE6EcbAf78"
    
    // MARK: - DEX Routers
    
    /// 1inch v6 Aggregation Router on Ethereum Mainnet
    static let oneInchRouterV6 = "0x111111125421ca6dc452d289314280a0f8842a65"
    
    /// Uniswap V3 Router on Ethereum Mainnet
    static let uniswapV3Router = "0xE592427A0AEce92De3Edee1F18E0157C05861564"
    
    /// USDC (USD Coin) on Ethereum Mainnet
    static let usdc = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    
    // MARK: - Fluid Protocol (Borrow Feature)
    
    /// Fluid PAXG/USDC Vault - Main vault for collateralized lending
    static let fluidPaxgUsdcVault = "0x238207734AdBD22037af0437Ef65F13bABbd1917"
    
    /// Fluid Vault Resolver - For fetching vault config and user positions
    static let fluidVaultResolver = "0x394Ce45678e0019c0045194a561E2bEd0FCc6Cf0"
    
    /// Fluid Lending Resolver - For fetching borrow APY rates
    static let fluidLendingResolver = "0xC215485C572365AE87f908ad35233EC2572A3BEC"
}

/// DEX and on-ramp configuration constants
enum ServiceConstants {
    
    // MARK: - OnMeta
    
    /// OnMeta minimum deposit in INR
    static let onMetaMinINR: Decimal = 500
    
    /// OnMeta maximum deposit in INR
    static let onMetaMaxINR: Decimal = 100_000
    
    /// OnMeta provider fee percentage (2%)
    static let onMetaFeePercentage: Decimal = 0.02
    
    /// OnMeta estimated time for transaction
    static let onMetaEstimatedTime = "5-15 minutes"
    
    /// OnMeta default exchange rate (1 USDT = ₹92.5)
    /// Note: In production, fetch from OnMeta quote API
    static let onMetaDefaultExchangeRate: Decimal = 92.5
    
    // MARK: - DEX Swap
    
    /// Default slippage tolerance (0.5%)
    static let defaultSlippageTolerance: Decimal = 0.5
    
    /// Gold price in USDT (approx $2000/oz)
    /// Note: In production, fetch from CoinGecko or oracle
    static let goldPriceUSDT: Decimal = 2000
    
    /// High price impact threshold (3%)
    static let highPriceImpactThreshold: Decimal = 3.0
    
    /// Estimated gas cost range
    static let estimatedGasCost = "~$5-10"
    
    /// Default swap route description
    static let defaultSwapRoute = "USDT → WETH → PAXG (Uniswap V3)"
    
    // MARK: - Timeouts
    
    /// Network request timeout (30 seconds)
    static let networkTimeout: TimeInterval = 30
    
    /// Quote fetch delay (0.5 seconds - for simulation)
    static let quoteDelay: UInt64 = 500_000_000
    
    /// Approval simulation delay (2 seconds)
    static let approvalDelay: UInt64 = 2_000_000_000
    
    /// Swap simulation delay (3 seconds)
    static let swapDelay: UInt64 = 3_000_000_000
    
    /// Balance refresh delay (3 seconds)
    static let balanceRefreshDelay: UInt64 = 3_000_000_000
}

