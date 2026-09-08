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
        } else {
            warnings.append(.managementKeyRequired)
        }

        let snapshot = UsageSnapshot(
            capturedAt: Date(),
            key: keyInfo,
            credits: credits,
            activity: activity,
            warnings: warnings
        )
        AppLog.refresh.info("Usage refresh completed (activity rows: \(activity.count), warnings: \(warnings.count))")
        return snapshot
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
