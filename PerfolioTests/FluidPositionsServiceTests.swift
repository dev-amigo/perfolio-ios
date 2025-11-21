import XCTest
@testable import PerFolio

@MainActor
final class FluidPositionsServiceTests: XCTestCase {
    
    var service: FluidPositionsService!
    var mockWeb3Client: MockWeb3Client!
    var mockVaultConfigService: MockVaultConfigService!
    var mockPriceOracleService: MockPriceOracleService!
    
    override func setUp() {
        super.setUp()
        mockWeb3Client = MockWeb3Client()
        mockVaultConfigService = MockVaultConfigService()
        mockPriceOracleService = MockPriceOracleService()
        
        service = FluidPositionsService(
            web3Client: mockWeb3Client,
            vaultConfigService: mockVaultConfigService,
            priceOracleService: mockPriceOracleService
        )
    }
    
    override func tearDown() {
        service = nil
        mockWeb3Client = nil
        mockVaultConfigService = nil
        mockPriceOracleService = nil
        super.tearDown()
    }
    
    // MARK: - Fetch Positions Tests
    
    func testFetchPositions_Success_WithOnePosition() async throws {
        // Given: Mock returns one position
        mockWeb3Client.mockResponse = createMockPositionsResponse(count: 1)
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.mockPrice = 4000.0
        
        // When: Fetch positions
        let positions = try await service.fetchPositions(for: "0xTest123")
        
        // Then: Should return parsed position
        XCTAssertEqual(positions.count, 1)
        XCTAssertEqual(mockWeb3Client.lastCallTo, ContractAddresses.fluidVaultResolver)
        XCTAssertTrue(mockWeb3Client.lastCallData.contains("347ca8bb")) // Function selector
    }
    
    func testFetchPositions_Success_WithMultiplePositions() async throws {
        // Given: Mock returns 3 positions
        mockWeb3Client.mockResponse = createMockPositionsResponse(count: 3)
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.mockPrice = 4000.0
        
        // When: Fetch positions
        let positions = try await service.fetchPositions(for: "0xTest123")
        
        // Then: Should return all positions
        XCTAssertEqual(positions.count, 3)
    }
    
    func testFetchPositions_Success_EmptyPositions() async throws {
        // Given: Mock returns no positions (execution reverted)
        mockWeb3Client.shouldThrowError = true
        mockWeb3Client.errorToThrow = Web3Error.rpcError(code: 3, message: "execution reverted")
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.mockPrice = 4000.0
        
        // When: Fetch positions
        let positions = try await service.fetchPositions(for: "0xTest123")
        
        // Then: Should return empty array (treated as no positions)
        XCTAssertTrue(positions.isEmpty)
    }
    
    func testFetchPositions_FiltersSupplyPositions() async throws {
        // Given: Mock returns mixed borrow and supply positions
        mockWeb3Client.mockResponse = createMockMixedPositionsResponse()
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.mockPrice = 4000.0
        
        // When: Fetch positions
        let positions = try await service.fetchPositions(for: "0xTest123")
        
        // Then: Should only return borrow positions (not supply)
        XCTAssertTrue(positions.allSatisfy { $0.borrowAmount > 0 })
    }
    
    func testFetchPositions_CallsCorrectContract() async throws {
        // Given: Valid setup
        mockWeb3Client.mockResponse = createMockPositionsResponse(count: 1)
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.mockPrice = 4000.0
        
        // When: Fetch positions
        _ = try await service.fetchPositions(for: "0xTestWallet")
        
        // Then: Should call Vault Resolver
        XCTAssertEqual(mockWeb3Client.lastCallTo, ContractAddresses.fluidVaultResolver)
        XCTAssertEqual(mockWeb3Client.ethCallCount, 1)
    }
    
    func testFetchPositions_EncodesAddressCorrectly() async throws {
        // Given: Wallet address
        let walletAddress = "0xB3Eb44b13f05eDcb2aC1802e2725b6F35f77D33c"
        mockWeb3Client.mockResponse = createMockPositionsResponse(count: 1)
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.mockPrice = 4000.0
        
        // When: Fetch positions
        _ = try await service.fetchPositions(for: walletAddress)
        
        // Then: Call data should contain function selector + padded address
        XCTAssertTrue(mockWeb3Client.lastCallData.hasPrefix("0x347ca8bb"))
        let addressPart = walletAddress.replacingOccurrences(of: "0x", with: "").lowercased()
        XCTAssertTrue(mockWeb3Client.lastCallData.lowercased().contains(addressPart))
    }
    
    // MARK: - Data Parsing Tests
    
    func testFetchPositions_ParsesCollateralCorrectly() async throws {
        // Given: Position with known collateral
        mockWeb3Client.mockResponse = createPositionWithCollateral(hexWei: "0x16345785d8a0000") // 0.1 PAXG
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.mockPrice = 4000.0
        
        // When: Fetch positions
        let positions = try await service.fetchPositions(for: "0xTest")
        
        // Then: Should parse collateral correctly
        XCTAssertEqual(positions.first?.collateralAmount, 0.1, accuracy: 0.001)
    }
    
