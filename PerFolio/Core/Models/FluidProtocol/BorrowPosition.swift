import Foundation

/// Represents a user's active borrow position (loan) in Fluid Protocol
/// Each position is represented as an ERC721 NFT
struct BorrowPosition: Identifiable, Codable, Equatable {
    
    // MARK: - Identifiers
    
    /// Unique identifier (composite: "vaultAddress-nftId")
    let id: String
    
    /// Position NFT ID (from ERC721 Transfer event)
    let nftId: String
    
    /// Owner's wallet address
    let owner: String
    
    /// Vault contract address
    let vaultAddress: String
    
    // MARK: - Token Amounts (in token units, not Wei)
    
    /// PAXG collateral amount (18 decimals)
    let collateralAmount: Decimal
    
    /// USDC borrowed amount (6 decimals)
    let borrowAmount: Decimal
    
    // MARK: - USD Values
    
    /// Collateral value in USD (collateralAmount × PAXG price)
    let collateralValueUSD: Decimal
    
    /// Debt value in USD (borrowAmount, assuming USDC ≈ $1)
    let debtValueUSD: Decimal
    
    // MARK: - Risk Metrics
    
    /// Health Factor (HF = collateral × liqThreshold / debt)
    /// HF > 1.0: Position is safe
    /// HF ≤ 1.0: Position can be liquidated
    let healthFactor: Decimal
    
    /// Current Loan-to-Value ratio (LTV = debt / collateral × 100)
    let currentLTV: Decimal
    
    /// PAXG price at which position will be liquidated (HF = 1.0)
    let liquidationPrice: Decimal
    
    /// Additional USDC user can borrow at max LTV
    let availableToBorrowUSD: Decimal
    
    // MARK: - Status
    
    /// Position risk status based on health factor
    let status: PositionStatus
    
    /// When position was created
    let createdAt: Date
    
    /// Last update timestamp
    let lastUpdatedAt: Date
    
    // MARK: - Computed Properties
    
    /// Format health factor for display (handle infinity)
    var formattedHealthFactor: String {
        if healthFactor.isInfinite {
            return "∞"
        }
        if healthFactor > 100 {
            return ">100"
        }
        return String(format: "%.2f", NSDecimalNumber(decimal: healthFactor).doubleValue)
    }
    
    /// Short display of collateral (e.g., "0.123 PAXG")
    var collateralDisplay: String {
        return "\(formatDecimal(collateralAmount, maxDecimals: 6)) PAXG"
    }
    
    /// Short display of debt (e.g., "$100.00")
    var debtDisplay: String {
        return "$\(formatDecimal(borrowAmount, maxDecimals: 2))"
    }
    
    /// Status emoji
    var statusEmoji: String {
        switch status {
        case .safe: return "🟢"
        case .warning: return "🟡"
        case .danger: return "🔴"
        case .liquidated: return "⚫"
        }
    }
    
    // MARK: - Helper
    
    private func formatDecimal(_ value: Decimal, maxDecimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxDecimals
        formatter.groupingSeparator = ","
        return formatter.string(from: value as NSDecimalNumber) ?? "0"
    }
}

// MARK: - Position Status

extension BorrowPosition {
    enum PositionStatus: String, Codable {
        case safe       // HF > 1.5
        case warning    // 1.2 < HF ≤ 1.5
        case danger     // 1.0 < HF ≤ 1.2
        case liquidated // HF ≤ 1.0
        
        var displayName: String {
            switch self {
            case .safe: return "Safe"
            case .warning: return "Warning"
            case .danger: return "Danger"
            case .liquidated: return "Liquidated"
            }
        }
        
        var color: String {
            switch self {
            case .safe: return "green"
            case .warning: return "yellow"
            case .danger: return "red"
            case .liquidated: return "gray"
            }
        }
    }
}

// MARK: - Factory

extension BorrowPosition {
    
