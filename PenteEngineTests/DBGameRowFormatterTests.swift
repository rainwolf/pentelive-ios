import XCTest
@testable import penteLive

final class DBGameRowFormatterTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let enUS = Locale(identifier: "en_US")

    private func now2026() -> Date {
        ISO8601DateFormatter().date(from: "2026-10-30T00:00:00Z")!
    }

    func testScore() {
        XCTAssertEqual(DBGameRowFormatter.score(winner: 1), "1 \u{2013} 0")
        XCTAssertEqual(DBGameRowFormatter.score(winner: 2), "0 \u{2013} 1")
        XCTAssertEqual(DBGameRowFormatter.score(winner: 0), "\u{2013}")
        XCTAssertEqual(DBGameRowFormatter.score(winner: 3), "\u{2013}")
    }

    func testDateSameYearOmitsYear() {
        let s = DBGameRowFormatter.date(iso: "2026-05-01T12:00:00Z", now: now2026(), locale: enUS, timeZone: utc)
        XCTAssertEqual(s, "May 1")
    }

    func testDateOtherYearShowsYear() {
        let s = DBGameRowFormatter.date(iso: "2019-05-01T12:00:00Z", now: now2026(), locale: enUS, timeZone: utc)
        XCTAssertTrue(s.contains("2019"), s)
    }

    func testNullDateEmpty() {
        XCTAssertEqual(DBGameRowFormatter.date(iso: nil, now: now2026(), locale: enUS, timeZone: utc), "")
        XCTAssertEqual(DBGameRowFormatter.date(iso: "garbage", now: now2026(), locale: enUS, timeZone: utc), "")
    }

    func testDateParsesUnderBuddhistCalendar() {
        let th = Locale(identifier: "th_TH@calendar=buddhist")
        let s = DBGameRowFormatter.date(iso: "2026-05-01T12:00:00Z", now: now2026(), locale: th, timeZone: utc)
        XCTAssertFalse(s.isEmpty)
        // Same instant rendered directly in the same locale: month and day must match (no shift).
        let f = DateFormatter()
        f.locale = th
        f.timeZone = utc
        f.setLocalizedDateFormatFromTemplate("MMMd")
        let expected = f.string(from: ISO8601DateFormatter().date(from: "2026-05-01T12:00:00Z")!)
        XCTAssertEqual(s, expected)
        XCTAssertTrue(s.contains("1"), s)
    }
}
