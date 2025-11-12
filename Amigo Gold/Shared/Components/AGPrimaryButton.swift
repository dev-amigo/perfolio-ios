import SwiftUI

struct AGPrimaryButton: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let title: LocalizedStringKey
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: trigger) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(themeManager.palette.background)
                }
                Text(title)
                    .font(themeManager.typography.button)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(themeManager.palette.background)
            .background(themeManager.palette.foreground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
        .opacity(isLoading ? 0.8 : 1)
    }

    private func trigger() {
        guard !isLoading else { return }
        action()
    }
}

#Preview {
    AGPrimaryButton(title: "Preview Button", isLoading: false, action: {})
        .environmentObject(ThemeManager())
        .padding()
        .background(Color.black)
}