    /// Create position from blockchain data
    static func from(
        nftId: String,
        owner: String,
        vaultAddress: String,
        collateralWei: String,  // Hex string
        borrowSmallestUnit: String,  // Hex string
        paxgPrice: Decimal,
        liquidationThreshold: Decimal,
        maxLTV: Decimal
    ) -> BorrowPosition {
        
        // Convert from Wei/smallest units to token amounts
        let collateralAmount = hexToDecimal(collateralWei, decimals: 18)
        let borrowAmount = hexToDecimal(borrowSmallestUnit, decimals: 6)
        
        // Calculate USD values
        let collateralValueUSD = collateralAmount * paxgPrice
        let debtValueUSD = borrowAmount  // USDC ≈ $1
        
        // Calculate risk metrics
        let currentLTV = collateralValueUSD > 0 ? (debtValueUSD / collateralValueUSD) * 100 : 0
        let healthFactor = calculateHealthFactor(
            collateralValueUSD: collateralValueUSD,
            debtValueUSD: debtValueUSD,
            liquidationThreshold: liquidationThreshold
        )
        let liquidationPrice = calculateLiquidationPrice(
            collateralAmount: collateralAmount,
            debtValueUSD: debtValueUSD,
            liquidationThreshold: liquidationThreshold
        )
        let availableToBorrowUSD = calculateAvailableToBorrow(
            collateralValueUSD: collateralValueUSD,
            currentDebtUSD: debtValueUSD,
            maxLTV: maxLTV
        )
        
        // Determine status
        let status: PositionStatus
        if healthFactor <= 1.0 {
            status = .liquidated
        } else if healthFactor <= 1.2 {
            status = .danger
        } else if healthFactor <= 1.5 {
            status = .warning
        } else {
            status = .safe
        }
        
        return BorrowPosition(
            id: "\(vaultAddress)-\(nftId)",
            nftId: nftId,
            owner: owner,
            vaultAddress: vaultAddress,
            collateralAmount: collateralAmount,
            borrowAmount: borrowAmount,
            collateralValueUSD: collateralValueUSD,
            debtValueUSD: debtValueUSD,
            healthFactor: healthFactor,
            currentLTV: currentLTV,
            liquidationPrice: liquidationPrice,
            availableToBorrowUSD: availableToBorrowUSD,
            status: status,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
    }
    
    /// Create a position from locally calculated borrow metrics.
    static func from(
        metrics: BorrowMetrics,
        nftId: String,
        owner: String,
        vaultAddress: String
    ) -> BorrowPosition {
        let collateralValueUSD = metrics.collateralValueUSD
        let debtValueUSD = metrics.borrowAmount
        let liquidationPrice = metrics.liquidationPrice
        let availableToBorrowUSD = max(metrics.maxBorrowableUSD - metrics.borrowAmount, 0)
        let healthFactor = metrics.healthFactor
        let currentLTV = metrics.currentLTV
        
        let status: PositionStatus
        if healthFactor <= 1.0 {
            status = .liquidated
        } else if healthFactor <= 1.2 {
            status = .danger
        } else if healthFactor <= 1.5 {
            status = .warning
        } else {
            status = .safe
        }
        
        return BorrowPosition(
            id: "\(vaultAddress)-\(nftId)",
            nftId: nftId,
            owner: owner,
            vaultAddress: vaultAddress,
            collateralAmount: metrics.collateralAmount,
            borrowAmount: metrics.borrowAmount,
            collateralValueUSD: collateralValueUSD,
            debtValueUSD: debtValueUSD,
            healthFactor: healthFactor,
            currentLTV: currentLTV,
            liquidationPrice: liquidationPrice,
            availableToBorrowUSD: availableToBorrowUSD,
            status: status,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
    }
    
    // MARK: - Calculation Helpers
    
    private static func hexToDecimal(_ hex: String, decimals: Int) -> Decimal {
        let cleanHex = hex.replacingOccurrences(of: "0x", with: "")
        var result: Decimal = 0
        for char in cleanHex {
            if let digit = char.hexDigitValue {
                result = result * 16 + Decimal(digit)
            }
        }
        return result / pow(Decimal(10), decimals)
    }
    
    private static func calculateHealthFactor(
        collateralValueUSD: Decimal,
        debtValueUSD: Decimal,
        liquidationThreshold: Decimal
    ) -> Decimal {
        guard debtValueUSD > 0 else { return Decimal(Double.infinity) }
        guard collateralValueUSD > 0 else { return 0 }
        let numerator = collateralValueUSD * (liquidationThreshold / 100)
        return numerator / debtValueUSD
    }
    
    private static func calculateLiquidationPrice(
        collateralAmount: Decimal,
        debtValueUSD: Decimal,
        liquidationThreshold: Decimal
    ) -> Decimal {
        guard collateralAmount > 0, liquidationThreshold > 0 else { return 0 }
        let denominator = collateralAmount * (liquidationThreshold / 100)
        return debtValueUSD / denominator
    }
    
    private static func calculateAvailableToBorrow(
        collateralValueUSD: Decimal,
        currentDebtUSD: Decimal,
        maxLTV: Decimal
    ) -> Decimal {
        let maxDebtUSD = collateralValueUSD * (maxLTV / 100)
        let available = maxDebtUSD - currentDebtUSD
        return max(0, available)
    }
}

// MARK: - Mock Data

extension BorrowPosition {
    static var mock: BorrowPosition {
        return BorrowPosition(
            id: "\(ContractAddresses.fluidPaxgUsdcVault)-1",
            nftId: "1",
            owner: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 0.1,  // 0.1 PAXG
            borrowAmount: 100.0,     // $100 USDC
            collateralValueUSD: 418.30,  // 0.1 × $4,183
            debtValueUSD: 100.0,
            healthFactor: 3.56,      // (418.30 × 0.85) / 100
            currentLTV: 23.9,        // (100 / 418.30) × 100
            liquidationPrice: 1176.47,  // 100 / (0.1 × 0.85)
            availableToBorrowUSD: 213.73,  // (418.30 × 0.75) - 100
            status: .safe,
            createdAt: Date().addingTimeInterval(-86400 * 2),  // 2 days ago
            lastUpdatedAt: Date()
        )
    }
}
