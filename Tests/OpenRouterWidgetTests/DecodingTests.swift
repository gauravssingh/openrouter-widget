import Foundation
import OpenRouterWidgetCore
import XCTest

/// Decodes representative fixtures modelled on the official OpenAPI examples.
final class DecodingTests: XCTestCase {
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures"
        )
        return try Data(contentsOf: XCTUnwrap(url, "Missing fixture \(name).json"))
    }

    func testCreditsDecoding() throws {
        let credits = try decoder.decode(CreditsResponse.self, from: fixtureData("credits")).data
        XCTAssertEqual(credits.totalCredits, 100.5, accuracy: 0.0001)
        XCTAssertEqual(credits.totalUsage, 25.75, accuracy: 0.0001)
        XCTAssertEqual(credits.remaining, 74.75, accuracy: 0.0001)
    }

    func testKeyInfoDecoding() throws {
        let key = try decoder.decode(KeyInfoResponse.self, from: fixtureData("key")).data
        XCTAssertEqual(key.label, "sk-or-v1-au7...890")
        XCTAssertEqual(key.usage, 25.5, accuracy: 0.0001)
        XCTAssertEqual(key.usageDaily, 25.5, accuracy: 0.0001)
        XCTAssertEqual(key.byokUsageDaily, 17.38, accuracy: 0.0001)
        XCTAssertEqual(key.limit, 100)
        XCTAssertEqual(key.limitRemaining, 74.5)
        XCTAssertEqual(key.limitReset, "monthly")
        XCTAssertTrue(key.isManagementKey)
        XCTAssertFalse(key.isFreeTier)
        XCTAssertEqual(key.expiresAt, "2027-12-31T23:59:59Z")
        XCTAssertEqual(key.totalDailyUsage, 42.88, accuracy: 0.0001)
    }

    func testKeyInfoWithNullableFieldsDecodes() throws {
        // A key without a limit and without expiry — all nullable fields null.
        let json = """
        {"data":{"label":"sk-or-v1-x","usage":1,"usage_daily":1,"usage_weekly":1,
        "usage_monthly":1,"byok_usage":0,"byok_usage_daily":0,"byok_usage_weekly":0,
        "byok_usage_monthly":0,"limit":null,"limit_remaining":null,"limit_reset":null,
        "include_byok_in_limit":false,"is_free_tier":true,"is_management_key":false,
        "is_provisioning_key":false,"expires_at":null,"creator_user_id":null,
        "rate_limit":{"interval":"1h","requests":-1}}}
        """
        let key = try decoder.decode(KeyInfoResponse.self, from: Data(json.utf8)).data
        XCTAssertNil(key.limit)
        XCTAssertNil(key.limitRemaining)
        XCTAssertNil(key.expiresAt)
        XCTAssertTrue(key.isFreeTier)
        XCTAssertFalse(key.isManagementKey)
    }

    func testActivityDecoding() throws {
        let items = try decoder.decode(ActivityResponse.self, from: fixtureData("activity")).data
        XCTAssertEqual(items.count, 3)

        let first = try XCTUnwrap(items.first)
        XCTAssertEqual(first.date, "2025-06-11")
        XCTAssertEqual(first.model, "openai/gpt-4.1")
        XCTAssertEqual(first.providerName, "OpenAI")
        XCTAssertEqual(first.usage, 0.015, accuracy: 0.0001)
        XCTAssertEqual(first.byokUsageInference, 0.012, accuracy: 0.0001)
        XCTAssertEqual(first.requests, 5)
        XCTAssertEqual(first.promptTokens, 50)
        XCTAssertEqual(first.completionTokens, 125)
        XCTAssertEqual(first.reasoningTokens, 25)
        XCTAssertEqual(first.totalCost, 0.027, accuracy: 0.0001)
    }

    func testEmptyActivityDecoding() throws {
        let items = try decoder.decode(ActivityResponse.self, from: fixtureData("activity-empty")).data
        XCTAssertTrue(items.isEmpty)
    }
}
