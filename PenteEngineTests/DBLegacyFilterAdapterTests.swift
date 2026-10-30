import XCTest
@testable import penteLive

final class DBLegacyFilterAdapterTests: XCTestCase {
    private func make(p1: String? = nil, p2: String? = nil, r1: String? = nil, r2: String? = nil,
                      either: Bool = false, winner: Int = 0,
                      after: Date? = nil, before: Date? = nil) -> DBFilters? {
        DBLegacyFilterAdapter.filters(p1Name: p1, p2Name: p2, p1Rating: r1, p2Rating: r2,
                                      eitherSeat: either, winner: winner, after: after, before: before)
    }

    func testEmptyIsNil() {
        XCTAssertNil(make())
        XCTAssertNil(make(p1: "  ", p2: "", r1: "0", r2: "-5", either: true))
    }

    func testEitherSeatWithNameSendsZeroSeats() {
        let f = make(p1: " alice ", either: true)
        XCTAssertEqual(f?.player1Name, "alice")
        XCTAssertEqual(f?.player1Seat, 0)
        XCTAssertEqual(f?.player2Seat, 0)
    }

    func testEitherSeatWithoutNameKeepsOneTwo() {
        let f = make(either: true, winner: 1)
        XCTAssertEqual(f?.player1Seat, 1)
        XCTAssertEqual(f?.player2Seat, 2)
        XCTAssertEqual(f?.winner, 1)
    }

    func testEitherSeatWithRatingSendsZeroSeats() {
        let f = make(r2: "1700", either: true)
        XCTAssertEqual(f?.player2RatingAbove, 1700)
        XCTAssertEqual(f?.player1Seat, 0)
        XCTAssertEqual(f?.player2Seat, 0)
    }

    func testPickerDateEmittedGregorian() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let d = cal.date(from: DateComponents(year: 2025, month: 12, day: 30, hour: 12))!
        let f = make(after: d, before: d)
        XCTAssertEqual(f?.afterDate, "2025-12-30")
        XCTAssertEqual(f?.beforeDate, "2025-12-30")
    }

    func testRatingParsing() {
        let f = make(r1: "abc", r2: "1800")
        XCTAssertEqual(f?.player1RatingAbove, 0)
        XCTAssertEqual(f?.player2RatingAbove, 1800)
    }
}
