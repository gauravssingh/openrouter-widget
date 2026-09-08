import Foundation
import os

/// Fetches a complete usage snapshot. `/key` is the source of truth for
/// connectivity: if it fails, the refresh fails. Credits and activity are
/// management-key-only; when the key lacks permissions (or the endpoints
/// fail transiently) the snapshot degrades to warnings instead of errors.
public final class UsageService: Sendable {
    private let api: OpenRouterAPI

    public init(api: OpenRouterAPI) {
        self.api = api
    }

    public func fetchSnapshot(apiKey: String) async throws -> UsageSnapshot {
        AppLog.refresh.info("Usage refresh started")
        let keyInfo = try await api.getKeyInfo(apiKey: apiKey)

        var credits: Credits?
        var activity: [ActivityItem] = []
        var accountSpend: AccountSpend?
        var warnings: [UsageWarning] = []

        if keyInfo.isManagementKey {
            do {
                credits = try await api.getCredits(apiKey: apiKey)
            } catch {
                warnings.append(.creditsUnavailable(shortDescription(of: error)))
            }
            do {
                activity = try await api.getActivity(apiKey: apiKey)
            } catch {
                warnings.append(.activityUnavailable(shortDescription(of: error)))
            }
            // Exact account-wide spend for the local periods shown in the
            // summary rows. Per-key usage figures miss traffic made through
            // other keys, so analytics is the correct source here.
            do {
                accountSpend = try await fetchAccountSpend(apiKey: apiKey)
            } catch {
                warnings.append(.spendUnavailable(shortDescription(of: error)))
            }
        } else {
            warnings.append(.managementKeyRequired)
        }

        let snapshot = UsageSnapshot(
            capturedAt: Date(),
            key: keyInfo,
            credits: credits,
            activity: activity,
            accountSpend: accountSpend,
            warnings: warnings
        )
        AppLog.refresh.info("Usage refresh completed (activity rows: \(activity.count), warnings: \(warnings.count))")
        return snapshot
    }

    private func fetchAccountSpend(apiKey: String) async throws -> AccountSpend {
        let now = Date()
        let boundaries = SpendPeriods.boundaries(now: now)
        async let today = api.getSpendTotal(apiKey: apiKey, from: boundaries.todayStart, to: now)
        async let week = api.getSpendTotal(apiKey: apiKey, from: boundaries.weekStart, to: now)
        async let month = api.getSpendTotal(apiKey: apiKey, from: boundaries.monthStart, to: now)
        return try await AccountSpend(today: today, week: week, month: month)
    }

    private func shortDescription(of error: Error) -> String {
        let apiError = error as? OpenRouterAPIError
        if let apiError {
            switch apiError {
            case .forbidden:
                return "management key required"
            case .unauthorized:
                return "unauthorized"
            case .rateLimited:
                return "rate limited"
            case .serverError(let status, _):
                return "server error \(status)"
            default:
                break
            }
        }
        return (error as? LocalizedError)?.errorDescription ?? "request failed"
    }
}
