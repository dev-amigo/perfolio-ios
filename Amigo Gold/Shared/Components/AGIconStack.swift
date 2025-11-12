import SwiftUI

struct AGIconStack: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 42, weight: .regular, design: .rounded))
            .frame(width: 96, height: 96)
            .foregroundStyle(themeManager.palette.foreground)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(themeManager.palette.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(themeManager.palette.border, lineWidth: 1)
            )
    }
}

#Preview {
    AGIconStack(systemName: "lock.shield")
        .environmentObject(ThemeManager())
        .padding()
        .background(Color.black)
}
