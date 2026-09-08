import Foundation

/// Why an optional part of a snapshot is missing. Surfaced in the UI without
/// failing the whole refresh.
public enum UsageWarning: Codable, Equatable, Sendable {
    /// The configured key is valid but has no management permissions.
    case managementKeyRequired
    /// Account credits exist but could not be fetched (transient or 403).
    case creditsUnavailable(String)
    /// Activity data could not be fetched.
    case activityUnavailable(String)
    /// Exact account spend totals could not be fetched from analytics.
    case spendUnavailable(String)

    public var message: String {
        switch self {
        case .managementKeyRequired:
            return "Account credits and spend history require a management key."
        case .creditsUnavailable(let detail):
            return "Account credits unavailable: \(detail)"
        case .activityUnavailable(let detail):
            return "Spend history unavailable: \(detail)"
        case .spendUnavailable(let detail):
            return "Account spend totals unavailable: \(detail)"
        }
    }
}

/// Exact account-wide spend (USD) for the local calendar periods shown in
/// the spend summary rows. Sourced from the analytics API (management key),
/// so unlike per-key `/key` usage it covers traffic from every API key.
public struct AccountSpend: Codable, Equatable, Sendable {
    /// Local calendar day (midnight → now).
    public let today: Double
    /// Local Monday → now.
    public let week: Double
    /// Local first of month → now.
    public let month: Double

    public init(today: Double, week: Double, month: Double) {
        self.today = today
        self.week = week
        self.month = month
    }
}

/// Everything the widget needs to render, captured at one point in time.
/// Cached to memory (and a small JSON file) so the UI stays useful offline.
public struct UsageSnapshot: Codable, Equatable, Sendable {
    public let capturedAt: Date
    public let key: KeyInfo
    /// Present only when the key has management permissions (or a
    /// successful credits fetch otherwise failed).
    public let credits: Credits?
    /// Activity rows for the last 30 completed UTC days (management key).
    public let activity: [ActivityItem]
    /// Exact account-wide local-period spend (analytics, management key).
    public let accountSpend: AccountSpend?
    public let warnings: [UsageWarning]

    public init(
        capturedAt: Date,
        key: KeyInfo,
        credits: Credits?,
        activity: [ActivityItem],
        accountSpend: AccountSpend? = nil,
        warnings: [UsageWarning]
    ) {
        self.capturedAt = capturedAt
        self.key = key
        self.credits = credits
        self.activity = activity
        self.accountSpend = accountSpend
        self.warnings = warnings
    }
}
