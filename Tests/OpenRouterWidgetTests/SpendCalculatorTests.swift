import Foundation
import OpenRouterWidgetCore
import XCTest

final class SpendCalculatorTests: XCTestCase {
    /// Fixed reference: Wednesday, 11 June 2025, 14:30 America/New_York.
    private var now: Date {
        dateComponents(2025, 6, 11, 14, 30, timeZone: newYork)
    }

    private var newYork: TimeZone {
        TimeZone(identifier: "America/New_York")!
    }

    private func dateComponents(
        _ year: Int, _ month: Int, _ day: Int,
        _ hour: Int = 12, _ minute: Int = 0,
        timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        return calendar.date(from: comps)!
    }

    private func item(_ day: String, model: String, cost: Double) -> ActivityItem {
        ActivityItem(
            date: day,
            model: model,
            modelPermaslug: model,
            endpointId: "endpoint-\(model)-\(day)",
            providerName: "Test",
            usage: cost,
            byokUsageInference: 0,
            requests: 1,
            promptTokens: 10,
            completionTokens: 10,
            reasoningTokens: 0
        )
    }

    // MARK: - Period totals

    func testTodayWeekMonthAnd30DayWindow() {
        let items = [
            item("2025-06-11", model: "anthropic/claude-sonnet-4.5", cost: 1.50), // today, Wed
            item("2025-06-09", model: "openai/gpt-4.1", cost: 2.00),               // Monday this week
            item("2025-06-08", model: "z-ai/glm-4.6", cost: 3.00),                 // Sunday, previous week
            item("2025-05-31", model: "z-ai/glm-4.6", cost: 1.00),                 // May: in 30d window, not month
            item("2025-05-12", model: "openai/gpt-4.1", cost: 4.00)                // outside 30d window
        ]

        let breakdown = SpendCalculator.breakdown(items: items, now: now, timeZone: newYork)

        XCTAssertEqual(breakdown.today, 1.50, accuracy: 0.0001)
        // Week = Monday 2025-06-09 … Sunday 2025-06-15 (local).
        XCTAssertEqual(breakdown.week, 3.50, accuracy: 0.0001)
        // Month = June 2025 local: 06-11 + 06-09 + 06-08.
        XCTAssertEqual(breakdown.month, 6.50, accuracy: 0.0001)
        // Window = 2025-05-13 … 2025-06-11.
        XCTAssertEqual(breakdown.last30Days, 7.50, accuracy: 0.0001)
    }

    func testLocalTimezoneDayBoundary() {
        // In Asia/Kolkata (UTC+5:30), 2025-06-11 03:00 local is still
        // 2025-06-10 in UTC. The local "today" is 06-11, so a UTC-day-10
        // activity row — less than six hours old — must NOT count as today.
        let kolkata = TimeZone(identifier: "Asia/Kolkata")!
        let nowIST = dateComponents(2025, 6, 11, 3, 0, timeZone: kolkata)

        let items = [
            item("2025-06-10", model: "z-ai/glm-4.6", cost: 2.00),
            item("2025-06-11", model: "z-ai/glm-4.6", cost: 0.25)
        ]

        let breakdown = SpendCalculator.breakdown(items: items, now: nowIST, timeZone: kolkata)
        XCTAssertEqual(breakdown.today, 0.25, accuracy: 0.0001)
        XCTAssertEqual(breakdown.week, 2.25, accuracy: 0.0001)
    }

    func testWeekStartsMonday() {
        // `now` is Sunday 2025-06-15 → week = Mon 06-09 … Sun 06-15.
        let sunday = dateComponents(2025, 6, 15, 20, 0, timeZone: newYork)
        let items = [
            item("2025-06-09", model: "a/a", cost: 1), // Monday — in
            item("2025-06-08", model: "b/b", cost: 10) // previous Sunday — out
        ]
        let breakdown = SpendCalculator.breakdown(items: items, now: sunday, timeZone: newYork)
        XCTAssertEqual(breakdown.week, 1, accuracy: 0.0001)
    }

    func testMonthBoundary() {
        // `now` is 1 July → June spend belongs to last month, not this month.
        let julyFirst = dateComponents(2025, 7, 1, 0, 30, timeZone: newYork)
        let items = [
            item("2025-06-30", model: "a/a", cost: 5),
            item("2025-07-01", model: "b/b", cost: 2)
        ]
        let breakdown = SpendCalculator.breakdown(items: items, now: julyFirst, timeZone: newYork)
        XCTAssertEqual(breakdown.month, 2, accuracy: 0.0001)
        XCTAssertEqual(breakdown.last30Days, 7, accuracy: 0.0001)
    }

