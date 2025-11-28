import SwiftUI

/// Theme variant options
enum ThemeVariant: String, CaseIterable, Identifiable {
    case dark = "Dark"
    case extraDark = "Extra Dark"
    case metalDark = "Metal Dark"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .dark:
            return "Balanced dark theme with subtle contrast"
        case .extraDark:
            return "Pure black for maximum contrast and OLED screens"
        case .metalDark:
            return "Dark metallic theme with cool tones"
        }
    }
    
    var icon: String {
        switch self {
        case .dark:
            return "moon.fill"
        case .extraDark:
            return "moon.stars.fill"
        case .metalDark:
            return "cube.fill"
        }
    }
}

/// PerFolio Gold Theme Tokens
struct PerFolioTheme {
    let primaryBackground: Color
    let secondaryBackground: Color
    let tintColor: Color
    let buttonBackground: Color
    let goldenBoxGradient: LinearGradient
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let border: Color
    let success: Color
    let warning: Color
    let danger: Color
    
    // MARK: - Dark Theme (Default)
    static let dark = PerFolioTheme(
        primaryBackground: Color(hex: "1D1D1D"),      // #1D1D1D
        secondaryBackground: Color(hex: "242424"),    // #242424
        tintColor: Color(hex: "D0B070"),
        buttonBackground: Color(hex: "9D7618"),
        goldenBoxGradient: LinearGradient(
            colors: [Color(hex: "D0B070"), Color(hex: "B88A3C")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.8),
        textTertiary: Color.white.opacity(0.6),
        border: Color.white.opacity(0.1),
        success: Color(hex: "4ADE80"),
        warning: Color(hex: "FBBF24"),
        danger: Color(hex: "EF4444")
    )
    
    // MARK: - Extra Dark Theme (Pure Black)
    static let extraDark = PerFolioTheme(
        primaryBackground: Color(hex: "000000"),      // Pure Black
        secondaryBackground: Color(hex: "0A0A0A"),    // Almost Black
        tintColor: Color(hex: "D0B070"),
        buttonBackground: Color(hex: "9D7618"),
        goldenBoxGradient: LinearGradient(
            colors: [
                Color(hex: "3D3020"),  // Dark brown-gold
                Color(hex: "2A2416"),  // Darker brown-gold
                Color(hex: "1F1A10")   // Very dark brown (almost black)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        textPrimary: .white,
        textSecondary: Color.white.opacity(0.85),
        textTertiary: Color.white.opacity(0.65),
        border: Color.white.opacity(0.08),
        success: Color(hex: "4ADE80"),
        warning: Color(hex: "FBBF24"),
        danger: Color(hex: "EF4444")
    )
    
    // MARK: - Metal Dark Theme (Cool Tones)
    static let metalDark = PerFolioTheme(
        primaryBackground: Color(hex: "121315"),      // RGB(18, 19, 21) - Deep metallic dark
        secondaryBackground: Color(hex: "16181A"),    // RGB(22, 24, 26) - Surface layer
        tintColor: Color(hex: "D0B070"),              // Goldish tint (always)
        buttonBackground: Color(hex: "2F343A"),       // RGB(47, 52, 58) - Button surface
        goldenBoxGradient: LinearGradient(
            colors: [Color(hex: "D0B070"), Color(hex: "B88A3C")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        ),
        textPrimary: Color(hex: "E8EAED"),
        textSecondary: Color(hex: "BDC1C6"),
        textTertiary: Color(hex: "9AA0A6"),
        border: Color(hex: "5F6368").opacity(0.3),
        success: Color(hex: "4ADE80"),
        warning: Color(hex: "FBBF24"),
        danger: Color(hex: "EF4444")
    )
    
    // MARK: - Variant Factory
    static func theme(for variant: ThemeVariant) -> PerFolioTheme {
        switch variant {
        case .dark:
            return .dark
        case .extraDark:
            return .extraDark
        case .metalDark:
            return .metalDark
        }
    }
    
    // Legacy: Keep gold alias for backward compatibility
    static let gold = PerFolioTheme.dark
}

// MARK: - Color Extension for Hex Support

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

