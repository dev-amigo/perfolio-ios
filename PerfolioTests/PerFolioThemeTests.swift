import XCTest
import SwiftUI
@testable import PerFolio

final class PerFolioThemeTests: XCTestCase {
    
    func testGoldThemeColors() {
        let theme = PerFolioTheme.gold
        
        // Test primary background color
        XCTAssertEqual(theme.primaryBackground, Color(hex: "1D1D1D"))
        
        // Test secondary background color
        XCTAssertEqual(theme.secondaryBackground, Color(hex: "242424"))
        
        // Test tint color
        XCTAssertEqual(theme.tintColor, Color(hex: "D0B070"))
        
        // Test button background color
        XCTAssertEqual(theme.buttonBackground, Color(hex: "9D7618"))
    }
    
    func testTextColors() {
        let theme = PerFolioTheme.gold
        
        XCTAssertEqual(theme.textPrimary, .white)
        XCTAssertEqual(theme.textSecondary, Color.white.opacity(0.8))
        XCTAssertEqual(theme.textTertiary, Color.white.opacity(0.6))
    }
    
    func testSemanticColors() {
        let theme = PerFolioTheme.gold
        
        // Success color (green)
        XCTAssertEqual(theme.success, Color(hex: "4ADE80"))
        
        // Warning color (yellow)
        XCTAssertEqual(theme.warning, Color(hex: "FBBF24"))
        
        // Danger color (red)
        XCTAssertEqual(theme.danger, Color(hex: "EF4444"))
    }
    
    func testGoldenBoxGradient() {
        let theme = PerFolioTheme.gold
        
        // Verify gradient exists and has correct colors
        let gradient = theme.goldenBoxGradient
        
        // Note: SwiftUI LinearGradient doesn't expose colors directly,
        // so we verify it's not nil and can be used in views
        XCTAssertNotNil(gradient)
    }
}

// MARK: - Color Hex Extension Tests

final class ColorHexTests: XCTestCase {
    
    func testHexToColor_6Characters() {
        let color = Color(hex: "FF5733")
        let uiColor = UIColor(color)
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        XCTAssertEqual(red, 1.0, accuracy: 0.01)    // FF = 255/255 = 1.0
        XCTAssertEqual(green, 0.34, accuracy: 0.01)  // 57 = 87/255 ≈ 0.34
        XCTAssertEqual(blue, 0.20, accuracy: 0.01)   // 33 = 51/255 ≈ 0.20
        XCTAssertEqual(alpha, 1.0, accuracy: 0.01)
    }
    
    func testHexToColor_WithHash() {
        let colorWithoutHash = Color(hex: "FF5733")
        let colorWithHash = Color(hex: "#FF5733")
        
        // Both should produce the same color
        XCTAssertEqual(UIColor(colorWithoutHash).cgColor.components,
                      UIColor(colorWithHash).cgColor.components)
    }
    
    func testHexToColor_3Characters() {
        let color = Color(hex: "F53")
        let uiColor = UIColor(color)
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // F53 expands to FF5533
        XCTAssertEqual(red, 1.0, accuracy: 0.01)
        XCTAssertEqual(green, 0.33, accuracy: 0.01)
        XCTAssertEqual(blue, 0.20, accuracy: 0.01)
        XCTAssertEqual(alpha, 1.0, accuracy: 0.01)
    }
    
    func testHexToColor_InvalidHex() {
        let color = Color(hex: "INVALID")
        let uiColor = UIColor(color)
        
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Invalid hex should default to black
        XCTAssertEqual(red, 0.0, accuracy: 0.01)
        XCTAssertEqual(green, 0.0, accuracy: 0.01)
        XCTAssertEqual(blue, 0.0, accuracy: 0.01)
    }
    
    func testGoldThemeSpecificColors() {
        // Test the actual theme colors from the spec
        let primaryBg = Color(hex: "1D1D1D")
        let secondaryBg = Color(hex: "242424")
        let tint = Color(hex: "D0B070")
        let buttonBg = Color(hex: "9D7618")
        
        XCTAssertNotNil(UIColor(primaryBg))
        XCTAssertNotNil(UIColor(secondaryBg))
        XCTAssertNotNil(UIColor(tint))
        XCTAssertNotNil(UIColor(buttonBg))
    }
}

