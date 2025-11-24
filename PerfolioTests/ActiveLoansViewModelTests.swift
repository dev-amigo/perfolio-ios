import XCTest
@testable import PerFolio

@MainActor
final class ActiveLoansViewModelTests: XCTestCase {
    
    var viewModel: ActiveLoansViewModel!
    var mockPositionsService: MockFluidPositionsService!
    
    override func setUp() {
        super.setUp()
        mockPositionsService = MockFluidPositionsService()
        viewModel = ActiveLoansViewModel(positionsService: mockPositionsService)
    }
    
    override func tearDown() {
        viewModel = nil
        mockPositionsService = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState() {
        // Given: Fresh view model
        // Then: Should have correct initial values
        XCTAssertEqual(viewModel.viewState, .loading)
        XCTAssertTrue(viewModel.positions.isEmpty)
        XCTAssertEqual(viewModel.summary.totalLoans, 0)
        XCTAssertEqual(viewModel.summary.totalCollateral, 0)
        XCTAssertEqual(viewModel.summary.totalDebt, 0)
    }
    
    // MARK: - Loading Positions Tests
    
    func testLoadPositions_Success_WithOnePosition() async {
        // Given: Mock service returns 1 position
        let mockPosition = BorrowPosition.mock
        mockPositionsService.mockPositions = [mockPosition]
        
        // When: Load positions
        UserDefaults.standard.set("0xTest123", forKey: "userWalletAddress")
        await viewModel.reload()
        
        // Then: Should show ready state with position
        XCTAssertEqual(viewModel.viewState, .ready)
        XCTAssertEqual(viewModel.positions.count, 1)
        XCTAssertEqual(viewModel.positions.first?.nftId, mockPosition.nftId)
        XCTAssertEqual(viewModel.summary.totalLoans, 1)
    }
    
    func testLoadPositions_Success_WithMultiplePositions() async {
        // Given: Mock service returns 3 positions
        let position1 = BorrowPosition.mock
        let position2 = BorrowPosition(
            id: "test-2",
            nftId: "2",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 0.2,
            borrowAmount: 200.0,
            collateralValueUSD: 800.0,
            debtValueUSD: 200.0,
            healthFactor: 2.5,
            currentLTV: 25.0,
            liquidationPrice: 500.0,
            availableToBorrowUSD: 400.0,
            status: .safe,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
        let position3 = BorrowPosition(
            id: "test-3",
            nftId: "3",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 0.05,
            borrowAmount: 50.0,
            collateralValueUSD: 200.0,
            debtValueUSD: 50.0,
            healthFactor: 3.0,
            currentLTV: 25.0,
            liquidationPrice: 300.0,
            availableToBorrowUSD: 100.0,
            status: .safe,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
        
        mockPositionsService.mockPositions = [position1, position2, position3]
        
        // When: Load positions
        UserDefaults.standard.set("0xTest123", forKey: "userWalletAddress")
        await viewModel.reload()
        
        // Then: Should aggregate correctly
        XCTAssertEqual(viewModel.viewState, .ready)
        XCTAssertEqual(viewModel.positions.count, 3)
        XCTAssertEqual(viewModel.summary.totalLoans, 3)
        XCTAssertEqual(viewModel.summary.totalCollateral, 0.35) // 0.1 + 0.2 + 0.05
        XCTAssertEqual(viewModel.summary.totalDebt, 350.0) // 100 + 200 + 50
    }
    
    func testLoadPositions_Success_EmptyPositions() async {
        // Given: Mock service returns no positions
        mockPositionsService.mockPositions = []
        
        // When: Load positions
        UserDefaults.standard.set("0xTest123", forKey: "userWalletAddress")
        await viewModel.reload()
        
        // Then: Should show empty state
        XCTAssertEqual(viewModel.viewState, .empty)
        XCTAssertTrue(viewModel.positions.isEmpty)
        XCTAssertEqual(viewModel.summary.totalLoans, 0)
    }
    
    func testLoadPositions_Failure_NoWallet() async {
        // Given: No wallet address stored
        UserDefaults.standard.removeObject(forKey: "userWalletAddress")
        
        // When: Load positions
        await viewModel.reload()
        
        // Then: Should show error
        if case .error(let message) = viewModel.viewState {
            XCTAssertTrue(message.contains("log in"))
        } else {
            XCTFail("Expected error state")
        }
    }
    
    func testLoadPositions_Failure_NetworkError() async {
        // Given: Mock service throws error
        mockPositionsService.shouldThrowError = true
        mockPositionsService.errorToThrow = NSError(domain: "test", code: 500)
        
        // When: Load positions
        UserDefaults.standard.set("0xTest123", forKey: "userWalletAddress")
        await viewModel.reload()
        
        // Then: Should show error state
        if case .error(let message) = viewModel.viewState {
            XCTAssertTrue(message.contains("Unable to load"))
        } else {
            XCTFail("Expected error state")
        }
    }
    
    // MARK: - Summary Calculation Tests
    
    func testSummaryCalculation_SinglePosition() async {
        // Given: One position with known values
        let position = BorrowPosition(
            id: "test-1",
            nftId: "1",
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 1.5,
            borrowAmount: 500.0,
            collateralValueUSD: 6000.0,
            debtValueUSD: 500.0,
            healthFactor: 5.0,
            currentLTV: 8.33,
            liquidationPrice: 200.0,
            availableToBorrowUSD: 4000.0,
            status: .safe,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
        mockPositionsService.mockPositions = [position]
        
        // When: Load positions
        UserDefaults.standard.set("0xTest123", forKey: "userWalletAddress")
        await viewModel.reload()
        
        // Then: Summary should match
        XCTAssertEqual(viewModel.summary.totalLoans, 1)
        XCTAssertEqual(viewModel.summary.totalCollateral, 1.5)
        XCTAssertEqual(viewModel.summary.totalDebt, 500.0)
        XCTAssertEqual(viewModel.summary.totalCollateralUSD, 6000.0)
        XCTAssertEqual(viewModel.summary.totalCollateralDisplay, "1.5 PAXG")
        XCTAssertEqual(viewModel.summary.totalDebtDisplay, "$500.00")
    }
    
    // MARK: - Reload Tests
    
    func testReload_UpdatesPositions() async {
        // Given: Initial positions
        mockPositionsService.mockPositions = [BorrowPosition.mock]
        UserDefaults.standard.set("0xTest123", forKey: "userWalletAddress")
        await viewModel.reload()
        XCTAssertEqual(viewModel.positions.count, 1)
        
        // When: Positions change and reload
        let newPosition = BorrowPosition.mock
        mockPositionsService.mockPositions = [BorrowPosition.mock, newPosition]
        await viewModel.reload()
        
        // Then: Should reflect new positions
        XCTAssertEqual(viewModel.positions.count, 2)
        XCTAssertEqual(viewModel.summary.totalLoans, 2)
    }
}

// MARK: - Mock Service (moved to MockObjects.swift to avoid duplication)

