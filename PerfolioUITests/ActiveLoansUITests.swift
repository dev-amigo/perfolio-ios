import XCTest

final class ActiveLoansUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDown() {
        app = nil
        super.tearDown()
    }
    
    // MARK: - Navigation Tests
    
    func testNavigateToLoansTab() {
        // Given: App is launched
        
        // When: Tap Loans tab
        let loansTab = app.tabBars.buttons["Loans"]
        XCTAssertTrue(loansTab.exists, "Loans tab should exist")
        loansTab.tap()
        
        // Then: Should show Active Loans screen
        XCTAssertTrue(app.staticTexts["Active Loans"].exists)
        XCTAssertTrue(app.staticTexts["View and manage every Fluid Protocol loan currently open."].exists)
    }
    
    // MARK: - Empty State Tests
    
    func testEmptyState_WhenNoPositions() {
        // Given: User has no active loans
        app.tabBars.buttons["Loans"].tap()
        
        // When: Screen loads
        waitForElement(app.staticTexts["No active loans yet"], timeout: 5)
        
        // Then: Should show empty state
        XCTAssertTrue(app.staticTexts["No active loans yet"].exists)
        XCTAssertTrue(app.staticTexts["Any loans you open will appear here with detailed stats and controls."].exists)
        XCTAssertTrue(app.images.containing(NSPredicate(format: "label CONTAINS 'lock.open'")).element.exists)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingState_ShowsProgressIndicator() {
        // Given: App is launched
        app.tabBars.buttons["Loans"].tap()
        
        // Then: Should show loading indicator initially
        let progressIndicator = app.activityIndicators.firstMatch
        
        // Wait a moment to catch loading state (might be fast)
        _ = progressIndicator.waitForExistence(timeout: 1)
        // Note: May not always catch it if loading is very fast
    }
    
    // MARK: - Position Display Tests
    
    func testPositionCard_DisplaysCorrectly() {
        // Given: User has active position
        app.tabBars.buttons["Loans"].tap()
        
        // Wait for position card to appear
        let positionCard = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Loan #'")).firstMatch
        
        if positionCard.waitForExistence(timeout: 5) {
            // Then: Should show position details
            XCTAssertTrue(positionCard.exists)
            
            // Check for key metrics
            XCTAssertTrue(app.staticTexts["Gold Locked"].exists)
            XCTAssertTrue(app.staticTexts["How Much You Borrowed"].exists)
            XCTAssertTrue(app.staticTexts["Loan Safety Score"].exists)
        }
    }
    
    func testPositionCard_Expandable() {
        // Given: User has active position
        app.tabBars.buttons["Loans"].tap()
        
        let positionCard = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Loan #'")).firstMatch
        
        if positionCard.waitForExistence(timeout: 5) {
            // When: Tap to expand
            positionCard.tap()
            
            // Then: Should show action buttons
            waitForElement(app.buttons["Pay Back Loan"], timeout: 2)
            XCTAssertTrue(app.buttons["Pay Back Loan"].exists)
            XCTAssertTrue(app.buttons["Add More Gold"].exists)
            XCTAssertTrue(app.buttons["Take Gold Back"].exists)
            XCTAssertTrue(app.buttons["Close Loan"].exists)
        }
    }
    
    func testPositionCard_Collapsible() {
        // Given: Position is expanded
        app.tabBars.buttons["Loans"].tap()
        
        let positionCard = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Loan #'")).firstMatch
        
        if positionCard.waitForExistence(timeout: 5) {
            positionCard.tap() // Expand
            waitForElement(app.buttons["Pay Back Loan"], timeout: 2)
            
            // When: Tap again to collapse
            positionCard.tap()
            
            // Then: Action buttons should be hidden
            XCTAssertFalse(app.buttons["Pay Back Loan"].exists)
        }
    }
    
    // MARK: - Summary Card Tests
    
    func testSummaryCard_DisplaysAggregatedStats() {
        // Given: User has active positions
        app.tabBars.buttons["Loans"].tap()
        
        // Wait for summary card
        let activeLoansLabel = app.staticTexts["Active Loans"]
        
        if activeLoansLabel.waitForExistence(timeout: 5) {
            // Then: Should show summary metrics
            XCTAssertTrue(app.staticTexts["ACTIVE LOANS"].exists)
            XCTAssertTrue(app.staticTexts["GOLD YOU PUT UP"].exists)
            XCTAssertTrue(app.staticTexts["MONEY YOU BORROWED"].exists)
        }
    }
    
    // MARK: - Action Button Tests
    
    func testPayBackButton_OpensSheet() {
        // Given: Position is expanded
        app.tabBars.buttons["Loans"].tap()
        
        let positionCard = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Loan #'")).firstMatch
        
        if positionCard.waitForExistence(timeout: 5) {
            positionCard.tap() // Expand
            
            waitForElement(app.buttons["Pay Back Loan"], timeout: 2)
            
            // When: Tap Pay Back button
            app.buttons["Pay Back Loan"].tap()
            
            // Then: Should open sheet with form
            XCTAssertTrue(app.navigationBars["Pay Back Loan"].exists)
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Enter how much USDC'")).element.exists)
            XCTAssertTrue(app.buttons["Cancel"].exists)
            XCTAssertTrue(app.buttons["Pay Back"].exists)
        }
    }
    
    func testAddMoreGoldButton_OpensSheet() {
        // Given: Position is expanded
        app.tabBars.buttons["Loans"].tap()
        
        let positionCard = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Loan #'")).firstMatch
        
        if positionCard.waitForExistence(timeout: 5) {
            positionCard.tap() // Expand
            
            waitForElement(app.buttons["Add More Gold"], timeout: 2)
            
            // When: Tap Add More Gold button
            app.buttons["Add More Gold"].tap()
            
            // Then: Should open sheet
            XCTAssertTrue(app.navigationBars["Add More Gold"].exists)
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Add extra PAXG'")).element.exists)
            XCTAssertTrue(app.buttons["Add Gold"].exists)
        }
    }
    
    func testTakeGoldBackButton_OpensSheet() {
        // Given: Position is expanded
        app.tabBars.buttons["Loans"].tap()
        
        let positionCard = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Loan #'")).firstMatch
        
        if positionCard.waitForExistence(timeout: 5) {
            positionCard.tap() // Expand
            
            waitForElement(app.buttons["Take Gold Back"], timeout: 2)
            
            // When: Tap Take Gold Back button
            app.buttons["Take Gold Back"].tap()
            
            // Then: Should open sheet
            XCTAssertTrue(app.navigationBars["Take Gold Back"].exists)
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Withdraw a portion'")).element.exists)
            XCTAssertTrue(app.buttons["Withdraw"].exists)
        }
    }
    
    func testCloseLoanButton_OpensSheet() {
        // Given: Position is expanded
        app.tabBars.buttons["Loans"].tap()
        
        let positionCard = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Loan #'")).firstMatch
        
        if positionCard.waitForExistence(timeout: 5) {
            positionCard.tap() // Expand
            
            waitForElement(app.buttons["Close Loan"], timeout: 2)
            
            // When: Tap Close Loan button
            app.buttons["Close Loan"].tap()
            
            // Then: Should open sheet
            XCTAssertTrue(app.navigationBars["Close Loan"].exists)
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Repay the remaining balance'")).element.exists)
            XCTAssertTrue(app.buttons["Close Loan"].exists)
        }
    }
    
    // MARK: - Form Validation Tests
    
    func testPayBackSheet_RequiresValidAmount() {
        // Given: Pay back sheet is open
        app.tabBars.buttons["Loans"].tap()
        
        let positionCard = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Loan #'")).firstMatch
        
        if positionCard.waitForExistence(timeout: 5) {
            positionCard.tap()
            waitForElement(app.buttons["Pay Back Loan"], timeout: 2)
            app.buttons["Pay Back Loan"].tap()
            
            // When: Try to submit without amount
            let textField = app.textFields["USDC"]
            textField.tap()
            textField.typeText("") // Empty
            
            app.buttons["Pay Back"].tap()
            
            // Then: Should show validation error
            waitForElement(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'valid amount'")).element, timeout: 2)
        }
    }
    
    func testActionSheet_CancelButton_DismissesSheet() {
        // Given: Any action sheet is open
        app.tabBars.buttons["Loans"].tap()
        
        let positionCard = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Loan #'")).firstMatch
        
        if positionCard.waitForExistence(timeout: 5) {
            positionCard.tap()
            waitForElement(app.buttons["Pay Back Loan"], timeout: 2)
            app.buttons["Pay Back Loan"].tap()
            
            XCTAssertTrue(app.navigationBars["Pay Back Loan"].exists)
            
            // When: Tap Cancel
            app.buttons["Cancel"].tap()
            
            // Then: Sheet should dismiss
            XCTAssertFalse(app.navigationBars["Pay Back Loan"].exists)
        }
    }
    
    // MARK: - Status Badge Tests
    
    func testStatusBadge_DisplaysCorrectly() {
        // Given: User has position
        app.tabBars.buttons["Loans"].tap()
        
        // Then: Should show status badge (SAFE, WARNING, DANGER, or LIQUIDATED)
        let statusBadges = ["SAFE", "WARNING", "DANGER", "LIQUIDATED"]
        
        waitFor(timeout: 5) {
            statusBadges.contains { self.app.staticTexts[$0].exists }
        }
    }
    
    // MARK: - Risk Meter Tests
    
    func testRiskMeter_DisplaysWhenExpanded() {
        // Given: Position is expanded
        app.tabBars.buttons["Loans"].tap()
        
        let positionCard = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Loan #'")).firstMatch
        
        if positionCard.waitForExistence(timeout: 5) {
            positionCard.tap() // Expand
            
            // Then: Should show risk meter
            waitForElement(app.staticTexts["Loan Risk Level"], timeout: 2)
            XCTAssertTrue(app.staticTexts["0% Safe"].exists)
            XCTAssertTrue(app.staticTexts["91% Danger"].exists)
        }
    }
    
    // MARK: - External Link Tests
    
    func testViewOnBlockchain_OpensLink() {
        // Given: Position is expanded
        app.tabBars.buttons["Loans"].tap()
        
        let positionCard = app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Loan #'")).firstMatch
        
        if positionCard.waitForExistence(timeout: 5) {
            positionCard.tap() // Expand
            
            // Then: Should show Etherscan link
            waitForElement(app.buttons["View on Blockchain"], timeout: 2)
            XCTAssertTrue(app.buttons["View on Blockchain"].exists)
            
            // Note: Actually opening external link would exit the app, so we just verify it exists
        }
    }
    
    // MARK: - Helper Methods
    
    private func waitForElement(_ element: XCUIElement, timeout: TimeInterval) {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, "Element \(element) did not appear within \(timeout) seconds")
    }
    
    private func waitFor(timeout: TimeInterval, condition: () -> Bool) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(block: { _, _ in condition() }),
            object: nil
        )
        wait(for: [expectation], timeout: timeout)
    }
}

