import SwiftUI

struct SearchSidebarView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var isCompact: Bool
    @State private var query: String = ""
    private let suggestions = [
        "Real-time gold price",
        "Tokenized bullion vaults",
        "Wallet security status",
        "Privacy settings",
        "Terms of service",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            if !isCompact {
                TextField("Search vaults, wallets, markets", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(suggestions.filter { query.isEmpty ? true : $0.localizedCaseInsensitiveContains(query) }, id: \.self) { suggestion in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion)
                                .font(.callout)
                            Text("Tap to pre-fill query")
                                .font(.caption2)
                                .foregroundStyle(themeManager.palette.subdued)
                        }
                        .padding(.vertical, 4)
                        .onTapGesture {
                            query = suggestion
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial.opacity(themeManager.colorScheme == .dark ? 0.6 : 0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(themeManager.palette.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.3), radius: 30, y: 20)
        )
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Search")
                    .font(.headline)
                Text("Across dashboard, wallets, markets")
                    .font(.caption)
                    .foregroundStyle(themeManager.palette.subdued)
                    .opacity(isCompact ? 0 : 1)
            }
            Spacer()
            Button {
                withAnimation {
                    isCompact.toggle()
                }
            } label: {
                Image(systemName: isCompact ? "arrow.left" : "arrow.right")
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    SearchSidebarView(isCompact: .constant(false))
        .environmentObject(ThemeManager())
        .padding()
        .background(Color.black)
}
