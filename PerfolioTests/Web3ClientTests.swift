import XCTest
@testable import PerFolio

final class Web3ClientTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: Web3Client!
    var mockSession: MockURLSession!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
    }
    
    override func tearDown() {
        sut = nil
        mockSession = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_WithCustomRPCs_UsesProvidedRPCs() async {
        // Given
        let primaryRPC = "https://primary-test.com"
        let fallbackRPC = "https://fallback-test.com"
        
        // When
        sut = Web3Client(
            primaryRPC: primaryRPC,
            fallbackRPC: fallbackRPC,
            session: mockSession
        )
        
        // Then
        XCTAssertNotNil(sut)
    }
    
    func testInit_WithoutCustomRPCs_UsesDefaults() async {
        // When
        sut = Web3Client(session: mockSession)
        
        // Then
        XCTAssertNotNil(sut)
    }
    
    // MARK: - eth_call Tests
    
    func testEthCall_Success_ReturnsResult() async throws {
        // Given
        sut = Web3Client(
            primaryRPC: "https://test-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        let expectedResult = "0x0000000000000000000000000000000000000000000000000000000000000001"
        mockSession.mockData = createSuccessRPCResponse(result: expectedResult)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test-rpc.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let result = try await sut.ethCall(
            to: "0x1234567890123456789012345678901234567890",
            data: "0xabcdef"
        )
        
        // Then
        XCTAssertEqual(result, expectedResult)
    }
    
    func testEthCall_WithFromParameter_IncludesFrom() async throws {
        // Given
        sut = Web3Client(
            primaryRPC: "https://test-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        let expectedResult = "0x0000000000000000000000000000000000000000000000000000000000000001"
        mockSession.mockData = createSuccessRPCResponse(result: expectedResult)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test-rpc.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let result = try await sut.ethCall(
            to: "0x1234567890123456789012345678901234567890",
            data: "0xabcdef",
            from: "0x9876543210987654321098765432109876543210"
        )
        
        // Then
        XCTAssertEqual(result, expectedResult)
        
        // Verify the request includes 'from'
        if let requestData = mockSession.lastRequest?.httpBody {
            let json = try? JSONSerialization.jsonObject(with: requestData) as? [String: Any]
            let params = json?["params"] as? [[String: Any]]
            let callObject = params?.first
            XCTAssertNotNil(callObject?["from"])
        }
    }
    
    func testEthCall_RPCError_ThrowsError() async {
        // Given
        sut = Web3Client(
            primaryRPC: "https://test-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        mockSession.mockData = createErrorRPCResponse(code: 3, message: "execution reverted")
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test-rpc.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When/Then
        do {
            _ = try await sut.ethCall(
                to: "0x1234567890123456789012345678901234567890",
                data: "0xabcdef"
            )
            XCTFail("Expected error to be thrown")
        } catch let error as Web3Error {
            if case .rpcError(let code, let message) = error {
                XCTAssertEqual(code, 3)
                XCTAssertEqual(message, "execution reverted")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testEthCall_InvalidResponse_ThrowsError() async {
        // Given
        sut = Web3Client(
            primaryRPC: "https://test-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        mockSession.mockData = "invalid json".data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test-rpc.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When/Then
        do {
            _ = try await sut.ethCall(
                to: "0x1234567890123456789012345678901234567890",
                data: "0xabcdef"
            )
            XCTFail("Expected error to be thrown")
        } catch {
            // Success - error thrown
            XCTAssertNotNil(error)
        }
    }
    
    func testEthCall_HTTPError_ThrowsError() async {
        // Given
        sut = Web3Client(
            primaryRPC: "https://test-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        mockSession.mockData = createSuccessRPCResponse(result: "0x01")
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test-rpc.com")!,
            statusCode: 500,  // Server error
            httpVersion: nil,
            headerFields: nil
        )
        
        // When/Then
        do {
            _ = try await sut.ethCall(
                to: "0x1234567890123456789012345678901234567890",
                data: "0xabcdef"
            )
            XCTFail("Expected error to be thrown")
        } catch {
            // Success - error thrown
            XCTAssertTrue(error is Web3Error)
        }
    }
    
    // MARK: - Fallback Logic Tests
    
    func testCall_PrimaryFails_FallsBackToSecondary() async throws {
        // Given
        sut = Web3Client(
            primaryRPC: "https://primary-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        let expectedResult = "0x0000000000000000000000000000000000000000000000000000000000000001"
        
        // First call (primary) fails, second call (fallback) succeeds
        var callCount = 0
        mockSession.dataHandler = { request in
            callCount += 1
            if callCount == 1 {
                // Primary fails
                throw URLError(.timedOut)
            } else {
                // Fallback succeeds
                let data = self.createSuccessRPCResponse(result: expectedResult)
                let response = HTTPURLResponse(
                    url: URL(string: "https://fallback-rpc.com")!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                return (data, response)
            }
        }
        
        // When
        let result = try await sut.ethCall(
            to: "0x1234567890123456789012345678901234567890",
            data: "0xabcdef"
        )
        
        // Then
        XCTAssertEqual(result, expectedResult)
        XCTAssertEqual(callCount, 2)  // Both primary and fallback were called
    }
    
    func testCall_BothFail_ThrowsError() async {
        // Given
        sut = Web3Client(
            primaryRPC: "https://primary-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        mockSession.dataHandler = { request in
            throw URLError(.timedOut)
        }
        
        // When/Then
        do {
            _ = try await sut.ethCall(
                to: "0x1234567890123456789012345678901234567890",
                data: "0xabcdef"
            )
            XCTFail("Expected error to be thrown")
        } catch {
            // Success - error thrown
            XCTAssertTrue(error is Web3Error || error is URLError)
        }
    }
    
    func testCall_PrimarySucceeds_DoesNotCallFallback() async throws {
        // Given
        sut = Web3Client(
            primaryRPC: "https://primary-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        let expectedResult = "0x0000000000000000000000000000000000000000000000000000000000000001"
        
        var callCount = 0
        mockSession.dataHandler = { request in
            callCount += 1
            let data = self.createSuccessRPCResponse(result: expectedResult)
            let response = HTTPURLResponse(
                url: URL(string: "https://primary-rpc.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        }
        
        // When
        let result = try await sut.ethCall(
            to: "0x1234567890123456789012345678901234567890",
            data: "0xabcdef"
        )
        
        // Then
        XCTAssertEqual(result, expectedResult)
        XCTAssertEqual(callCount, 1)  // Only primary was called
    }
    
    // MARK: - getBlockNumber Tests
    
    func testGetBlockNumber_Success_ReturnsBlockNumber() async throws {
        // Given
        sut = Web3Client(
            primaryRPC: "https://test-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        // Block number 18000000 in hex
        let blockNumberHex = "0x112a880"
        mockSession.mockData = createSuccessRPCResponse(result: blockNumberHex)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test-rpc.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let blockNumber = try await sut.getBlockNumber()
        
        // Then
        XCTAssertEqual(blockNumber, 18_000_000)
    }
    
    func testGetBlockNumber_InvalidHex_ThrowsError() async {
        // Given
        sut = Web3Client(
            primaryRPC: "https://test-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        mockSession.mockData = createSuccessRPCResponse(result: "0xZZZ")  // Invalid hex
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test-rpc.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When/Then
        do {
            _ = try await sut.getBlockNumber()
            XCTFail("Expected error to be thrown")
        } catch let error as Web3Error {
            XCTAssertEqual(error, Web3Error.decodingFailed)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testGetBlockNumber_NonStringResult_ThrowsError() async {
        // Given
        sut = Web3Client(
            primaryRPC: "https://test-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        // Return a number instead of hex string
        let json = """
        {
            "jsonrpc": "2.0",
            "id": 1,
            "result": 18000000
        }
        """
        mockSession.mockData = json.data(using: .utf8)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test-rpc.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When/Then
        do {
            _ = try await sut.getBlockNumber()
            XCTFail("Expected error to be thrown")
        } catch {
            // Success - error thrown
            XCTAssertTrue(error is Web3Error)
        }
    }
    
    // MARK: - Edge Cases
    
    func testEthCall_EmptyData_HandlesCorrectly() async throws {
        // Given
        sut = Web3Client(
            primaryRPC: "https://test-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        let expectedResult = "0x"
        mockSession.mockData = createSuccessRPCResponse(result: expectedResult)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test-rpc.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let result = try await sut.ethCall(
            to: "0x1234567890123456789012345678901234567890",
            data: "0x"
        )
        
        // Then
        XCTAssertEqual(result, expectedResult)
    }
    
    func testEthCall_LargeData_HandlesCorrectly() async throws {
        // Given
        sut = Web3Client(
            primaryRPC: "https://test-rpc.com",
            fallbackRPC: "https://fallback-rpc.com",
            session: mockSession
        )
        
        // Large hex string (256 bytes)
        let largeResult = "0x" + String(repeating: "0", count: 512)
        mockSession.mockData = createSuccessRPCResponse(result: largeResult)
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://test-rpc.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // When
        let result = try await sut.ethCall(
            to: "0x1234567890123456789012345678901234567890",
            data: "0xabcdef"
        )
        
        // Then
        XCTAssertEqual(result, largeResult)
    }
    
    // MARK: - Helper Methods
    
    private func createSuccessRPCResponse(result: String) -> Data {
        let json = """
        {
            "jsonrpc": "2.0",
            "id": 1,
            "result": "\(result)"
        }
        """
        return json.data(using: .utf8)!
    }
    
    private func createErrorRPCResponse(code: Int, message: String) -> Data {
        let json = """
        {
            "jsonrpc": "2.0",
            "id": 1,
            "error": {
                "code": \(code),
                "message": "\(message)"
            }
        }
        """
        return json.data(using: .utf8)!
    }
}

// MARK: - Mock URLSession

class MockURLSession: URLSession {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
    var dataHandler: ((URLRequest) throws -> (Data, URLResponse))?
    var lastRequest: URLRequest?
    
    override func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lastRequest = request
        
        if let handler = dataHandler {
            return try handler(request)
        }
        
        if let error = mockError {
            throw error
        }
        
        let data = mockData ?? Data()
        let response = mockResponse ?? HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        return (data, response)
    }
}

