import XCTest
@testable import PerFolio

final class BorrowPositionTests: XCTestCase {
    
    // MARK: - Factory Method Tests
    
    func testFrom_CreatesPositionCorrectly() {
        // Given: Valid blockchain data
        let nftId = "1234"
        let owner = "0xB3Eb44b13f05eDcb2aC1802e2725b6F35f77D33c"
        let vaultAddress = ContractAddresses.fluidPaxgUsdcVault
        let collateralWei = "0x8ac7230489e80000" // 0.01 PAXG (10^16 wei)
        let borrowSmallestUnit = "0x1f4f62" // ~2.05 USDC (2050000 smallest units)
        let paxgPrice: Decimal = 4000.0
        let liquidationThreshold: Decimal = 85.0
        let maxLTV: Decimal = 75.0
        
        // When: Create position from blockchain data
        let position = BorrowPosition.from(
            nftId: nftId,
            owner: owner,
            vaultAddress: vaultAddress,
            collateralWei: collateralWei,
            borrowSmallestUnit: borrowSmallestUnit,
            paxgPrice: paxgPrice,
            liquidationThreshold: liquidationThreshold,
            maxLTV: maxLTV
        )
        
        // Then: Should parse correctly
        XCTAssertEqual(position.nftId, nftId)
        XCTAssertEqual(position.owner, owner)
        XCTAssertEqual(position.vaultAddress, vaultAddress)
        XCTAssertGreaterThan(position.collateralAmount, 0)
        XCTAssertGreaterThan(position.borrowAmount, 0)
        XCTAssertGreaterThan(position.healthFactor, 0)
    }
    
    // MARK: - Status Calculation Tests
    
    func testStatus_Safe_WhenHealthFactorAbove1Point5() {
        // Given: Position with HF = 3.0
        let position = createTestPosition(healthFactor: 3.0)
        
        // Then: Status should be safe
        XCTAssertEqual(position.status, .safe)
        XCTAssertEqual(position.statusEmoji, "🟢")
    }
    
    func testStatus_Warning_WhenHealthFactorBetween1Point2And1Point5() {
        // Given: Position with HF = 1.3
        let position = createTestPosition(healthFactor: 1.3)
        
        // Then: Status should be warning
        XCTAssertEqual(position.status, .warning)
        XCTAssertEqual(position.statusEmoji, "🟡")
    }
    
    func testStatus_Danger_WhenHealthFactorBetween1Point0And1Point2() {
        // Given: Position with HF = 1.1
        let position = createTestPosition(healthFactor: 1.1)
        
        // Then: Status should be danger
        XCTAssertEqual(position.status, .danger)
        XCTAssertEqual(position.statusEmoji, "🔴")
    }
    
    func testStatus_Liquidated_WhenHealthFactorBelow1Point0() {
        // Given: Position with HF = 0.9
        let position = createTestPosition(healthFactor: 0.9)
        
        // Then: Status should be liquidated
        XCTAssertEqual(position.status, .liquidated)
        XCTAssertEqual(position.statusEmoji, "⚫")
    }
    
    // MARK: - Display Format Tests
    
    func testFormattedHealthFactor_ShowsCorrectFormat() {
        // Test normal value
        let position1 = createTestPosition(healthFactor: 3.56)
        XCTAssertEqual(position1.formattedHealthFactor, "3.56")
        
        // Test infinity
        let position2 = createTestPosition(healthFactor: Decimal(Double.infinity))
        XCTAssertEqual(position2.formattedHealthFactor, "∞")
        
        // Test > 100
        let position3 = createTestPosition(healthFactor: 150.0)
        XCTAssertEqual(position3.formattedHealthFactor, ">100")
    }
    
