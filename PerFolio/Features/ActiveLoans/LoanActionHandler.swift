import Foundation
import Combine

@MainActor
final class LoanActionHandler: ObservableObject {
    @Published var isPerforming = false
    
    private let vaultService: FluidVaultService
    
    init(vaultService: FluidVaultService? = nil) {
        if let provided = vaultService {
            self.vaultService = provided
        } else {
            self.vaultService = FluidVaultService()
        }
    }
    
    func addCollateral(position: BorrowPosition, amount: Decimal) async throws {
        try await perform {
            try await vaultService.addCollateral(position: position, amount: amount)
        }
    }
    
    func repay(position: BorrowPosition, amount: Decimal) async throws {
        try await perform {
            try await vaultService.repay(position: position, amount: amount)
        }
    }
    
    func withdraw(position: BorrowPosition, amount: Decimal) async throws {
        try await perform {
            try await vaultService.withdraw(position: position, amount: amount)
        }
    }
    
    func close(position: BorrowPosition) async throws {
        try await perform {
            try await vaultService.close(position: position)
        }
    }
    
    private func perform(_ operation: () async throws -> Void) async throws {
        guard !isPerforming else { return }
        isPerforming = true
        defer { isPerforming = false }
        try await operation()
    }
}
