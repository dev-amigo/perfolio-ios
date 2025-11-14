import Foundation
import SafariServices
import Combine

/// OnMeta on-ramp service for INR → USDT conversion
/// Based on the web app's OnMeta adapter implementation
final class OnMetaService: ObservableObject {
    
    // MARK: - Types
    
    struct OnMetaConfig {
        let apiKey: String
        let baseURL: String
        let chainId: Int
        let environment: String
        
        static var current: OnMetaConfig {
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "AGOnMetaAPIKey") as? String ?? ""
            let baseURL = Bundle.main.object(forInfoDictionaryKey: "AGOnMetaBaseURL") as? String ?? "https://platform.onmeta.in"
            let chainId = 1 // Ethereum Mainnet
            let env = Bundle.main.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String ?? "development"
            
            return OnMetaConfig(
                apiKey: apiKey,
                baseURL: baseURL,
                chainId: chainId,
                environment: env
            )
        }
    }
    
    struct Quote {
        let inrAmount: Decimal
        let usdtAmount: Decimal
        let exchangeRate: Decimal
        let providerFee: Decimal
        let estimatedTime: String
        
        var displayInrAmount: String {
            "₹\(formatCurrency(inrAmount))"
        }
        
        var displayUsdtAmount: String {
            "~\(formatDecimal(usdtAmount)) USDT"
        }
        
        var displayFee: String {
            "₹\(formatCurrency(providerFee))"
        }
        
        var displayRate: String {
            "1 USDT = ₹\(formatDecimal(exchangeRate))"
        }
        
        private func formatCurrency(_ value: Decimal) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 0
            formatter.maximumFractionDigits = 2
            return formatter.string(from: value as NSNumber) ?? "0"
        }
        
        private func formatDecimal(_ value: Decimal) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 6
            return formatter.string(from: value as NSNumber) ?? "0"
        }
    }
    
    enum OnMetaError: LocalizedError {
        case invalidAmount
        case missingAPIKey
        case missingWalletAddress
        case widgetLoadFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidAmount:
                return "Please enter a valid amount between ₹500 and ₹100,000"
            case .missingAPIKey:
                return "OnMeta API key not configured"
            case .missingWalletAddress:
                return "Wallet address not available"
            case .widgetLoadFailed:
                return "Failed to load OnMeta widget"
            }
        }
    }
    
    // MARK: - Properties
    
    private let config: OnMetaConfig
    @Published var isLoading = false
    @Published var currentQuote: Quote?
    @Published var error: OnMetaError?
    
    // Limits (from OnMeta documentation)
    let minInrAmount: Decimal = 500
    let maxInrAmount: Decimal = 100_000
    
    // MARK: - Initialization
    
    init(config: OnMetaConfig = .current) {
        self.config = config
        AppLogger.log("💳 OnMetaService initialized", category: "onmeta")
        AppLogger.log("   Base URL: \(config.baseURL)", category: "onmeta")
        AppLogger.log("   Chain ID: \(config.chainId)", category: "onmeta")
        AppLogger.log("   Environment: \(config.environment)", category: "onmeta")
    }
    
    // MARK: - Public Methods
    
    /// Validate INR amount
    func validateAmount(_ amount: String) -> Bool {
        guard let decimal = Decimal(string: amount.replacingOccurrences(of: "₹", with: "").replacingOccurrences(of: ",", with: "")) else {
            return false
        }
        return decimal >= minInrAmount && decimal <= maxInrAmount
    }
    
    /// Get quote for INR → USDT conversion
    /// Note: This is a simplified quote calculation. In production, you'd fetch this from OnMeta API.
    func getQuote(inrAmount: String) async throws -> Quote {
        AppLogger.log("📊 Getting quote for INR amount: \(inrAmount)", category: "onmeta")
        
        guard let amount = Decimal(string: inrAmount.replacingOccurrences(of: "₹", with: "").replacingOccurrences(of: ",", with: "")) else {
            throw OnMetaError.invalidAmount
        }
        
        guard amount >= minInrAmount && amount <= maxInrAmount else {
            throw OnMetaError.invalidAmount
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Simulate API delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        // Simplified quote calculation
        // In production, call OnMeta quote API: GET /api/v1/quote
        let exchangeRate: Decimal = 92.5 // 1 USDT ≈ ₹92.5 (example rate)
        let feePercentage: Decimal = 0.02 // 2% fee
        let providerFee = amount * feePercentage
        let netAmount = amount - providerFee
        let usdtAmount = netAmount / exchangeRate
        
        let quote = Quote(
            inrAmount: amount,
            usdtAmount: usdtAmount,
            exchangeRate: exchangeRate,
            providerFee: providerFee,
            estimatedTime: "5-15 minutes"
        )
        
        currentQuote = quote
        AppLogger.log("✅ Quote generated: \(quote.displayInrAmount) → \(quote.displayUsdtAmount)", category: "onmeta")
        
        return quote
    }
    
    /// Build OnMeta widget URL for payment flow
    func buildWidgetURL(walletAddress: String, inrAmount: String) throws -> URL {
        guard !config.apiKey.isEmpty else {
            throw OnMetaError.missingAPIKey
        }
        
        guard !walletAddress.isEmpty else {
            throw OnMetaError.missingWalletAddress
        }
        
        guard let amount = Decimal(string: inrAmount.replacingOccurrences(of: "₹", with: "").replacingOccurrences(of: ",", with: "")) else {
            throw OnMetaError.invalidAmount
        }
        
        // Build URL with query parameters (matching web adapter)
        var components = URLComponents(string: config.baseURL)
        components?.queryItems = [
            URLQueryItem(name: "apiKey", value: config.apiKey),
            URLQueryItem(name: "walletAddress", value: walletAddress),
            URLQueryItem(name: "fiatAmount", value: "\(amount)"),
            URLQueryItem(name: "fiatType", value: "INR"),
            URLQueryItem(name: "tokenSymbol", value: "USDT"),
            URLQueryItem(name: "chainId", value: "\(config.chainId)"),
            URLQueryItem(name: "offRamp", value: "disabled")
        ]
        
        guard let url = components?.url else {
            throw OnMetaError.widgetLoadFailed
        }
        
        AppLogger.log("🔗 OnMeta widget URL: \(url.absoluteString)", category: "onmeta")
        return url
    }
    
    /// Clear current quote and error
    func reset() {
        currentQuote = nil
        error = nil
    }
}

