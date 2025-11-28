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
    private let cacheExpiryInterval: TimeInterval = 1800 // 30 minutes (increased from 5 for rate limiting)
    
    // Rate limiting & backoff
    private var lastRequestTime: Date?
    private var consecutiveFailures: Int = 0
    private let minRequestInterval: TimeInterval = 1.0 // 1 second between requests
    private let maxBackoffDelay: TimeInterval = 300 // 5 minutes max backoff
    
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
        // Check if we should wait due to rate limiting
        if let backoffDelay = getBackoffDelay() {
            AppLogger.log("⏸️ Rate limited: waiting \(Int(backoffDelay))s before retry", category: "currency")
            throw CurrencyError.rateLimited(retryAfter: backoffDelay)
        }
        
        // Rate limiting: enforce minimum interval between requests
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < minRequestInterval {
                let waitTime = minRequestInterval - timeSinceLastRequest
                AppLogger.log("⏱️ Rate limiting: waiting \(waitTime)s", category: "currency")
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Build currency list for API call
        let currencyIds = supportedCurrencies.map { $0.id.lowercased() }.joined(separator: ",")
        
        // Get API key from bundle (optional)
        let apiKey = Bundle.main.object(forInfoDictionaryKey: "AGCoinGeckoAPIKey") as? String
        
        // CoinGecko API endpoint for REAL-TIME exchange rates
        // Using USDC as base (it's pegged 1:1 with USD)
        var urlString = "\(baseURL)/simple/price?ids=usd-coin&vs_currencies=\(currencyIds)"
        
        // Add API key if available (Pro/Free tier)
        if let apiKey = apiKey, !apiKey.isEmpty {
            urlString += "&x_cg_pro_api_key=\(apiKey)"
            AppLogger.log("🔑 Using CoinGecko API key", category: "currency")
        } else {
            AppLogger.log("⚠️ No API key - using free tier (50 calls/min limit)", category: "currency")
        }
        
        guard let url = URL(string: urlString) else {
            throw CurrencyError.invalidURL
        }
        
        // Record request time for rate limiting
        lastRequestTime = Date()
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CurrencyError.networkError
            }
            
            // Handle rate limiting (429)
            if httpResponse.statusCode == 429 {
                consecutiveFailures += 1
                let retryAfter = getBackoffDelay() ?? 60
                AppLogger.log("🚫 Rate limited (429): backing off for \(Int(retryAfter))s (failure #\(consecutiveFailures))", category: "currency")
                throw CurrencyError.rateLimited(retryAfter: retryAfter)
            }
            
            guard httpResponse.statusCode == 200 else {
                consecutiveFailures += 1
                AppLogger.log("❌ HTTP error: \(httpResponse.statusCode)", category: "currency")
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
            
            // Reset failure count on success
            consecutiveFailures = 0
            
            AppLogger.log("✅ Exchange rates updated: \(usdcRates.count) currencies", category: "currency")
            
        } catch {
            AppLogger.log("❌ Failed to fetch exchange rates: \(error.localizedDescription)", category: "currency")
            
            // Don't increment failures if it's already a rate limit error
            if case CurrencyError.rateLimited = error {
                // Already handled above
            } else {
                consecutiveFailures += 1
            }
            
            throw CurrencyError.fetchFailed(error)
        }
    }
    
    /// Calculate exponential backoff delay based on consecutive failures
    private func getBackoffDelay() -> TimeInterval? {
        guard consecutiveFailures > 0 else { return nil }
        
        // Exponential backoff: 2^n seconds, capped at maxBackoffDelay
        let delay = min(pow(2.0, Double(consecutiveFailures)), maxBackoffDelay)
        return delay
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
        // Try to refresh if cache expired
        if shouldRefreshRates() {
            AppLogger.log("🔄 Cache expired, attempting to fetch fresh rates...", category: "currency")
            do {
                try await fetchLiveExchangeRates()
            } catch {
                AppLogger.log("⚠️ Failed to refresh rates, using cached/default values: \(error.localizedDescription)", category: "currency")
                // Continue with cached rates - don't throw
            }
        }
        
        // Get currency objects from LIVE supportedCurrencies array (updated from API)
        // NOT from static Currency.allCurrencies (which has hardcoded rates)
        guard let fromCurrency = supportedCurrencies.first(where: { $0.id == from }),
              let toCurrency = supportedCurrencies.first(where: { $0.id == to }) else {
            AppLogger.log("⚠️ Unsupported currency pair: \(from) → \(to), returning 1.0", category: "currency")
            return 1.0 // Default fallback
        }
        
        // Cross-rate calculation: from → USD → to
        // Rate = (1 USD in TO currency) / (1 USD in FROM currency)
        let rate = toCurrency.conversionRate / fromCurrency.conversionRate
        
        let dataSource = shouldRefreshRates() ? "CACHED" : "LIVE"
        AppLogger.log("""
            💱 Conversion Rate (\(dataSource)):
            - From: \(from) (1 USD = \(fromCurrency.conversionRate))
            - To: \(to) (1 USD = \(toCurrency.conversionRate))
            - Rate: 1 \(from) = \(rate) \(to)
            - Last Updated: \(lastUpdateDate?.description ?? "Using defaults")
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
    case rateLimited(retryAfter: TimeInterval)
    
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
        case .rateLimited(let retryAfter):
            return "Rate limited. Please wait \(Int(retryAfter)) seconds before retrying."
        }
    }
}

