import Foundation

/// Represents a fiat currency with its metadata and conversion rate
struct Currency: Identifiable, Codable, Equatable, Hashable {
    let id: String              // Currency code: "INR", "USD", "EUR"
    let name: String            // Full name: "Indian Rupee", "US Dollar"
    let symbol: String          // Currency symbol: "₹", "$", "€"
    let flag: String            // Flag emoji: "🇮🇳", "🇺🇸", "🇪🇺"
    var conversionRate: Decimal // Rate to USD (1 USD = X currency)
    let region: CurrencyRegion  // Geographic region
    let isPopular: Bool         // Show in popular section
    
    enum CurrencyRegion: String, Codable {
        case asia = "Asia"
        case europe = "Europe"
        case americas = "Americas"
        case middleEast = "Middle East"
        case africa = "Africa"
        case oceania = "Oceania"
    }
    
    /// Default popular currencies (top 20 most used globally)
    /// Conversion rates are INITIAL VALUES and get updated via CoinGecko API
    /// Rates are approximate as of Nov 2025 (1 USD = X currency)
    static let popularCurrencies: [Currency] = [
        Currency(id: "INR", name: "Indian Rupee", symbol: "₹", flag: "🇮🇳", conversionRate: 83.50, region: .asia, isPopular: true),
        Currency(id: "USD", name: "US Dollar", symbol: "$", flag: "🇺🇸", conversionRate: 1.0, region: .americas, isPopular: true),
        Currency(id: "EUR", name: "Euro", symbol: "€", flag: "🇪🇺", conversionRate: 0.92, region: .europe, isPopular: true),
        Currency(id: "GBP", name: "British Pound", symbol: "£", flag: "🇬🇧", conversionRate: 0.79, region: .europe, isPopular: true),
        Currency(id: "JPY", name: "Japanese Yen", symbol: "¥", flag: "🇯🇵", conversionRate: 149.50, region: .asia, isPopular: true),
        Currency(id: "AUD", name: "Australian Dollar", symbol: "A$", flag: "🇦🇺", conversionRate: 1.53, region: .oceania, isPopular: true),
        Currency(id: "CAD", name: "Canadian Dollar", symbol: "C$", flag: "🇨🇦", conversionRate: 1.35, region: .americas, isPopular: true),
        Currency(id: "CHF", name: "Swiss Franc", symbol: "CHF", flag: "🇨🇭", conversionRate: 0.88, region: .europe, isPopular: true),
        Currency(id: "CNY", name: "Chinese Yuan", symbol: "¥", flag: "🇨🇳", conversionRate: 7.24, region: .asia, isPopular: true),
        Currency(id: "SGD", name: "Singapore Dollar", symbol: "S$", flag: "🇸🇬", conversionRate: 1.34, region: .asia, isPopular: true),
        Currency(id: "AED", name: "UAE Dirham", symbol: "AED", flag: "🇦🇪", conversionRate: 3.67, region: .middleEast, isPopular: true),
        Currency(id: "SAR", name: "Saudi Riyal", symbol: "SAR", flag: "🇸🇦", conversionRate: 3.75, region: .middleEast, isPopular: true),
        Currency(id: "KRW", name: "South Korean Won", symbol: "₩", flag: "🇰🇷", conversionRate: 1310.0, region: .asia, isPopular: true),
        Currency(id: "MYR", name: "Malaysian Ringgit", symbol: "RM", flag: "🇲🇾", conversionRate: 4.47, region: .asia, isPopular: true),
        Currency(id: "THB", name: "Thai Baht", symbol: "฿", flag: "🇹🇭", conversionRate: 35.50, region: .asia, isPopular: true),
        Currency(id: "IDR", name: "Indonesian Rupiah", symbol: "Rp", flag: "🇮🇩", conversionRate: 15650.0, region: .asia, isPopular: true),
        Currency(id: "PHP", name: "Philippine Peso", symbol: "₱", flag: "🇵🇭", conversionRate: 55.80, region: .asia, isPopular: true),
        Currency(id: "VND", name: "Vietnamese Dong", symbol: "₫", flag: "🇻🇳", conversionRate: 24500.0, region: .asia, isPopular: true),
        Currency(id: "BRL", name: "Brazilian Real", symbol: "R$", flag: "🇧🇷", conversionRate: 4.98, region: .americas, isPopular: true),
        Currency(id: "MXN", name: "Mexican Peso", symbol: "Mex$", flag: "🇲🇽", conversionRate: 17.10, region: .americas, isPopular: true),
    ]
    
