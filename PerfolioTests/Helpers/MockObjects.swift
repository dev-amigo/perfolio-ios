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

