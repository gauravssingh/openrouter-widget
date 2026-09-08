import Charts
import SwiftUI

/// Minimal native Swift Charts bar chart answering "how much have I been
/// spending recently?" over the last 30 days.
public struct SpendChartView: View {
    private let series: [SpendDay]
    private let total: Double

    public init(series: [SpendDay], total: Double) {
        self.series = series
        self.total = total
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Spend — Last 30 Days")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(CurrencyFormatter.string(from: total))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(
                "Spend last 30 days \(CurrencyFormatter.string(from: total))"
            )

            if series.allSatisfy({ $0.amount == 0 }) {
                emptyState
            } else {
                chart
            }
        }
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Text("No spend in the last 30 days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(height: 72)
        .accessibilityElement(children: .combine)
    }

    private var chart: some View {
        Chart {
            ForEach(series) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Spend", day.amount)
                )
                .cornerRadius(2)
                .foregroundStyle(Color.accentColor.opacity(0.85))
                .annotation(position: .top) {
                    // Detail tooltip: show the value only for the peak day
                    // to keep the chart quiet but informative.
                    if day.amount == series.map(\.amount).max(), day.amount > 0 {
                        Text(CurrencyFormatter.string(from: day.amount))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .offset(y: -4)
                    }
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 72)
        .accessibilityLabel("30-day spend bar chart, highest day \(CurrencyFormatter.string(from: series.map(\.amount).max() ?? 0))")
    }
}
