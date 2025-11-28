import Foundation

/// Configuration parameters for a Fluid Protocol vault
/// These parameters define the lending rules and risk thresholds
struct VaultConfig: Codable {
    
    // MARK: - Vault Identifiers
    
    let vaultAddress: String
    let supplyToken: String        // Collateral token (PAXG address)
    let borrowToken: String         // Debt token (USDC address)
    
    // MARK: - Risk Parameters
    
    /// Maximum Loan-to-Value ratio (e.g., 75.0 = 75%)
    /// Users can borrow up to this percentage of their collateral value
    let maxLTV: Decimal
    
    /// Liquidation Threshold (e.g., 85.0 = 85%)
    /// Position gets liquidated when debt reaches this percentage of collateral
    let liquidationThreshold: Decimal
    
    /// Liquidation Penalty (e.g., 3.0 = 3%)
    /// Extra fee charged when a position is liquidated
    let liquidationPenalty: Decimal
    
    // MARK: - Initialization
    
    /// Initialize with parsed blockchain data
    /// - Parameter rawConfig: Dictionary from VaultResolver.getVaultEntireData()
    init(rawConfig: [String: Any]) {
        // Parse vault address
        let constantVars = rawConfig["constantVariables"] as? [String: Any] ?? [:]
        self.vaultAddress = constantVars["vault"] as? String ?? ""
        self.supplyToken = constantVars["supplyToken"] as? String ?? ContractAddresses.paxg
        self.borrowToken = constantVars["borrowToken"] as? String ?? ContractAddresses.usdc
        
        // Parse configs (values are integers: 7500 = 75%)
        let configs = rawConfig["configs"] as? [String: Any] ?? [:]
        
        // Safely parse collateralFactor (max LTV)
        if let collateralFactorRaw = configs["collateralFactor"] as? Int {
            let value = Decimal(collateralFactorRaw) / 100
            // Safety check: if value is unreasonably large (> 100%), use safe default
            self.maxLTV = value > 100 ? 75.0 : value
        } else {
            self.maxLTV = 75.0  // Safe default
        }
        
        // Safely parse liquidationThreshold
        if let liquidationThresholdRaw = configs["liquidationThreshold"] as? Int {
            let value = Decimal(liquidationThresholdRaw) / 100
            self.liquidationThreshold = value > 100 ? 85.0 : value
        } else {
            self.liquidationThreshold = 85.0  // Safe default
        }
        
        // Safely parse liquidationPenalty
        if let liquidationPenaltyRaw = configs["liquidationPenalty"] as? Int {
            let value = Decimal(liquidationPenaltyRaw) / 100
            self.liquidationPenalty = value > 100 ? 3.0 : value
        } else {
            self.liquidationPenalty = 3.0  // Safe default
        }
    }
    
    /// Initialize with explicit values (for testing/mocking)
    init(
        vaultAddress: String = ContractAddresses.fluidPaxgUsdcVault,
        supplyToken: String = ContractAddresses.paxg,
        borrowToken: String = ContractAddresses.usdc,
        maxLTV: Decimal = 75.0,
        liquidationThreshold: Decimal = 85.0,
        liquidationPenalty: Decimal = 3.0
    ) {
        self.vaultAddress = vaultAddress
        self.supplyToken = supplyToken
        self.borrowToken = borrowToken
        self.maxLTV = maxLTV
        self.liquidationThreshold = liquidationThreshold
        self.liquidationPenalty = liquidationPenalty
    }
}

// MARK: - Mock Data (for development)

extension VaultConfig {
    static var mock: VaultConfig {
        return VaultConfig(
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            supplyToken: ContractAddresses.paxg,
            borrowToken: ContractAddresses.usdc,
            maxLTV: 75.0,
            liquidationThreshold: 85.0,
            liquidationPenalty: 3.0
        )
    }
    
    /// Default configuration used when API fails
    /// Provides safe, conservative values for borrowing
    static func defaultConfig() -> VaultConfig {
        return VaultConfig(
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            supplyToken: ContractAddresses.paxg,
            borrowToken: ContractAddresses.usdc,
            maxLTV: 75.0,          // 75% max loan-to-value (safe)
            liquidationThreshold: 85.0,  // 85% liquidation threshold
            liquidationPenalty: 3.0      // 3% liquidation penalty
        )
    }
}

