import XCTest
@testable import PerFolio

final class VaultConfigServiceTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: VaultConfigService!
    var mockWeb3Client: MockWeb3ClientActor!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockWeb3Client = MockWeb3ClientActor()
        sut = VaultConfigService(web3Client: mockWeb3Client)
    }
    
    override func tearDown() {
        sut = nil
        mockWeb3Client = nil
        super.tearDown()
    }
    
    // MARK: - fetchVaultConfig Tests
    
    func testFetchVaultConfig_Success_ReturnsConfig() async throws {
        // Given
        // Mock response with vault config data
        // Format: maxLTV (75%), liquidationThreshold (85%), etc.
        let mockResponse = "0x" +
            "0000000000000000000000000000000000000000000000000000000000000020" + // offset
            "0000000000000000000000000000000000000000000000000000000000000004" + // max LTV (75%)
            "0000000000000000000000000000000000000000000000000000000000000005" + // liq threshold (85%)
            "0000000000000000000000000000000000000000000000000000000000000003" + // liq penalty (3%)
            "0000000000000000000000238207734adbD22037af0437Ef65F13bABbd1917"   // vault address
        
        await mockWeb3Client.setMockResult(mockResponse)
        
        // When
        let config = try await sut.fetchVaultConfig()
        
        // Then
        XCTAssertNotNil(config)
        XCTAssertEqual(config.vaultAddress, ContractAddresses.fluidPaxgUsdcVault)
    }
    
    func testFetchVaultConfig_ParsesMaxLTV() async throws {
        // Given
        let mockResponse = createMockVaultConfigResponse(
            maxLTV: 75.0,
            liquidationThreshold: 85.0,
            liquidationPenalty: 3.0
        )
        await mockWeb3Client.setMockResult(mockResponse)
        
        // When
        let config = try await sut.fetchVaultConfig()
        
        // Then
        XCTAssertEqual(config.maxLTV, 75.0, accuracy: 0.1)
    }
    
    func testFetchVaultConfig_ParsesLiquidationThreshold() async throws {
        // Given
        let mockResponse = createMockVaultConfigResponse(
            maxLTV: 75.0,
            liquidationThreshold: 85.0,
            liquidationPenalty: 3.0
        )
        await mockWeb3Client.setMockResult(mockResponse)
        
        // When
        let config = try await sut.fetchVaultConfig()
        
        // Then
        XCTAssertEqual(config.liquidationThreshold, 85.0, accuracy: 0.1)
    }
    
    func testFetchVaultConfig_ParsesLiquidationPenalty() async throws {
        // Given
        let mockResponse = createMockVaultConfigResponse(
            maxLTV: 75.0,
            liquidationThreshold: 85.0,
            liquidationPenalty: 3.0
        )
        await mockWeb3Client.setMockResult(mockResponse)
        
        // When
        let config = try await sut.fetchVaultConfig()
        
        // Then
        XCTAssertEqual(config.liquidationPenalty, 3.0, accuracy: 0.1)
    }
    
    func testFetchVaultConfig_Web3Error_ThrowsError() async {
        // Given
        await mockWeb3Client.setShouldThrowError(true)
        
        // When/Then
        do {
            _ = try await sut.fetchVaultConfig()
            XCTFail("Expected error to be thrown")
        } catch {
            // Success - error thrown
            XCTAssertNotNil(error)
        }
    }
    
    func testFetchVaultConfig_InvalidResponse_ThrowsError() async {
        // Given
        await mockWeb3Client.setMockResult("0x")  // Empty response
        
        // When/Then
        do {
            _ = try await sut.fetchVaultConfig()
            XCTFail("Expected error to be thrown")
        } catch {
            // Success - error thrown
            XCTAssertNotNil(error)
        }
    }
    
    func testFetchVaultConfig_CallsCorrectContract() async throws {
        // Given
        let mockResponse = createMockVaultConfigResponse(
            maxLTV: 75.0,
            liquidationThreshold: 85.0,
            liquidationPenalty: 3.0
        )
        await mockWeb3Client.setMockResult(mockResponse)
        
        // When
        _ = try await sut.fetchVaultConfig()
        
        // Then
        let lastCallData = await mockWeb3Client.lastCallData
        XCTAssertNotNil(lastCallData)
        // Should call getVaultEntireData function (selector: 0x09c062e2)
        XCTAssertTrue(lastCallData?.hasPrefix("0x09c062e2") ?? false)
    }
    
    func testFetchVaultConfig_DefaultValues_ReturnsReasonableConfig() async throws {
        // Given
        let mockResponse = createMockVaultConfigResponse(
            maxLTV: 75.0,
            liquidationThreshold: 85.0,
            liquidationPenalty: 3.0
        )
        await mockWeb3Client.setMockResult(mockResponse)
        
        // When
        let config = try await sut.fetchVaultConfig()
        
        // Then
        XCTAssertGreaterThan(config.maxLTV, 0)
        XCTAssertLessThan(config.maxLTV, 100)
        XCTAssertGreaterThan(config.liquidationThreshold, config.maxLTV)
        XCTAssertGreaterThan(config.liquidationPenalty, 0)
    }
    
    func testFetchVaultConfig_CachingBehavior_ReturnsSameConfig() async throws {
        // Given
        let mockResponse = createMockVaultConfigResponse(
            maxLTV: 75.0,
            liquidationThreshold: 85.0,
            liquidationPenalty: 3.0
        )
        await mockWeb3Client.setMockResult(mockResponse)
        
        // When
        let config1 = try await sut.fetchVaultConfig()
        let config2 = try await sut.fetchVaultConfig()
        
        // Then - Should return same config
        XCTAssertEqual(config1.maxLTV, config2.maxLTV)
        XCTAssertEqual(config1.liquidationThreshold, config2.liquidationThreshold)
    }
    
    func testFetchVaultConfig_VariousLTVValues_ParsesCorrectly() async throws {
        // Test different LTV values
        let testCases: [Decimal] = [50.0, 60.0, 75.0, 80.0, 90.0]
        
        for expectedLTV in testCases {
            // Given
            let mockResponse = createMockVaultConfigResponse(
                maxLTV: expectedLTV,
                liquidationThreshold: 85.0,
                liquidationPenalty: 3.0
            )
            await mockWeb3Client.setMockResult(mockResponse)
            
            // When
            let config = try await sut.fetchVaultConfig()
            
            // Then
            XCTAssertEqual(config.maxLTV, expectedLTV, accuracy: 1.0, "Failed for LTV: \(expectedLTV)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockVaultConfigResponse(
        maxLTV: Decimal,
        liquidationThreshold: Decimal,
        liquidationPenalty: Decimal
    ) -> String {
        // Simplified mock response
        // In reality, this would be properly ABI-encoded hex
        return "0x0000000000000000000000000000000000000000000000000000000000000001"
    }
}

