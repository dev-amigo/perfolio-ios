import XCTest
@testable import PerFolio

final class CurrencyFormatterTests: XCTestCase {
    
    // MARK: - Decimal Formatting Tests
    
    func testFormatDecimal_WithStandardValue() {
        let result = CurrencyFormatter.formatDecimal(123.456)
        XCTAssertEqual(result, "123.456")
    }
    
    func testFormatDecimal_WithLargeValue() {
        let result = CurrencyFormatter.formatDecimal(1_234_567.89)
        XCTAssertEqual(result, "1,234,567.89")
    }
    
    func testFormatDecimal_WithSmallValue() {
        let result = CurrencyFormatter.formatDecimal(0.000123, maxDecimals: 6)
        XCTAssertEqual(result, "0.000123")
    }
    
    func testFormatDecimal_WithZero() {
        let result = CurrencyFormatter.formatDecimal(0)
        XCTAssertEqual(result, "0.00")
    }
    
    // MARK: - INR Formatting Tests
    
    func testFormatINR_WithStandardValue() {
        let result = CurrencyFormatter.formatINR(1000)
        XCTAssertEqual(result, "₹1,000")
    }
    
    func testFormatINR_WithDecimalValue() {
        let result = CurrencyFormatter.formatINR(1000.50)
        XCTAssertEqual(result, "₹1,000.5")
    }
    
    func testFormatINR_WithLargeValue() {
        let result = CurrencyFormatter.formatINR(100_000)
        XCTAssertEqual(result, "₹100,000")
    }
    
    // MARK: - USD Formatting Tests
    
    func testFormatUSD_WithStandardValue() {
        let result = CurrencyFormatter.formatUSD(2000)
        XCTAssertEqual(result, "$2,000.00")
    }
    
    func testFormatUSD_WithDecimalValue() {
        let result = CurrencyFormatter.formatUSD(123.45)
        XCTAssertEqual(result, "$123.45")
    }
    
    // MARK: - Token Formatting Tests
    
    func testFormatToken_USDC() {
        let result = CurrencyFormatter.formatToken(1000.50, symbol: "USDC")
        XCTAssertEqual(result, "1,000.50 USDC")
    }
    
    func testFormatToken_PAXG() {
        let result = CurrencyFormatter.formatToken(0.025, symbol: "PAXG", maxDecimals: 8)
        XCTAssertEqual(result, "0.025 PAXG")
    }
    
    // MARK: - Amount Parsing Tests
    
    func testParseINRAmount_WithRupeeSymbol() {
        let result = CurrencyFormatter.parseINRAmount("₹1,000")
        XCTAssertNotNil(result)
        XCTAssertEqual(result, 1000)
    }
    
    func testParseINRAmount_WithCommas() {
        let result = CurrencyFormatter.parseINRAmount("50,000")
        XCTAssertNotNil(result)
        XCTAssertEqual(result, 50000)
    }
    
    func testParseINRAmount_WithSpaces() {
        let result = CurrencyFormatter.parseINRAmount("  1000  ")
        XCTAssertNotNil(result)
        XCTAssertEqual(result, 1000)
    }
    
    func testParseINRAmount_WithInvalidValue() {
        let result = CurrencyFormatter.parseINRAmount("invalid")
        XCTAssertNil(result)
    }
    
    func testParseDecimalAmount_WithCommas() {
        let result = CurrencyFormatter.parseDecimalAmount("1,234.56")
        XCTAssertNotNil(result)
        XCTAssertEqual(result, 1234.56)
    }
    
    func testParseDecimalAmount_WithInvalidValue() {
        let result = CurrencyFormatter.parseDecimalAmount("abc")
        XCTAssertNil(result)
    }
    
    // MARK: - Validation Tests
    
    func testValidateAmount_WithinRange() {
        XCTAssertTrue(CurrencyFormatter.validateAmount(1000, min: 500, max: 100_000))
    }
    
    func testValidateAmount_BelowMin() {
        XCTAssertFalse(CurrencyFormatter.validateAmount(400, min: 500, max: 100_000))
    }
    
    func testValidateAmount_AboveMax() {
        XCTAssertFalse(CurrencyFormatter.validateAmount(200_000, min: 500, max: 100_000))
    }
    
    func testValidateAmount_ExactMin() {
        XCTAssertTrue(CurrencyFormatter.validateAmount(500, min: 500, max: 100_000))
    }
    
    func testValidateAmount_ExactMax() {
        XCTAssertTrue(CurrencyFormatter.validateAmount(100_000, min: 500, max: 100_000))
    }
    
    func testValidateAmount_Zero() {
        XCTAssertFalse(CurrencyFormatter.validateAmount(0, min: 500, max: 100_000))
    }
    
    func testValidateAmount_Negative() {
        XCTAssertFalse(CurrencyFormatter.validateAmount(-100, min: 500, max: 100_000))
    }
}
