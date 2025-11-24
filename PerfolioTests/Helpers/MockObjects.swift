import Foundation
@testable import PerFolio

// MARK: - BorrowPosition Mock

extension BorrowPosition {
    static var mock: BorrowPosition {
        BorrowPosition(
            id: "mock-position-1",
            nftId: "8896",
            owner: "0xB3Eb44b13f05eDcb2aC1802e2725b6F35f77D33c",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: 0.1,
            borrowAmount: 100.0,
            collateralValueUSD: 400.0,
            debtValueUSD: 100.0,
            healthFactor: 3.4,
            currentLTV: 25.0,
            liquidationPrice: 1176.47,
            availableToBorrowUSD: 200.0,
            status: .safe,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
    }
    
    static func mockWith(
        nftId: String = "1",
        collateralAmount: Decimal = 0.1,
        borrowAmount: Decimal = 100.0,
        healthFactor: Decimal = 3.0,
        status: PositionStatus = .safe
    ) -> BorrowPosition {
        BorrowPosition(
            id: "mock-\(nftId)",
            nftId: nftId,
            owner: "0xTest",
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralAmount: collateralAmount,
            borrowAmount: borrowAmount,
            collateralValueUSD: collateralAmount * 4000.0,
            debtValueUSD: borrowAmount,
            healthFactor: healthFactor,
            currentLTV: (borrowAmount / (collateralAmount * 4000.0)) * 100,
            liquidationPrice: borrowAmount / (collateralAmount * 0.85),
            availableToBorrowUSD: max(0, (collateralAmount * 4000.0 * 0.75) - borrowAmount),
            status: status,
            createdAt: Date(),
            lastUpdatedAt: Date()
        )
    }
}

// MARK: - VaultConfig Mock

extension VaultConfig {
    static var mock: VaultConfig {
        VaultConfig(
            vaultAddress: ContractAddresses.fluidPaxgUsdcVault,
            collateralToken: "PAXG",
            debtToken: "USDC",
            maxLTV: 75.0,
            liquidationThreshold: 85.0,
            liquidationPenalty: 3.0,
            borrowRate: 5.0,
            supplyRate: 3.0,
            lastUpdated: Date()
        )
    }
}

// MARK: - Web3 Error

enum Web3Error: Error, Equatable {
    case invalidResponse
    case rpcError(code: Int, message: String)
    case networkError(String)
    case decodingError
    
    static func ==(lhs: Web3Error, rhs: Web3Error) -> Bool {
        switch (lhs, rhs) {
        case (.invalidResponse, .invalidResponse):
            return true
        case let (.rpcError(code1, msg1), .rpcError(code2, msg2)):
            return code1 == code2 && msg1 == msg2
        case let (.networkError(msg1), .networkError(msg2)):
            return msg1 == msg2
        case (.decodingError, .decodingError):
            return true
        default:
            return false
        }
    }
}

// MARK: - Vault Config Error

enum VaultConfigError: Error {
    case networkError(Error)
    case invalidData
    case contractReverted
}

// MARK: - Mock Services

@MainActor
class MockFluidVaultService: FluidVaultService {
    // Mock properties for BorrowViewModel tests
    var mockPAXGPrice: Decimal = 4000.0
    var mockVaultConfig: VaultConfig?
    var mockCurrentAPY: Decimal = 5.5
    var mockNFTId: String = "8896"
    var shouldThrowError = false
    var executeBorrowCalled = false
    
    // Mock properties for LoanActionHandler tests
    var borrowCalled = false
    var lastBorrowRequest: BorrowRequest?
    var borrowResult: Result<String, Error> = .success("0xmocktxhash")
    
    var repayCalled = false
    var lastRepayAmount: Decimal?
    var lastPosition: BorrowPosition?
    var repayResult: Result<Void, Error> = .success(())
    
    var addCollateralCalled = false
    var lastCollateralAmount: Decimal?
    var addCollateralResult: Result<Void, Error> = .success(())
    
    var withdrawCalled = false
    var lastWithdrawAmount: Decimal?
    var withdrawResult: Result<Void, Error> = .success(())
    
    var closeCalled = false
    var closeResult: Result<Void, Error> = .success(())
    
    override func initialize() async throws {
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock initialization error"])
        }
        
        paxgPrice = mockPAXGPrice
        vaultConfig = mockVaultConfig
        currentAPY = mockCurrentAPY
    }
    
    override func executeBorrow(request: BorrowRequest) async throws -> String {
        executeBorrowCalled = true
        borrowCalled = true
        lastBorrowRequest = request
        
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock borrow error"])
        }
        
        switch borrowResult {
        case .success:
            return mockNFTId
        case .failure(let error):
            throw error
        }
    }
    
    override func repay(position: BorrowPosition, amount: Decimal) async throws {
        repayCalled = true
        lastRepayAmount = amount
        lastPosition = position
        switch repayResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    override func addCollateral(position: BorrowPosition, amount: Decimal) async throws {
        addCollateralCalled = true
        lastCollateralAmount = amount
        lastPosition = position
        switch addCollateralResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    override func withdraw(position: BorrowPosition, amount: Decimal) async throws {
        withdrawCalled = true
        lastWithdrawAmount = amount
        lastPosition = position
        switch withdrawResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
    
    override func close(position: BorrowPosition) async throws {
        closeCalled = true
        lastPosition = position
        switch closeResult {
        case .success:
            return
        case .failure(let error):
            throw error
        }
    }
}

@MainActor
class MockFluidPositionsService: FluidPositionsService {
    var mockPositions: [BorrowPosition] = []
    var shouldThrowError = false
    var errorToThrow: Error = Web3Error.networkError("Mock error")
    
    override func fetchPositions(for owner: String) async throws -> [BorrowPosition] {
        if shouldThrowError {
            throw errorToThrow
        }
        return mockPositions
    }
}

// MockWeb3Client and MockERC20Contract removed - actors cannot be subclassed
// Test files should use their own specialized mocks when needed

@MainActor
class MockVaultConfigService: VaultConfigService {
    var mockConfig: VaultConfig?
    var shouldThrowError = false
    var errorToThrow: Error = Web3Error.networkError("Mock error")
    
    override func fetchVaultConfig(vaultAddress: String = ContractAddresses.fluidPaxgUsdcVault) async throws -> VaultConfig {
        if shouldThrowError {
            throw errorToThrow
        }
        return mockConfig ?? VaultConfig.mock
    }
}

class MockTransakService: TransakService {
    var mockURL: URL?
    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "MockError", code: -1)
    var buildWithdrawURLCalled = false
    var lastCryptoAmount: String?
    
    override func buildWithdrawURL(
        cryptoAmount: String,
        cryptoCurrency: String = "USDC",
        fiatCurrency: String = "INR"
    ) throws -> URL {
        buildWithdrawURLCalled = true
        lastCryptoAmount = cryptoAmount
        
        if shouldThrowError {
            throw errorToThrow
        }
        return mockURL ?? URL(string: "https://global.transak.com")!
    }
}

