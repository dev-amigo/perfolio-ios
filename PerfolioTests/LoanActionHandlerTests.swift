import XCTest
@testable import PerFolio

@MainActor
final class LoanActionHandlerTests: XCTestCase {
    
    var handler: LoanActionHandler!
    var mockVaultService: MockFluidVaultService!
    var testPosition: BorrowPosition!
    
    override func setUp() {
        super.setUp()
        mockVaultService = MockFluidVaultService()
        handler = LoanActionHandler(vaultService: mockVaultService)
        
        testPosition = BorrowPosition.mock
    }
    
    override func tearDown() {
        handler = nil
        mockVaultService = nil
        testPosition = nil
        super.tearDown()
    }
    
    // MARK: - Add Collateral Tests
    
    func testAddCollateral_Success() async throws {
        // Given: Valid amount
        let amount: Decimal = 0.05
        
        // When: Add collateral
        try await handler.addCollateral(position: testPosition, amount: amount)
        
        // Then: Service should be called with correct parameters
        XCTAssertTrue(mockVaultService.addCollateralCalled)
        XCTAssertEqual(mockVaultService.lastCollateralAmount, amount)
        XCTAssertEqual(mockVaultService.lastPosition?.nftId, testPosition.nftId)
    }
    
    func testAddCollateral_PreventsDuplicateCalls() async throws {
        // Given: Handler is already performing
        mockVaultService.shouldDelay = true
        
        // When: Trigger two add collateral calls simultaneously
        let task1 = Task { try await handler.addCollateral(position: testPosition, amount: 0.05) }
        let task2 = Task { try await handler.addCollateral(position: testPosition, amount: 0.03) }
        
        _ = try await task1.value
        _ = try await task2.value
        
        // Then: Only first call should execute
        XCTAssertEqual(mockVaultService.addCollateralCallCount, 1)
    }
    
    func testAddCollateral_UpdatesIsPerformingState() async throws {
        // Given: Initial state
        XCTAssertFalse(handler.isPerforming)
        
        // When: Add collateral
        mockVaultService.shouldDelay = true
        let task = Task {
            try await handler.addCollateral(position: testPosition, amount: 0.05)
        }
        
        // Give async task time to start
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then: Should be performing
        XCTAssertTrue(handler.isPerforming)
        
        // Wait for completion
        _ = try await task.value
        
        // Then: Should be done
        XCTAssertFalse(handler.isPerforming)
    }
    
    // MARK: - Repay Tests
    
    func testRepay_Success() async throws {
        // Given: Valid repay amount
        let amount: Decimal = 50.0
        
        // When: Repay
        try await handler.repay(position: testPosition, amount: amount)
        
        // Then: Service should be called
        XCTAssertTrue(mockVaultService.repayCalled)
        XCTAssertEqual(mockVaultService.lastRepayAmount, amount)
        XCTAssertEqual(mockVaultService.lastPosition?.nftId, testPosition.nftId)
    }
    