    func testCollateralDisplay_ShowsCorrectFormat() {
        // Given: Position with 0.1 PAXG
        let position = BorrowPosition(
            id: "test",
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 0.123456,
            borrowAmount: 100.0,
            collateralValueUSD: 500.0,
            debtValueUSD: 100.0,
            healthFactor: 3.0,
            currentLTV: 20.0,
            liquidationPrice: 200.0,
            availableToBorrowUSD: 275.0,
            status: .safe,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
        
        // Then: Should display with max 6 decimals
        XCTAssertEqual(position.collateralDisplay, "0.123456 PAXG")
    }
    
    func testDebtDisplay_ShowsCorrectFormat() {
        // Given: Position with 100.50 USDC debt
        let position = BorrowPosition(
            id: "test",
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 0.1,
            borrowAmount: 100.50,
            collateralValueUSD: 400.0,
            debtValueUSD: 100.50,
            healthFactor: 3.0,
            currentLTV: 25.0,
            liquidationPrice: 200.0,
            availableToBorrowUSD: 199.50,
            status: .safe,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
        
        // Then: Should display with $ and 2 decimals
        XCTAssertEqual(position.debtDisplay, "$100.5")
    }
    
    // MARK: - Hex Conversion Tests
    
    func testHexToDecimal_PAXG_18Decimals() {
        // Given: 0.01 PAXG in hex (10^16 wei)
        let hexValue = "0x8ac7230489e80000"
        
        // When: Convert using factory method
        let position = BorrowPosition.from(
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralWei: hexValue,
            borrowSmallestUnit: "0x0",
            paxgPrice: 4000.0,
            liquidationThreshold: 85.0,
            maxLTV: 75.0
        )
        
        // Then: Should convert correctly
        XCTAssertEqual(position.collateralAmount, 0.01, accuracy: 0.0001)
    }
    
    func testHexToDecimal_USDC_6Decimals() {
        // Given: 100 USDC in hex (100 * 10^6 = 100000000)
        let hexValue = "0x5f5e100" // 100000000 in hex
        
        // When: Convert using factory method
        let position = BorrowPosition.from(
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralWei: "0x0",
            borrowSmallestUnit: hexValue,
            paxgPrice: 4000.0,
            liquidationThreshold: 85.0,
            maxLTV: 75.0
        )
        
        // Then: Should convert correctly
        XCTAssertEqual(position.borrowAmount, 100.0, accuracy: 0.01)
    }
    
    // MARK: - Risk Metrics Calculation Tests
    
    func testHealthFactor_Calculation() {
        // Given: Known values
        // Collateral: 0.1 PAXG @ $4000 = $400
        // Debt: $100
        // Liquidation threshold: 85%
        // Expected HF = (400 * 0.85) / 100 = 3.4
        
        let position = BorrowPosition.from(
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralWei: "0x16345785d8a0000", // 0.1 PAXG
            borrowSmallestUnit: "0x5f5e100", // 100 USDC
            paxgPrice: 4000.0,
            liquidationThreshold: 85.0,
            maxLTV: 75.0
        )
        
        // Then: Health factor should be ~3.4
        XCTAssertEqual(position.healthFactor, 3.4, accuracy: 0.1)
    }
    
    func testLTV_Calculation() {
        // Given: Known values
        // Collateral: $400, Debt: $100
        // Expected LTV = (100 / 400) * 100 = 25%
        
        let position = BorrowPosition.from(
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralWei: "0x16345785d8a0000", // 0.1 PAXG
            borrowSmallestUnit: "0x5f5e100", // 100 USDC
            paxgPrice: 4000.0,
            liquidationThreshold: 85.0,
            maxLTV: 75.0
        )
        
        // Then: LTV should be ~25%
        XCTAssertEqual(position.currentLTV, 25.0, accuracy: 1.0)
    }
    
    func testLiquidationPrice_Calculation() {
        // Given: Known values
        // Collateral: 0.1 PAXG, Debt: $100, Liq threshold: 85%
        // Expected liquidation price = 100 / (0.1 * 0.85) = $1,176.47
        
        let position = BorrowPosition.from(
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralWei: "0x16345785d8a0000", // 0.1 PAXG
            borrowSmallestUnit: "0x5f5e100", // 100 USDC
            paxgPrice: 4000.0,
            liquidationThreshold: 85.0,
            maxLTV: 75.0
        )
        
        // Then: Liquidation price should be ~$1176
        XCTAssertEqual(position.liquidationPrice, 1176.47, accuracy: 10.0)
    }
    
    func testAvailableToBorrow_Calculation() {
        // Given: Known values
        // Collateral: $400, Current debt: $100, Max LTV: 75%
        // Max possible debt = 400 * 0.75 = $300
        // Available = 300 - 100 = $200
        
        let position = BorrowPosition.from(
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralWei: "0x16345785d8a0000", // 0.1 PAXG
            borrowSmallestUnit: "0x5f5e100", // 100 USDC
            paxgPrice: 4000.0,
            liquidationThreshold: 85.0,
            maxLTV: 75.0
        )
        
        // Then: Available to borrow should be ~$200
        XCTAssertEqual(position.availableToBorrowUSD, 200.0, accuracy: 10.0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testHealthFactor_Infinity_WhenNoDebt() {
        // Given: Position with 0 debt
        let position = BorrowPosition.from(
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralWei: "0x16345785d8a0000", // 0.1 PAXG
            borrowSmallestUnit: "0x0", // 0 USDC
            paxgPrice: 4000.0,
            liquidationThreshold: 85.0,
            maxLTV: 75.0
        )
        
        // Then: Health factor should be infinite
        XCTAssertTrue(position.healthFactor.isInfinite)
        XCTAssertEqual(position.formattedHealthFactor, "∞")
    }
    
    func testLTV_Zero_WhenNoDebt() {
        // Given: Position with 0 debt
        let position = BorrowPosition.from(
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralWei: "0x16345785d8a0000",
            borrowSmallestUnit: "0x0",
            paxgPrice: 4000.0,
            liquidationThreshold: 85.0,
            maxLTV: 75.0
        )
        
        // Then: LTV should be 0
        XCTAssertEqual(position.currentLTV, 0.0)
    }
    
    // MARK: - Helper Methods
    
    private func createTestPosition(healthFactor: Decimal) -> BorrowPosition {
        return BorrowPosition(
            id: "test-\(UUID().uuidString)",
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 0.1,
            borrowAmount: 100.0,
            collateralValueUSD: 400.0,
            debtValueUSD: 100.0,
            healthFactor: healthFactor,
            currentLTV: 25.0,
            liquidationPrice: 200.0,
            availableToBorrowUSD: 200.0,
            status: determineStatus(healthFactor: healthFactor),
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
    }
    
    private func determineStatus(healthFactor: Decimal) -> BorrowPosition.PositionStatus {
        if healthFactor <= 1.0 {
            return .liquidated
        } else if healthFactor <= 1.2 {
            return .danger
        } else if healthFactor <= 1.5 {
            return .warning
        } else {
            return .safe
        }
    }
}

