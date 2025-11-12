import SwiftUI

struct GlassCard<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.thinMaterial.opacity(themeManager.colorScheme == .dark ? 0.4 : 0.7))
                    .background(themeManager.palette.surfaceSecondary.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(themeManager.palette.border, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 30, y: 20)
            )
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

#Preview {
    GlassCard {
        Text("Glass Card")
            .foregroundStyle(.white)
    }
    .environmentObject(ThemeManager())
    .padding()
    .background(Color.black)
}
