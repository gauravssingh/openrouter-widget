import Charts
import SwiftUI

/// Minimal native Swift Charts bar chart answering "how much have I been
/// spending recently?" over the last 30 days. Hover reveals the day's value.
public struct SpendChartView: View {
    private let series: [SpendDay]
    private let total: Double

    @State private var hoveredDay: SpendDay?

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
                // The trailing value shows the hovered day while the pointer
                // rests on the chart, otherwise the 30-day total.
                Text(hoveredValue ?? CurrencyFormatter.string(from: total))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(hoveredDay == nil ? .secondary : .primary)
                    .animation(.default, value: hoveredDay)
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

            if let hoveredDay {
                Text(Self.dayLabel(for: hoveredDay.date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .transition(.opacity)
            }
        }
    }

    private var hoveredValue: String? {
        guard let hoveredDay else { return nil }
        return CurrencyFormatter.string(from: hoveredDay.amount)
    }

    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Image(systemName: "chart.bar")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                Text("No spending activity")
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
                .foregroundStyle(
                    Color.accentColor.opacity(hoveredDay?.id == day.id ? 1.0 : 0.85)
                )
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        // Anchor the scale at zero so very small daily amounts render as
        // short-but-visible bars instead of an inflated auto domain.
        .chartYScale(domain: 0...Double.infinity)
        .frame(height: 72)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let plotFrame = geometry[proxy.plotAreaFrame]
                            guard location.x >= plotFrame.minX,
                                  location.x <= plotFrame.maxX else {
                                hoveredDay = nil
                                return
                            }
                            if let date: Date = proxy.value(
                                atX: location.x - plotFrame.minX,
                                as: Date.self
                            ) {
                                hoveredDay = series.first {
                                    Calendar.current.isDate($0.date, inSameDayAs: date)
                                }
                            } else {
                                hoveredDay = nil
                            }
                        case .ended:
                            hoveredDay = nil
                        }
                    }
            }
        }
        .accessibilityLabel(
            "30-day spend bar chart, total \(CurrencyFormatter.string(from: total)), highest day \(CurrencyFormatter.string(from: series.map(\.amount).max() ?? 0))"
        )
    }

    private static func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
