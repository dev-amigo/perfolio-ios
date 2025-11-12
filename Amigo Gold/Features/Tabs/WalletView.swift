import SwiftUI

struct WalletView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    private let holdings: [Holding] = [
        .init(symbol: "AMG", name: "Amigo Gold Token", value: "$48,120", allocation: "68%"),
        .init(symbol: "USDC", name: "USD Coin", value: "$12,400", allocation: "18%"),
        .init(symbol: "ETH", name: "Ethereum Collateral", value: "$10,210", allocation: "14%"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summary
                ForEach(holdings) { holding in
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(holding.symbol)
                                    .font(.system(.title3, weight: .semibold, design: .rounded))
                                Text(holding.name)
                                    .font(.footnote)
                                    .foregroundStyle(themeManager.palette.subdued)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 6) {
                                Text(holding.value)
                                    .font(.system(.title3, weight: .semibold, design: .rounded))
                                Text(holding.allocation)
                                    .font(.footnote)
                                    .foregroundStyle(themeManager.palette.subdued)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(themeManager.palette.background)
    }

    private var summary: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Custodied via Privy")
                    .font(.system(.caption, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(themeManager.palette.foreground.opacity(0.1))
                    .clipShape(Capsule())

                Text("$70,730")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                Text("Total holdings across wallets")
                    .font(.callout)
                    .foregroundStyle(themeManager.palette.subdued)

                HStack(spacing: 12) {
                    AGPrimaryButton(title: "Deposit", isLoading: false) {}
                        .environmentObject(themeManager)
                    Button("Withdraw") {}
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}

private struct Holding: Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let value: String
    let allocation: String
}

#Preview {
    WalletView()
        .environmentObject(ThemeManager())
}
