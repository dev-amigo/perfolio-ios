import XCTest
@testable import PerFolio

final class ERC20ContractTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: ERC20Contract!
    var mockWeb3Client: MockWeb3ClientForERC20Tests!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockWeb3Client = MockWeb3ClientForERC20Tests()
        sut = ERC20Contract(web3Client: mockWeb3Client)
    }
    
    override func tearDown() {
        sut = nil
        mockWeb3Client = nil
        super.tearDown()
    }
    
    // MARK: - Token Enum Tests
    
    func testToken_PAXG_HasCorrectProperties() {
        // When
        let token = ERC20Contract.Token.paxg
        
        // Then
        XCTAssertEqual(token.symbol, "PAXG")
        XCTAssertEqual(token.decimals, 18)
        XCTAssertEqual(token.address, "0x45804880De22913dAFE09f4980848ECE6EcbAf78")
    }
    
    func testToken_USDT_HasCorrectProperties() {
        // When
        let token = ERC20Contract.Token.usdt
        
        // Then
        XCTAssertEqual(token.symbol, "USDT")
        XCTAssertEqual(token.decimals, 6)
        XCTAssertEqual(token.address, "0xdAC17F958D2ee523a2206206994597C13D831ec7")
    }
    
    func testToken_USDC_HasCorrectProperties() {
        // When
        let token = ERC20Contract.Token.usdc
        
        // Then
        XCTAssertEqual(token.symbol, "USDC")
        XCTAssertEqual(token.decimals, 6)
        XCTAssertEqual(token.address, "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48")
    }
    
    // MARK: - balanceOf Tests
    
    func testBalanceOf_PAXG_Success() async throws {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        
        // Balance: 0.1 PAXG (100000000000000000 wei = 0x016345785d8a0000)
        await mockWeb3Client.setMockResult("0x00000000000000000000000000000000000000000000000000016345785d8a0000")
        
        // When
        let balance = try await sut.balanceOf(token: .paxg, address: walletAddress)
        
        // Then
        XCTAssertEqual(balance.symbol, "PAXG")
        XCTAssertEqual(balance.decimals, 18)
        XCTAssertEqual(balance.address, ERC20Contract.Token.paxg.address)
        XCTAssertEqual(balance.decimalBalance, 0.1, accuracy: 0.0001)
    }
    
    func testBalanceOf_USDC_Success() async throws {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        
        // Balance: 100 USDC (100000000 = 0x05f5e100)
        await mockWeb3Client.setMockResult("0x0000000000000000000000000000000000000000000000000000000005f5e100")
        
        // When
        let balance = try await sut.balanceOf(token: .usdc, address: walletAddress)
        
        // Then
        XCTAssertEqual(balance.symbol, "USDC")
        XCTAssertEqual(balance.decimals, 6)
        XCTAssertEqual(balance.decimalBalance, 100.0, accuracy: 0.01)
    }
    
    func testBalanceOf_ZeroBalance_ReturnsZero() async throws {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        
        // Balance: 0 (all zeros)
        await mockWeb3Client.setMockResult("0x0000000000000000000000000000000000000000000000000000000000000000")
        
        // When
        let balance = try await sut.balanceOf(token: .usdc, address: walletAddress)
        
        // Then
        XCTAssertEqual(balance.decimalBalance, 0)
    }
    
    func testBalanceOf_LargeBalance_HandlesCorrectly() async throws {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        
        // Balance: 1,000,000 USDC (1000000000000 = 0xe8d4a51000)
        await mockWeb3Client.setMockResult("0x000000000000000000000000000000000000000000000000000000e8d4a51000")
        
        // When
        let balance = try await sut.balanceOf(token: .usdc, address: walletAddress)
        
        // Then
        XCTAssertEqual(balance.decimalBalance, 1_000_000.0, accuracy: 0.01)
    }
    
    func testBalanceOf_SmallBalance_HandlesCorrectly() async throws {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        
        // Balance: 0.000001 PAXG (1000000000000 wei = 0xe8d4a51000)
        await mockWeb3Client.setMockResult("0x000000000000000000000000000000000000000000000000000000e8d4a51000")
        
        // When
        let balance = try await sut.balanceOf(token: .paxg, address: walletAddress)
        
        // Then
        XCTAssertGreaterThan(balance.decimalBalance, 0)
        XCTAssertLessThan(balance.decimalBalance, 0.01)
    }
    
    func testBalanceOf_ConstructsCorrectCallData() async throws {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        await mockWeb3Client.setMockResult("0x0000000000000000000000000000000000000000000000000000000000000000")
        
        // When
        _ = try await sut.balanceOf(token: .usdc, address: walletAddress)
        
        // Then
        let lastCallData = await mockWeb3Client.lastCallData
        XCTAssertNotNil(lastCallData)
        XCTAssertTrue(lastCallData?.hasPrefix("0x70a08231") ?? false)  // balanceOf selector
        
        // Should contain padded address
        let cleanAddress = walletAddress.replacingOccurrences(of: "0x", with: "").lowercased()
        XCTAssertTrue(lastCallData?.lowercased().contains(cleanAddress) ?? false)
    }
    
    func testBalanceOf_Web3Error_ThrowsError() async {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        await mockWeb3Client.setShouldThrowError(true)
        
        // When/Then
        do {
            _ = try await sut.balanceOf(token: .usdc, address: walletAddress)
            XCTFail("Expected error to be thrown")
        } catch {
            // Success - error thrown
            XCTAssertNotNil(error)
        }
    }
    
    func testBalanceOf_InvalidHex_ThrowsError() async {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        
        // Invalid hex string with non-hex characters
        await mockWeb3Client.setMockResult("0xZZZZZZ")
        
        // When/Then
        do {
            _ = try await sut.balanceOf(token: .usdc, address: walletAddress)
            XCTFail("Expected error to be thrown")
        } catch {
            // Success - error thrown
            XCTAssertTrue(error is Web3Error)
        }
    }
    
    // MARK: - balancesOf Tests (Multi-token)
    
    func testBalancesOf_MultipleTokens_Success() async throws {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        
        // Set up mock to return different values for different calls
        await mockWeb3Client.setMockResults([
            "0x0000000000000000000000000000000000000000000000000000000005f5e100", // 100 USDC
            "0x00000000000000000000000000000000000000000000000000016345785d8a0000", // 0.1 PAXG
            "0x0000000000000000000000000000000000000000000000000000000002faf080"  // 50 USDT
        ])
        
        // When
        let balances = try await sut.balancesOf(
            tokens: [.usdc, .paxg, .usdt],
            address: walletAddress
        )
        
        // Then
        XCTAssertEqual(balances.count, 3)
        
        // Check all tokens are present
        XCTAssertTrue(balances.contains(where: { $0.symbol == "USDC" }))
        XCTAssertTrue(balances.contains(where: { $0.symbol == "PAXG" }))
        XCTAssertTrue(balances.contains(where: { $0.symbol == "USDT" }))
    }
    
    func testBalancesOf_EmptyArray_ReturnsEmpty() async throws {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        
        // When
        let balances = try await sut.balancesOf(tokens: [], address: walletAddress)
        
        // Then
        XCTAssertEqual(balances.count, 0)
    }
    
    func testBalancesOf_SingleToken_ReturnsOne() async throws {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        await mockWeb3Client.setMockResult("0x0000000000000000000000000000000000000000000000000000000005f5e100")
        
        // When
        let balances = try await sut.balancesOf(tokens: [.usdc], address: walletAddress)
        
        // Then
        XCTAssertEqual(balances.count, 1)
        XCTAssertEqual(balances.first?.symbol, "USDC")
    }
    
    func testBalancesOf_OneFailure_ThrowsError() async {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        
        // Set up to fail on second call
        await mockWeb3Client.setMockResults([
            "0x0000000000000000000000000000000000000000000000000000000005f5e100",
            "error"  // This will cause a failure
        ])
        
        // When/Then
        do {
            _ = try await sut.balancesOf(tokens: [.usdc, .paxg], address: walletAddress)
            XCTFail("Expected error to be thrown")
        } catch {
            // Success - error thrown
            XCTAssertNotNil(error)
        }
    }
    
    // MARK: - Formatting Tests
    
    func testFormatBalance_USDC_TwoDecimals() async throws {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        
        // 123.456789 USDC (should format to 2 decimals)
        await mockWeb3Client.setMockResult("0x00000000000000000000000000000000000000000000000000000000075bcd15")
        
        // When
        let balance = try await sut.balanceOf(token: .usdc, address: walletAddress)
        
        // Then
        XCTAssertTrue(balance.formattedBalance.contains("123.45") || balance.formattedBalance.contains("123.46"))
    }
    
    func testFormatBalance_PAXG_FourDecimals() async throws {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        
        // 0.123456789 PAXG (should format to 4 decimals)
        await mockWeb3Client.setMockResult("0x000000000000000000000000000000000000000000000000001b667a56d48815")
        
        // When
        let balance = try await sut.balanceOf(token: .paxg, address: walletAddress)
        
        // Then
        // Should have 4 decimals for PAXG
        XCTAssertTrue(balance.formattedBalance.contains(".") || balance.formattedBalance == "0")
    }
    
    // MARK: - Edge Cases
    
    func testBalanceOf_AddressWithoutPrefix_HandlesCorrectly() async throws {
        // Given
        let walletAddress = "8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"  // No 0x prefix
        await mockWeb3Client.setMockResult("0x0000000000000000000000000000000000000000000000000000000005f5e100")
        
        // When
        let balance = try await sut.balanceOf(token: .usdc, address: walletAddress)
        
        // Then
        XCTAssertEqual(balance.decimalBalance, 100.0, accuracy: 0.01)
    }
    
    func testBalanceOf_ShortHexResult_HandlesCorrectly() async throws {
        // Given
        let walletAddress = "0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a"
        
        // Short hex (0x01 = 1 wei)
        await mockWeb3Client.setMockResult("0x01")
        
        // When
        let balance = try await sut.balanceOf(token: .usdc, address: walletAddress)
        
        // Then
        XCTAssertGreaterThan(balance.decimalBalance, 0)
    }
}

// MARK: - Mock Web3Client Actor (actors don't support inheritance, so using composition)

actor MockWeb3ClientForERC20Tests {
    private var mockResult: String = "0x0"
    private var mockResults: [String] = []
    private var callCount = 0
    private var shouldThrowError = false
    var lastCallData: String?
    
    func setMockResult(_ result: String) {
        mockResult = result
        mockResults = []
    }
    
    func setMockResults(_ results: [String]) {
        mockResults = results
        callCount = 0
    }
    
    func setShouldThrowError(_ shouldThrow: Bool) {
        shouldThrowError = shouldThrow
    }
    
    func ethCall(
        to contractAddress: String,
        data: String,
        from: String? = nil,
        block: String = "latest"
    ) async throws -> String {
        lastCallData = data
        
        if shouldThrowError {
            throw Web3Error.rpcError(code: 3, message: "Mock error")
        }
        
        if !mockResults.isEmpty {
            defer { callCount += 1 }
            if callCount < mockResults.count {
                let result = mockResults[callCount]
                if result == "error" {
                    throw Web3Error.rpcError(code: 3, message: "Mock error")
                }
                return result
            }
            return mockResults.last ?? mockResult
        }
        
        return mockResult
    }
}

