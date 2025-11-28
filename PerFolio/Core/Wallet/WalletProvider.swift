import Foundation

/// Wallet providers for signing blockchain transactions
/// 
/// Supports multiple wallet options:
/// - Privy: Standard embedded wallet (production ready)
/// - Alchemy: Alternative RPC provider for testing (dev mode only)
/// 
/// **Note:** Both options currently use Privy's embedded wallet for signing.
/// True Alchemy AA with gas sponsorship requires their SDK (future enhancement).
enum WalletProvider: String, CaseIterable, Identifiable {
    case privyEmbedded = "privy"
    case alchemyAA = "alchemy"
    
    var id: String { rawValue }
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .privyEmbedded:
            return "Privy Embedded Wallet"
        case .alchemyAA:
            return "Alchemy RPC (Testing)"
        }
    }
    
    /// Short description of the provider
    var description: String {
        switch self {
        case .privyEmbedded:
            return "Production-ready embedded wallet"
        case .alchemyAA:
            return "Alternative RPC for testing (requires user ETH for gas)"
        }
    }
    
    /// SF Symbol icon for UI
    var icon: String {
        switch self {
        case .privyEmbedded:
            return "lock.shield.fill"
        case .alchemyAA:
            return "network"
        }
    }
    
    /// Whether this provider supports gas sponsorship
    /// Note: Both use Privy, so gas sponsorship depends on Privy policy configuration
    var supportsGasSponsorship: Bool {
        switch self {
        case .privyEmbedded:
            return true  // Via Privy policies
        case .alchemyAA:
            return true  // Via Privy policies (same as standard)
        }
    }
    
    /// Whether this provider is available in current build
    var isAvailable: Bool {
        switch self {
        case .privyEmbedded:
            return true  // Always available
        case .alchemyAA:
            #if DEBUG
            return true  // Only available in debug builds
            #else
            return false
            #endif
        }
    }
    
    /// Badge text (e.g., "Production", "Testing")
    var badge: String? {
        switch self {
        case .privyEmbedded:
            return "Production"
        case .alchemyAA:
            return "Testing"
        }
    }
    
    /// Get current selected provider from preferences
    static var current: WalletProvider {
        let rawValue = UserPreferences.selectedWalletProvider
        return WalletProvider(rawValue: rawValue) ?? .privyEmbedded
    }
    
    /// Save provider to preferences
    func select() {
        UserPreferences.selectedWalletProvider = self.rawValue
    }
}

