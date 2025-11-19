import XCTest
import Combine
@testable import PerFolio

final class OnMetaServiceTests: XCTestCase {
    
    var sut: OnMetaService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        let config = OnMetaService.OnMetaConfig(
            apiKey: "test_api_key",
            baseURL: "https://platform.onmeta.in",
            chainId: 1,
            environment: "test"
        )
        sut = OnMetaService(config: config)
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        sut = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_ConfiguresCorrectly() {
        XCTAssertNotNil(sut)
        XCTAssertEqual(sut.minInrAmount, 500)
        XCTAssertEqual(sut.maxInrAmount, 100_000)
    }
    
    // MARK: - Amount Validation Tests
    
    func testValidateAmount_ValidAmount() {
        XCTAssertTrue(sut.validateAmount("1000"))
    }
    
    func testValidateAmount_ValidAmountWithRupeeSymbol() {
        XCTAssertTrue(sut.validateAmount("₹1000"))
    }
    
    func testValidateAmount_ValidAmountWithCommas() {
        XCTAssertTrue(sut.validateAmount("10,000"))
    }
    
    func testValidateAmount_MinimumBoundary() {
        XCTAssertTrue(sut.validateAmount("500"))
    }
    
    func testValidateAmount_MaximumBoundary() {
        XCTAssertTrue(sut.validateAmount("100000"))
    }
    
    func testValidateAmount_BelowMinimum() {
        XCTAssertFalse(sut.validateAmount("400"))
    }
    
    func testValidateAmount_AboveMaximum() {
        XCTAssertFalse(sut.validateAmount("150000"))
    }
    
    func testValidateAmount_InvalidString() {
        XCTAssertFalse(sut.validateAmount("invalid"))
    }
    
    func testValidateAmount_EmptyString() {
        XCTAssertFalse(sut.validateAmount(""))
    }
    
    func testValidateAmount_NegativeNumber() {
        XCTAssertFalse(sut.validateAmount("-1000"))
    }
    
    // MARK: - Quote Generation Tests
    
    func testGetQuote_ValidAmount_ReturnsQuote() async throws {
        let quote = try await sut.getQuote(inrAmount: "1000")
        
        XCTAssertEqual(quote.inrAmount, 1000)
        XCTAssertGreaterThan(quote.usdtAmount, 0)
        XCTAssertGreaterThan(quote.exchangeRate, 0)
        XCTAssertGreaterThan(quote.providerFee, 0)
        XCTAssertFalse(quote.estimatedTime.isEmpty)
    }
    
    func testGetQuote_CalculatesFeeCorrectly() async throws {
        let quote = try await sut.getQuote(inrAmount: "1000")
        
        // Fee should be 2% of INR amount (ServiceConstants.onMetaFeePercentage)
        let expectedFee: Decimal = 1000 * 0.02
        XCTAssertEqual(quote.providerFee, expectedFee)
    }
    
    func testGetQuote_CalculatesUSDTAmountCorrectly() async throws {
        let quote = try await sut.getQuote(inrAmount: "1000")
        
        // USDT = (INR - fee) / exchange_rate
        let expectedFee: Decimal = 1000 * 0.02
        let netAmount = 1000 - expectedFee
        let expectedUSDT = netAmount / ServiceConstants.onMetaDefaultExchangeRate
        
        XCTAssertEqual(quote.usdtAmount, expectedUSDT)
    }
    
