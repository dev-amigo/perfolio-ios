import SwiftUI

/// Reusable card component with PerFolio gold theme styling
struct PerFolioCard<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    private let content: Content
    private let style: CardStyle
    private let padding: CGFloat
    
    enum CardStyle {
        case secondary      // Standard card with secondary background
        case gradient       // Golden gradient card
        case primary        // Primary background (darker)
    }
    
    init(
        style: CardStyle = .secondary,
        padding: CGFloat = 20,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(backgroundView)
            .overlay(overlayView)
            .shadow(color: shadowColor, radius: shadowRadius, y: shadowY)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .secondary:
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(themeManager.perfolioTheme.secondaryBackground)
        case .gradient:
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(themeManager.perfolioTheme.goldenBoxGradient)
        case .primary:
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(themeManager.perfolioTheme.primaryBackground)
        }
    }
    
    @ViewBuilder
    private var overlayView: some View {
        if style != .gradient {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(themeManager.perfolioTheme.border, lineWidth: 1)
        }
    }
    
    private var shadowColor: Color {
        .clear  // No shadow
    }
    
    private var shadowRadius: CGFloat {
        0  // No shadow
    }
    
    private var shadowY: CGFloat {
        0  // No shadow
    }
}

#Preview {
    VStack(spacing: 20) {
        PerFolioCard(style: .secondary) {
            Text("Secondary Card")
        }
        
        PerFolioCard(style: .gradient) {
            Text("Gradient Card")
        }
        
        PerFolioCard(style: .primary) {
            Text("Primary Card")
        }
    }
    .padding()
    .background(Color(hex: "1D1D1D"))
    .environmentObject(ThemeManager())
}

