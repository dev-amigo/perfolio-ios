import XCTest
@testable import PerFolio

final class HexParserTests: XCTestCase {
    
    // MARK: - Parse to Decimal Tests
    
    func testParseToDecimal_SmallNumber() throws {
        let result = try HexParser.parseToDecimal("0x64") // 100 in decimal
        XCTAssertEqual(result, 100)
    }
    
    func testParseToDecimal_WithoutPrefix() throws {
        let result = try HexParser.parseToDecimal("64") // 100 in decimal
        XCTAssertEqual(result, 100)
    }
    
    func testParseToDecimal_LargeNumber() throws {
        let result = try HexParser.parseToDecimal("0xFFFFFFFF") // 4294967295
        XCTAssertEqual(result, 4294967295)
    }
    
    func testParseToDecimal_VeryLargeNumber() throws {
        // 1 million USDC (with 6 decimals): 1000000 * 10^6 = 1000000000000
        let result = try HexParser.parseToDecimal("0xE8D4A51000") // 1,000,000,000,000
        XCTAssertEqual(result, 1_000_000_000_000)
    }
    
    func testParseToDecimal_Zero() throws {
        let result = try HexParser.parseToDecimal("0x0")
        XCTAssertEqual(result, 0)
    }
    
    func testParseToDecimal_SingleDigit() throws {
        let result = try HexParser.parseToDecimal("0x5")
        XCTAssertEqual(result, 5)
    }
    
    func testParseToDecimal_InvalidHexString() {
        XCTAssertThrowsError(try HexParser.parseToDecimal("0xGHI")) { error in
            XCTAssertTrue(error is HexParser.ParsingError)
        }
    }
    
    func testParseToDecimal_EmptyString() {
        XCTAssertThrowsError(try HexParser.parseToDecimal("0x")) { error in
            XCTAssertEqual(error as? HexParser.ParsingError, .invalidHexString)
        }
    }
    
    func testParseToDecimal_MixedCase() throws {
        let result = try HexParser.parseToDecimal("0xAbCdEf")
        XCTAssertEqual(result, 11259375)
    }
    
    // MARK: - Parse to Int64 Tests
    
    func testParseToInt64_SmallNumber() throws {
        let result = try HexParser.parseToInt64("0x64")
        XCTAssertEqual(result, 100)
    }
    
    func testParseToInt64_LargeNumber() throws {
        let result = try HexParser.parseToInt64("0xFFFFFFFF")
        XCTAssertEqual(result, 4294967295)
    }
    
    func testParseToInt64_InvalidHexString() {
        XCTAssertThrowsError(try HexParser.parseToInt64("0xZZZ"))
    }
    
    // MARK: - Decimal to Hex Tests
    
    func testDecimalToHex_SmallNumber() {
        let result = HexParser.decimalToHex(100)
        XCTAssertEqual(result, "0x64")
    }
    
    func testDecimalToHex_LargeNumber() {
        let result = HexParser.decimalToHex(4294967295)
        XCTAssertEqual(result, "0xffffffff")
    }
    
    func testDecimalToHex_Zero() {
        let result = HexParser.decimalToHex(0)
        XCTAssertEqual(result, "0x0")
    }
    
    // MARK: - Edge Cases
    
    func testParseToDecimal_LeadingZeros() throws {
        let result = try HexParser.parseToDecimal("0x0064")
        XCTAssertEqual(result, 100)
    }
    
    func testParseToDecimal_MaxSafeInt() throws {
        // Test with a very large number that should still be safely parsed
        let maxSafeHex = "0x" + String(repeating: "F", count: 15) // 60 bits
        let result = try HexParser.parseToDecimal(maxSafeHex)
        XCTAssertGreaterThan(result, 0)
    }
}
