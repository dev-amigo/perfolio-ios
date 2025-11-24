import Foundation

/// Service for Transak off-ramp (crypto → fiat withdrawals)
/// Handles USDC → INR bank transfers
class TransakService {
    
    // MARK: - Types
    
    enum TransakError: Error, LocalizedError {
        case invalidURL
        case missingAPIKey
        case invalidAmount
        case missingWalletAddress
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Failed to build Transak widget URL"
            case .missingAPIKey:
                return "Transak API key not configured"
            case .invalidAmount:
                return "Invalid withdrawal amount"
            case .missingWalletAddress:
                return "Wallet address not available"
            }
        }
    }
    
    struct WithdrawRequest {
        let cryptoAmount: String
        let cryptoCurrency: String
        let fiatCurrency: String
        let walletAddress: String
        let network: String
        
        init(
            cryptoAmount: String,
            cryptoCurrency: String = "USDC",
            fiatCurrency: String = "INR",
            walletAddress: String,
            network: String = "ethereum"
        ) {
            self.cryptoAmount = cryptoAmount
            self.cryptoCurrency = cryptoCurrency
            self.fiatCurrency = fiatCurrency
            self.walletAddress = walletAddress
            self.network = network
        }
    }
    
    // MARK: - Properties
    
    private let environment: EnvironmentConfiguration
    private let transakBaseURL = "https://global.transak.com"
    
    // MARK: - Initialization
    
    init(environment: EnvironmentConfiguration = .current) {
        self.environment = environment
        AppLogger.log("💸 TransakService initialized", category: "transak")
        AppLogger.log("   API Key: \(environment.transakAPIKey.isEmpty ? "Not configured" : "Configured")", category: "transak")
        AppLogger.log("   Environment: \(environment.environment.displayName)", category: "transak")
    }
    
    // MARK: - Public Methods
    
    /// Build Transak widget URL for off-ramp (USDC → INR withdrawal)
    func buildWithdrawURL(request: WithdrawRequest) throws -> URL {
        guard !environment.transakAPIKey.isEmpty else {
            AppLogger.log("❌ Transak API key not configured", category: "transak")
            throw TransakError.missingAPIKey
        }
        
        guard let amount = Double(request.cryptoAmount), amount > 0 else {
            AppLogger.log("❌ Invalid amount: \(request.cryptoAmount)", category: "transak")
            throw TransakError.invalidAmount
        }
        
        guard !request.walletAddress.isEmpty else {
            AppLogger.log("❌ Wallet address is empty", category: "transak")
            throw TransakError.missingWalletAddress
        }
        
        AppLogger.log("🔗 Building Transak withdraw URL:", category: "transak")
        AppLogger.log("   Amount: \(request.cryptoAmount) \(request.cryptoCurrency)", category: "transak")
        AppLogger.log("   Wallet: \(request.walletAddress)", category: "transak")
        AppLogger.log("   Fiat: \(request.fiatCurrency)", category: "transak")
        
        // Build URL components
        guard var components = URLComponents(string: transakBaseURL) else {
            throw TransakError.invalidURL
        }
        
        // Add query parameters
        components.queryItems = [
            // Required
            URLQueryItem(name: "apiKey", value: environment.transakAPIKey),
            URLQueryItem(name: "walletAddress", value: request.walletAddress),
            
            // Transaction details
            URLQueryItem(name: "cryptoCurrencyCode", value: request.cryptoCurrency),
            URLQueryItem(name: "fiatCurrency", value: request.fiatCurrency),
            URLQueryItem(name: "cryptoAmount", value: request.cryptoAmount),
            URLQueryItem(name: "network", value: request.network),
            
            // Product type
            URLQueryItem(name: "productsAvailed", value: "SELL"),  // SELL = off-ramp (crypto → fiat)
            URLQueryItem(name: "isFiatCurrency", value: "false"),  // We specify crypto amount
            
            // UI customization
            URLQueryItem(name: "themeColor", value: "D4AF37"),  // Gold color
            URLQueryItem(name: "hideMenu", value: "true"),
            URLQueryItem(name: "disableWalletAddressForm", value: "true"),  // Pre-filled
            
            // Environment
            URLQueryItem(name: "environment", value: environment.environment == .production ? "PRODUCTION" : "STAGING"),
            
            // Redirect
            URLQueryItem(name: "redirectURL", value: "\(environment.deepLinkScheme)://transak-complete")
        ]
        
        guard let url = components.url else {
            AppLogger.log("❌ Failed to build URL", category: "transak")
            throw TransakError.invalidURL
        }
        
        AppLogger.log("✅ Transak URL built successfully:", category: "transak")
        AppLogger.log("   URL: \(url.absoluteString)", category: "transak")
        
        return url
    }
    
    /// Convenience method to build withdraw URL with user's wallet address
    func buildWithdrawURL(
        cryptoAmount: String,
        cryptoCurrency: String = "USDC",
        fiatCurrency: String = "INR"
    ) throws -> URL {
        // Get user's wallet address from UserDefaults
        guard let walletAddress = UserDefaults.standard.string(forKey: "userWalletAddress") else {
            AppLogger.log("❌ User wallet address not found in UserDefaults", category: "transak")
            throw TransakError.missingWalletAddress
        }
        
        let request = WithdrawRequest(
            cryptoAmount: cryptoAmount,
            cryptoCurrency: cryptoCurrency,
            fiatCurrency: fiatCurrency,
            walletAddress: walletAddress
        )
        
        return try buildWithdrawURL(request: request)
    }
    
    /// Parse redirect URL to check transaction status
    func parseRedirectURL(_ url: URL) -> TransactionStatus {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return .unknown
        }
        
        // Transak redirect parameters:
        // - transak_status: COMPLETED, FAILED, CANCELLED
        // - transak_order_id: Order ID
        
        let status = queryItems.first(where: { $0.name == "transak_status" })?.value ?? ""
        let orderId = queryItems.first(where: { $0.name == "transak_order_id" })?.value
        
        AppLogger.log("📥 Transak redirect received:", category: "transak")
        AppLogger.log("   Status: \(status)", category: "transak")
        AppLogger.log("   Order ID: \(orderId ?? "N/A")", category: "transak")
        
        switch status.uppercased() {
        case "COMPLETED":
            return .completed(orderId: orderId)
        case "FAILED":
            return .failed(orderId: orderId)
        case "CANCELLED":
            return .cancelled(orderId: orderId)
        default:
            return .unknown
        }
    }
    
    enum TransactionStatus {
        case completed(orderId: String?)
        case failed(orderId: String?)
        case cancelled(orderId: String?)
        case unknown
    }
}