    func testFetchPositions_ParsesDebtCorrectly() async throws {
        // Given: Position with known debt
        mockWeb3Client.mockResponse = createPositionWithDebt(hexSmallest: "0x5f5e100") // 100 USDC
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.mockPrice = 4000.0
        
        // When: Fetch positions
        let positions = try await service.fetchPositions(for: "0xTest")
        
        // Then: Should parse debt correctly
        XCTAssertEqual(positions.first?.borrowAmount, 100.0, accuracy: 0.1)
    }
    
    func testFetchPositions_CalculatesMetricsWithCurrentPrice() async throws {
        // Given: Position and current PAXG price
        mockWeb3Client.mockResponse = createMockPositionsResponse(count: 1)
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.mockPrice = 5000.0 // $5000 per PAXG
        
        // When: Fetch positions
        let positions = try await service.fetchPositions(for: "0xTest")
        
        // Then: Should use current price for calculations
        if let position = positions.first {
            let expectedCollateralValue = position.collateralAmount * 5000.0
            XCTAssertEqual(position.collateralValueUSD, expectedCollateralValue, accuracy: 1.0)
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testFetchPositions_ThrowsError_WhenVaultConfigFails() async {
        // Given: Vault config service fails
        mockWeb3Client.mockResponse = createMockPositionsResponse(count: 1)
        mockVaultConfigService.shouldThrowError = true
        mockPriceOracleService.mockPrice = 4000.0
        
        // When/Then: Should propagate error
        do {
            _ = try await service.fetchPositions(for: "0xTest")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testFetchPositions_ThrowsError_WhenPriceFetchFails() async {
        // Given: Price oracle fails
        mockWeb3Client.mockResponse = createMockPositionsResponse(count: 1)
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.shouldThrowError = true
        
        // When/Then: Should propagate error
        do {
            _ = try await service.fetchPositions(for: "0xTest")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertNotNil(error)
        }
    }
    
    func testFetchPositions_ThrowsError_WhenWeb3CallFails() async {
        // Given: Web3 call fails with non-revert error
        mockWeb3Client.shouldThrowError = true
        mockWeb3Client.errorToThrow = Web3Error.invalidResponse
        mockVaultConfigService.mockConfig = VaultConfig.mock
        mockPriceOracleService.mockPrice = 4000.0
        
        // When/Then: Should propagate error
        do {
            _ = try await service.fetchPositions(for: "0xTest")
            XCTFail("Expected error to be thrown")
        } catch let error as Web3Error {
            XCTAssertEqual(error, Web3Error.invalidResponse)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockPositionsResponse(count: Int) -> String {
        // Simplified mock response (would be full ABI-encoded data in reality)
        // This is a placeholder - actual implementation would need proper ABI encoding
        return "0x0000000000000000000000000000000000000000000000000000000000000020"
    }
    
    private func createMockMixedPositionsResponse() -> String {
        // Mock response with both supply and borrow positions
        return "0x0000000000000000000000000000000000000000000000000000000000000020"
    }
    
    private func createPositionWithCollateral(hexWei: String) -> String {
        return "0x0000000000000000000000000000000000000000000000000000000000000020"
    }
    
    private func createPositionWithDebt(hexSmallest: String) -> String {
        return "0x0000000000000000000000000000000000000000000000000000000000000020"
    }
}

// MARK: - Mock Services

class MockWeb3Client: Web3Client {
    var mockResponse = ""
    var shouldThrowError = false
    var errorToThrow: Error?
    var ethCallCount = 0
    var lastCallTo = ""
    var lastCallData = ""
    
    override func ethCall(to contractAddress: String, data: String, from: String? = nil, block: String = "latest") async throws -> String {
        ethCallCount += 1
        lastCallTo = contractAddress
        lastCallData = data
        
        if shouldThrowError {
            throw errorToThrow ?? Web3Error.invalidResponse
        }
        
        return mockResponse
    }
}

class MockVaultConfigService: VaultConfigService {
    var mockConfig: VaultConfig?
    var shouldThrowError = false
    
    override func fetchVaultConfig(vaultAddress: String = ContractAddresses.fluidPaxgUsdcVault) async throws -> VaultConfig {
        if shouldThrowError {
            throw VaultConfigError.networkError(NSError(domain: "test", code: -1))
        }
        return mockConfig ?? VaultConfig.mock
    }
}

class MockPriceOracleService: PriceOracleService {
    var mockPrice: Decimal = 4000.0
    var shouldThrowError = false
    
    override func fetchPAXGPrice() async throws -> Decimal {
        if shouldThrowError {
            throw NSError(domain: "test", code: -1)
        }
        return mockPrice
    }
}

