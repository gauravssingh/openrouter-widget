import Foundation
import OpenRouterWidgetCore
import XCTest

final class DateHelperTests: XCTestCase {
    private func date(secondsAgo: Double) -> Date {
        Date().addingTimeInterval(-secondsAgo)
    }

    func testHumanRelativeBoundaries() {
        XCTAssertEqual(DateHelpers.humanRelative(from: date(secondsAgo: 30)), "just now")
        XCTAssertEqual(DateHelpers.humanRelative(from: date(secondsAgo: 60)), "1 min ago")
        XCTAssertEqual(DateHelpers.humanRelative(from: date(secondsAgo: 120)), "2 min ago")
        XCTAssertEqual(DateHelpers.humanRelative(from: date(secondsAgo: 59 * 60)), "59 min ago")
        XCTAssertEqual(DateHelpers.humanRelative(from: date(secondsAgo: 60 * 60)), "1 hr ago")
        XCTAssertEqual(DateHelpers.humanRelative(from: date(secondsAgo: 5 * 3600)), "5 hr ago")
        XCTAssertEqual(DateHelpers.humanRelative(from: date(secondsAgo: 24 * 3600)), "1 day ago")
        XCTAssertEqual(DateHelpers.humanRelative(from: date(secondsAgo: 3 * 86400)), "3 days ago")
    }

    func testHumanRelativeNeverNegative() {
        // A clock skew or future-captured timestamp must not read "-5 min ago".
        XCTAssertEqual(DateHelpers.humanRelative(from: date(secondsAgo: -300)), "just now")
    }

    func testParseUTCDay() {
        let date = DateHelpers.parseUTCDay("2025-06-11")
        XCTAssertNotNil(date)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(calendar.dateComponents([.year, .month, .day], from: date!).day, 11)
    }

    func testParseISO8601() {
        XCTAssertNotNil(DateHelpers.parseISO8601("2027-12-31T23:59:59Z"))
        XCTAssertNil(DateHelpers.parseISO8601("not-a-date"))
    }

    func testChartDayLabel() {
        let date = DateHelpers.parseUTCDay("2026-09-04")!
        let label = DateHelpers.chartDayLabel(for: date)
        XCTAssertFalse(label.isEmpty)
        XCTAssertTrue(label.contains("4"))
    }

    func testMediumDayLabel() {
        let date = DateHelpers.parseUTCDay("2026-09-04")!
        let label = DateHelpers.mediumDayLabel(for: date)
        XCTAssertFalse(label.isEmpty)
        XCTAssertTrue(label.contains("2026"))
    }
}
