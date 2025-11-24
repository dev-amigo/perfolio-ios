import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    @Published private(set) var palette: ThemePalette
    @Published private(set) var perfolioTheme: PerFolioTheme
    @Published private(set) var typography = ThemeTypography()
    @Published private(set) var colorScheme: ColorScheme
    @Published var currentThemeVariant: ThemeVariant {
        didSet {
            saveThemeVariant(currentThemeVariant)
            applyThemeVariant(currentThemeVariant)
        }
    }
    
    private let themeVariantKey = "selectedThemeVariant"

    init(colorScheme: ColorScheme = .dark) {
        self.colorScheme = colorScheme
        self.palette = colorScheme == .dark ? .dark : .light
        
        // Load saved theme variant or default to Extra Dark
        let savedVariantString = UserDefaults.standard.string(forKey: themeVariantKey) ?? ThemeVariant.extraDark.rawValue
        let loadedVariant = ThemeVariant(rawValue: savedVariantString) ?? .extraDark
        self.currentThemeVariant = loadedVariant
        self.perfolioTheme = PerFolioTheme.theme(for: loadedVariant)
        
        AppLogger.log("🎨 Theme Manager initialized with variant: \(loadedVariant.rawValue)", category: "theme")
    }

    func toggleScheme() {
        updateColorScheme(colorScheme == .dark ? .light : .dark)
    }

    func updateColorScheme(_ newScheme: ColorScheme) {
        guard newScheme != colorScheme else { return }
        colorScheme = newScheme
        palette = newScheme == .dark ? .dark : .light
    }
    
    func setThemeVariant(_ variant: ThemeVariant) {
        AppLogger.log("🎨 Setting theme variant to: \(variant.rawValue)", category: "theme")
        currentThemeVariant = variant
    }
    
    private func applyThemeVariant(_ variant: ThemeVariant) {
        perfolioTheme = PerFolioTheme.theme(for: variant)
        AppLogger.log("✅ Theme variant applied: \(variant.rawValue)", category: "theme")
    }
    
    private func saveThemeVariant(_ variant: ThemeVariant) {
        UserDefaults.standard.set(variant.rawValue, forKey: themeVariantKey)
        AppLogger.log("💾 Theme variant saved: \(variant.rawValue)", category: "theme")
    }
}
