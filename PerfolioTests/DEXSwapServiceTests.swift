import XCTest
import Combine
@testable import PerFolio

final class DEXSwapServiceTests: XCTestCase {
    
    var sut: DEXSwapService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        sut = DEXSwapService(oneInchAPIKey: "test_api_key")
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
        XCTAssertEqual(sut.defaultSlippageTolerance, 0.5)
    }
    
    // MARK: - Token Tests
    
    func testToken_USDT_HasCorrectAddress() {
        XCTAssertEqual(DEXSwapService.Token.usdt.address, ContractAddresses.usdt)
        XCTAssertEqual(DEXSwapService.Token.usdt.symbol, "USDT")
        XCTAssertEqual(DEXSwapService.Token.usdt.decimals, 6)
    }
    
    func testToken_PAXG_HasCorrectAddress() {
        XCTAssertEqual(DEXSwapService.Token.paxg.address, ContractAddresses.paxg)
        XCTAssertEqual(DEXSwapService.Token.paxg.symbol, "PAXG")
        XCTAssertEqual(DEXSwapService.Token.paxg.decimals, 18)
    }
    
    // MARK: - Swap Quote Display Tests
    
    func testSwapQuote_DisplayFromAmount_FormatsCorrectly() {
        let quote = DEXSwapService.SwapQuote(
            fromToken: .usdt,
            toToken: .paxg,
            fromAmount: 1000.50,
            toAmount: 0.5,
            estimatedGas: "~$5-10",
            priceImpact: 0.1,
            route: "USDT → WETH → PAXG"
        )
        
        XCTAssertTrue(quote.displayFromAmount.contains("1,000.5"))
        XCTAssertTrue(quote.displayFromAmount.contains("USDT"))
    }
    
    func testSwapQuote_DisplayToAmount_FormatsCorrectly() {
        let quote = DEXSwapService.SwapQuote(
            fromToken: .usdt,
            toToken: .paxg,
            fromAmount: 1000,
            toAmount: 0.025,
            estimatedGas: "~$5-10",
            priceImpact: 0.1,
            route: "USDT → WETH → PAXG"
        )
        
        XCTAssertTrue(quote.displayToAmount.contains("0.025"))
        XCTAssertTrue(quote.displayToAmount.contains("PAXG"))
    }
    
    func testSwapQuote_DisplayPriceImpact_FormatsCorrectly() {
        let quote = DEXSwapService.SwapQuote(
            fromToken: .usdt,
            toToken: .paxg,
            fromAmount: 1000,
            toAmount: 0.5,
            estimatedGas: "~$5-10",
            priceImpact: 2.5,
            route: "USDT → WETH → PAXG"
        )
        
        XCTAssertTrue(quote.displayPriceImpact.contains("2.5"))
        XCTAssertTrue(quote.displayPriceImpact.contains("%"))
    }
    
    func testSwapQuote_IsPriceImpactHigh_LowImpact() {
        let quote = DEXSwapService.SwapQuote(
            fromToken: .usdt,
            toToken: .paxg,
            fromAmount: 1000,
            toAmount: 0.5,
            estimatedGas: "~$5-10",
            priceImpact: 2.0,
            route: "USDT → WETH → PAXG"
        )
        
        XCTAssertFalse(quote.isPriceImpactHigh)
    }
    
    func testSwapQuote_IsPriceImpactHigh_HighImpact() {
        let quote = DEXSwapService.SwapQuote(
            fromToken: .usdt,
            toToken: .paxg,
            fromAmount: 1000,
            toAmount: 0.5,
            estimatedGas: "~$5-10",
            priceImpact: 5.0,
            route: "USDT → WETH → PAXG"
        )
        
        XCTAssertTrue(quote.isPriceImpactHigh)
    }
    
    // MARK: - Swap Error Tests
    
    func testSwapError_InsufficientBalance_HasCorrectDescription() {
        let error = DEXSwapService.SwapError.insufficientBalance
        XCTAssertEqual(error.errorDescription, "Insufficient USDT balance")
    }
    
    func testSwapError_InvalidAmount_HasCorrectDescription() {
        let error = DEXSwapService.SwapError.invalidAmount
        XCTAssertEqual(error.errorDescription, "Please enter a valid amount")
    }
    
    func testSwapError_ApprovalRequired_HasCorrectDescription() {
        let error = DEXSwapService.SwapError.approvalRequired
        XCTAssertEqual(error.errorDescription, "Token approval required before swap")
    }
    
    func testSwapError_NetworkError_HasCorrectDescription() {
        let error = DEXSwapService.SwapError.networkError("Connection failed")
        XCTAssertTrue(error.errorDescription?.contains("Connection failed") ?? false)
    }
    
    // MARK: - Approval State Tests
    
    func testApprovalState_InitialState() {
        XCTAssertEqual(sut.approvalState, .notRequired)
    }
    
    // MARK: - Reset Tests
    
    func testReset_ClearsQuoteAndApprovalState() {
        // Set some state
        let quote = DEXSwapService.SwapQuote(
            fromToken: .usdt,
            toToken: .paxg,
            fromAmount: 1000,
            toAmount: 0.5,
            estimatedGas: "~$5-10",
            priceImpact: 0.1,
            route: "USDT → WETH → PAXG"
        )
        sut.currentQuote = quote
        sut.approvalState = .approved
        
        // Reset
        sut.reset()
        
        // Verify
        XCTAssertNil(sut.currentQuote)
        XCTAssertEqual(sut.approvalState, .notRequired)
    }
    
    // MARK: - Swap Params Tests
    
    func testSwapParams_InitializesCorrectly() {
        let params = DEXSwapService.SwapParams(
            fromToken: .usdt,
            toToken: .paxg,
            amount: 1000,
            slippageTolerance: 0.5,
            fromAddress: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        )
        
        XCTAssertEqual(params.fromToken.symbol, "USDT")
        XCTAssertEqual(params.toToken.symbol, "PAXG")
        XCTAssertEqual(params.amount, 1000)
        XCTAssertEqual(params.slippageTolerance, 0.5)
        XCTAssertEqual(params.fromAddress, "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb")
    }
    
    // MARK: - Constants Validation Tests
    
    func testServiceConstants_ContractAddresses() {
        XCTAssertFalse(ContractAddresses.usdt.isEmpty)
        XCTAssertFalse(ContractAddresses.paxg.isEmpty)
        XCTAssertFalse(ContractAddresses.oneInchRouterV6.isEmpty)
        
        XCTAssertTrue(ContractAddresses.usdt.hasPrefix("0x"))
        XCTAssertTrue(ContractAddresses.paxg.hasPrefix("0x"))
        XCTAssertTrue(ContractAddresses.oneInchRouterV6.hasPrefix("0x"))
        
        XCTAssertEqual(ContractAddresses.usdt.count, 42) // 0x + 40 hex chars
        XCTAssertEqual(ContractAddresses.paxg.count, 42)
        XCTAssertEqual(ContractAddresses.oneInchRouterV6.count, 42)
    }
    
    func testServiceConstants_DEXParameters() {
        XCTAssertEqual(ServiceConstants.defaultSlippageTolerance, 0.5)
        XCTAssertEqual(ServiceConstants.goldPriceUSDT, 2000)
        XCTAssertEqual(ServiceConstants.highPriceImpactThreshold, 3.0)
        XCTAssertFalse(ServiceConstants.estimatedGasCost.isEmpty)
        XCTAssertFalse(ServiceConstants.defaultSwapRoute.isEmpty)
    }
    
    func testServiceConstants_Timeouts() {
        XCTAssertEqual(ServiceConstants.networkTimeout, 30)
        XCTAssertEqual(ServiceConstants.quoteDelay, 500_000_000)
        XCTAssertEqual(ServiceConstants.approvalDelay, 2_000_000_000)
        XCTAssertEqual(ServiceConstants.swapDelay, 3_000_000_000)
        XCTAssertEqual(ServiceConstants.balanceRefreshDelay, 3_000_000_000)
    }
    
    // MARK: - Integration Tests (Note: These are mock tests since we don't have real network calls)
    
    func testStringPaddingExtension() {
        let testString = "123"
        let padded = testString.paddingToLeft(upTo: 6, using: "0")
        XCTAssertEqual(padded, "000123")
    }
    
    func testStringPaddingExtension_AlreadyLongEnough() {
        let testString = "123456"
        let padded = testString.paddingToLeft(upTo: 6, using: "0")
        XCTAssertEqual(padded, "123456")
    }
    
    func testStringPaddingExtension_Longer() {
        let testString = "1234567"
        let padded = testString.paddingToLeft(upTo: 6, using: "0")
        XCTAssertEqual(padded, "1234567")
    }
}

// MARK: - String Extension for Testing

private extension String {
    func paddingToLeft(upTo length: Int, using element: String) -> String {
        let padCount = length - self.count
        guard padCount > 0 else { return self }
        return String(repeating: element, count: padCount) + self
    }
}

