import Foundation
import Combine

/// Service for managing currency conversions and live exchange rates
@MainActor
final class CurrencyService: ObservableObject {
    
    static let shared = CurrencyService()
    
    @Published var supportedCurrencies: [Currency] = Currency.allCurrencies
    @Published var isLoading: Bool = false
    @Published var lastUpdateDate: Date?
    
    private let baseURL = "https://api.coingecko.com/api/v3"
    private var conversionRatesCache: [String: Decimal] = [:]
    private let cacheExpiryInterval: TimeInterval = 300 // 5 minutes
    
    private init() {
        lastUpdateDate = UserPreferences.lastCurrencyUpdate
    }
    
    // MARK: - Currency List Management
    
    /// Get all supported currencies
    func fetchSupportedCurrencies() async throws -> [Currency] {
        // Return cached list - we have a predefined list
        // In production, you might want to fetch this from API
        return supportedCurrencies
    }
    
    /// Get currency with LIVE conversion rate
    /// This is the preferred method over Currency.getCurrency() which has static rates
    func getCurrency(code: String) -> Currency? {
        return supportedCurrencies.first { $0.id.uppercased() == code.uppercased() }
    }
    
    /// Get popular currencies only
    func getPopularCurrencies() -> [Currency] {
        return supportedCurrencies.filter { $0.isPopular }
    }
    
    /// Get currencies by region
    func getCurrencies(in region: Currency.CurrencyRegion) -> [Currency] {
        return supportedCurrencies.filter { $0.region == region }
    }
    
    /// Search currencies by name or code
    func searchCurrencies(query: String) -> [Currency] {
        let lowercasedQuery = query.lowercased()
        return supportedCurrencies.filter {
            $0.name.lowercased().contains(lowercasedQuery) ||
            $0.id.lowercased().contains(lowercasedQuery)
        }
    }
    
    // MARK: - Exchange Rates
    
    /// Fetch live exchange rates from CoinGecko API
    /// 
    /// **DATA SOURCE:** CoinGecko Free API (No authentication required)
    /// **ENDPOINT:** api.coingecko.com/api/v3/simple/price
    /// **RATE LIMIT:** 50 calls/minute (generous for free tier)
    /// **CACHE:** 5 minutes to minimize API calls
    /// 
    /// **HOW IT WORKS:**
    /// 1. Queries CoinGecko for USDC price in all supported currencies
    /// 2. Since USDC = $1 USD (stablecoin), rates = USD exchange rates
    /// 3. Updates all Currency objects with live rates
    /// 4. Stores cache timestamp
    /// 
    /// **EXAMPLE RESPONSE:**
    /// ```json
    /// {
    ///   "usd-coin": {
    ///     "inr": 83.50,
    ///     "usd": 1.0,
    ///     "eur": 0.92,
    ///     ...
    ///   }
    /// }
    /// ```
    func fetchLiveExchangeRates() async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Build currency list for API call
        let currencyIds = supportedCurrencies.map { $0.id.lowercased() }.joined(separator: ",")
        
        // CoinGecko API endpoint for REAL-TIME exchange rates
        // Using USDC as base (it's pegged 1:1 with USD)
        let urlString = "\(baseURL)/simple/price?ids=usd-coin&vs_currencies=\(currencyIds)"
        
        guard let url = URL(string: urlString) else {
            throw CurrencyError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw CurrencyError.networkError
            }
            
            // Parse response
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard let usdcRates = json?["usd-coin"] as? [String: Double] else {
                throw CurrencyError.invalidResponse
            }
            
            // Update currency conversion rates
            for i in 0..<supportedCurrencies.count {
                let currencyCode = supportedCurrencies[i].id.lowercased()
                if let rate = usdcRates[currencyCode] {
                    supportedCurrencies[i].conversionRate = Decimal(rate)
                    conversionRatesCache[supportedCurrencies[i].id] = Decimal(rate)
                }
            }
            
            lastUpdateDate = Date()
            UserPreferences.lastCurrencyUpdate = lastUpdateDate
            
