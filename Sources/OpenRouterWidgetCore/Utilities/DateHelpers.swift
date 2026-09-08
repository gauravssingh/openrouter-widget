import Foundation

/// Date parsing/formatting helpers shared by the API, domain, and UI layers.
public enum DateHelpers {
    /// Parses OpenRouter activity day labels (`"2025-08-24"`) as UTC dates.
    private static let utcDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let localDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    /// Parses a `YYYY-MM-DD` string as the start of that day in UTC.
    public static func parseUTCDay(_ string: String) -> Date? {
        utcDayFormatter.date(from: String(string.prefix(10)))
    }

    /// Day label (`YYYY-MM-DD`) for a date in the given timezone.
    public static func dayLabel(for date: Date, timeZone: TimeZone) -> String {
        localDayFormatter.timeZone = timeZone
        // Guard against formatter time zone races by formatting directly.
        return localDayFormatter.string(from: date)
    }

    /// Parses ISO-8601 UTC timestamps (e.g. key `expires_at`).
    public static func parseISO8601(_ string: String) -> Date? {
        ISO8601DateFormatter().date(from: string)
    }

    /// `"2 min ago"`, `"3 hr ago"`, …
    public static func relativeDescription(from date: Date, to now: Date = Date()) -> String {
        relative.localizedString(for: date, relativeTo: now)
    }
}
