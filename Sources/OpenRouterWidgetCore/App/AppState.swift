import Foundation
import os

/// Holds all app state: credentials, the latest usage snapshot, refresh
/// bookkeeping, and user settings. `@MainActor` — all UI state mutations
/// happen on the main thread.
@MainActor
public final class AppState: ObservableObject {
    // MARK: - Published state

    /// True once a key exists in the credential store.
    @Published public private(set) var hasStoredKey = false
    /// Latest successful snapshot (may predate a failed refresh).
    @Published public private(set) var snapshot: UsageSnapshot?
    /// Non-nil when the most recent refresh attempt failed.
    @Published public private(set) var lastRefreshError: String?
    @Published public private(set) var isRefreshing = false

    // Setup/connect flow.
    @Published public var isConnecting = false
    @Published public var setupError: String?

    // Settings test-connection flow.
    @Published public var isTestingConnection = false
    @Published public var lastTestResult: String?

    // MARK: - Settings (UserDefaults-backed)

    public static let defaultRefreshIntervalMinutes = 5

    public var refreshIntervalMinutes: Int {
        didSet {
            guard oldValue != refreshIntervalMinutes else { return }
            UserDefaults.standard.set(refreshIntervalMinutes, forKey: Self.refreshIntervalKey)
            objectWillChange.send()
            armScheduler()
        }
    }

    public var showBalanceInMenuBar: Bool {
        didSet {
            guard oldValue != showBalanceInMenuBar else { return }
            UserDefaults.standard.set(showBalanceInMenuBar, forKey: Self.menuBarBalanceKey)
            objectWillChange.send()
        }
    }

    private static let refreshIntervalKey = "refreshIntervalMinutes"
    private static let menuBarBalanceKey = "showBalanceInMenuBar"

    // MARK: - Dependencies

    private let credentials: CredentialStore
    private let api: OpenRouterAPI
    private let usageService: UsageService
    private let cache: SnapshotCache
    private let scheduler = RefreshScheduler()
    private var started = false

    // MARK: - Init

    public init(
        credentials: CredentialStore = KeychainCredentialStore(),
        api: OpenRouterAPI = OpenRouterAPIClient(),
        cache: SnapshotCache = SnapshotCache()
    ) {
        self.credentials = credentials
        self.api = api
        self.usageService = UsageService(api: api)
        self.cache = cache

        let defaults = UserDefaults.standard
        self.refreshIntervalMinutes =
            defaults.object(forKey: Self.refreshIntervalKey) as? Int
            ?? Self.defaultRefreshIntervalMinutes
        self.showBalanceInMenuBar =
            defaults.object(forKey: Self.menuBarBalanceKey) as? Bool ?? true

        hasStoredKey = (try? credentials.loadAPIKey()) != nil
    }

    // MARK: - Lifecycle

    /// Idempotent: called when the menu-bar UI first appears.
    public func start() {
        guard !started else { return }
        started = true

        if snapshot == nil {
            snapshot = cache.load()
        }

        Task { await refresh() }
        armScheduler()
    }

    // MARK: - Refresh

    /// Refreshes usage. Never evicts a valid snapshot on failure and never
    /// runs concurrently with itself.
    public func refresh() async {
        guard !isRefreshing else { return }
        guard let apiKey = (try? credentials.loadAPIKey()) ?? nil, !apiKey.isEmpty else {
            hasStoredKey = false
            return
        }

        isRefreshing = true
        AppLog.refresh.info("Usage refresh started (source: manual/schedule)")
        defer { isRefreshing = false }

        do {
            let fresh = try await usageService.fetchSnapshot(apiKey: apiKey)
            snapshot = fresh
            lastRefreshError = nil
            setupError = nil
            cache.save(fresh)
            AppLog.refresh.info("Usage refresh completed")
        } catch {
            // Keep showing the cached snapshot; only record the failure.
            lastRefreshError = Self.friendlyMessage(for: error)
            AppLog.refresh.error("Usage refresh failed: \(self.lastRefreshError ?? "unknown")")
        }
    }

    // MARK: - Setup / credentials

    /// Validates a pasted key, stores it in the Keychain, and refreshes.
    public func connect(apiKey: String) async {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            setupError = "Enter an API key."
            return
        }
        isConnecting = true
        setupError = nil
        defer { isConnecting = false }

