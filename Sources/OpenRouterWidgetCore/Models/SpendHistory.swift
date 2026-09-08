import Foundation

/// One day bucket of the 30-day spend series.
public struct SpendDay: Equatable, Identifiable, Sendable {
    /// Local start of the day.
    public let date: Date
    public let amount: Double

    public var id: Date { date }
}

/// Spend attributed to one model over the analyzed window.
public struct ModelSpend: Equatable, Identifiable, Sendable {
    /// Full model slug (`anthropic/claude-sonnet-4.5`).
    public let model: String
    /// Compact display name (`Claude Sonnet 4.5`).
    public let displayName: String
    public let amount: Double

    public var id: String { model }
}

/// Locally-computed spend breakdown derived from activity rows.
public struct SpendBreakdown: Equatable, Sendable {
    public let today: Double
    /// Monday–Sunday, local calendar week containing `now`.
    public let week: Double
    /// Local calendar month containing `now`.
    public let month: Double
    /// Rolling local 30-day window ending today.
    public let last30Days: Double
    /// 30 daily buckets, oldest first, zero-filled.
    public let dailySeries: [SpendDay]
    /// Top models in the 30-day window, sorted by spend descending,
    /// with a trailing "Other" row when there are more than `topModelCount`.
    public let topModels: [ModelSpend]
}

/// Computes local-timezone spend periods from OpenRouter activity rows.
///
/// Activity rows are aggregates per UTC day; the calculator treats each row's
/// `YYYY-MM-DD` label as its calendar-day identity and compares it against
/// day labels generated in the user's local timezone. "Week" is defined as
/// Monday–Sunday (the same convention OpenRouter uses for its own weekly
/// key-usage figures). See `docs/api.md` for the full rationale.
public enum SpendCalculator {
    public static let topModelCount = 4

    public static func breakdown(
        items: [ActivityItem],
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> SpendBreakdown {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2 // Monday

        let entries: [(dayLabel: String, cost: Double, model: String)] = items
            .compactMap { item in
                let label = String(item.date.prefix(10))
                guard label.count == 10, DateHelpers.parseUTCDay(label) != nil else {
                    return nil
                }
                return (label, item.totalCost, item.model)
            }

        let todayLabel = DateHelpers.dayLabel(for: now, timeZone: timeZone)
        let today = sum(entries, in: Set([todayLabel]))

        let weekLabels = dayLabels(
            from: startOfWeek(containing: now, calendar: calendar),
            count: 7,
            calendar: calendar
        )
        let week = sum(entries, in: weekLabels)

        let monthLabels = dayLabels(
            from: startOfMonth(containing: now, calendar: calendar),
            count: calendar.range(of: .day, in: .month, for: now)?.count ?? 30,
            calendar: calendar
        )
        let month = sum(entries, in: monthLabels)

        let windowStart = calendar.date(
            byAdding: .day,
            value: -29,
            to: calendar.startOfDay(for: now)
        ) ?? now
        let windowLabels = dayLabels(from: windowStart, count: 30, calendar: calendar)
        let last30Days = sum(entries, in: windowLabels)

        var series: [SpendDay] = []
        series.reserveCapacity(30)
        var currentDate = windowStart
        for _ in 0..<30 {
            let label = DateHelpers.dayLabel(for: currentDate, timeZone: timeZone)
            let amount = entries
                .filter { $0.dayLabel == label }
                .reduce(0) { $0 + $1.cost }
            series.append(SpendDay(date: currentDate, amount: amount))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }

        return SpendBreakdown(
            today: today,
            week: week,
            month: month,
            last30Days: last30Days,
            dailySeries: series,
            topModels: topModels(entries: entries, windowLabels: windowLabels)
        )
    }

    // MARK: - Internals

    private static func sum(
        _ entries: [(dayLabel: String, cost: Double, model: String)],
        in labels: Set<String>
    ) -> Double {
        entries
            .filter { labels.contains($0.dayLabel) }
            .reduce(0) { $0 + $1.cost }
    }

    private static func dayLabels(
        from start: Date,
        count: Int,
        calendar: Calendar
    ) -> Set<String> {
        var labels = Set<String>()
        labels.reserveCapacity(count)
        var date = calendar.startOfDay(for: start)
        for _ in 0..<count {
            // Day label in the calendar's timezone (the user's local zone).
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            if let y = comps.year, let m = comps.month, let d = comps.day {
                labels.insert(String(format: "%04d-%02d-%02d", y, m, d))
            }
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? date
        }
        return labels
    }

    static func startOfWeek(containing date: Date, calendar: Calendar) -> Date {
        // With firstWeekday = 2, yearForWeekOfYear/weekOfYear resolve to the
        // Monday-start week containing `date`.
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    static func startOfMonth(containing date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    private static func topModels(
        entries: [(dayLabel: String, cost: Double, model: String)],
        windowLabels: Set<String>
    ) -> [ModelSpend] {
        let totals = Dictionary(grouping: entries.filter { windowLabels.contains($0.dayLabel) }, by: \.model)
            .map { model, rows -> ModelSpend in
                ModelSpend(
                    model: model,
                    displayName: ModelNameFormatter.displayName(for: model),
                    amount: rows.reduce(0) { $0 + $1.cost }
                )
            }
            .sorted { lhs, rhs in
                if lhs.amount != rhs.amount { return lhs.amount > rhs.amount }
                return lhs.model < rhs.model
            }

        if totals.count <= topModelCount {
            return totals
        }
        let top = Array(totals.prefix(topModelCount))
        let otherAmount = totals.dropFirst(topModelCount).reduce(0) { $0 + $1.amount }
        return top + [ModelSpend(model: "_other", displayName: "Other", amount: otherAmount)]
    }
}

/// Local-calendar period boundaries used for exact account spend queries.
public enum SpendPeriods {
    public struct Boundaries: Equatable, Sendable {
        /// Local midnight of the current day.
        public let todayStart: Date
        /// Local Monday of the current week.
        public let weekStart: Date
        /// Local first day of the current month.
        public let monthStart: Date
    }

    public static func boundaries(
        now: Date = Date(),
        timeZone: TimeZone = .current
    ) -> Boundaries {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.firstWeekday = 2 // Monday
        return Boundaries(
            todayStart: calendar.startOfDay(for: now),
            weekStart: SpendCalculator.startOfWeek(containing: now, calendar: calendar),
            monthStart: SpendCalculator.startOfMonth(containing: now, calendar: calendar)
        )
    }
}