    /// Additional currencies (less common but still supported)
    static let additionalCurrencies: [Currency] = [
        Currency(id: "NZD", name: "New Zealand Dollar", symbol: "NZ$", flag: "🇳🇿", conversionRate: 1.66, region: .oceania, isPopular: false),
        Currency(id: "HKD", name: "Hong Kong Dollar", symbol: "HK$", flag: "🇭🇰", conversionRate: 7.82, region: .asia, isPopular: false),
        Currency(id: "SEK", name: "Swedish Krona", symbol: "kr", flag: "🇸🇪", conversionRate: 10.50, region: .europe, isPopular: false),
        Currency(id: "NOK", name: "Norwegian Krone", symbol: "kr", flag: "🇳🇴", conversionRate: 10.80, region: .europe, isPopular: false),
        Currency(id: "DKK", name: "Danish Krone", symbol: "kr", flag: "🇩🇰", conversionRate: 6.88, region: .europe, isPopular: false),
        Currency(id: "PLN", name: "Polish Złoty", symbol: "zł", flag: "🇵🇱", conversionRate: 4.02, region: .europe, isPopular: false),
        Currency(id: "CZK", name: "Czech Koruna", symbol: "Kč", flag: "🇨🇿", conversionRate: 22.80, region: .europe, isPopular: false),
        Currency(id: "HUF", name: "Hungarian Forint", symbol: "Ft", flag: "🇭🇺", conversionRate: 356.0, region: .europe, isPopular: false),
        Currency(id: "ILS", name: "Israeli Shekel", symbol: "₪", flag: "🇮🇱", conversionRate: 3.68, region: .middleEast, isPopular: false),
        Currency(id: "TRY", name: "Turkish Lira", symbol: "₺", flag: "🇹🇷", conversionRate: 32.50, region: .middleEast, isPopular: false),
        Currency(id: "ZAR", name: "South African Rand", symbol: "R", flag: "🇿🇦", conversionRate: 18.70, region: .africa, isPopular: false),
        Currency(id: "RUB", name: "Russian Ruble", symbol: "₽", flag: "🇷🇺", conversionRate: 92.50, region: .europe, isPopular: false),
        Currency(id: "ARS", name: "Argentine Peso", symbol: "AR$", flag: "🇦🇷", conversionRate: 350.0, region: .americas, isPopular: false),
        Currency(id: "CLP", name: "Chilean Peso", symbol: "CL$", flag: "🇨🇱", conversionRate: 890.0, region: .americas, isPopular: false),
        Currency(id: "COP", name: "Colombian Peso", symbol: "COL$", flag: "🇨🇴", conversionRate: 3950.0, region: .americas, isPopular: false),
    ]
    
    /// All supported currencies
    static var allCurrencies: [Currency] {
        return popularCurrencies + additionalCurrencies
    }
    
    /// Get currency by code
    static func getCurrency(code: String) -> Currency? {
        return allCurrencies.first { $0.id == code }
    }
    
    /// Format amount in this currency
    func format(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = id
        formatter.currencySymbol = symbol
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(symbol)\(amount)"
    }
    
    /// Convert USD amount to this currency
    func convertFromUSD(_ usdAmount: Decimal) -> Decimal {
        return usdAmount * conversionRate
    }
    
    /// Convert this currency amount to USD
    func convertToUSD(_ amount: Decimal) -> Decimal {
        return amount / conversionRate
    }
}

// MARK: - Decimal Extension for Currency Formatting

extension Decimal {
    /// Format this amount in the specified currency
    func formatted(in currencyCode: String) -> String {
        guard let currency = Currency.getCurrency(code: currencyCode) else {
            return "\(currencyCode) \(self)"
        }
        return currency.format(self)
    }
    
    /// Convert this USD amount to the specified currency
    func convertedTo(_ currencyCode: String) -> Decimal {
        guard let currency = Currency.getCurrency(code: currencyCode) else {
            return self
        }
        return currency.convertFromUSD(self)
    }
}

