import Foundation

/// Custom notification names for app-wide events
extension Notification.Name {
    /// Posted when user changes their preferred currency in Settings
    /// UserInfo contains: ["newCurrency": String]
    static let currencyDidChange = Notification.Name("currencyDidChange")
    
    /// Posted when theme variant changes
    static let themeDidChange = Notification.Name("themeDidChange")
    
    /// Posted when user completes initial onboarding
    static let onboardingDidComplete = Notification.Name("onboardingDidComplete")
}

