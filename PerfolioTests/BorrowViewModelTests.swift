import XCTest
import Combine
@testable import PerFolio

@MainActor
final class BorrowViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: BorrowViewModel!
    var mockFluidVaultService: MockFluidVaultService!
    var mockERC20Contract: MockERC20Contract!
    var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        cancellables = Set<AnyCancellable>()
        
        // Create mocks
        mockFluidVaultService = MockFluidVaultService()
        mockERC20Contract = MockERC20Contract()
        
        // Set up mock data
        mockFluidVaultService.mockPAXGPrice = 4000.0
        mockFluidVaultService.mockVaultConfig = VaultConfig.mock
        mockFluidVaultService.mockCurrentAPY = 5.5
        
        mockERC20Contract.mockBalances = [
            .paxg: ERC20Contract.TokenBalance(
                address: "0xTest",
                symbol: "PAXG",
                decimals: 18,
                balance: "100000000000000000", // 0.1 PAXG
                decimalBalance: 0.1
            )
        ]
        
        // Store test wallet address
        UserDefaults.standard.set("0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a", forKey: "userWalletAddress")
        
        // Create SUT
        sut = BorrowViewModel(
            fluidVaultService: mockFluidVaultService,
            erc20Contract: mockERC20Contract
        )
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "userWalletAddress")
        cancellables = nil
        sut = nil
        mockFluidVaultService = nil
        mockERC20Contract = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState_AllPropertiesSetCorrectly() {
        // Then
        XCTAssertEqual(sut.collateralAmount, "")
        XCTAssertEqual(sut.borrowAmount, "")
        XCTAssertEqual(sut.paxgBalance, 0)
        XCTAssertEqual(sut.paxgPrice, 0)
        XCTAssertNil(sut.vaultConfig)
        XCTAssertEqual(sut.currentAPY, 0)
        XCTAssertNil(sut.metrics)
        XCTAssertNil(sut.validationError)
        XCTAssertEqual(sut.viewState, .loading)
        XCTAssertEqual(sut.transactionState, .idle)
        XCTAssertFalse(sut.showingTransactionModal)
        XCTAssertFalse(sut.showingAPYChart)
    }
    
    // MARK: - Load Initial Data Tests
    
    func testLoadInitialData_Success_LoadsAllData() async {
        // When
        await sut.loadInitialData()
        
        // Then
        XCTAssertEqual(sut.viewState, .ready)
        XCTAssertEqual(sut.paxgPrice, 4000.0)
        XCTAssertEqual(sut.currentAPY, 5.5)
        XCTAssertNotNil(sut.vaultConfig)
        XCTAssertEqual(sut.paxgBalance, 0.1)
        XCTAssertEqual(sut.collateralAmount, "0.1") // Auto-filled with balance
    }
    
    func testLoadInitialData_Failure_SetsErrorState() async {
        // Given
        mockFluidVaultService.shouldThrowError = true
        
        // When
        await sut.loadInitialData()
        
        // Then
        if case .error(let message) = sut.viewState {
            XCTAssertTrue(message.contains("Failed to load"))
        } else {
            XCTFail("Expected error state")
        }
    }
    
    func testLoadInitialData_NoWalletAddress_SkipsBalanceLoading() async {
        // Given
        UserDefaults.standard.removeObject(forKey: "userWalletAddress")
        
        // When
        await sut.loadInitialData()
        
        // Then
        XCTAssertEqual(sut.paxgBalance, 0)
        XCTAssertEqual(sut.collateralAmount, "") // Not auto-filled
    }
    
    func testLoadInitialData_ZeroBalance_DoesNotAutoFill() async {
        // Given
        mockERC20Contract.mockBalances = [
            .paxg: ERC20Contract.TokenBalance(
                address: "0xTest",
                symbol: "PAXG",
                decimals: 18,
                balance: "0",
                decimalBalance: 0
            )
        ]
        
        // When
        await sut.loadInitialData()
        
        // Then
        XCTAssertEqual(sut.paxgBalance, 0)
        XCTAssertEqual(sut.collateralAmount, "") // Not auto-filled
    }
    
    // MARK: - Quick Actions Tests
    
    func testSetCollateralToMax_SetsMaxBalance() async {
        // Given
        await sut.loadInitialData()
        sut.collateralAmount = "0.05"
        
        // When
        sut.setCollateralToMax()
        
        // Then
        XCTAssertEqual(sut.collateralAmount, "0.1")
    }
    
    func testSetQuickLTV_25Percent_CalculatesCorrectBorrow() async {
        // Given
        await sut.loadInitialData()
        sut.collateralAmount = "0.1"  // 0.1 PAXG @ $4000 = $400
        
        // When
        sut.setQuickLTV(25)  // 25% of $400 = $100
        
        // Then
        XCTAssertEqual(sut.borrowAmount, "100")
    }
    
    func testSetQuickLTV_50Percent_CalculatesCorrectBorrow() async {
        // Given
        await sut.loadInitialData()
        sut.collateralAmount = "0.1"  // 0.1 PAXG @ $4000 = $400
        
        // When
        sut.setQuickLTV(50)  // 50% of $400 = $200
        
        // Then
        XCTAssertEqual(sut.borrowAmount, "200")
    }
    
    func testSetQuickLTV_75Percent_CalculatesCorrectBorrow() async {
        // Given
        await sut.loadInitialData()
        sut.collateralAmount = "0.1"  // 0.1 PAXG @ $4000 = $400
        
        // When
        sut.setQuickLTV(75)  // 75% of $400 = $300
        
        // Then
        XCTAssertEqual(sut.borrowAmount, "300")
    }
    
    func testSetQuickLTV_NoCollateral_DoesNothing() async {
        // Given
        await sut.loadInitialData()
        sut.collateralAmount = ""
        
        // When
        sut.setQuickLTV(50)
        
        // Then
        XCTAssertEqual(sut.borrowAmount, "")
    }
    
    func testShowAPYChart_SetsFlag() {
        // When
        sut.showingAPYChart = false
        sut.showAPYChart()
        
        // Then
        XCTAssertTrue(sut.showingAPYChart)
    }
    
    // MARK: - Reactive Calculations Tests
    
    func testMetricsCalculation_ValidInputs_CalculatesMetrics() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.collateralAmount = "0.1"
        sut.borrowAmount = "100"
        
        // Wait for debounce
        try? await Task.sleep(nanoseconds: 400_000_000)  // 400ms
        
        // Then
        XCTAssertNotNil(sut.metrics)
        XCTAssertEqual(sut.metrics?.collateralAmount, 0.1)
        XCTAssertEqual(sut.metrics?.borrowAmount, 100.0)
        XCTAssertNil(sut.validationError)
    }
    
    func testMetricsCalculation_ZeroCollateral_NoMetrics() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.collateralAmount = "0"
        sut.borrowAmount = "100"
        
        // Wait for debounce
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Then
        XCTAssertNil(sut.metrics)
    }
    
    func testMetricsCalculation_ZeroBorrow_NoMetrics() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.collateralAmount = "0.1"
        sut.borrowAmount = "0"
        
        // Wait for debounce
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Then
        XCTAssertNil(sut.metrics)
    }
    
    func testMetricsCalculation_InvalidInput_NoMetrics() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.collateralAmount = "abc"
        sut.borrowAmount = "100"
        
        // Wait for debounce
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Then
        XCTAssertNil(sut.metrics)
    }
    
    // MARK: - Validation Tests
    
    func testValidation_InsufficientBalance_ShowsError() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.collateralAmount = "1.0"  // More than balance (0.1)
        sut.borrowAmount = "100"
        
        // Wait for debounce
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Then
        XCTAssertNotNil(sut.validationError)
        XCTAssertTrue(sut.validationError?.contains("Insufficient") ?? false)
    }
    
    func testValidation_ExceedsMaxBorrow_ShowsError() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.collateralAmount = "0.1"  // 0.1 PAXG @ $4000 = $400
        sut.borrowAmount = "400"      // More than 75% LTV ($300)
        
        // Wait for debounce
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Then
        XCTAssertNotNil(sut.validationError)
        XCTAssertTrue(sut.validationError?.contains("Maximum") ?? false)
    }
    
    func testValidation_UnsafeHealthFactor_ShowsError() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.collateralAmount = "0.1"  // 0.1 PAXG @ $4000 = $400
        sut.borrowAmount = "350"      // Very high, unsafe HF
        
        // Wait for debounce
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Then
        XCTAssertNotNil(sut.validationError)
        // Note: This might not trigger if 350 exceeds max borrow
        // Adjust based on actual vault config
    }
    
    func testValidation_ValidInputs_NoError() async {
        // Given
        await sut.loadInitialData()
        
        // When
        sut.collateralAmount = "0.1"  // 0.1 PAXG @ $4000 = $400
        sut.borrowAmount = "100"      // Safe 25% LTV
        
        // Wait for debounce
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // Then
        XCTAssertNil(sut.validationError)
    }
    
    // MARK: - Execute Borrow Tests
    
    func testExecuteBorrow_Success_UpdatesTransactionState() async {
        // Given
        await sut.loadInitialData()
        sut.collateralAmount = "0.1"
        sut.borrowAmount = "100"
        
        // Wait for metrics
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        mockFluidVaultService.mockNFTId = "8896"
        
        // When
        await sut.executeBorrow()
        
        // Then
        if case .success(let positionId) = sut.transactionState {
            XCTAssertEqual(positionId, "8896")
        } else {
            XCTFail("Expected success state, got: \(sut.transactionState)")
        }
        XCTAssertTrue(sut.showingTransactionModal)
    }
    
    func testExecuteBorrow_Failure_ShowsError() async {
        // Given
        await sut.loadInitialData()
        sut.collateralAmount = "0.1"
        sut.borrowAmount = "100"
        
        // Wait for metrics
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        mockFluidVaultService.shouldThrowError = true
        
        // When
        await sut.executeBorrow()
        
        // Then
        if case .failed(let message) = sut.transactionState {
            XCTAssertFalse(message.isEmpty)
        } else {
            XCTFail("Expected failed state")
        }
    }
    
    func testExecuteBorrow_ValidationError_DoesNotExecute() async {
        // Given
        await sut.loadInitialData()
        sut.collateralAmount = "1.0"  // More than balance
        sut.borrowAmount = "100"
        
        // Wait for metrics and validation
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // When
        await sut.executeBorrow()
        
        // Then
        XCTAssertEqual(sut.transactionState, .idle)
        XCTAssertFalse(mockFluidVaultService.executeBorrowCalled)
    }
    
    func testExecuteBorrow_NoWalletAddress_ShowsError() async {
        // Given
        UserDefaults.standard.removeObject(forKey: "userWalletAddress")
        await sut.loadInitialData()
        sut.collateralAmount = "0.1"
        sut.borrowAmount = "100"
        
        // Wait for metrics
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        // When
        await sut.executeBorrow()
        
        // Then
        if case .failed(let message) = sut.transactionState {
            XCTAssertTrue(message.contains("Invalid"))
        } else {
            XCTFail("Expected failed state")
        }
    }
    
    func testExecuteBorrow_TransitionsThroughStates() async {
        // Given
        await sut.loadInitialData()
        sut.collateralAmount = "0.1"
        sut.borrowAmount = "100"
        
        // Wait for metrics
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        mockFluidVaultService.mockNFTId = "8896"
        
        var observedStates: [BorrowViewModel.TransactionState] = []
        
        // Observe state changes
        sut.$transactionState
            .sink { state in
                // Store state descriptions for comparison
                switch state {
                case .idle: observedStates.append(.idle)
                case .checkingApproval: observedStates.append(.checkingApproval)
                case .approvingPAXG: observedStates.append(.approvingPAXG)
                case .depositingAndBorrowing: observedStates.append(.depositingAndBorrowing)
                case .success: observedStates.append(.success(positionId: ""))
                case .failed: observedStates.append(.failed(""))
                }
            }
            .store(in: &cancellables)
        
        // When
        await sut.executeBorrow()
        
        // Then
        XCTAssertTrue(observedStates.contains { state in
            if case .checkingApproval = state { return true }
            return false
        })
        XCTAssertTrue(observedStates.contains { state in
            if case .approvingPAXG = state { return true }
            return false
        })
        XCTAssertTrue(observedStates.contains { state in
            if case .depositingAndBorrowing = state { return true }
            return false
        })
    }
    
    func testExecuteBorrow_RefreshesBalanceOnSuccess() async {
        // Given
        await sut.loadInitialData()
        let initialBalance = sut.paxgBalance
        
        sut.collateralAmount = "0.05"
        sut.borrowAmount = "50"
        
        // Wait for metrics
        try? await Task.sleep(nanoseconds: 400_000_000)
        
        mockFluidVaultService.mockNFTId = "8896"
        
        // Change mock balance to simulate spending
        mockERC20Contract.mockBalances = [
            .paxg: ERC20Contract.TokenBalance(
                address: "0xTest",
                symbol: "PAXG",
                decimals: 18,
                balance: "50000000000000000", // 0.05 PAXG remaining
                decimalBalance: 0.05
            )
        ]
        
        // When
        await sut.executeBorrow()
        
        // Then
        XCTAssertNotEqual(sut.paxgBalance, initialBalance)
        XCTAssertEqual(sut.paxgBalance, 0.05)
    }
    
    func testResetTransaction_ResetsState() {
        // Given
        sut.transactionState = .success(positionId: "8896")
        sut.showingTransactionModal = true
        
        // When
        sut.resetTransaction()
        
        // Then
        XCTAssertEqual(sut.transactionState, .idle)
        XCTAssertFalse(sut.showingTransactionModal)
    }
}

// Note: MockFluidVaultService moved to MockObjects.swift to avoid duplication

