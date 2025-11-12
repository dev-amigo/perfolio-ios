import SwiftUI

struct ThemePalette {
    let background: Color
    let surface: Color
    let surfaceSecondary: Color
    let foreground: Color
    let subdued: Color
    let accent: Color
    let border: Color

    static let dark = ThemePalette(
        background: .black,
        surface: Color(red: 0.08, green: 0.08, blue: 0.08),
        surfaceSecondary: Color(red: 0.12, green: 0.12, blue: 0.12),
        foreground: .white,
        subdued: Color.white.opacity(0.7),
        accent: Color.white,
        border: Color.white.opacity(0.12)
    )

    static let light = ThemePalette(
        background: .white,
        surface: Color(red: 0.95, green: 0.95, blue: 0.95),
        surfaceSecondary: Color(red: 0.90, green: 0.90, blue: 0.90),
        foreground: .black,
        subdued: Color.black.opacity(0.7),
        accent: .black,
        border: Color.black.opacity(0.08)
    )
}

struct ThemeTypography {
    let title: Font = .system(.title, weight: .semibold, design: .rounded)
    let subtitle: Font = .system(.body, weight: .regular, design: .rounded)
    let button: Font = .system(.headline, weight: .semibold, design: .rounded)
    let badge: Font = .system(.caption, weight: .medium, design: .rounded)
}
