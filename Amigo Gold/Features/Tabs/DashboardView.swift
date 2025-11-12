import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var themeManager: ThemeManager

    private let highlights: [Highlight] = [
        .init(title: "Gold Vault", value: "48.12 oz", trend: "+2.4%"),
        .init(title: "Token Value", value: "$2,432", trend: "+1.3%"),
        .init(title: "Daily PnL", value: "+$318", trend: "+0.9%"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header
                highlightGrid
                ActivityTimelineView()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(themeManager.palette.background)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Welcome back")
                .font(.system(.title3, weight: .medium, design: .rounded))
                .foregroundStyle(themeManager.palette.subdued)
            Text("Your Gold Strategy")
                .font(.system(.largeTitle, weight: .bold, design: .rounded))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var highlightGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
            ForEach(highlights) { highlight in
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(highlight.title.uppercased())
                            .font(.caption)
                            .foregroundStyle(themeManager.palette.subdued)
                        Text(highlight.value)
                            .font(.system(.title2, weight: .semibold, design: .rounded))
                        Text(highlight.trend)
                            .font(.footnote)
                            .foregroundStyle(highlight.trend.hasPrefix("+") ? .green : .red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct Highlight: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let trend: String
}

private struct ActivityTimelineView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    private let activities: [Activity] = [
        .init(title: "Bought 2.3 oz Gold Token", subtitle: "Settled via Privy wallet"),
        .init(title: "Earned staking rewards", subtitle: "+$42 USDC credited"),
        .init(title: "Deposited collateral", subtitle: "0.4 ETH secured"),
    ]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 18) {
                Text("Activity")
                    .font(.system(.title3, weight: .semibold, design: .rounded))
                ForEach(activities) { activity in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity.title)
                            .font(.system(.body, weight: .semibold, design: .rounded))
                        Text(activity.subtitle)
                            .font(.footnote)
                            .foregroundStyle(themeManager.palette.subdued)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
                    .overlay(
                        Divider()
                            .background(themeManager.palette.border)
                            .opacity(activity.id == activities.last?.id ? 0 : 1),
                        alignment: .bottom
                    )
                }
            }
        }
    }
}

private struct Activity: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

#Preview {
    DashboardView()
        .environmentObject(ThemeManager())
}