            AppLogger.log("✅ Exchange rates updated: \(usdcRates.count) currencies", category: "currency")
            
        } catch {
            AppLogger.log("❌ Failed to fetch exchange rates: \(error.localizedDescription)", category: "currency")
            throw CurrencyError.fetchFailed(error)
        }
    }
    
    /// Get conversion rate between two currencies
    /// 
    /// **CALCULATION METHOD:**
    /// Uses cross-rate calculation via USD as base currency
    /// 
    /// **EXAMPLE:** Converting EUR to INR
    /// - 1 USD = 0.92 EUR (from CoinGecko)
    /// - 1 USD = 83.50 INR (from CoinGecko)
    /// - Therefore: 1 EUR = 83.50 / 0.92 = 90.76 INR
    /// 
    /// **FORMULA:**
    /// Rate = (1 USD in TO currency) / (1 USD in FROM currency)
    /// 
    /// - Parameters:
    ///   - from: Source currency code (e.g., "USD")
    ///   - to: Target currency code (e.g., "INR")
    /// - Returns: Conversion rate (e.g., 83.50 for USD→INR)
    func getConversionRate(from: String, to: String) async throws -> Decimal {
        // CRITICAL: Auto-refresh rates if cache expired (5 minutes)
        // This ensures we ALWAYS have live rates from CoinGecko
        if shouldRefreshRates() {
            AppLogger.log("🔄 Cache expired, fetching fresh rates from CoinGecko...", category: "currency")
            try await fetchLiveExchangeRates()
        }
        
        // Get currency objects from LIVE supportedCurrencies array (updated from API)
        // NOT from static Currency.allCurrencies (which has hardcoded rates)
        guard let fromCurrency = supportedCurrencies.first(where: { $0.id == from }),
              let toCurrency = supportedCurrencies.first(where: { $0.id == to }) else {
            throw CurrencyError.unsupportedCurrency
        }
        
        // Cross-rate calculation: from → USD → to
        // Rate = (1 USD in TO currency) / (1 USD in FROM currency)
        let rate = toCurrency.conversionRate / fromCurrency.conversionRate
        
        AppLogger.log("""
            💱 Conversion Rate Calculated (LIVE):
            - From: \(from) (1 USD = \(fromCurrency.conversionRate) - LIVE)
            - To: \(to) (1 USD = \(toCurrency.conversionRate) - LIVE)
            - Rate: 1 \(from) = \(rate) \(to)
            - Last Updated: \(lastUpdateDate?.description ?? "Never")
            """, category: "currency")
        
        return rate
    }
    
    /// Convert amount from one currency to another
    func convert(amount: Decimal, from: String, to: String) async throws -> Decimal {
        let rate = try await getConversionRate(from: from, to: to)
        return amount * rate
    }
    
    // MARK: - Crypto Prices
    
    /// Get real-time crypto prices in user's preferred currency
    /// tokens: ["usd-coin", "pax-gold"]
    func getCryptoPrices(tokens: [String], currency: String) async throws -> [String: Decimal] {
        isLoading = true
        defer { isLoading = false }
        
        let tokenIds = tokens.joined(separator: ",")
        let currencyCode = currency.lowercased()
        
        let urlString = "\(baseURL)/simple/price?ids=\(tokenIds)&vs_currencies=\(currencyCode)"
        
        guard let url = URL(string: urlString) else {
            throw CurrencyError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw CurrencyError.networkError
            }
            
            let json = try JSONSerialization.jsonObject(with: data) as? [String: [String: Double]]
            
            var prices: [String: Decimal] = [:]
            for token in tokens {
                if let tokenPrices = json?[token],
                   let price = tokenPrices[currencyCode] {
                    prices[token] = Decimal(price)
                }
            }
            
            AppLogger.log("✅ Crypto prices fetched: \(prices.count) tokens", category: "currency")
            return prices
            
        } catch {
            AppLogger.log("❌ Failed to fetch crypto prices: \(error.localizedDescription)", category: "currency")
            throw CurrencyError.fetchFailed(error)
        }
    }
    
    /// Get USDC price in user's currency
    func getUSDCPrice(in currency: String) async throws -> Decimal {
        let prices = try await getCryptoPrices(tokens: ["usd-coin"], currency: currency)
        return prices["usd-coin"] ?? 1.0
    }
    
    /// Get PAXG price in user's currency
    func getPAXGPrice(in currency: String) async throws -> Decimal {
        let prices = try await getCryptoPrices(tokens: ["pax-gold"], currency: currency)
        return prices["pax-gold"] ?? 0.0
    }
    
    // MARK: - Cache Management
    
    /// Check if rates need to be refreshed
    private func shouldRefreshRates() -> Bool {
        guard let lastUpdate = lastUpdateDate else {
            return true
        }
        
        let timeSinceUpdate = Date().timeIntervalSince(lastUpdate)
        return timeSinceUpdate > cacheExpiryInterval
    }
    
    /// Force refresh rates
    func forceRefresh() async throws {
        try await fetchLiveExchangeRates()
    }
    
    /// Clear cached rates
    func clearCache() {
        conversionRatesCache.removeAll()
        lastUpdateDate = nil
        UserPreferences.lastCurrencyUpdate = nil
        AppLogger.log("🗑️ Currency cache cleared", category: "currency")
    }
    
    // MARK: - User Currency Helpers
    
    /// Get user's current currency
    func getUserCurrency() -> Currency {
        return Currency.getCurrency(code: UserPreferences.defaultCurrency) ?? Currency.popularCurrencies[0]
    }
    
    /// Update user's default currency
    func setUserCurrency(_ currencyCode: String) {
        UserPreferences.defaultCurrency = currencyCode
        AppLogger.log("✅ User currency updated to: \(currencyCode)", category: "currency")
    }
    
    /// Convert USD amount to user's currency
    func convertToUserCurrency(_ usdAmount: Decimal) -> Decimal {
        let userCurrency = getUserCurrency()
        return userCurrency.convertFromUSD(usdAmount)
    }
    
    /// Format amount in user's currency
    func formatInUserCurrency(_ usdAmount: Decimal) -> String {
        let userCurrency = getUserCurrency()
        let convertedAmount = userCurrency.convertFromUSD(usdAmount)
        return userCurrency.format(convertedAmount)
    }
}

// MARK: - Currency Errors

enum CurrencyError: LocalizedError {
    case invalidURL
    case networkError
    case invalidResponse
    case unsupportedCurrency
    case fetchFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .networkError:
            return "Network error occurred"
        case .invalidResponse:
            return "Invalid response from server"
        case .unsupportedCurrency:
            return "Currency not supported"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        }
    }
}

