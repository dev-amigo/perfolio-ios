import SwiftUI

/// Currency picker component for selecting fiat currency
/// Shows flag, currency code, and name in a dropdown-style sheet
struct CurrencyPicker: View {
    @Binding var selectedCurrency: FiatCurrency
    @State private var showingPicker = false
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button {
            showingPicker = true
        } label: {
            HStack(spacing: 12) {
                // Flag & Code
                Text(selectedCurrency.displayName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                
                Spacer()
                
                // Chevron indicator
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
            }
            .padding(14)
            .background(themeManager.perfolioTheme.primaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(themeManager.perfolioTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPicker) {
            CurrencyPickerSheet(selectedCurrency: $selectedCurrency, isPresented: $showingPicker)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Currency Picker Sheet

private struct CurrencyPickerSheet: View {
    @Binding var selectedCurrency: FiatCurrency
    @Binding var isPresented: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ZStack {
                themeManager.perfolioTheme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 12) {
                        // Popular currencies section
                        if !FiatCurrency.popular.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Popular")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 8)
                                
                                VStack(spacing: 1) {
                                    ForEach(FiatCurrency.popular) { currency in
                                        CurrencyRow(
                                            currency: currency,
                                            isSelected: selectedCurrency == currency
                                        ) {
                                            selectedCurrency = currency
                                            isPresented = false
                                        }
                                    }
                                }
                                .background(themeManager.perfolioTheme.secondaryBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .padding(.horizontal, 20)
                            }
                            
                            Divider()
                                .background(themeManager.perfolioTheme.border)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                        }
                        
                        // All currencies section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("All Currencies")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                                .padding(.horizontal, 20)
                            
                            VStack(spacing: 1) {
                                ForEach(FiatCurrency.allCases) { currency in
                                    CurrencyRow(
                                        currency: currency,
                                        isSelected: selectedCurrency == currency
                                    ) {
                                        selectedCurrency = currency
                                        isPresented = false
                                    }
                                }
                            }
                            .background(themeManager.perfolioTheme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                    .foregroundStyle(themeManager.perfolioTheme.tintColor)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Currency Row

private struct CurrencyRow: View {
    let currency: FiatCurrency
    let isSelected: Bool
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Flag
                Text(currency.flag)
                    .font(.system(size: 32))
                
                // Currency info
                VStack(alignment: .leading, spacing: 4) {
                    Text(currency.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                    
                    HStack(spacing: 8) {
                        Text(currency.rawValue)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                        
                        Text("•")
                            .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                        
                        Text(currency.symbol)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                }
                
                Spacer()
                
                // Checkmark for selected
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(themeManager.perfolioTheme.tintColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isSelected
                    ? themeManager.perfolioTheme.tintColor.opacity(0.1)
                    : Color.clear
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Currency Picker") {
    struct PreviewContainer: View {
        @State private var selectedCurrency: FiatCurrency = .inr
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Selected: \(selectedCurrency.fullDisplayName)")
                    .foregroundStyle(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Select Currency")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.gray)
                    
                    CurrencyPicker(selectedCurrency: $selectedCurrency)
                }
            }
            .padding(20)
            .background(Color.black.ignoresSafeArea())
            .environmentObject(ThemeManager())
        }
    }
    
    return PreviewContainer()
}

#Preview("Currency Picker Sheet") {
    struct PreviewContainer: View {
        @State private var selectedCurrency: FiatCurrency = .inr
        @State private var isPresented = true
        
        var body: some View {
            Color.black
                .sheet(isPresented: $isPresented) {
                    CurrencyPickerSheet(selectedCurrency: $selectedCurrency, isPresented: $isPresented)
                        .environmentObject(ThemeManager())
                }
        }
    }
    
    return PreviewContainer()
}

