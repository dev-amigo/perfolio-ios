import Foundation

/// Supported fiat currencies for deposits and withdrawals
/// Top 10 currencies based on global usage and supported payment methods
enum FiatCurrency: String, CaseIterable, Identifiable {
    case inr = "INR"  // Indian Rupee
    case usd = "USD"  // US Dollar
    case eur = "EUR"  // Euro
    case gbp = "GBP"  // British Pound
    case aud = "AUD"  // Australian Dollar
    case cad = "CAD"  // Canadian Dollar
    case sgd = "SGD"  // Singapore Dollar
    case aed = "AED"  // UAE Dirham
    case jpy = "JPY"  // Japanese Yen
    case chf = "CHF"  // Swiss Franc
    
    var id: String { rawValue }
    
    /// Currency symbol (₹, $, €, £, etc.)
    var symbol: String {
        switch self {
        case .inr: return "₹"
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .jpy: return "¥"
        case .chf: return "CHF"
        case .aud, .cad, .sgd: return "$"
        case .aed: return "د.إ"
        }
    }
    
    /// Flag emoji
    var flag: String {
        switch self {
        case .inr: return "🇮🇳"
        case .usd: return "🇺🇸"
        case .eur: return "🇪🇺"
        case .gbp: return "🇬🇧"
        case .aud: return "🇦🇺"
        case .cad: return "🇨🇦"
        case .sgd: return "🇸🇬"
        case .aed: return "🇦🇪"
        case .jpy: return "🇯🇵"
        case .chf: return "🇨🇭"
        }
    }
    
    /// Full currency name
    var name: String {
        switch self {
        case .inr: return "Indian Rupee"
        case .usd: return "US Dollar"
        case .eur: return "Euro"
        case .gbp: return "British Pound"
        case .aud: return "Australian Dollar"
        case .cad: return "Canadian Dollar"
        case .sgd: return "Singapore Dollar"
        case .aed: return "UAE Dirham"
        case .jpy: return "Japanese Yen"
        case .chf: return "Swiss Franc"
        }
    }
    
    /// Display label (flag + code)
    var displayName: String {
        "\(flag) \(rawValue)"
    }
    
    /// Full display label (flag + name)
    var fullDisplayName: String {
        "\(flag) \(name)"
    }
    
    // MARK: - Transaction Limits
    
    /// Minimum deposit amount in local currency
    var minDepositAmount: Decimal {
        switch self {
        case .inr: return 500        // ₹500
        case .usd: return 10         // $10
        case .eur: return 10         // €10
        case .gbp: return 8          // £8
        case .aud: return 15         // $15
        case .cad: return 13         // $13
        case .sgd: return 13         // $13
        case .aed: return 37         // د.إ37
        case .jpy: return 1500       // ¥1500
        case .chf: return 9          // CHF9
        }
    }
    
    /// Maximum deposit amount in local currency
    var maxDepositAmount: Decimal {
        switch self {
        case .inr: return 100_000    // ₹100,000
        case .usd: return 1_500      // $1,500
        case .eur: return 1_200      // €1,200
        case .gbp: return 1_000      // £1,000
        case .aud: return 2_000      // $2,000
        case .cad: return 2_000      // $2,000
        case .sgd: return 2_000      // $2,000
        case .aed: return 5_500      // د.إ5,500
        case .jpy: return 200_000    // ¥200,000
        case .chf: return 1_400      // CHF1,400
        }
    }
    
    // MARK: - Preset Values
    
    /// Quick preset amounts for this currency
    var presetValues: [String] {
        switch self {
        case .inr:
            return ["₹500", "₹1000", "₹5000", "₹10000"]
        case .usd:
            return ["$25", "$50", "$100", "$500"]
        case .eur:
            return ["€25", "€50", "€100", "€500"]
        case .gbp:
            return ["£20", "£50", "£100", "£500"]
        case .aud, .cad, .sgd:
            return ["\(symbol)25", "\(symbol)50", "\(symbol)100", "\(symbol)500"]
        case .aed:
            return ["د.إ100", "د.إ250", "د.إ500", "د.إ2000"]
        case .jpy:
            return ["¥2500", "¥5000", "¥10000", "¥50000"]
        case .chf:
            return ["CHF25", "CHF50", "CHF100", "CHF500"]
        }
    }
    
    /// Numeric preset values (for parsing)
    var numericPresets: [Decimal] {
        switch self {
        case .inr:
            return [500, 1000, 5000, 10000]
        case .usd, .eur:
            return [25, 50, 100, 500]
        case .gbp:
            return [20, 50, 100, 500]
        case .aud, .cad, .sgd:
            return [25, 50, 100, 500]
        case .aed:
            return [100, 250, 500, 2000]
        case .jpy:
            return [2500, 5000, 10000, 50000]
        case .chf:
            return [25, 50, 100, 500]
        }
    }
    
    // MARK: - Formatting Helpers
    
    /// Format amount with currency symbol
    func format(_ amount: Decimal, includeSymbol: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = includeSymbol ? symbol : ""
        formatter.minimumFractionDigits = self == .jpy ? 0 : 2
        formatter.maximumFractionDigits = self == .jpy ? 0 : 2
        
        return formatter.string(from: amount as NSNumber) ?? "\(symbol)0"
    }
    
    /// Parse string amount to Decimal (removes symbol and commas)
    func parse(_ amountString: String) -> Decimal? {
        let cleanString = amountString
            .replacingOccurrences(of: symbol, with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return Decimal(string: cleanString)
    }
    
    /// Validate amount is within limits
    func validate(_ amount: Decimal) -> Bool {
        return amount >= minDepositAmount && amount <= maxDepositAmount
    }
    
    /// Get error message for invalid amount
    func validationError(for amount: Decimal) -> String {
        if amount < minDepositAmount {
            return "Minimum amount is \(format(minDepositAmount))"
        } else if amount > maxDepositAmount {
            return "Maximum amount is \(format(maxDepositAmount))"
        } else {
            return "Invalid amount"
        }
    }
    
    // MARK: - Provider Routing
    
    /// Which payment provider to use for this currency
    var preferredProvider: PaymentProvider {
        switch self {
        case .inr:
            return .onMeta  // Best for India (UPI, lowest fees)
        default:
            return .transak // Global coverage
        }
    }
    
    enum PaymentProvider {
        case onMeta
        case transak
        
        var name: String {
            switch self {
            case .onMeta: return "OnMeta"
            case .transak: return "Transak"
            }
        }
    }
}

// MARK: - Static Helpers

extension FiatCurrency {
    /// Default currency (India first, then US)
    static var `default`: FiatCurrency {
        // Can be based on device locale in the future
        return .inr
    }
    
    /// Most popular currencies (show first in picker)
    static var popular: [FiatCurrency] {
        return [.inr, .usd, .eur, .gbp, .aud]
    }
    
    /// Get currency by code
    static func from(code: String) -> FiatCurrency? {
        return FiatCurrency.allCases.first { $0.rawValue == code.uppercased() }
    }
}