    // MARK: - Series

    func testDailySeriesIsThirtyZeroFilledBuckets() {
        let breakdown = SpendCalculator.breakdown(items: [], now: now, timeZone: newYork)
        XCTAssertEqual(breakdown.dailySeries.count, 30)
        XCTAssertTrue(breakdown.dailySeries.allSatisfy { $0.amount == 0 })
        // Oldest bucket is 29 days before today.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = newYork
        let expectedStart = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now))!
        XCTAssertEqual(breakdown.dailySeries.first?.date, expectedStart)
    }

    func testDailySeriesSumsByDay() throws {
        let items = [
            item("2025-06-11", model: "a/a", cost: 1),
            item("2025-06-11", model: "b/b", cost: 2),
            item("2025-06-10", model: "a/a", cost: 4)
        ]
        let breakdown = SpendCalculator.breakdown(items: items, now: now, timeZone: newYork)
        let lastDay = try XCTUnwrap(breakdown.dailySeries.last)
        XCTAssertEqual(lastDay.amount, 3, accuracy: 0.0001)
        XCTAssertEqual(breakdown.dailySeries.count, 30)
    }

    // MARK: - Models

    func testEmptyActivityProducesZeroBreakdown() {
        let breakdown = SpendCalculator.breakdown(items: [], now: now, timeZone: newYork)
        XCTAssertEqual(breakdown.today, 0)
        XCTAssertEqual(breakdown.week, 0)
        XCTAssertEqual(breakdown.month, 0)
        XCTAssertEqual(breakdown.last30Days, 0)
        XCTAssertTrue(breakdown.topModels.isEmpty)
    }

    func testTopModelsSortedWithOtherBucket() throws {
        var items: [ActivityItem] = []
        let models = [
            "anthropic/claude-sonnet-4.5": 8.00,
            "openai/gpt-4.1": 5.00,
            "z-ai/glm-4.6": 2.00,
            "openai/o3-mini": 1.50,
            "google/gemini-2.5-pro": 1.00, // 5th → folded into Other
            "meta-llama/llama-3.3-70b": 0.50 // 6th → folded into Other
        ]
        for (model, cost) in models {
            items.append(item("2025-06-10", model: model, cost: cost))
        }

        let breakdown = SpendCalculator.breakdown(items: items, now: now, timeZone: newYork)

        XCTAssertEqual(breakdown.topModels.count, 5) // 4 + Other
        let top = try XCTUnwrap(breakdown.topModels.first)
        XCTAssertEqual(top.model, "anthropic/claude-sonnet-4.5")
        XCTAssertEqual(top.amount, 8.00, accuracy: 0.0001)
        let other = try XCTUnwrap(breakdown.topModels.last)
        XCTAssertEqual(other.displayName, "Other")
        XCTAssertEqual(other.amount, 1.50, accuracy: 0.0001)
    }

    func testFewModelsNoOtherBucket() {
        let items = [
            item("2025-06-10", model: "a/a", cost: 1),
            item("2025-06-10", model: "b/b", cost: 2)
        ]
        let breakdown = SpendCalculator.breakdown(items: items, now: now, timeZone: newYork)
        XCTAssertEqual(breakdown.topModels.count, 2)
        XCTAssertFalse(breakdown.topModels.contains { $0.model == "_other" })
    }

    func testTopModelsIgnoreSpendOutsideWindow() {
        let items = [
            item("2024-01-01", model: "old/old", cost: 100),
            item("2025-06-10", model: "new/new", cost: 1)
        ]
        let breakdown = SpendCalculator.breakdown(items: items, now: now, timeZone: newYork)
        XCTAssertEqual(breakdown.topModels.map(\.model), ["new/new"])
    }

    // MARK: - Model names

    func testModelNameFormatting() {
        XCTAssertEqual(
            ModelNameFormatter.displayName(for: "anthropic/claude-sonnet-4.5"),
            "Claude Sonnet 4.5"
        )
        XCTAssertEqual(ModelNameFormatter.displayName(for: "openai/gpt-4o"), "GPT 4o")
        XCTAssertEqual(ModelNameFormatter.displayName(for: "z-ai/glm-4.6"), "GLM 4.6")
        XCTAssertEqual(ModelNameFormatter.displayName(for: "openai/o3-mini"), "O3 Mini")
        XCTAssertEqual(ModelNameFormatter.displayName(for: "google/gemini-2.5-pro"), "Gemini 2.5 Pro")
        XCTAssertEqual(ModelNameFormatter.displayName(for: "google/dall-e-3"), "DALL-E 3")
    }
}
