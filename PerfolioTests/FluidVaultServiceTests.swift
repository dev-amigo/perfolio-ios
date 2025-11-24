import XCTest
@testable import PerFolio

@MainActor
final class FluidVaultServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: FluidVaultService!
    var mockWeb3Client: MockWeb3Client!
    var mockERC20Contract: MockERC20Contract!
    var mockVaultConfigService: MockVaultConfigService!
    var mockPriceOracleService: MockPriceOracleService!
    var mockAPYService: MockBorrowAPYService!
    var testEnvironment: EnvironmentConfiguration!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create mocks
        mockWeb3Client = MockWeb3Client()
        mockERC20Contract = MockERC20Contract()
        mockVaultConfigService = MockVaultConfigService()
        mockPriceOracleService = MockPriceOracleService()
        mockAPYService = MockBorrowAPYService()
        
        // Test environment
        testEnvironment = EnvironmentConfiguration.development
        
        // Store test wallet address
        UserDefaults.standard.set("0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a", forKey: "userWalletAddress")
        
        // Create SUT
        sut = FluidVaultService(
            web3Client: mockWeb3Client,
            erc20Contract: mockERC20Contract,
            vaultConfigService: mockVaultConfigService,
            priceOracleService: mockPriceOracleService,
            apyService: mockAPYService,
            environment: testEnvironment
        )
    }
    
    override func tearDown() {
        // Clear user defaults
        UserDefaults.standard.removeObject(forKey: "userWalletAddress")
        UserDefaults.standard.removeObject(forKey: "userWalletId")
        
        sut = nil
        mockWeb3Client = nil
        mockERC20Contract = nil
        mockVaultConfigService = nil
        mockPriceOracleService = nil
        mockAPYService = nil
        testEnvironment = nil
        
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialize_Success_LoadsAllData() async throws {
        // Given
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.mockPrice = 4000.0
        mockAPYService.mockAPY = 5.5
        
        // When
        try await sut.initialize()
        
        // Then
        XCTAssertEqual(sut.vaultConfig?.maxLTV, 75.0)
        XCTAssertEqual(sut.paxgPrice, 4000.0)
        XCTAssertEqual(sut.currentAPY, 5.5)
        XCTAssertFalse(sut.isLoading)
    }
    
    func testInitialize_Failure_ThrowsError() async {
        // Given
        mockVaultConfigService.shouldThrowError = true
        
        // When/Then
        do {
            try await sut.initialize()
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testInitialize_SetsLoadingState() async throws {
        // Given
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.mockPrice = 4000.0
        mockAPYService.mockAPY = 5.5
        
        // When
        let loadingExpectation = expectation(description: "Loading state changes")
        
        Task {
            // Should be true during initialization
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            if sut.isLoading {
                loadingExpectation.fulfill()
            }
        }
        
        try await sut.initialize()
        
        // Then
        await fulfillment(of: [loadingExpectation], timeout: 1.0)
        XCTAssertFalse(sut.isLoading) // Should be false after completion
    }
    
    // MARK: - Execute Borrow Tests
    
    func testExecuteBorrow_Success_ReturnsNFTId() async throws {
        // Given
        let request = BorrowRequest(
            collateralAmount: 0.1,
            borrowAmount: 100.0,
            userAddress: "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault
        )
        
        mockERC20Contract.mockBalances = [
            .paxg: ERC20Contract.TokenBalance(
                address: request.userAddress,
                symbol: "PAXG",
                decimals: 18,
                balance: "100000000000000000", // 0.1 PAXG
                decimalBalance: 0.1
            )
        ]
        
        mockWeb3Client.mockResponses["allowance"] = "0x0" // No allowance, need approval
        mockWeb3Client.mockResponses["sendTransaction"] = "0xabcd1234..." // Mock tx hash
        
        // When
        let nftId = try await sut.executeBorrow(request: request)
        
        // Then
        XCTAssertFalse(nftId.isEmpty)
        XCTAssertTrue(mockWeb3Client.ethCallCalled)
    }
    
    func testExecuteBorrow_InvalidRequest_ThrowsError() async {
        // Given
        let request = BorrowRequest(
            collateralAmount: 0,  // Invalid: zero collateral
            borrowAmount: 100.0,
            userAddress: "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault
        )
        
        // When/Then
        do {
            _ = try await sut.executeBorrow(request: request)
            XCTFail("Expected error to be thrown")
        } catch FluidVaultError.invalidRequest {
            // Success
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testExecuteBorrow_InsufficientBalance_ThrowsError() async {
        // Given
        let request = BorrowRequest(
            collateralAmount: 1.0,  // More than balance
            borrowAmount: 100.0,
            userAddress: "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault
        )
        
        mockERC20Contract.mockBalances = [
            .paxg: ERC20Contract.TokenBalance(
                address: request.userAddress,
                symbol: "PAXG",
                decimals: 18,
                balance: "50000000000000000", // Only 0.05 PAXG
                decimalBalance: 0.05
            )
        ]
        
        // When/Then
        do {
            _ = try await sut.executeBorrow(request: request)
            XCTFail("Expected error to be thrown")
        } catch FluidVaultError.transactionFailed(let message) {
            XCTAssertTrue(message.contains("Insufficient"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Add Collateral Tests
    
    func testAddCollateral_Success() async throws {
        // Given
        let position = BorrowPosition.mock
        let addAmount: Decimal = 0.05
        
        mockERC20Contract.mockBalances = [
            .paxg: ERC20Contract.TokenBalance(
                address: position.owner,
                symbol: "PAXG",
                decimals: 18,
                balance: "100000000000000000", // 0.1 PAXG
                decimalBalance: 0.1
            )
        ]
        
        mockWeb3Client.mockResponses["allowance"] = "0x0"
        mockWeb3Client.mockResponses["sendTransaction"] = "0xhash123"
        
        // When/Then
        do {
            try await sut.addCollateral(position: position, amount: addAmount)
            XCTAssertTrue(mockWeb3Client.ethCallCalled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testAddCollateral_ZeroAmount_ThrowsError() async {
        // Given
        let position = BorrowPosition.mock
        
        // When/Then
        do {
            try await sut.addCollateral(position: position, amount: 0)
            XCTFail("Expected error to be thrown")
        } catch FluidVaultError.invalidRequest {
            // Success
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testAddCollateral_InsufficientBalance_ThrowsError() async {
        // Given
        let position = BorrowPosition.mock
        let addAmount: Decimal = 1.0  // More than balance
        
        mockERC20Contract.mockBalances = [
            .paxg: ERC20Contract.TokenBalance(
                address: position.owner,
                symbol: "PAXG",
                decimals: 18,
                balance: "10000000000000000", // Only 0.01 PAXG
                decimalBalance: 0.01
            )
        ]
        
        // When/Then
        do {
            try await sut.addCollateral(position: position, amount: addAmount)
            XCTFail("Expected error to be thrown")
        } catch FluidVaultError.transactionFailed(let message) {
            XCTAssertTrue(message.contains("Insufficient"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Repay Tests
    
    func testRepay_Success() async throws {
        // Given
        let position = BorrowPosition.mock  // Has 100 USDC debt
        let repayAmount: Decimal = 50.0
        
        mockERC20Contract.mockBalances = [
            .usdc: ERC20Contract.TokenBalance(
                address: position.owner,
                symbol: "USDC",
                decimals: 6,
                balance: "100000000", // 100 USDC
                decimalBalance: 100.0
            )
        ]
        
        mockWeb3Client.mockResponses["allowance"] = "0x0"
        mockWeb3Client.mockResponses["sendTransaction"] = "0xhash456"
        
        // When/Then
        do {
            try await sut.repay(position: position, amount: repayAmount)
            XCTAssertTrue(mockWeb3Client.ethCallCalled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRepay_ZeroAmount_ThrowsError() async {
        // Given
        let position = BorrowPosition.mock
        
        // When/Then
        do {
            try await sut.repay(position: position, amount: 0)
            XCTFail("Expected error to be thrown")
        } catch FluidVaultError.invalidRequest {
            // Success
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testRepay_MoreThanDebt_UsesDebtAmount() async throws {
        // Given
        let position = BorrowPosition.mock  // Has 100 USDC debt
        let repayAmount: Decimal = 200.0  // More than debt
        
        mockERC20Contract.mockBalances = [
            .usdc: ERC20Contract.TokenBalance(
                address: position.owner,
                symbol: "USDC",
                decimals: 6,
                balance: "200000000", // 200 USDC
                decimalBalance: 200.0
            )
        ]
        
        mockWeb3Client.mockResponses["allowance"] = "0x0"
        mockWeb3Client.mockResponses["sendTransaction"] = "0xhash789"
        
        // When/Then - Should only repay up to debt amount (100)
        do {
            try await sut.repay(position: position, amount: repayAmount)
            XCTAssertTrue(mockWeb3Client.ethCallCalled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testRepay_InsufficientBalance_ThrowsError() async {
        // Given
        let position = BorrowPosition.mock  // Has 100 USDC debt
        let repayAmount: Decimal = 50.0
        
        mockERC20Contract.mockBalances = [
            .usdc: ERC20Contract.TokenBalance(
                address: position.owner,
                symbol: "USDC",
                decimals: 6,
                balance: "10000000", // Only 10 USDC
                decimalBalance: 10.0
            )
        ]
        
        // When/Then
        do {
            try await sut.repay(position: position, amount: repayAmount)
            XCTFail("Expected error to be thrown")
        } catch FluidVaultError.transactionFailed(let message) {
            XCTAssertTrue(message.contains("Insufficient"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Withdraw Tests
    
    func testWithdraw_Success() async throws {
        // Given
        let position = BorrowPosition.mock  // Has 0.1 PAXG collateral
        let withdrawAmount: Decimal = 0.05
        
        mockWeb3Client.mockResponses["sendTransaction"] = "0xwithdraw123"
        
        // When/Then
        do {
            try await sut.withdraw(position: position, amount: withdrawAmount)
            XCTAssertTrue(mockWeb3Client.ethCallCalled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testWithdraw_ZeroAmount_ThrowsError() async {
        // Given
        let position = BorrowPosition.mock
        
        // When/Then
        do {
            try await sut.withdraw(position: position, amount: 0)
            XCTFail("Expected error to be thrown")
        } catch FluidVaultError.invalidRequest {
            // Success
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    func testWithdraw_ExceedsCollateral_ThrowsError() async {
        // Given
        let position = BorrowPosition.mock  // Has 0.1 PAXG collateral
        let withdrawAmount: Decimal = 0.2  // More than collateral
        
        // When/Then
        do {
            try await sut.withdraw(position: position, amount: withdrawAmount)
            XCTFail("Expected error to be thrown")
        } catch FluidVaultError.transactionFailed(let message) {
            XCTAssertTrue(message.contains("exceeds"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
    
    // MARK: - Close Position Tests
    
    func testClose_WithDebtAndCollateral_Success() async throws {
        // Given
        let position = BorrowPosition.mock  // Has both debt and collateral
        
        mockERC20Contract.mockBalances = [
            .usdc: ERC20Contract.TokenBalance(
                address: position.owner,
                symbol: "USDC",
                decimals: 6,
                balance: "100000000", // 100 USDC
                decimalBalance: 100.0
            )
        ]
        
        mockWeb3Client.mockResponses["allowance"] = "0x0"
        mockWeb3Client.mockResponses["sendTransaction"] = "0xclose123"
        
        // When/Then
        do {
            try await sut.close(position: position)
            XCTAssertTrue(mockWeb3Client.ethCallCalled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testClose_OnlyCollateral_Success() async throws {
        // Given
        var position = BorrowPosition.mock
        position = BorrowPosition(
            nftId: position.nftId,
            owner: position.owner,
            vaultAddress: position.vaultAddress,
            collateralAmount: 0.1,
            borrowAmount: 0.0,  // No debt
            healthFactor: .infinity,
            currentLTV: 0,
            liquidationPrice: 0,
            maxBorrowable: 300.0,
            status: .safe
        )
        
        mockWeb3Client.mockResponses["sendTransaction"] = "0xclose456"
        
        // When/Then
        do {
            try await sut.close(position: position)
            XCTAssertTrue(mockWeb3Client.ethCallCalled)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testClose_InsufficientUSDC_ThrowsError() async {
        // Given
        let position = BorrowPosition.mock  // Has 100 USDC debt
        
        mockERC20Contract.mockBalances = [
            .usdc: ERC20Contract.TokenBalance(
                address: position.owner,
                symbol: "USDC",
                decimals: 6,
                balance: "10000000", // Only 10 USDC
                decimalBalance: 10.0
            )
        ]
        
        // When/Then
        do {
            try await sut.close(position: position)
            XCTFail("Expected error to be thrown")
        } catch FluidVaultError.transactionFailed(let message) {
            XCTAssertTrue(message.contains("Insufficient"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}

// MARK: - Mock Objects

class MockWeb3Client: Web3Client {
    var ethCallCalled = false
    var ethCallCount = 0
    var mockResponses: [String: String] = [:]
    var shouldThrowError = false
    
    override func ethCall(to: String, data: String) async throws -> String {
        ethCallCalled = true
        ethCallCount += 1
        
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        
        // Return appropriate mock based on function call
        if data.contains("dd62ed3e") {  // allowance
            return mockResponses["allowance"] ?? "0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
        }
        
        return mockResponses["default"] ?? "0x0000000000000000000000000000000000000000000000000000000000000000"
    }
}

class MockERC20Contract: ERC20Contract {
    var mockBalances: [Token: TokenBalance] = [:]
    var shouldThrowError = false
    
    override func balanceOf(token: Token, address: String) async throws -> TokenBalance {
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        
        return mockBalances[token] ?? TokenBalance(
            address: address,
            symbol: token.symbol,
            decimals: token.decimals,
            balance: "0",
            decimalBalance: 0
        )
    }
}

// MockVaultConfigService moved to MockObjects.swift to avoid duplication

class MockPriceOracleService: PriceOracleService {
    var mockPrice: Decimal = 4000.0
    var shouldThrowError = false
    
    override func fetchPAXGPrice() async throws -> Decimal {
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        return mockPrice
    }
}

class MockBorrowAPYService: BorrowAPYService {
    var mockAPY: Decimal = 5.5
    var shouldThrowError = false
    
    override func fetchBorrowAPY() async throws -> Decimal {
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: nil)
        }
        return mockAPY
    }
}