        do {
            _ = try await api.getKeyInfo(apiKey: trimmed)
            try credentials.saveAPIKey(trimmed)
            hasStoredKey = true
            AppLog.app.info("API key connected")
            await refresh()
        } catch {
            setupError = Self.friendlyMessage(for: error)
        }
    }

    /// Replaces the stored key (same flow as first connect).
    public func replaceKey(apiKey: String) async {
        await connect(apiKey: apiKey)
    }

    /// Removes the stored key and all derived data.
    public func removeKey() {
        try? credentials.deleteAPIKey()
        hasStoredKey = false
        snapshot = nil
        lastRefreshError = nil
        lastTestResult = nil
        cache.clear()
        scheduler.stop()
        AppLog.app.info("API key removed")
    }

    /// Masked representation of the stored key for the settings UI,
    /// e.g. `•••••••• 890`. Never returns the full key.
    public func maskedStoredKey() -> String? {
        guard let key = (try? credentials.loadAPIKey()) ?? nil, !key.isEmpty else {
            return nil
        }
        let suffix = key.count >= 4 ? String(key.suffix(4)) : "••••"
        return "•••••••••••••••• \(suffix)"
    }

    /// Exercises the current key without changing any state.
    public func testConnection() async {
        guard let key = (try? credentials.loadAPIKey()) ?? nil, !key.isEmpty else {
            lastTestResult = "No API key configured."
            return
        }
        isTestingConnection = true
        defer { isTestingConnection = false }
        do {
            let info = try await api.getKeyInfo(apiKey: key)
            let role = info.isManagementKey ? "management key" : "inference key"
            lastTestResult = "Connected — \(role) “\(info.label)”"
        } catch {
            lastTestResult = Self.friendlyMessage(for: error)
        }
    }

    // MARK: - Derived values for the UI

    /// Activity-derived spend in the user's local timezone. Nil when the key
    /// has no management permissions (no activity available).
    public var spendBreakdown: SpendBreakdown? {
        guard let snapshot, snapshot.key.isManagementKey || !snapshot.activity.isEmpty else {
            return nil
        }
        return SpendCalculator.breakdown(items: snapshot.activity)
    }

    /// The hero balance: account credits when available, otherwise the key's
    /// remaining spending limit.
    public var balance: (amount: Double, label: String, isAccountCredits: Bool)? {
        guard let snapshot else { return nil }
        if let credits = snapshot.credits {
            return (credits.remaining, "Available credits", true)
        }
        if let remaining = snapshot.key.limitRemaining, snapshot.key.limit != nil {
            return (remaining, "Key limit remaining", false)
        }
        return nil
    }

    /// Compact menu-bar title, e.g. `OR $42.18` or `OR`.
    public var menuBarTitle: String {
        guard showBalanceInMenuBar, let balance else { return "OR" }
        return "OR \(CurrencyFormatter.compact(from: balance.amount))"
    }

    /// "Updated 2 min ago" for the footer.
    public var updatedAgoText: String? {
        guard let snapshot else { return nil }
        return "Updated \(DateHelpers.relativeDescription(from: snapshot.capturedAt))"
    }

    public var managementPermissionsWarning: UsageWarning? {
        snapshot?.warnings.first(where: \.requiresManagementKey)
    }

    // MARK: - Internals

    private func armScheduler() {
        let interval = TimeInterval(refreshIntervalMinutes * 60)
        scheduler.start(interval: interval) { [weak self] in
            guard let self else { return }
            Task { await self.refresh() }
        }
    }

    private static func friendlyMessage(for error: Error) -> String {
        if case OpenRouterAPIError.forbidden(let message) = error {
            let suffix = (message ?? "").isEmpty ? "" : " — \(message!)"
            return "Access denied\(suffix). Check that your key has the required permissions."
        }
        return (error as? LocalizedError)?.errorDescription
            ?? error.localizedDescription
    }
}

private extension UsageWarning {
    var requiresManagementKey: Bool {
        switch self {
        case .managementKeyRequired:
            return true
        case .creditsUnavailable, .activityUnavailable:
            return false
        }
    }
}
