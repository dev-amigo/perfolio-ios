import SwiftUI

struct AGSurfaceCard<Content: View>: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity)
            .background(themeManager.palette.surfaceSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(themeManager.palette.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

#Preview {
    AGSurfaceCard {
        Text("Reusable surface")
            .foregroundStyle(.white)
    }
    .environmentObject(ThemeManager())
    .padding()
    .background(Color.black)
}
