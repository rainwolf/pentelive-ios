import XCTest
@testable import penteLive

final class MoveResultTests: XCTestCase {
    func testHoldsValues() {
        let caps = [Capture(position: 10, color: 2), Capture(position: 11, color: 2)]
        let r = MoveResult(captured: caps, poofed: true, winner: 1, placed: 2)
        XCTAssertEqual(r.captured.count, 2)
        XCTAssertEqual(r.captured[0].position, 10)
        XCTAssertEqual(r.captured[0].color, 2)
        XCTAssertTrue(r.poofed)
        XCTAssertEqual(r.winner, 1)
        XCTAssertEqual(r.placed, 2)
    }
}
