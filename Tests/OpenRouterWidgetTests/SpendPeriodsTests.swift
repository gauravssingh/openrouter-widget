import Foundation
import OpenRouterWidgetCore
import XCTest

final class SpendPeriodsTests: XCTestCase {
    private func date(
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

    /// Wednesday, 11 June 2025, 14:30 in New York.
    func testBoundariesMidWeek() {
        let tz = TimeZone(identifier: "America/New_York")!
        let now = date(2025, 6, 11, 14, 30, timeZone: tz)
        let boundaries = SpendPeriods.boundaries(now: now, timeZone: tz)

        XCTAssertEqual(boundaries.todayStart, date(2025, 6, 11, 0, 0, timeZone: tz))
        // Monday of the same week.
        XCTAssertEqual(boundaries.weekStart, date(2025, 6, 9, 0, 0, timeZone: tz))
        XCTAssertEqual(boundaries.monthStart, date(2025, 6, 1, 0, 0, timeZone: tz))
    }

    /// Sunday counts as the tail of the Monday-start week.
    func testWeekStartOnSunday() {
        let tz = TimeZone(identifier: "America/New_York")!
        let now = date(2025, 6, 15, 20, 0, timeZone: tz) // Sunday evening
        let boundaries = SpendPeriods.boundaries(now: now, timeZone: tz)
        XCTAssertEqual(boundaries.weekStart, date(2025, 6, 9, 0, 0, timeZone: tz))
    }

    /// Month boundary: 1 July still belongs to June's week if it is Monday.
    func testMonthAndWeekDisagree() {
        let tz = TimeZone(identifier: "Asia/Kolkata")!
        let now = date(2025, 6, 30, 9, 0, timeZone: tz) // Monday, 30 June
        let boundaries = SpendPeriods.boundaries(now: now, timeZone: tz)
        XCTAssertEqual(boundaries.weekStart, date(2025, 6, 30, 0, 0, timeZone: tz))
        XCTAssertEqual(boundaries.monthStart, date(2025, 6, 1, 0, 0, timeZone: tz))
    }

    /// Local midnight boundaries must be expressed in the given timezone —
    /// e.g. IST midnight is 18:30 of the previous UTC day.
    func testTodayStartIsLocalMidnight() {
        let tz = TimeZone(identifier: "Asia/Kolkata")!
        let now = date(2025, 6, 11, 3, 0, timeZone: tz)
        let boundaries = SpendPeriods.boundaries(now: now, timeZone: tz)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let utcComponents = utc.dateComponents(in: tz, from: boundaries.todayStart)
        XCTAssertEqual(utcComponents.hour, 0)
        XCTAssertEqual(utcComponents.minute, 0)
        XCTAssertEqual(utcComponents.day, 11)
    }
}
