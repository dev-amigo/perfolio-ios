import SwiftUI

struct LiquidGlassTabBar<Selection: Hashable>: View {
    struct TabItem<ID: Hashable>: Identifiable {
        let id: ID
        let title: String
        let systemImage: String
        let content: AnyView

        init<T: View>(id: ID, title: String, systemImage: String, @ViewBuilder content: () -> T) {
            self.id = id
            self.title = title
            self.systemImage = systemImage
            self.content = AnyView(content())
        }

        var identifier: ID { id }
    }

    @Binding private var selection: Selection
    private let tabs: [TabItem<Selection>]

    init(selection: Binding<Selection>, tabs: [TabItem<Selection>]) {
        self._selection = selection
        self.tabs = tabs
    }

    var body: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: $selection) {
                ForEach(tabs) { tab in
                    Tab(tab.title, systemImage: tab.systemImage, value: tab.id) {
                        tab.content
                    }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
//            .tabBarMinimizeBehavior(.onScrollDown)
        } else {
            TabView(selection: $selection) {
                ForEach(tabs) { tab in
                    tab.content
                        .tag(tab.id)
                        .tabItem {
                            Label(tab.title, systemImage: tab.systemImage)
                        }
                }
            }
            .tabViewStyle(.sidebarAdaptable)
            .tabBarMinimizeBehavior(.onScrollDown)
        }
    }
}

#Preview {
    struct Container: View {
        enum DemoTab: Hashable {
            case first, second
        }

        @State private var selection: DemoTab = .first

        var body: some View {
            LiquidGlassTabBar(
                selection: $selection,
                tabs: [
                    .init(id: .first, title: "Dashboard", systemImage: "chart.line.uptrend.xyaxis") {
                        Color.black.overlay(Text("Dashboard").foregroundStyle(.white))
                    },
                    .init(id: .second, title: "Wallet", systemImage: "wallet.pass") {
                        Color.gray.overlay(Text("Wallet"))
                    }
                ]
            )
        }
    }

    return Container()
}
