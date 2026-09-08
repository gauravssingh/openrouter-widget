import SwiftUI

/// The Today / This week / This month spend rows.
public struct UsageSummaryView: View {
    private struct Row: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }

    private let rows: [Row]
    private let footnote: String?

    /// - Parameters:
    ///   - today: today's spend (from key usage, includes the current day).
    ///   - week: local Monday–Sunday week spend from activity.
    ///   - month: local calendar-month spend from activity.
    ///   - footnote: honest source/semantics caption shown under the rows.
    public init(today: Double, week: Double, month: Double, footnote: String?) {
        self.rows = [
            Row(label: "Today", value: today),
            Row(label: "This week", value: week),
            Row(label: "This month", value: month)
        ]
        self.footnote = footnote
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(rows) { row in
                HStack(alignment: .firstTextBaseline) {
                    Text(row.label)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(CurrencyFormatter.string(from: row.value))
                        .monospacedDigit()
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
                .font(.callout)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.label) spend \(CurrencyFormatter.string(from: row.value))")
            }

            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
