import SwiftUI

struct LiquidGlassTabBar<Selection: Hashable>: View {
    struct TabItem<ID: Hashable>: Hashable {
        let id: ID
        let title: String
        let systemImage: String
    }

    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var selection: Selection
    let tabs: [TabItem<Selection>]
    @Namespace private var namespace

    init(selection: Binding<Selection>, tabs: [TabItem<Selection>]) {
        _selection = selection
        self.tabs = tabs
    }

    var body: some View {
        HStack(spacing: 14) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    selection = tab.id
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.systemImage)
                            .symbolEffect(.bounce, value: selection == tab.id)
                        Text(tab.title)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(selection == tab.id ? themeManager.palette.background : themeManager.palette.subdued)
                    .background {
                        if selection == tab.id {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(themeManager.palette.foreground)
                                .matchedGeometryEffect(id: "selection", in: namespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(.ultraThinMaterial.opacity(themeManager.colorScheme == .dark ? 0.6 : 0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(themeManager.palette.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 40, y: 20)
        )
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 40, style: .continuous))
    }
}

#Preview {
    struct Container: View {
        @State private var selection = 0
        var body: some View {
            LiquidGlassTabBar(
                selection: $selection,
                tabs: [
                    .init(id: 0, title: "Dashboard", systemImage: "chart.line.uptrend.xyaxis"),
                    .init(id: 1, title: "Wallet", systemImage: "wallet.pass")
                ]
            )
            .environmentObject(ThemeManager())
            .padding()
            .background(Color.black)
        }
    }
    return Container()
}
