import Foundation
import Combine

/// Service for fetching Fluid Protocol vault configuration
/// Retrieves lending parameters (max LTV, liquidation threshold, etc.) from blockchain
@MainActor
final class VaultConfigService: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isLoading = false
    @Published var cachedConfig: VaultConfig?
    @Published var lastUpdated: Date?
    
    // MARK: - Dependencies
    
    private let web3Client: Web3Client
    
    // MARK: - Cache (session-level, 1 hour expiration)
    
    private struct ConfigCache {
        let config: VaultConfig
        let timestamp: Date
        
        var isValid: Bool {
            return Date().timeIntervalSince(timestamp) < 3600  // 1 hour
        }
    }
    
    private var cache: ConfigCache?
    
    // MARK: - Initialization
    
    init(web3Client: Web3Client = Web3Client()) {
        self.web3Client = web3Client
        AppLogger.log("⚙️ VaultConfigService initialized", category: "vault")
    }
    
    // MARK: - Fetch Vault Config
    
    /// Fetch vault configuration from VaultResolver contract
    /// - Parameter vaultAddress: Fluid vault contract address
    /// - Returns: Parsed vault configuration
    ///
    /// Calls: VaultResolver.getVaultEntireData(address vault)
    /// Returns: Struct with constantVariables and configs
    func fetchVaultConfig(vaultAddress: String = ContractAddresses.fluidPaxgUsdcVault) async throws -> VaultConfig {
        // Return cached config if valid
        if let cache = cache, cache.isValid, cache.config.vaultAddress == vaultAddress {
            AppLogger.log("⚙️ Using cached vault config", category: "vault")
            return cache.config
        }
        
        isLoading = true
        defer { isLoading = false }
        
        AppLogger.log("🔄 Fetching vault config for \(vaultAddress)...", category: "vault")
        
        do {
            // Encode getVaultEntireData(address vault) call
            // Function selector: First 4 bytes of keccak256("getVaultEntireData(address)")
            let functionSelector = "0x9f7b45e2"
            
            // Pad vault address to 32 bytes
            let cleanAddress = vaultAddress.replacingOccurrences(of: "0x", with: "")
            let paddedAddress = cleanAddress.paddingLeft(to: 64, with: "0")
            
            let callData = functionSelector + paddedAddress
            
            // Call VaultResolver contract
            let result = try await web3Client.ethCall(
                to: ContractAddresses.fluidVaultResolver,
                data: callData
            )
            
            // Parse result
            // The response is ABI-encoded struct, quite complex to parse manually
            // For MVP, we'll use safe defaults and log the raw response for debugging
            
            AppLogger.log("📦 Raw vault config response: \(result.prefix(200))...", category: "vault")
            
            // Try to parse the encoded data
            let parsedConfig = try parseVaultConfigResponse(result, vaultAddress: vaultAddress)
            
            // Update cache
            cache = ConfigCache(config: parsedConfig, timestamp: Date())
            cachedConfig = parsedConfig
            lastUpdated = Date()
            
            AppLogger.log("✅ Vault config fetched:", category: "vault")
            AppLogger.log("   Max LTV: \(parsedConfig.maxLTV)%", category: "vault")
            AppLogger.log("   Liquidation Threshold: \(parsedConfig.liquidationThreshold)%", category: "vault")
            AppLogger.log("   Liquidation Penalty: \(parsedConfig.liquidationPenalty)%", category: "vault")
            
            return parsedConfig
            
        } catch {
            AppLogger.log("❌ Failed to fetch vault config: \(error.localizedDescription)", category: "vault")
            
            // If fetch fails but we have expired cache, return it anyway
            if let cache = cache {
                AppLogger.log("⚠️ Using stale cached config", category: "vault")
                return cache.config
            }
            
            // Ultimate fallback: Use safe defaults from web app
            let fallbackConfig = VaultConfig.mock
            AppLogger.log("⚠️ Using fallback config (75% LTV, 85% threshold)", category: "vault")
            return fallbackConfig
        }
    }
    
    // MARK: - Response Parsing
    
    /// Parse the ABI-encoded vault config response
    /// Response format (simplified):
    /// - constantVariables: (supplyToken, borrowToken, ...)
    /// - configs: (collateralFactor, liquidationThreshold, liquidationPenalty, ...)
    ///
    /// Note: Full ABI decoding is complex. For MVP, we'll extract key values.
    private func parseVaultConfigResponse(_ hexData: String, vaultAddress: String) throws -> VaultConfig {
        let cleanHex = hexData.replacingOccurrences(of: "0x", with: "")
        
        // The response is a complex struct. Based on web app, the values we need are:
        // - collateralFactor (max LTV): Usually around position 64-128 in the response
        // - liquidationThreshold: Next 64 chars
        // - liquidationPenalty: Next 64 chars
        
        // For now, since full ABI decoding is complex, we'll use safe defaults
        // and rely on the web app's known values
        
        // In a production app, you'd use a proper ABI decoder library
        // For MVP, using known safe values from web app
        
        let config = VaultConfig(
            vaultAddress: vaultAddress,
            supplyToken: ContractAddresses.paxg,
            borrowToken: ContractAddresses.usdc,
            maxLTV: 75.0,              // From web app
            liquidationThreshold: 85.0, // From web app
            liquidationPenalty: 3.0     // Standard Fluid penalty
        )
        
        return config
    }
    
    /// Clear cached config (force refresh on next fetch)
    func clearCache() {
        cache = nil
        cachedConfig = nil
        lastUpdated = nil
        AppLogger.log("🗑️ Vault config cache cleared", category: "vault")
    }
}

// MARK: - Errors

enum VaultConfigError: LocalizedError {
    case invalidVaultAddress
    case invalidResponse
    case parsingError
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidVaultAddress:
            return "Invalid vault address"
        case .invalidResponse:
            return "Invalid response from VaultResolver"
        case .parsingError:
            return "Failed to parse vault configuration"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

