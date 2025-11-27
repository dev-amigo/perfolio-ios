import Foundation

/// Dashboard display type
enum DashboardType: String, CaseIterable {
    case regular = "regular"
    case simplified = "simplified"
    
    var displayName: String {
        switch self {
        case .regular: return "Regular"
        case .simplified: return "Simple"
        }
    }
}

/// Centralized user preferences management using UserDefaults
struct UserPreferences {
    
    // MARK: - Keys
    
    private enum Keys {
        static let defaultCurrency = "defaultCurrency"
        static let currencySymbol = "currencySymbol"
        static let notificationsEnabled = "notificationsEnabled"
        static let lastCurrencyUpdate = "lastCurrencyUpdate"
        static let onboardingCompletedPrefix = "onboardingCompleted_"
        static let hapticEnabled = "hapticEnabled"
        static let soundEnabled = "soundEnabled"
        static let privyUserEmail = "privyUserEmail"
        static let themeVariant = "themeVariant"
        static let hasVisitedLoansTab = "hasVisitedLoansTab"
        static let preferredDashboard = "preferredDashboard"
        static let dashboardBaselineValue = "dashboardBaselineValue"
        static let dashboardBaselineDate = "dashboardBaselineDate"
    }
    
    // MARK: - Currency Preferences
    
    /// User's default currency code (e.g., "INR", "USD")
    static var defaultCurrency: String {
        get {
            UserDefaults.standard.string(forKey: Keys.defaultCurrency) ?? "INR"
        }
        set {
            // Get old currency BEFORE setting new one
            let oldCurrency = UserDefaults.standard.string(forKey: Keys.defaultCurrency) ?? "INR"
            
            UserDefaults.standard.set(newValue, forKey: Keys.defaultCurrency)
            
            // Update symbol when currency changes
            if let currency = Currency.getCurrency(code: newValue) {
                currencySymbol = currency.symbol
            }
            
            lastCurrencyUpdate = Date()
            
            // Notify observers that currency has changed (send BOTH old and new)
            NotificationCenter.default.post(
                name: .currencyDidChange,
                object: nil,
                userInfo: [
                    "oldCurrency": oldCurrency,
                    "newCurrency": newValue
                ]
            )
            
            AppLogger.log("💱 Currency changed: \(oldCurrency) → \(newValue), notifying observers", category: "preferences")
        }
    }
    
    /// User's currency symbol (e.g., "₹", "$")
    static var currencySymbol: String {
        get {
            UserDefaults.standard.string(forKey: Keys.currencySymbol) ?? "₹"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.currencySymbol)
        }
    }
    
    /// Last time currency rates were updated
    static var lastCurrencyUpdate: Date? {
        get {
            UserDefaults.standard.object(forKey: Keys.lastCurrencyUpdate) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.lastCurrencyUpdate)
        }
    }
    
    // MARK: - Notification Preferences
    
    /// Whether user has enabled notifications
    static var notificationsEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.notificationsEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.notificationsEnabled)
        }
    }
    
    // MARK: - Onboarding
    
    /// Check if user has completed initial onboarding for their email
    static func hasCompletedOnboarding(for email: String) -> Bool {
        let key = Keys.onboardingCompletedPrefix + email.lowercased()
        return UserDefaults.standard.bool(forKey: key)
    }
    
    /// Mark initial onboarding as completed for user's email
    static func setOnboardingCompleted(for email: String) {
        let key = Keys.onboardingCompletedPrefix + email.lowercased()
        UserDefaults.standard.set(true, forKey: key)
        AppLogger.log("✅ Onboarding completed for: \(email)", category: "preferences")
    }
    
    /// Reset onboarding status (for testing)
    static func resetOnboarding(for email: String) {
        let key = Keys.onboardingCompletedPrefix + email.lowercased()
        UserDefaults.standard.removeObject(forKey: key)
        AppLogger.log("🔄 Onboarding reset for: \(email)", category: "preferences")
    }
    
    // MARK: - Haptic & Sound (Existing)
    
    static var hapticEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: Keys.hapticEnabled) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.hapticEnabled)
        }
    }
    
    static var soundEnabled: Bool {
        get {
            UserDefaults.standard.object(forKey: Keys.soundEnabled) as? Bool ?? true
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.soundEnabled)
        }
    }
    
    // MARK: - User Info (Existing)
    
    static var privyUserEmail: String? {
        get {
            UserDefaults.standard.string(forKey: Keys.privyUserEmail)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.privyUserEmail)
        }
    }
    
    // MARK: - Theme (Existing)
    
    static var themeVariant: String {
        get {
            UserDefaults.standard.string(forKey: Keys.themeVariant) ?? "extraDark"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.themeVariant)
        }
    }
    
    // MARK: - Navigation (Existing)
    
    static var hasVisitedLoansTab: Bool {
        get {
            UserDefaults.standard.bool(forKey: Keys.hasVisitedLoansTab)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.hasVisitedLoansTab)
        }
    }
    
    // MARK: - Dashboard Preferences
    
    /// User's preferred dashboard type
    static var preferredDashboard: DashboardType {
        get {
            let raw = UserDefaults.standard.string(forKey: Keys.preferredDashboard) ?? DashboardType.regular.rawValue
            return DashboardType(rawValue: raw) ?? .regular
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.preferredDashboard)
        }
    }
    
    /// Baseline value for profit/loss calculation
    static var dashboardBaselineValue: Decimal? {
        get {
            if let string = UserDefaults.standard.string(forKey: Keys.dashboardBaselineValue) {
                return Decimal(string: string)
            }
            return nil
        }
        set {
            if let value = newValue {
                UserDefaults.standard.set(value.description, forKey: Keys.dashboardBaselineValue)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.dashboardBaselineValue)
            }
        }
    }
    
    /// Date when baseline was set
    static var dashboardBaselineDate: Date? {
        get {
            UserDefaults.standard.object(forKey: Keys.dashboardBaselineDate) as? Date
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.dashboardBaselineDate)
        }
    }
    
    // MARK: - Utilities
    
    /// Clear all user preferences (for logout)
    static func clearAll() {
        let domain = Bundle.main.bundleIdentifier!
        UserDefaults.standard.removePersistentDomain(forName: domain)
        UserDefaults.standard.synchronize()
        AppLogger.log("🗑️ All preferences cleared", category: "preferences")
    }
    
    /// Reset only currency-related preferences
    static func resetCurrencyPreferences() {
        UserDefaults.standard.removeObject(forKey: Keys.defaultCurrency)
        UserDefaults.standard.removeObject(forKey: Keys.currencySymbol)
        UserDefaults.standard.removeObject(forKey: Keys.lastCurrencyUpdate)
        AppLogger.log("🔄 Currency preferences reset", category: "preferences")
    }
    
    /// Get current currency object
    static var currentCurrency: Currency? {
        return Currency.getCurrency(code: defaultCurrency)
    }
    
    /// Print all current preferences (for debugging)
    static func printCurrentPreferences() {
        AppLogger.log("""
        📊 Current Preferences:
        - Currency: \(defaultCurrency) (\(currencySymbol))
        - Notifications: \(notificationsEnabled)
        - Haptic: \(hapticEnabled)
        - Sound: \(soundEnabled)
        - Theme: \(themeVariant)
        - Last Update: \(lastCurrencyUpdate?.description ?? "Never")
        """, category: "preferences")
    }
}

