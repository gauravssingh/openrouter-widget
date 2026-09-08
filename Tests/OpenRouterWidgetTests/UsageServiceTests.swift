import Foundation
import OpenRouterWidgetCore
import XCTest

/// Scriptable fake so UsageService orchestration can be tested offline.
actor FakeAPI: OpenRouterAPI {
    private(set) var keyCalls = 0
    private(set) var creditsCalls = 0
    private(set) var activityCalls = 0
    private(set) var spendCalls = 0

    var keyResult: Result<KeyInfo, Error> = .success(FakeAPI.defaultKey())
    var creditsResult: Result<Credits, Error> = .success(Credits(totalCredits: 100, totalUsage: 30))
    var activityResult: Result<[ActivityItem], Error> = .success([])
    var spendResult: Result<Double, Error> = .success(42)

    private(set) var spendRanges: [(start: Date, end: Date)] = []

    nonisolated static func defaultKey(isManagement: Bool = true) -> KeyInfo {
        KeyInfo(
            label: "sk-or-v1-abc...123",
            usage: 10, usageDaily: 1, usageWeekly: 5, usageMonthly: 9,
            byokUsage: 0, byokUsageDaily: 0, byokUsageWeekly: 0, byokUsageMonthly: 0,
            limit: 50, limitRemaining: 40, limitReset: "monthly",
            includeByokInLimit: false,
            isFreeTier: false, isManagementKey: isManagement, isProvisioningKey: false,
            expiresAt: nil, creatorUserId: nil
        )
    }

    func getKeyInfo(apiKey: String) throws -> KeyInfo {
        keyCalls += 1
        return try keyResult.get()
    }

    func getCredits(apiKey: String) throws -> Credits {
        creditsCalls += 1
        return try creditsResult.get()
    }

    func getActivity(apiKey: String) throws -> [ActivityItem] {
        activityCalls += 1
        return try activityResult.get()
    }

    func getSpendTotal(apiKey: String, from start: Date, to end: Date) throws -> Double {
        spendCalls += 1
        spendRanges.append((start, end))
        return try spendResult.get()
    }

    // Test scripting helpers.
    func setKeyResult(_ result: Result<KeyInfo, Error>) { keyResult = result }
    func setCreditsResult(_ result: Result<Credits, Error>) { creditsResult = result }
    func setActivityResult(_ result: Result<[ActivityItem], Error>) { activityResult = result }
    func setSpendResult(_ result: Result<Double, Error>) { spendResult = result }
    func callCounts() -> (key: Int, credits: Int, activity: Int, spend: Int) {
        (keyCalls, creditsCalls, activityCalls, spendCalls)
    }
}

private func makeItem(_ day: String, model: String, cost: Double) -> ActivityItem {
    ActivityItem(
        date: day, model: model, modelPermaslug: model,
        endpointId: "e-\(model)", providerName: "P",
        usage: cost, byokUsageInference: 0,
        requests: 1, promptTokens: 1, completionTokens: 1, reasoningTokens: 0
    )
}

final class UsageServiceTests: XCTestCase {
    private let apiKey = "sk-or-v1-service-test"

    func testManagementKeyFetchesCreditsActivityAndSpend() async throws {
        let api = FakeAPI()
        let items = [makeItem("2025-06-10", model: "a/a", cost: 1)]
        await api.setActivityResult(.success(items))

        let service = UsageService(api: api)
        let snapshot = try await service.fetchSnapshot(apiKey: apiKey)

        let calls = await api.callCounts()
        XCTAssertEqual(calls.key, 1)
        XCTAssertEqual(calls.credits, 1)
        XCTAssertEqual(calls.activity, 1)
        XCTAssertEqual(calls.spend, 3) // today + week + month
        XCTAssertEqual(snapshot.credits?.remaining ?? 0, 70, accuracy: 0.0001)
        XCTAssertEqual(snapshot.activity, items)
        XCTAssertEqual(snapshot.accountSpend?.today ?? 0, 42, accuracy: 0.0001)
        XCTAssertEqual(snapshot.accountSpend?.week ?? 0, 42, accuracy: 0.0001)
        XCTAssertEqual(snapshot.accountSpend?.month ?? 0, 42, accuracy: 0.0001)
        XCTAssertTrue(snapshot.warnings.isEmpty)

        // The three spend queries cover the local periods; they run
        // concurrently, so order them before comparing.
        let ranges = await api.spendRanges
        XCTAssertEqual(ranges.count, 3)
        let starts = ranges.map(\.start).sorted()
        for pair in zip(starts, starts.dropFirst()) {
            XCTAssertLessThan(pair.0, pair.1)
        }
        XCTAssertLessThanOrEqual(starts[0], starts[1])
        XCTAssertLessThanOrEqual(starts[1], starts[2])
    }