    func testGetQuote_InvalidAmount_ThrowsError() async {
        do {
            _ = try await sut.getQuote(inrAmount: "invalid")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is OnMetaService.OnMetaError)
        }
    }
    
    func testGetQuote_BelowMinimum_ThrowsError() async {
        do {
            _ = try await sut.getQuote(inrAmount: "400")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? OnMetaService.OnMetaError, .invalidAmount)
        }
    }
    
    func testGetQuote_AboveMaximum_ThrowsError() async {
        do {
            _ = try await sut.getQuote(inrAmount: "150000")
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(error as? OnMetaService.OnMetaError, .invalidAmount)
        }
    }
    
    func testGetQuote_UpdatesLoadingState() async throws {
        // Start quote request
        Task {
            _ = try await sut.getQuote(inrAmount: "1000")
        }
        
        // Wait a bit to ensure loading state was set
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        // Wait for completion
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6s (more than quote delay)
        
        XCTAssertFalse(sut.isLoading)
    }
    
    func testGetQuote_StoresQuote() async throws {
        let quote = try await sut.getQuote(inrAmount: "1000")
        
        XCTAssertNotNil(sut.currentQuote)
        XCTAssertEqual(sut.currentQuote?.inrAmount, quote.inrAmount)
    }
    
    // MARK: - Widget URL Building Tests
    
    func testBuildWidgetURL_ValidInputs_ReturnsURL() throws {
        let url = try sut.buildWidgetURL(
            walletAddress: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            inrAmount: "1000"
        )
        
        XCTAssertNotNil(url)
        XCTAssertTrue(url.absoluteString.contains("platform.onmeta.in"))
        XCTAssertTrue(url.absoluteString.contains("apiKey=test_api_key"))
        XCTAssertTrue(url.absoluteString.contains("walletAddress=0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"))
        XCTAssertTrue(url.absoluteString.contains("fiatAmount=1000"))
        XCTAssertTrue(url.absoluteString.contains("fiatType=INR"))
        XCTAssertTrue(url.absoluteString.contains("tokenSymbol=USDT"))
        XCTAssertTrue(url.absoluteString.contains("chainId=1"))
        XCTAssertTrue(url.absoluteString.contains("offRamp=disabled"))
    }
    
    func testBuildWidgetURL_EmptyWalletAddress_ThrowsError() {
        XCTAssertThrowsError(try sut.buildWidgetURL(walletAddress: "", inrAmount: "1000")) { error in
            XCTAssertEqual(error as? OnMetaService.OnMetaError, .missingWalletAddress)
        }
    }
    
    func testBuildWidgetURL_InvalidAmount_ThrowsError() {
        XCTAssertThrowsError(try sut.buildWidgetURL(
            walletAddress: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            inrAmount: "invalid"
        )) { error in
            XCTAssertEqual(error as? OnMetaService.OnMetaError, .invalidAmount)
        }
    }
    
    func testBuildWidgetURL_NoAPIKey_ThrowsError() {
        let config = OnMetaService.OnMetaConfig(
            apiKey: "",
            baseURL: "https://platform.onmeta.in",
            chainId: 1,
            environment: "test"
        )
        let serviceWithoutKey = OnMetaService(config: config)
        
        XCTAssertThrowsError(try serviceWithoutKey.buildWidgetURL(
            walletAddress: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb",
            inrAmount: "1000"
        )) { error in
            XCTAssertEqual(error as? OnMetaService.OnMetaError, .missingAPIKey)
        }
    }
    
    // MARK: - Display Format Tests
    
    func testQuote_DisplayInrAmount_FormatsCorrectly() async throws {
        let quote = try await sut.getQuote(inrAmount: "1000")
        XCTAssertTrue(quote.displayInrAmount.contains("₹"))
        XCTAssertTrue(quote.displayInrAmount.contains("1,000"))
    }
    
    func testQuote_DisplayUsdtAmount_FormatsCorrectly() async throws {
        let quote = try await sut.getQuote(inrAmount: "1000")
        XCTAssertTrue(quote.displayUsdtAmount.contains("~"))
        XCTAssertTrue(quote.displayUsdtAmount.contains("USDT"))
    }
    
    func testQuote_DisplayFee_FormatsCorrectly() async throws {
        let quote = try await sut.getQuote(inrAmount: "1000")
        XCTAssertTrue(quote.displayFee.contains("₹"))
    }
    
    func testQuote_DisplayRate_FormatsCorrectly() async throws {
        let quote = try await sut.getQuote(inrAmount: "1000")
        XCTAssertTrue(quote.displayRate.contains("1 USDT = ₹"))
    }
    
    // MARK: - Reset Tests
    
    func testReset_ClearsQuoteAndError() async throws {
        _ = try await sut.getQuote(inrAmount: "1000")
        XCTAssertNotNil(sut.currentQuote)
        
        sut.reset()
        
        XCTAssertNil(sut.currentQuote)
        XCTAssertNil(sut.error)
    }
    
    // MARK: - Edge Cases
    
    func testGetQuote_WithRupeeSymbolAndCommas() async throws {
        let quote = try await sut.getQuote(inrAmount: "₹10,000")
        XCTAssertEqual(quote.inrAmount, 10000)
    }
    
    func testGetQuote_MinimumAmount() async throws {
        let quote = try await sut.getQuote(inrAmount: "500")
        XCTAssertEqual(quote.inrAmount, 500)
    }
    
    func testGetQuote_MaximumAmount() async throws {
        let quote = try await sut.getQuote(inrAmount: "100000")
        XCTAssertEqual(quote.inrAmount, 100_000)
    }
}

