import XCTest
import SwiftUI
@testable import PerFolio

final class PerFolioShellViewTests: XCTestCase {
    
    func testTabEnumRawValues() {
        // Test that tab enum raw values are sequential
        XCTAssertEqual(PerFolioShellView.Tab.dashboard.rawValue, 0)
        XCTAssertEqual(PerFolioShellView.Tab.wallet.rawValue, 1)
        XCTAssertEqual(PerFolioShellView.Tab.borrow.rawValue, 2)
        XCTAssertEqual(PerFolioShellView.Tab.loans.rawValue, 3)
    }
    
    func testTabInitFromRawValue() {
        // Test tab initialization from raw value
        XCTAssertEqual(PerFolioShellView.Tab(rawValue: 0), .dashboard)
        XCTAssertEqual(PerFolioShellView.Tab(rawValue: 1), .wallet)
        XCTAssertEqual(PerFolioShellView.Tab(rawValue: 2), .borrow)
        XCTAssertEqual(PerFolioShellView.Tab(rawValue: 3), .loans)
        XCTAssertNil(PerFolioShellView.Tab(rawValue: 999))
    }
}

// Deposit & Buy View tests removed as the enum structure has changed

// MARK: - Theme Manager Tests

@MainActor
final class ThemeManagerTests: XCTestCase {
    
    func testThemeManagerInitialization() {
        let themeManager = ThemeManager()
        
        // Test default initialization
        XCTAssertEqual(themeManager.colorScheme, .dark)
        XCTAssertNotNil(themeManager.perfolioTheme)
        XCTAssertNotNil(themeManager.typography)
    }
    
    func testToggleScheme() {
        let themeManager = ThemeManager()
        
        // Initial state
        XCTAssertEqual(themeManager.colorScheme, .dark)
        
        // Toggle to light
        themeManager.toggleScheme()
        XCTAssertEqual(themeManager.colorScheme, .light)
        
        // Toggle back to dark
        themeManager.toggleScheme()
        XCTAssertEqual(themeManager.colorScheme, .dark)
    }
    
    func testUpdateColorScheme() {
        let themeManager = ThemeManager()
        
        // Update to light
        themeManager.updateColorScheme(.light)
        XCTAssertEqual(themeManager.colorScheme, .light)
        
        // Update back to dark
        themeManager.updateColorScheme(.dark)
        XCTAssertEqual(themeManager.colorScheme, .dark)
        
        // Update to same scheme (should not change)
        themeManager.updateColorScheme(.dark)
        XCTAssertEqual(themeManager.colorScheme, .dark)
    }
    
    func testPerFolioThemeIsGold() {
        let themeManager = ThemeManager()
        
        // PerFolio theme should always be .gold
        XCTAssertEqual(themeManager.perfolioTheme.tintColor, PerFolioTheme.gold.tintColor)
        XCTAssertEqual(themeManager.perfolioTheme.buttonBackground, PerFolioTheme.gold.buttonBackground)
    }
}