    func testSpendFailureDegradesToWarningWithKeyFallback() async throws {
        let api = FakeAPI()
        await api.setSpendResult(.failure(OpenRouterAPIError.rateLimited(message: "slow down")))

        let service = UsageService(api: api)
        let snapshot = try await service.fetchSnapshot(apiKey: apiKey)

        XCTAssertNil(snapshot.accountSpend)
        guard case .spendUnavailable = snapshot.warnings.first else {
            return XCTFail("Expected spendUnavailable warning")
        }
        // Credits/activity still present.
        XCTAssertEqual(snapshot.credits?.remaining ?? 0, 70, accuracy: 0.0001)
    }

    func testNonManagementKeySkipsCreditsActivityAndSpendAndWarns() async throws {
        let api = FakeAPI()
        await api.setKeyResult(.success(FakeAPI.defaultKey(isManagement: false)))

        let service = UsageService(api: api)
        let snapshot = try await service.fetchSnapshot(apiKey: apiKey)

        let calls = await api.callCounts()
        XCTAssertEqual(calls.credits, 0)
        XCTAssertEqual(calls.activity, 0)
        XCTAssertEqual(calls.spend, 0)
        XCTAssertNil(snapshot.credits)
        XCTAssertTrue(snapshot.activity.isEmpty)
        XCTAssertEqual(snapshot.warnings, [.managementKeyRequired])
    }

    func testKeyFailureFailsTheWholeRefresh() async {
        let api = FakeAPI()
        await api.setKeyResult(.failure(OpenRouterAPIError.unauthorized(message: "Invalid key")))

        let service = UsageService(api: api)
        do {
            _ = try await service.fetchSnapshot(apiKey: apiKey)
            XCTFail("Expected error")
        } catch {
            guard case OpenRouterAPIError.unauthorized = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        let snapshotAPI = await api.callCounts()
        XCTAssertEqual(snapshotAPI.credits, 0)
    }

    func testCreditsFailureDegradesToWarning() async throws {
        let api = FakeAPI()
        await api.setCreditsResult(.failure(
            OpenRouterAPIError.forbidden(message: "Only management keys can perform this operation")
        ))

        let service = UsageService(api: api)
        let snapshot = try await service.fetchSnapshot(apiKey: apiKey)

        let calls = await api.callCounts()
        XCTAssertNil(snapshot.credits)
        XCTAssertEqual(calls.activity, 1) // activity still attempted
        guard case .creditsUnavailable = snapshot.warnings.first else {
            return XCTFail("Expected creditsUnavailable warning")
        }
    }

    func testActivityFailureDegradesToWarning() async throws {
        let api = FakeAPI()
        await api.setActivityResult(.failure(OpenRouterAPIError.rateLimited(message: "slow down")))

        let service = UsageService(api: api)
        let snapshot = try await service.fetchSnapshot(apiKey: apiKey)

        XCTAssertEqual(snapshot.credits?.remaining ?? 0, 70, accuracy: 0.0001)
        guard case .activityUnavailable = snapshot.warnings.first else {
            return XCTFail("Expected activityUnavailable warning")
        }
    }
}
