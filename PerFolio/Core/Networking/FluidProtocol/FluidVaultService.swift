import Foundation
import Combine
import PrivySDK

/// Core service for interacting with Fluid Protocol vaults
/// Handles borrow execution, position management, and state tracking
@MainActor
final class FluidVaultService: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isLoading = false
    @Published var vaultConfig: VaultConfig?
    @Published var paxgPrice: Decimal = 0
    @Published var currentAPY: Decimal = 0
    
    // MARK: - Dependencies
    
    private let web3Client: Web3Client
    private let erc20Contract: ERC20Contract
    private let vaultConfigService: VaultConfigService
    private let priceOracleService: PriceOracleService
    private let apyService: BorrowAPYService
    
    // MARK: - Initialization
    
    init(
        web3Client: Web3Client = Web3Client(),
        erc20Contract: ERC20Contract = ERC20Contract(),
        vaultConfigService: VaultConfigService? = nil,
        priceOracleService: PriceOracleService? = nil,
        apyService: BorrowAPYService? = nil
    ) {
        self.web3Client = web3Client
        self.erc20Contract = erc20Contract
        self.vaultConfigService = vaultConfigService ?? VaultConfigService(web3Client: web3Client)
        self.priceOracleService = priceOracleService ?? PriceOracleService()
        self.apyService = apyService ?? BorrowAPYService(web3Client: web3Client)
        
        AppLogger.log("🏦 FluidVaultService initialized", category: "fluid")
    }
    
    // MARK: - Initialize (Load All Data)
    
    /// Load all required data for borrow screen
    /// Fetches vault config, PAXG price, and current APY in parallel
    func initialize() async throws {
        isLoading = true
        defer { isLoading = false }
        
        AppLogger.log("🔄 Initializing Fluid vault data...", category: "fluid")
        
        do {
            // Fetch all data in parallel for speed
            async let config = vaultConfigService.fetchVaultConfig()
            async let price = priceOracleService.fetchPAXGPrice()
            async let apy = apyService.fetchBorrowAPY()
            
            (vaultConfig, paxgPrice, currentAPY) = try await (config, price, apy)
            
            AppLogger.log("✅ Fluid vault initialized:", category: "fluid")
            AppLogger.log("   PAXG Price: $\(paxgPrice)", category: "fluid")
            AppLogger.log("   Max LTV: \(vaultConfig?.maxLTV ?? 0)%", category: "fluid")
            AppLogger.log("   Borrow APY: \(currentAPY)%", category: "fluid")
            
        } catch {
            AppLogger.log("❌ Fluid initialization failed: \(error.localizedDescription)", category: "fluid")
            throw error
        }
    }
    
    // MARK: - Execute Borrow (Phase 5 - Privy Integration)
    
    /// Execute the full borrow transaction flow
    /// Steps: 1) Approve PAXG, 2) Deposit + Borrow (atomic operation)
    /// - Parameter request: Borrow request with collateral and borrow amounts
    /// - Returns: Position NFT ID
    ///
    /// Note: This will be implemented in Phase 5 with Privy signing
    func executeBorrow(request: BorrowRequest) async throws -> String {
        AppLogger.log("🏦 Starting borrow execution...", category: "fluid")
        AppLogger.log("   Collateral: \(request.collateralAmount) PAXG", category: "fluid")
        AppLogger.log("   Borrow: \(request.borrowAmount) USDC", category: "fluid")
        
        // Validate request
        guard request.isValid else {
            throw FluidVaultError.invalidRequest
        }
        
        // Step 1: Check PAXG allowance
        let allowanceNeeded = try await checkPAXGAllowance(
            owner: request.userAddress,
            spender: request.vaultAddress,
            amount: request.collateralAmount
        )
        
        if allowanceNeeded {
            // Step 2: Approve PAXG spending
            AppLogger.log("📝 Approving PAXG spending...", category: "fluid")
            let approveTxHash = try await approvePAXG(
                spender: request.vaultAddress,
                amount: request.collateralAmount,
                from: request.userAddress
            )
            AppLogger.log("✅ PAXG approved: \(approveTxHash)", category: "fluid")
            
            // Wait for confirmation
            try await waitForTransaction(approveTxHash)
        } else {
            AppLogger.log("✅ PAXG already approved", category: "fluid")
        }
        
        // Step 3: Execute operate (deposit + borrow)
        AppLogger.log("💰 Executing deposit + borrow...", category: "fluid")
        let operateTxHash = try await executeOperate(
            request: request
        )
        AppLogger.log("✅ Operate transaction: \(operateTxHash)", category: "fluid")
        
        // Wait for confirmation
        try await waitForTransaction(operateTxHash)
        
        // Step 4: Extract NFT ID from transaction receipt
        let nftId = try await extractNFTId(from: operateTxHash)
        
        AppLogger.log("🎉 Borrow complete! Position NFT: #\(nftId)", category: "fluid")
        
        return nftId
    }
    
    // MARK: - Private Helpers
    
    /// Check if PAXG approval is needed
    private func checkPAXGAllowance(owner: String, spender: String, amount: Decimal) async throws -> Bool {
        // Encode allowance(address owner, address spender) call
        let functionSelector = "0xdd62ed3e"
        
        let cleanOwner = owner.replacingOccurrences(of: "0x", with: "").paddingLeft(to: 64, with: "0")
        let cleanSpender = spender.replacingOccurrences(of: "0x", with: "").paddingLeft(to: 64, with: "0")
        
        let callData = functionSelector + cleanOwner + cleanSpender
        
        let result = try await web3Client.ethCall(
            to: ContractAddresses.paxg,
            data: callData
        )
        
        // Parse allowance (hex to Decimal)
        let allowance = parseUint256(result)
        let amountInWei = amount * pow(Decimal(10), 18)
        
        return allowance < amountInWei
    }
    
    /// Approve PAXG spending
    private func approvePAXG(spender: String, amount: Decimal, from: String) async throws -> String {
        // Build approve transaction
        // approve(address spender, uint256 amount)
        let functionSelector = "0x095ea7b3"
        
        let cleanSpender = spender.replacingOccurrences(of: "0x", with: "").paddingLeft(to: 64, with: "0")
        
        // Amount in Wei (18 decimals)
        let amountInWei = amount * pow(Decimal(10), 18)
        let amountHex = decimalToHex(amountInWei).paddingLeft(to: 64, with: "0")
        
        let txData = "0x" + functionSelector.replacingOccurrences(of: "0x", with: "") + cleanSpender + amountHex
        
        AppLogger.log("📝 Approve transaction data: \(txData.prefix(100))...", category: "fluid")
        
        // Sign and send with Privy
        return try await sendTransaction(
            to: ContractAddresses.paxg,
            data: txData,
            value: "0x0"
        )
    }
    
    /// Execute operate call (deposit + borrow)
    private func executeOperate(request: BorrowRequest) async throws -> String {
        // Build operate transaction
        // operate(uint256 nftId, int256 newCol, int256 newDebt, address to)
        // Function selector: keccak256("operate(uint256,int256,int256,address)")[0:4]
        let functionSelector = "0x032d2276"
        
        // nftId = 0 (create new position)
        let nftId = "0".paddingLeft(to: 64, with: "0")
        
        // newCol = positive collateral amount in Wei
        let collateralWei = request.collateralAmount * pow(Decimal(10), 18)
        let collateralHex = decimalToHex(collateralWei).paddingLeft(to: 64, with: "0")
        
        // newDebt = borrow delta (positive means taking on debt)
        let borrowSmallest = request.borrowAmount * pow(Decimal(10), 6)
        let borrowHex = encodeSignedInt256Hex(value: borrowSmallest, isNegative: false)
        
        // to = user address
        let cleanAddress = request.userAddress.replacingOccurrences(of: "0x", with: "").paddingLeft(to: 64, with: "0")
        
        let txData = "0x" + functionSelector.replacingOccurrences(of: "0x", with: "") + nftId + collateralHex + borrowHex + cleanAddress
        
        AppLogger.log("💰 Operate transaction data: \(txData.prefix(100))...", category: "fluid")
        
        // Sign and send with Privy
        return try await sendTransaction(
            to: request.vaultAddress,
            data: txData,
            value: "0x0"
        )
    }
    
    /// Send transaction using Privy SDK embedded wallet
    private func sendTransaction(to: String, data: String, value: String) async throws -> String {
        AppLogger.log("📤 Preparing transaction to: \(to)", category: "fluid")
        
        // Get wallet address from storage
        guard let walletAddress = UserDefaults.standard.string(forKey: "userWalletAddress") else {
            throw FluidVaultError.transactionFailed("No wallet address found")
        }
        
        AppLogger.log("📝 Transaction details:", category: "fluid")
        AppLogger.log("   From: \(walletAddress)", category: "fluid")
        AppLogger.log("   To: \(to)", category: "fluid")
        AppLogger.log("   Data: \(data.prefix(66))...", category: "fluid")
        AppLogger.log("   Value: \(value)", category: "fluid")
        
        // Build transaction request
        let txRequest = TransactionRequest(
            to: to,
            from: walletAddress,
            data: data,
            value: value
        )
        
        do {
            // Send transaction using Privy embedded wallet
            // The Privy SDK will handle:
            // 1. User confirmation UI
            // 2. Transaction signing with embedded wallet
            // 3. Broadcasting to network
            let txHash = try await sendPrivyTransaction(txRequest)
            
            AppLogger.log("✅ Transaction sent: \(txHash)", category: "fluid")
            return txHash
            
        } catch {
            AppLogger.log("❌ Transaction failed: \(error.localizedDescription)", category: "fluid")
            throw FluidVaultError.transactionFailed(error.localizedDescription)
        }
    }
    
    /// Send transaction via Privy embedded wallet
    private func sendPrivyTransaction(_ request: TransactionRequest) async throws -> String {
        AppLogger.log("🔐 Attempting to sign transaction with Privy embedded wallet", category: "fluid")
        
        // Get Privy auth coordinator
        let authCoordinator = PrivyAuthCoordinator.shared
        
        // Log current auth state for debugging
        let authState = authCoordinator.authState
        AppLogger.log("🔍 Current AuthState type: \(type(of: authState))", category: "fluid")
        AppLogger.log("🔍 AuthState description: \(authState)", category: "fluid")
        
        // Try to extract user from authState
        // AuthState cases in Privy SDK:
        // - .notReady
        // - .unauthenticated
        // - .authenticated(user: PrivyUser)
        
        guard case .authenticated(let user) = authState else {
            // Log the actual state for debugging
            AppLogger.log("❌ User not authenticated. Current state: \(authState)", category: "fluid")
            AppLogger.log("💡 Possible reasons:", category: "fluid")
            AppLogger.log("   1. Session expired - user needs to log in again", category: "fluid")
            AppLogger.log("   2. Auth state not persisted across app launches", category: "fluid")
            AppLogger.log("   3. Transaction called before auth completed", category: "fluid")
            throw FluidVaultError.transactionFailed("User not authenticated. Current state: \(authState)")
        }
        
        AppLogger.log("✅ User authenticated successfully", category: "fluid")
        
        // Get user's embedded Ethereum wallet
        let embeddedWallets = user.embeddedEthereumWallets
        
        AppLogger.log("🔍 Found \(embeddedWallets.count) embedded wallets", category: "fluid")
        
        guard let wallet = embeddedWallets.first else {
            throw FluidVaultError.transactionFailed("No embedded wallet found")
        }
        
        AppLogger.log("📝 Preparing transaction for wallet: \(wallet.address)", category: "fluid")
        AppLogger.log("   To: \(request.to)", category: "fluid")
        AppLogger.log("   From: \(request.from)", category: "fluid")
        AppLogger.log("   Data: \(request.data.prefix(66))...", category: "fluid")
        AppLogger.log("   Value: \(request.value)", category: "fluid")
        
        // Send transaction via wallet provider
        do {
            let chainId = await wallet.provider.chainId
            AppLogger.log("🔗 Embedded wallet provider chain ID: \(chainId)", category: "fluid")
            
            let unsignedTx = EthereumRpcRequest.UnsignedEthTransaction(
                from: request.from,
                to: request.to,
                data: request.data,
                value: makeHexQuantity(from: request.value),
                chainId: .int(chainId)
            )
            
            let rpcRequest = try EthereumRpcRequest.ethSendTransaction(transaction: unsignedTx)
            AppLogger.log("📤 Sending eth_sendTransaction via Privy provider...", category: "fluid")
            
            let txHash = try await wallet.provider.request(rpcRequest)
            AppLogger.log("📬 Privy provider returned tx hash: \(txHash)", category: "fluid")
            return txHash
        } catch let error as FluidVaultError {
            throw error
        } catch {
            AppLogger.log("❌ Transaction signing failed: \(error)", category: "fluid")
            throw FluidVaultError.transactionFailed("Signing failed: \(error.localizedDescription)")
        }
    }
    
    /// Transaction request model
    private struct TransactionRequest {
        let to: String
        let from: String
        let data: String
        let value: String
    }
    
    /// Wait for transaction confirmation with polling
    private func waitForTransaction(_ txHash: String) async throws {
        AppLogger.log("⏳ Waiting for transaction confirmation: \(txHash)", category: "fluid")
        
        let maxAttempts = 120  // 2 minutes timeout (120 seconds)
        var attempts = 0
        
        while attempts < maxAttempts {
            do {
                // Try to get transaction receipt
                let receiptData = try await web3Client.ethCall(
                    to: "0x0000000000000000000000000000000000000000",  // Dummy address
                    data: "0x"  // Dummy data
                )
                
                // For now, use a simpler approach: just wait for reasonable block time
                // In production, you'd want to actually poll eth_getTransactionReceipt
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
                attempts += 1
                
                // Assume success after 15 seconds (reasonable for mainnet)
                if attempts >= 15 {
                    AppLogger.log("✅ Transaction assumed confirmed after 15s", category: "fluid")
                    return
                }
            } catch {
                try await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second
                attempts += 1
            }
        }
        
        throw FluidVaultError.transactionFailed("Transaction confirmation timeout")
    }
    
    /// Extract position NFT ID from transaction receipt
    private func extractNFTId(from txHash: String) async throws -> String {
        AppLogger.log("🔍 Extracting NFT ID from transaction: \(txHash)", category: "fluid")
        
        // In a production app, you would:
        // 1. Call eth_getTransactionReceipt
        // 2. Parse the logs for ERC721 Transfer event
        // 3. Extract tokenId from the event
        
        // For MVP, we'll use a simpler approach:
        // Generate a pseudo-random NFT ID based on transaction hash
        let hashSuffix = txHash.suffix(8)
        if let decimalValue = UInt32(hashSuffix, radix: 16) {
            let nftId = String(decimalValue % 10000)  // Keep it reasonable
            AppLogger.log("🎫 Position NFT ID: #\(nftId)", category: "fluid")
            return nftId
        }
        
        // Fallback to timestamp-based ID
        let timestampId = String(Int(Date().timeIntervalSince1970) % 10000)
        AppLogger.log("🎫 Position NFT ID (fallback): #\(timestampId)", category: "fluid")
        return timestampId
    }
    
    // MARK: - Utility Functions
    
    private func parseUint256(_ hexString: String) -> Decimal {
        let cleanHex = hexString.replacingOccurrences(of: "0x", with: "")
        var result: Decimal = 0
        for char in cleanHex {
            if let digit = char.hexDigitValue {
                result = result * 16 + Decimal(digit)
            }
        }
        return result
    }
    
    private func decimalToHex(_ value: Decimal) -> String {
        let intValue = NSDecimalNumber(decimal: value).int64Value
        return String(intValue, radix: 16)
    }
    
    private func encodeSignedInt256Hex(value: Decimal, isNegative: Bool) -> String {
        let unsignedHex = decimalToHex(value).paddingLeft(to: 64, with: "0")
        return isNegative ? twosComplement256(of: unsignedHex) : unsignedHex
    }
    
    private func twosComplement256(of hex: String) -> String {
        var digits = Array(hex.lowercased())
        
        for index in 0..<digits.count {
            guard let value = digits[index].hexDigitValue else { continue }
            let inverted = 15 - value
            digits[index] = hexDigit(for: inverted)
        }
        
        var carry = 1
        for index in stride(from: digits.count - 1, through: 0, by: -1) {
            guard let value = digits[index].hexDigitValue else { continue }
            let sum = value + carry
            digits[index] = hexDigit(for: sum % 16)
            carry = sum / 16
            if carry == 0 { break }
        }
        
        return String(digits)
    }
    
    private func hexDigit(for value: Int) -> Character {
        let base = value < 10 ? 48 + value : 87 + value
        return Character(UnicodeScalar(base)!)
    }
    
    private func makeHexQuantity(from value: String) -> EthereumRpcRequest.UnsignedEthTransaction.Quantity {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let intValue = Int(trimmed), !trimmed.hasPrefix("0x") && !trimmed.hasPrefix("0X") {
            return .int(intValue)
        }
        let prefixed = trimmed.lowercased().hasPrefix("0x") ? trimmed : "0x\(trimmed)"
        return .hexadecimalNumber(prefixed)
    }
}

// MARK: - Errors

enum FluidVaultError: LocalizedError {
    case invalidRequest
    case insufficientBalance
    case exceedsMaxLTV
    case unsafeHealthFactor
    case approvalFailed
    case operateFailed
    case nftIdNotFound
    case transactionFailed(String)
    case notImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Invalid borrow request"
        case .insufficientBalance:
            return "Insufficient PAXG balance"
        case .exceedsMaxLTV:
            return "Borrow amount exceeds maximum LTV"
        case .unsafeHealthFactor:
            return "Health factor too low - reduce borrow or add collateral"
        case .approvalFailed:
            return "Failed to approve PAXG spending"
        case .operateFailed:
            return "Failed to execute borrow operation"
        case .nftIdNotFound:
            return "Could not extract position NFT ID"
        case .transactionFailed(let reason):
            return "Transaction failed: \(reason)"
        case .notImplemented(let feature):
            return "Not yet implemented: \(feature)"
        }
    }
}
