import SwiftUI

@MainActor
final class ThemeManager: ObservableObject {
    @Published private(set) var palette: ThemePalette
    @Published private(set) var typography = ThemeTypography()
    @Published private(set) var colorScheme: ColorScheme

    init(colorScheme: ColorScheme = .dark) {
        self.colorScheme = colorScheme
        self.palette = colorScheme == .dark ? .dark : .light
    }

    func toggleScheme() {
        updateColorScheme(colorScheme == .dark ? .light : .dark)
    }

    func updateColorScheme(_ newScheme: ColorScheme) {
        guard newScheme != colorScheme else { return }
        colorScheme = newScheme
        palette = newScheme == .dark ? .dark : .light
    }
}
