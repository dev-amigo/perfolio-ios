import XCTest
@testable import PerFolio

@MainActor
final class WithdrawViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: WithdrawViewModel!
    var mockERC20Contract: MockERC20Contract!
    var mockTransakService: MockTransakService!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Create mocks
        mockERC20Contract = MockERC20Contract()
        mockTransakService = MockTransakService()
        
        // Set up mock data
        mockERC20Contract.mockBalances = [
            .usdc: ERC20Contract.TokenBalance(
                address: "0xTest",
                symbol: "USDC",
                decimals: 6,
                balance: "100000000", // 100 USDC
                decimalBalance: 100.0
            )
        ]
        
        // Store test wallet address
        UserDefaults.standard.set("0x8E0614AA1C09A9A48f1d0A09b63F0Ae8aB8a8a8a", forKey: "userWalletAddress")
        
        // Create SUT
        sut = WithdrawViewModel(
            erc20Contract: mockERC20Contract,
            transakService: mockTransakService
        )
    }
    
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "userWalletAddress")
        sut = nil
        mockERC20Contract = nil
        mockTransakService = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_LoadsBalanceAutomatically() async {
        // Wait a bit for async init to complete
        try? await Task.sleep(nanoseconds: 100_000_000)  // 100ms
        
        // Then
        XCTAssertEqual(sut.usdcBalance, 100.0)
        XCTAssertEqual(sut.viewState, .ready)
    }
    
    func testInit_NoWalletAddress_SetsError() async {
        // Given
        UserDefaults.standard.removeObject(forKey: "userWalletAddress")
        
        // When
        let newSut = WithdrawViewModel(
            erc20Contract: mockERC20Contract,
            transakService: mockTransakService
        )
        
        // Wait for async init
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        // Then
        if case .error(let message) = newSut.viewState {
            XCTAssertTrue(message.contains("Wallet address"))
        } else {
            XCTFail("Expected error state")
        }
    }
    
    func testInit_InitialState() {
        // Then
        XCTAssertEqual(sut.usdcAmount, "")
    }
    
    // MARK: - Load Balance Tests
    
    func testLoadBalance_Success_LoadsBalance() async {
        // When
        await sut.loadBalance()
        
        // Then
        XCTAssertEqual(sut.usdcBalance, 100.0)
        XCTAssertEqual(sut.viewState, .ready)
    }
    
    func testLoadBalance_Failure_SetsError() async {
        // Given
        mockERC20Contract.shouldThrowError = true
        
        // When
        await sut.loadBalance()
        
        // Then
        if case .error(let message) = sut.viewState {
            XCTAssertTrue(message.contains("Failed to load balance"))
        } else {
            XCTFail("Expected error state")
        }
    }
    
    func testLoadBalance_NoUSDCBalance_SetsError() async {
        // Given
        mockERC20Contract.mockBalances = [
            .paxg: ERC20Contract.TokenBalance(  // Wrong token
                address: "0xTest",
                symbol: "PAXG",
                decimals: 18,
                balance: "0",
                decimalBalance: 0
            )
        ]
        
        // When
        await sut.loadBalance()
        
        // Then
        if case .error(let message) = sut.viewState {
            XCTAssertTrue(message.contains("Failed to fetch USDC balance"))
        } else {
            XCTFail("Expected error state")
        }
    }
    
    // MARK: - Computed Properties Tests
    
    func testFormattedUSDCBalance_ReturnsFormattedString() async {
        // Given
        await sut.loadBalance()
        
        // When
        let formatted = sut.formattedUSDCBalance
        
        // Then
        XCTAssertTrue(formatted.contains("100"))
        XCTAssertTrue(formatted.contains("USDC"))
    }
    
    func testUSDCBalanceINR_CalculatesCorrectly() async {
        // Given
        await sut.loadBalance()
        
        // When
        let inrBalance = sut.usdcBalanceINR
        
        // Then - 100 USDC * 83 = ₹8,300
        XCTAssertTrue(inrBalance.contains("8,300") || inrBalance.contains("8300"))
    }
    
    func testEstimatedINRAmount_ZeroAmount_ReturnsZero() {
        // Given
        sut.usdcAmount = ""
        
        // When
        let estimated = sut.estimatedINRAmount
        
        // Then
        XCTAssertEqual(estimated, "≈ ₹0.00")
    }
    
    func testEstimatedINRAmount_ValidAmount_CalculatesWithFee() {
        // Given
        sut.usdcAmount = "100"  // 100 USDC
        
        // When
        let estimated = sut.estimatedINRAmount
        
        // Then
        // 100 USDC * 83 = ₹8,300
        // Fee: ₹8,300 * 2.5% = ₹207.50
        // Net: ₹8,300 - ₹207.50 = ₹8,092.50
        XCTAssertTrue(estimated.contains("8,092") || estimated.contains("8092"))
    }
    
    func testEstimatedINRAmount_50USDC_CalculatesCorrectly() {
        // Given
        sut.usdcAmount = "50"  // 50 USDC
        
        // When
        let estimated = sut.estimatedINRAmount
        
        // Then
        // 50 USDC * 83 = ₹4,150
        // Fee: ₹4,150 * 2.5% = ₹103.75
        // Net: ₹4,150 - ₹103.75 = ₹4,046.25
        XCTAssertTrue(estimated.contains("4,046") || estimated.contains("4046"))
    }
    
    func testProviderFeeAmount_ZeroAmount_ReturnsZero() {
        // Given
        sut.usdcAmount = ""
        
        // When
        let fee = sut.providerFeeAmount
        
        // Then
        XCTAssertEqual(fee, "₹0.00")
    }
    
    func testProviderFeeAmount_ValidAmount_CalculatesCorrectly() {
        // Given
        sut.usdcAmount = "100"  // 100 USDC
        
        // When
        let fee = sut.providerFeeAmount
        
        // Then
        // 100 USDC * 83 = ₹8,300
        // Fee: ₹8,300 * 2.5% = ₹207.50
        XCTAssertTrue(fee.contains("207") || fee.contains("207.50"))
    }
    
    func testIsValidAmount_EmptyString_ReturnsFalse() {
        // Given
        sut.usdcAmount = ""
        
        // When
        let isValid = sut.isValidAmount
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func testIsValidAmount_InvalidString_ReturnsFalse() {
        // Given
        sut.usdcAmount = "abc"
        
        // When
        let isValid = sut.isValidAmount
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func testIsValidAmount_ZeroAmount_ReturnsFalse() async {
        // Given
        await sut.loadBalance()
        sut.usdcAmount = "0"
        
        // When
        let isValid = sut.isValidAmount
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func testIsValidAmount_NegativeAmount_ReturnsFalse() async {
        // Given
        await sut.loadBalance()
        sut.usdcAmount = "-10"
        
        // When
        let isValid = sut.isValidAmount
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func testIsValidAmount_ExceedsBalance_ReturnsFalse() async {
        // Given
        await sut.loadBalance()
        sut.usdcAmount = "200"  // More than balance (100)
        
        // When
        let isValid = sut.isValidAmount
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    func testIsValidAmount_ValidAmount_ReturnsTrue() async {
        // Given
        await sut.loadBalance()
        sut.usdcAmount = "50"  // Valid: 0 < 50 <= 100
        
        // When
        let isValid = sut.isValidAmount
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testIsValidAmount_MaxBalance_ReturnsTrue() async {
        // Given
        await sut.loadBalance()
        sut.usdcAmount = "100"  // Exactly at balance
        
        // When
        let isValid = sut.isValidAmount
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    // MARK: - Preset Amount Tests
    
    func testSetPresetAmount_50Percent_SetsHalfBalance() async {
        // Given
        await sut.loadBalance()
        
        // When
        sut.setPresetAmount("50%")
        
        // Then
        XCTAssertEqual(sut.usdcAmount, "50.00")
    }
    
    func testSetPresetAmount_Max_SetsFullBalance() async {
        // Given
        await sut.loadBalance()
        
        // When
        sut.setPresetAmount("Max")
        
        // Then
        XCTAssertEqual(sut.usdcAmount, "100.00")
    }
    
    func testSetPresetAmount_ZeroBalance_SetsEmpty() async {
        // Given
        mockERC20Contract.mockBalances = [
            .usdc: ERC20Contract.TokenBalance(
                address: "0xTest",
                symbol: "USDC",
                decimals: 6,
                balance: "0",
                decimalBalance: 0
            )
        ]
        await sut.loadBalance()
        
        // When
        sut.setPresetAmount("50%")
        
        // Then
        XCTAssertEqual(sut.usdcAmount, "")
    }
    
    func testSetPresetAmount_UnknownPreset_DoesNothing() async {
        // Given
        await sut.loadBalance()
        sut.usdcAmount = "25"
        
        // When
        sut.setPresetAmount("Unknown")
        
        // Then
        XCTAssertEqual(sut.usdcAmount, "25")  // Unchanged
    }
    
    // MARK: - Validation Tests
    
    func testValidateAndProceed_EmptyAmount_ReturnsError() {
        // Given
        sut.usdcAmount = ""
        
        // When
        let result = sut.validateAndProceed()
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Please enter a valid amount")
    }
    
    func testValidateAndProceed_InvalidAmount_ReturnsError() {
        // Given
        sut.usdcAmount = "abc"
        
        // When
        let result = sut.validateAndProceed()
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Please enter a valid amount")
    }
    
    func testValidateAndProceed_ZeroAmount_ReturnsError() {
        // Given
        sut.usdcAmount = "0"
        
        // When
        let result = sut.validateAndProceed()
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Amount must be greater than 0")
    }
    
    func testValidateAndProceed_NegativeAmount_ReturnsError() {
        // Given
        sut.usdcAmount = "-10"
        
        // When
        let result = sut.validateAndProceed()
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Amount must be greater than 0")
    }
    
    func testValidateAndProceed_ExceedsBalance_ReturnsError() async {
        // Given
        await sut.loadBalance()
        sut.usdcAmount = "200"  // More than balance
        
        // When
        let result = sut.validateAndProceed()
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Insufficient USDC balance")
    }
    
    func testValidateAndProceed_BelowMinimum_ReturnsError() async {
        // Given
        await sut.loadBalance()
        sut.usdcAmount = "5"  // Below 10 USDC minimum
        
        // When
        let result = sut.validateAndProceed()
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Minimum withdrawal is 10 USDC")
    }
    
    func testValidateAndProceed_ValidAmount_ReturnsSuccess() async {
        // Given
        await sut.loadBalance()
        sut.usdcAmount = "50"  // Valid amount
        
        // When
        let result = sut.validateAndProceed()
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }
    
    func testValidateAndProceed_MinimumAmount_ReturnsSuccess() async {
        // Given
        await sut.loadBalance()
        sut.usdcAmount = "10"  // Exactly at minimum
        
        // When
        let result = sut.validateAndProceed()
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }
    
    func testValidateAndProceed_MaximumAmount_ReturnsSuccess() async {
        // Given
        await sut.loadBalance()
        sut.usdcAmount = "100"  // Exactly at balance
        
        // When
        let result = sut.validateAndProceed()
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }
    
    // MARK: - Build Transak URL Tests
    
    func testBuildTransakURL_ValidAmount_ReturnsURL() throws {
        // Given
        sut.usdcAmount = "50"
        mockTransakService.mockURL = URL(string: "https://global.transak.com?amount=50")!
        
        // When
        let url = try sut.buildTransakURL()
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url.absoluteString.contains("global.transak.com"))
    }
    
    func testBuildTransakURL_CallsTransakService() throws {
        // Given
        sut.usdcAmount = "75"
        mockTransakService.mockURL = URL(string: "https://global.transak.com?amount=75")!
        
        // When
        _ = try sut.buildTransakURL()
        
        // Then
        XCTAssertTrue(mockTransakService.buildWithdrawURLCalled)
        XCTAssertEqual(mockTransakService.lastCryptoAmount, "75")
    }
    
    func testBuildTransakURL_PassesCorrectParameters() throws {
        // Given
        sut.usdcAmount = "25.50"
        mockTransakService.mockURL = URL(string: "https://global.transak.com")!
        
        // When
        _ = try sut.buildTransakURL()
        
        // Then
        XCTAssertEqual(mockTransakService.lastCryptoAmount, "25.50")
        XCTAssertEqual(mockTransakService.lastCryptoCurrency, "USDC")
        XCTAssertEqual(mockTransakService.lastFiatCurrency, "INR")
    }
    
    func testBuildTransakURL_TransakServiceError_ThrowsError() {
        // Given
        sut.usdcAmount = "50"
        mockTransakService.shouldThrowError = true
        
        // When/Then
        XCTAssertThrowsError(try sut.buildTransakURL()) { error in
            XCTAssertNotNil(error)
        }
    }
}

// MARK: - Mock TransakService (moved to MockObjects.swift to avoid duplication)