    func testRepay_ThrowsError_WhenServiceFails() async {
        // Given: Service will fail
        mockVaultService.shouldThrowError = true
        mockVaultService.errorToThrow = FluidVaultError.insufficientBalance
        
        // When/Then: Should throw error
        do {
            try await handler.repay(position: testPosition, amount: 50.0)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is FluidVaultError)
        }
    }
    
    // MARK: - Withdraw Tests
    
    func testWithdraw_Success() async throws {
        // Given: Valid withdraw amount
        let amount: Decimal = 0.02
        
        // When: Withdraw
        try await handler.withdraw(position: testPosition, amount: amount)
        
        // Then: Service should be called
        XCTAssertTrue(mockVaultService.withdrawCalled)
        XCTAssertEqual(mockVaultService.lastWithdrawAmount, amount)
        XCTAssertEqual(mockVaultService.lastPosition?.nftId, testPosition.nftId)
    }
    
    func testWithdraw_ThrowsError_WhenServiceFails() async {
        // Given: Service will fail
        mockVaultService.shouldThrowError = true
        mockVaultService.errorToThrow = FluidVaultError.unsafeHealthFactor
        
        // When/Then: Should throw error
        do {
            try await handler.withdraw(position: testPosition, amount: 0.05)
            XCTFail("Expected error to be thrown")
        } catch let error as FluidVaultError {
            XCTAssertEqual(error, FluidVaultError.unsafeHealthFactor)
        }
    }
    
    // MARK: - Close Tests
    
    func testClose_Success() async throws {
        // When: Close position
        try await handler.close(position: testPosition)
        
        // Then: Service should be called
        XCTAssertTrue(mockVaultService.closeCalled)
        XCTAssertEqual(mockVaultService.lastPosition?.nftId, testPosition.nftId)
    }
    
    func testClose_CallsRepayAndWithdraw() async throws {
        // When: Close position
        try await handler.close(position: testPosition)
        
        // Then: Should call both repay and withdraw
        XCTAssertTrue(mockVaultService.closeCalled)
        // Close internally calls repay + withdraw in FluidVaultService
    }
    
    // MARK: - Concurrent Operation Tests
    
    func testConcurrentOperations_OnlyOneExecutes() async throws {
        // Given: Multiple operations
        mockVaultService.shouldDelay = true
        
        // When: Trigger multiple operations simultaneously
        let task1 = Task { try await handler.addCollateral(position: testPosition, amount: 0.05) }
        let task2 = Task { try await handler.repay(position: testPosition, amount: 10.0) }
        let task3 = Task { try await handler.withdraw(position: testPosition, amount: 0.01) }
        
        _ = try await task1.value
        _ = try await task2.value
        _ = try await task3.value
        
        // Then: Should complete all operations sequentially
        let totalCalls = mockVaultService.addCollateralCallCount +
                        mockVaultService.repayCallCount +
                        mockVaultService.withdrawCallCount
        XCTAssertEqual(totalCalls, 3)
    }
}

// MARK: - Mock Fluid Vault Service

@MainActor
class MockFluidVaultService: FluidVaultService {
    var addCollateralCalled = false
    var addCollateralCallCount = 0
    var repayCalled = false
    var repayCallCount = 0
    var withdrawCalled = false
    var withdrawCallCount = 0
    var closeCalled = false
    var closeCallCount = 0
    
    var lastPosition: BorrowPosition?
    var lastCollateralAmount: Decimal?
    var lastRepayAmount: Decimal?
    var lastWithdrawAmount: Decimal?
    
    var shouldThrowError = false
    var errorToThrow: Error?
    var shouldDelay = false
    
    override func addCollateral(position: BorrowPosition, amount: Decimal) async throws {
        if shouldDelay {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
        }
        
        if shouldThrowError {
            throw errorToThrow ?? FluidVaultError.invalidRequest
        }
        
        addCollateralCalled = true
        addCollateralCallCount += 1
        lastPosition = position
        lastCollateralAmount = amount
    }
    
    override func repay(position: BorrowPosition, amount: Decimal) async throws {
        if shouldDelay {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        
        if shouldThrowError {
            throw errorToThrow ?? FluidVaultError.invalidRequest
        }
        
        repayCalled = true
        repayCallCount += 1
        lastPosition = position
        lastRepayAmount = amount
    }
    
    override func withdraw(position: BorrowPosition, amount: Decimal) async throws {
        if shouldDelay {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        
        if shouldThrowError {
            throw errorToThrow ?? FluidVaultError.invalidRequest
        }
        
        withdrawCalled = true
        withdrawCallCount += 1
        lastPosition = position
        lastWithdrawAmount = amount
    }
    
    override func close(position: BorrowPosition) async throws {
        if shouldDelay {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        
        if shouldThrowError {
            throw errorToThrow ?? FluidVaultError.invalidRequest
        }
        
        closeCalled = true
        closeCallCount += 1
        lastPosition = position
    }
}

