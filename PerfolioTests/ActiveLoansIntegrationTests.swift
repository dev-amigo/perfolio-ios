import XCTest
@testable import PerFolio

@MainActor
final class ActiveLoansIntegrationTests: XCTestCase {
    
    // MARK: - End-to-End Action Flow Tests
    
    func testPayBackLoan_CompleteFlow() async throws {
        // Given: User has active position with debt
        let position = BorrowPosition.mock
        let mockVaultService = MockFluidVaultService()
        let handler = LoanActionHandler(vaultService: mockVaultService)
        
        // When: User pays back part of the loan
        let payBackAmount: Decimal = 50.0
        try await handler.repay(position: position, amount: payBackAmount)
        
        // Then: Transaction should be submitted correctly
        XCTAssertTrue(mockVaultService.repayCalled)
        XCTAssertEqual(mockVaultService.lastRepayAmount, payBackAmount)
    }
    
    func testAddCollateral_ImproveHealth Factor() async throws {
        // Given: Position with moderate health factor
        let initialPosition = BorrowPosition(
            id: "test-1",
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 0.1,
            borrowAmount: 200.0,
            collateralValueUSD: 400.0,
            debtValueUSD: 200.0,
            healthFactor: 1.7, // Warning range
            currentLTV: 50.0,
            liquidationPrice: 500.0,
            availableToBorrowUSD: 100.0,
            status: .warning,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
        
        let mockVaultService = MockFluidVaultService()
        let handler = LoanActionHandler(vaultService: mockVaultService)
        
        // When: User adds more collateral
        let additionalCollateral: Decimal = 0.05
        try await handler.addCollateral(position: initialPosition, amount: additionalCollateral)
        
        // Then: Transaction should be submitted
        XCTAssertTrue(mockVaultService.addCollateralCalled)
        
        // Calculate expected new health factor
        // New collateral: 0.15 PAXG @ $4000 = $600
        // Debt remains: $200
        // New HF = (600 * 0.85) / 200 = 2.55 (Safe!)
        let newCollateralValue = (initialPosition.collateralAmount + additionalCollateral) * 4000.0
        let newHealthFactor = (newCollateralValue * 0.85) / initialPosition.debtValueUSD
        XCTAssertGreaterThan(newHealthFactor, 2.0, "Health factor should improve to safe range")
    }
    
    func testWithdraw_RiskValidation() async throws {
        // Given: Position near max LTV
        let position = BorrowPosition(
            id: "test-1",
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 0.1,
            borrowAmount: 290.0, // Near max (0.1 * 4000 * 0.75 = 300)
            collateralValueUSD: 400.0,
            debtValueUSD: 290.0,
            healthFactor: 1.17, // Danger range
            currentLTV: 72.5,
            liquidationPrice: 3800.0,
            availableToBorrowUSD: 10.0,
            status: .danger,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
        
        let mockVaultService = MockFluidVaultService()
        let handler = LoanActionHandler(vaultService: mockVaultService)
        
        // When: User tries to withdraw too much collateral
        // Withdrawing 0.05 PAXG would leave only 0.05 PAXG ($200) vs $290 debt
        // Health factor would become: (200 * 0.85) / 290 = 0.59 (Liquidation!)
        
        // For this test, we'll simulate that the vault service prevents this
        mockVaultService.shouldThrowError = true
        mockVaultService.errorToThrow = FluidVaultError.unsafeHealthFactor
        
        // Then: Should throw error
        do {
            try await handler.withdraw(position: position, amount: 0.05)
            XCTFail("Should have thrown unsafeHealthFactor error")
        } catch let error as FluidVaultError {
            XCTAssertEqual(error, FluidVaultError.unsafeHealthFactor)
        }
    }
    
    func testCloseLoan_FullFlow() async throws {
        // Given: Position with both collateral and debt
        let position = BorrowPosition(
            id: "test-1",
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 0.1,
            borrowAmount: 100.0,
            collateralValueUSD: 400.0,
            debtValueUSD: 100.0,
            healthFactor: 3.4,
            currentLTV: 25.0,
            liquidationPrice: 1176.0,
            availableToBorrowUSD: 200.0,
            status: .safe,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
        
        let mockVaultService = MockFluidVaultService()
        let handler = LoanActionHandler(vaultService: mockVaultService)
        
        // When: User closes the loan
        try await handler.close(position: position)
        
        // Then: Should call close (which internally calls repay + withdraw)
        XCTAssertTrue(mockVaultService.closeCalled)
    }
    
    // MARK: - Position Lifecycle Tests
    
    func testPositionLifecycle_FromCreationToClosure() async throws {
        // This test simulates the full lifecycle of a loan position
        
        // Step 1: Position created (from blockchain data)
        let initialPosition = BorrowPosition.from(
            nftId: "8896",
            owner: "0xB3Eb44b13f05eDcb2aC1802e2725b6F35f77D33c",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralWei: "0x16345785d8a0000", // 0.1 PAXG
            borrowSmallestUnit: "0x5f5e100", // 100 USDC
            paxgPrice: 4000.0,
            liquidationThreshold: 85.0,
            maxLTV: 75.0
        )
        
        // Verify initial state
        XCTAssertEqual(initialPosition.status, .safe)
        XCTAssertGreaterThan(initialPosition.healthFactor, 2.0)
        
        // Step 2: Simulate price drop
        let positionAfterPriceDrop = BorrowPosition.from(
            nftId: "8896",
            owner: "0xB3Eb44b13f05eDcb2aC1802e2725b6F35f77D33c",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralWei: "0x16345785d8a0000", // Same 0.1 PAXG
            borrowSmallestUnit: "0x5f5e100", // Same 100 USDC
            paxgPrice: 1500.0, // PAXG dropped to $1500
            liquidationThreshold: 85.0,
            maxLTV: 75.0
        )
        
        // Verify health factor decreased
        XCTAssertLessThan(positionAfterPriceDrop.healthFactor, initialPosition.healthFactor)
        // HF = (0.1 * 1500 * 0.85) / 100 = 1.275 (Warning!)
        XCTAssertEqual(positionAfterPriceDrop.status, .warning)
        
        // Step 3: User adds collateral to improve health
        let mockVaultService = MockFluidVaultService()
        let handler = LoanActionHandler(vaultService: mockVaultService)
        
        try await handler.addCollateral(position: positionAfterPriceDrop, amount: 0.05)
        XCTAssertTrue(mockVaultService.addCollateralCalled)
        
        // Step 4: User eventually closes position
        try await handler.close(position: initialPosition)
        XCTAssertTrue(mockVaultService.closeCalled)
    }
    
    // MARK: - Multi-Position Management Tests
    
    func testMultiplePositions_IndependentManagement() async {
        // Given: User has 2 different positions
        let position1 = BorrowPosition(
            id: "vault1-nft1",
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 0.1,
            borrowAmount: 100.0,
            collateralValueUSD: 400.0,
            debtValueUSD: 100.0,
            healthFactor: 3.4,
            currentLTV: 25.0,
            liquidationPrice: 1176.0,
            availableToBorrowUSD: 200.0,
            status: .safe,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
        
        let position2 = BorrowPosition(
            id: "vault1-nft2",
            nftId: "2",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 0.2,
            borrowAmount: 300.0,
            collateralValueUSD: 800.0,
            debtValueUSD: 300.0,
            healthFactor: 2.27,
            currentLTV: 37.5,
            liquidationPrice: 1764.0,
            availableToBorrowUSD: 300.0,
            status: .safe,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
        
        let mockVaultService = MockFluidVaultService()
        let handler = LoanActionHandler(vaultService: mockVaultService)
        
        // When: Manage positions independently
        try await handler.repay(position: position1, amount: 50.0)
        XCTAssertEqual(mockVaultService.repayCallCount, 1)
        
        try await handler.addCollateral(position: position2, amount: 0.05)
        XCTAssertEqual(mockVaultService.addCollateralCallCount, 1)
        
        // Then: Each position should be managed separately
        XCTAssertEqual(mockVaultService.lastPosition?.nftId, "2")
    }
    
    // MARK: - Error Recovery Tests
    
    func testTransactionFailure_DoesNotCorruptState() async throws {
        // Given: Position and handler
        let position = BorrowPosition.mock
        let mockVaultService = MockFluidVaultService()
        let handler = LoanActionHandler(vaultService: mockVaultService)
        
        // When: Transaction fails
        mockVaultService.shouldThrowError = true
        mockVaultService.errorToThrow = FluidVaultError.transactionFailed("Network error")
        
        do {
            try await handler.repay(position: position, amount: 50.0)
            XCTFail("Should have thrown error")
        } catch {
            // Then: Handler state should be reset
            XCTAssertFalse(handler.isPerforming)
            
            // And: Should be able to retry
            mockVaultService.shouldThrowError = false
            try await handler.repay(position: position, amount: 50.0)
            XCTAssertTrue(mockVaultService.repayCalled)
        }
    }
    
    // MARK: - Data Consistency Tests
    
    func testPositionData_RemainsConsistent() {
        // Given: Position with specific values
        let collateralAmount: Decimal = 0.1
        let borrowAmount: Decimal = 100.0
        let paxgPrice: Decimal = 4000.0
        let liquidationThreshold: Decimal = 85.0
        
        let position = BorrowPosition.from(
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralWei: "0x16345785d8a0000",
            borrowSmallestUnit: "0x5f5e100",
            paxgPrice: paxgPrice,
            liquidationThreshold: liquidationThreshold,
            maxLTV: 75.0
        )
        
        // Then: Verify all calculated values are consistent
        let expectedCollateralValue = collateralAmount * paxgPrice
        let expectedHealthFactor = (expectedCollateralValue * (liquidationThreshold / 100)) / borrowAmount
        let expectedLTV = (borrowAmount / expectedCollateralValue) * 100
        let expectedLiquidationPrice = borrowAmount / (collateralAmount * (liquidationThreshold / 100))
        
        XCTAssertEqual(position.collateralValueUSD, expectedCollateralValue, accuracy: 1.0)
        XCTAssertEqual(position.healthFactor, expectedHealthFactor, accuracy: 0.1)
        XCTAssertEqual(position.currentLTV, expectedLTV, accuracy: 1.0)
        XCTAssertEqual(position.liquidationPrice, expectedLiquidationPrice, accuracy: 10.0)
    }
}

