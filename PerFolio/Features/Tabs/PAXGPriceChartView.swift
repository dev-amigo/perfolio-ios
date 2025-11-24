import SwiftUI
import Charts

struct PAXGPriceChartView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    let data: [PricePoint]
    
    var body: some View {
        Chart(data) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Price", NSDecimalNumber(decimal: point.price).doubleValue)
            )
            .foregroundStyle(themeManager.perfolioTheme.tintColor)
            .lineStyle(StrokeStyle(lineWidth: 2))
            
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Price", NSDecimalNumber(decimal: point.price).doubleValue)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        themeManager.perfolioTheme.tintColor.opacity(0.3),
                        themeManager.perfolioTheme.tintColor.opacity(0.05),
                        .clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 15)) { value in
                if let date = value.as(Date.self) {
                    AxisValueLabel {
                        Text(formatDate(date))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                    }
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(themeManager.perfolioTheme.border)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let price = value.as(Double.self) {
                        Text(formatPrice(price))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(themeManager.perfolioTheme.textTertiary)
                    }
                }
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 2]))
                    .foregroundStyle(themeManager.perfolioTheme.border)
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(themeManager.perfolioTheme.secondaryBackground.opacity(0.3))
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func formatPrice(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "$0"
    }
}

#Preview {
    let mockData = (0...89).map { i in
        PricePoint(
            date: Calendar.current.date(byAdding: .day, value: i - 89, to: Date())!,
            price: Decimal(2400 + Double.random(in: -500...500))
        )
    }
    
    return PAXGPriceChartView(data: mockData)
        .environmentObject(ThemeManager())
        .frame(height: 200)
        .padding()
        .background(Color.black)
}

