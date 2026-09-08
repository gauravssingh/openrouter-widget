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

    public var message: String {
        switch self {
        case .managementKeyRequired:
            return "Account credits and spend history require a management key."
        case .creditsUnavailable(let detail):
            return "Account credits unavailable: \(detail)"
        case .activityUnavailable(let detail):
            return "Spend history unavailable: \(detail)"
        }
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
    public let warnings: [UsageWarning]

    public init(
        capturedAt: Date,
        key: KeyInfo,
        credits: Credits?,
        activity: [ActivityItem],
        warnings: [UsageWarning]
    ) {
        self.capturedAt = capturedAt
        self.key = key
        self.credits = credits
        self.activity = activity
        self.warnings = warnings
    }
}
