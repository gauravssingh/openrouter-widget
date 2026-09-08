import Charts
import SwiftUI

/// Minimal native Swift Charts bar chart answering "when did I spend money
/// during the last 30 days?". Hover reveals the day's date and spend amount
/// in a compact native overlay without altering popover dimensions.
public struct SpendChartView: View {
    private let series: [SpendDay]
    private let total: Double

    @State private var hoveredDay: SpendDay?
    @State private var hoverLocationX: CGFloat?

    public init(
        series: [SpendDay],
        total: Double,
        initialHoveredDay: SpendDay? = nil,
        initialHoverLocationX: CGFloat? = nil
    ) {
        self.series = series
        self.total = total
        self._hoveredDay = State(initialValue: initialHoveredDay)
        self._hoverLocationX = State(initialValue: initialHoverLocationX)
    }

    private var maxAmount: Double {
        series.map(\.amount).max() ?? 0
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if series.allSatisfy({ $0.amount == 0 }) {
                emptyState
            } else {
                chartContainer
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Spend — Last 30 Days")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer()
            Text(CurrencyFormatter.string(from: total))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Spend over the last 30 days: \(CurrencyFormatter.string(from: total))"
        )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack {
            Spacer()
            Text("No spending activity")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(height: LayoutTokens.chartHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No spending activity over the last 30 days")
    }

    // MARK: - Chart container

    private var chartContainer: some View {
        chart
            .frame(height: LayoutTokens.chartHeight)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                handleHover(phase: phase, proxy: proxy, geometry: geometry)
                            }

                        if let hoveredDay, let hoverLocationX {
                            tooltipView(day: hoveredDay, locationX: hoverLocationX, width: geometry.size.width)
                        }
                    }
                }
            }
            .accessibilityLabel(chartAccessibilityLabel)
    }

    private var chart: some View {
        Chart {
            // Subtle baseline across the bottom of the chart
            RuleMark(y: .value("Baseline", 0))
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(Color.secondary.opacity(0.18))

            ForEach(series) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Spend", visualAmount(for: day.amount))
                )
                .cornerRadius(1.5)
                .foregroundStyle(barColor(for: day))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
    }

    // MARK: - Bar styling & visual height

    /// Ensures very small legitimate values (e.g. $0.005) are visible as a
    /// subtle ~1.5pt pip on the baseline without distorting larger bars.
    /// Zero-spend days remain strictly at 0 (flat on the baseline).
    private func visualAmount(for amount: Double) -> Double {
        guard amount > 0 else { return 0 }
        let threshold = maxAmount * 0.025
        return max(amount, threshold)
    }

    private func barColor(for day: SpendDay) -> Color {
        guard let hoveredDay else {
            return Color.accentColor.opacity(0.85)
        }
        if Calendar.current.isDate(day.date, inSameDayAs: hoveredDay.date) {
            return Color.accentColor
        } else {
            return Color.accentColor.opacity(0.4)
        }
    }

    // MARK: - Hover handling & tooltip

    private func handleHover(phase: HoverPhase, proxy: ChartProxy, geometry: GeometryProxy) {
        switch phase {
        case .active(let location):
            guard let plotFrameAnchor = proxy.plotFrame else {
                hoveredDay = nil
                hoverLocationX = nil
                return
            }
            let plotFrame = geometry[plotFrameAnchor]
            guard location.x >= plotFrame.minX, location.x <= plotFrame.maxX else {
                hoveredDay = nil
                hoverLocationX = nil
                return
            }
            if let date: Date = proxy.value(atX: location.x - plotFrame.minX, as: Date.self) {
                hoveredDay = series.first {
                    Calendar.current.isDate($0.date, inSameDayAs: date)
                }
                hoverLocationX = location.x
            } else {
                hoveredDay = nil
                hoverLocationX = nil
            }
        case .ended:
            hoveredDay = nil
            hoverLocationX = nil
        }
    }

    private func tooltipView(day: SpendDay, locationX: CGFloat, width: CGFloat) -> some View {
        let tooltipWidth: CGFloat = 84
        let halfWidth = tooltipWidth / 2
        let clampedX = min(max(locationX, halfWidth + 4), width - halfWidth - 4)

        return HStack(spacing: 4) {
            Text(DateHelpers.chartDayLabel(for: day.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(CurrencyFormatter.string(from: day.amount))
                .font(.caption2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3.5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1.5)
        .position(x: clampedX, y: 14)
        .transition(.opacity)
        .allowsHitTesting(false)
    }

    private var chartAccessibilityLabel: String {
        if let hoveredDay {
            return "\(DateHelpers.mediumDayLabel(for: hoveredDay.date)) spend: \(CurrencyFormatter.string(from: hoveredDay.amount))"
        }
        let highest = series.map(\.amount).max() ?? 0
        return "30-day spend bar chart, total \(CurrencyFormatter.string(from: total)), highest day \(CurrencyFormatter.string(from: highest))"
    }
}
