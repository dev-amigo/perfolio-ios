import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let didFinish: () -> Void
    @State private var isVisible = false

    var body: some View {
        ZStack {
            themeManager.palette.background
                .ignoresSafeArea()

            Text(L10n.text(.splashTitle))
                .font(themeManager.typography.title)
                .foregroundStyle(themeManager.palette.foreground)
                .tracking(4)
                .opacity(isVisible ? 1 : 0)
                .scaleEffect(isVisible ? 1 : 0.9)
                .animation(.easeInOut(duration: AppConstants.splashFadeDuration), value: isVisible)
        }
        .task {
            guard !isVisible else { return }
            isVisible = true
            try? await Task.sleep(for: .seconds(AppConstants.splashDisplayTime))
            await MainActor.run {
                didFinish()
            }
        }
    }
}

#Preview {
    SplashView { }
        .environmentObject(ThemeManager())
}
