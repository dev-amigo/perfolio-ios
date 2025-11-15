import SwiftUI

/// Modal view showing 30-day borrow APY history
struct APYChartView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var historicalData: [APYDataPoint] = []
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            themeManager.perfolioTheme.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Borrow APY History")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                        
                        Text("Last 30 days")
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.perfolioTheme.tintColor))
                        .scaleEffect(1.5)
                    Spacer()
                } else {
                    // Current APY Card
                    currentAPYCard
                    
                    // Chart
                    chartView
                    
                    // Info
                    infoText
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            loadHistoricalData()
        }
    }
    
    // MARK: - Current APY Card
    
    private var currentAPYCard: some View {
        PerFolioCard {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Borrow APY")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(themeManager.perfolioTheme.textSecondary)
                    
                    if let latestAPY = historicalData.last?.apy {
                        Text(formatPercentage(latestAPY))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.tintColor)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12))
                        Text(trendText)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(trendColor)
                }
                
                Spacer()
                
                Image(systemName: "percent.ar")
                    .font(.system(size: 64))
                    .foregroundStyle(themeManager.perfolioTheme.buttonBackground.opacity(0.3))
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Chart View
    
    private var chartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("APY Trend")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(themeManager.perfolioTheme.textPrimary)
                .padding(.horizontal, 20)
            
            // Simple line visualization
            GeometryReader { geometry in
                ZStack(alignment: .bottomLeading) {
                    // Grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<5) { i in
                            if i > 0 {
                                Divider()
                                    .background(themeManager.perfolioTheme.border.opacity(0.3))
                            }
                            Spacer()
                        }
                    }
                    
                    // Line path
                    Path { path in
                        guard !historicalData.isEmpty else { return }
                        
                        let maxAPY = historicalData.map { $0.apy }.max() ?? 6.0
                        let minAPY = historicalData.map { $0.apy }.min() ?? 4.0
                        let range = max(maxAPY - minAPY, 1.0)
                        
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let xStep = width / CGFloat(historicalData.count - 1)
                        
                        for (index, dataPoint) in historicalData.enumerated() {
                            let x = CGFloat(index) * xStep
                            let normalizedYDecimal = (dataPoint.apy - minAPY) / range
                            let normalizedY = CGFloat(NSDecimalNumber(decimal: normalizedYDecimal).doubleValue)
                            let y = height - (normalizedY * height)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(themeManager.perfolioTheme.tintColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    
                    // Gradient fill
                    Path { path in
                        guard !historicalData.isEmpty else { return }
                        
                        let maxAPY = historicalData.map { $0.apy }.max() ?? 6.0
                        let minAPY = historicalData.map { $0.apy }.min() ?? 4.0
                        let range = max(maxAPY - minAPY, 1.0)
                        
                        let width = geometry.size.width
                        let height = geometry.size.height
                        let xStep = width / CGFloat(historicalData.count - 1)
                        
                        for (index, dataPoint) in historicalData.enumerated() {
                            let x = CGFloat(index) * xStep
                            let normalizedYDecimal = (dataPoint.apy - minAPY) / range
                            let normalizedY = CGFloat(NSDecimalNumber(decimal: normalizedYDecimal).doubleValue)
                            let y = height - (normalizedY * height)
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: 0, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.perfolioTheme.tintColor.opacity(0.3),
                                themeManager.perfolioTheme.tintColor.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .frame(height: 200)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Info Text
    
    private var infoText: some View {
        PerFolioInfoBanner("APY varies based on market conditions and protocol utilization. Historical data is for reference only.")
            .padding(.horizontal, 20)
    }
    
    // MARK: - Helpers
    
    private func loadHistoricalData() {
        Task {
            // Simulate API delay
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            let currentAPY = BorrowAPYService.mockAPY()
            let service = BorrowAPYService()
            historicalData = service.generateHistoricalAPY(currentAPY: currentAPY)
            isLoading = false
        }
    }
    
    private var trendText: String {
        guard historicalData.count >= 2 else { return "No change" }
        
        let latest = historicalData.last!.apy
        let previous = historicalData[historicalData.count - 2].apy
        
        if latest > previous {
            return "↗ Trending up"
        } else if latest < previous {
            return "↘ Trending down"
        } else {
            return "→ Stable"
        }
    }
    
    private var trendColor: Color {
        guard historicalData.count >= 2 else { return themeManager.perfolioTheme.textSecondary }
        
        let latest = historicalData.last!.apy
        let previous = historicalData[historicalData.count - 2].apy
        
        if latest > previous {
            return .green
        } else if latest < previous {
            return .red
        } else {
            return themeManager.perfolioTheme.textSecondary
        }
    }
    
    private func formatPercentage(_ value: Decimal) -> String {
        return String(format: "%.2f%%", NSDecimalNumber(decimal: value).doubleValue)
    }
}

// MARK: - Preview

#Preview {
    APYChartView()
        .environmentObject(ThemeManager())
}

