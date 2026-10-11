@testable import penteLive
import XCTest

final class ArenaMyRequestsModelTests: XCTestCase {
    func testTapOnUnmarkedTableRequestsOnceUntilAnswered() {
        var model = ArenaMyRequestsModel()
        XCTAssertEqual(model.tap(table: 3), .request)
        XCTAssertTrue(model.isAwaiting(3))
        XCTAssertEqual(model.tap(table: 3), .ignore) // a double tap never sends a DUPLICATE request
        model.apply(tables: [3])
        XCTAssertFalse(model.isAwaiting(3))
        XCTAssertTrue(model.isRequested(3))
    }

    func testTapOnMarkedTableAsksToWithdraw() {
        var model = ArenaMyRequestsModel()
        model.apply(tables: [5])
        XCTAssertEqual(model.tap(table: 5), .confirmWithdraw)
        XCTAssertFalse(model.isAwaiting(5)) // nothing is sent until the confirm
    }

    func testWithdrawWaitsForTheAnswer() {
        var model = ArenaMyRequestsModel()
        model.apply(tables: [5])
        XCTAssertTrue(model.beginWithdraw(table: 5))
        XCTAssertEqual(model.tap(table: 5), .ignore)
        XCTAssertFalse(model.beginWithdraw(table: 5))
        model.apply(tables: [])
        XCTAssertFalse(model.isRequested(5))
        XCTAssertEqual(model.tap(table: 5), .request)
    }

    func testAnAnswerClearsEveryOutstandingTap() {
        var model = ArenaMyRequestsModel()
        XCTAssertEqual(model.tap(table: 1), .request)
        XCTAssertEqual(model.tap(table: 2), .request)
        model.apply(tables: [1])
        XCTAssertFalse(model.isAwaiting(1))
        XCTAssertFalse(model.isAwaiting(2))
        XCTAssertEqual(model.requested, [1])
        XCTAssertEqual(model.tap(table: 2), .request)
    }

    func testRefusedRequestLeavesNoMark() {
        var model = ArenaMyRequestsModel()
        XCTAssertEqual(model.tap(table: 4), .request)
        model.apply(tables: []) // refused (e.g. BLOCKED); R11 still answers with the set
        XCTAssertFalse(model.isRequested(4))
        XCTAssertFalse(model.isAwaiting(4))
    }

    func testWithdrawConfirmedAfterTableLeftTheSetStillSends() {
        var model = ArenaMyRequestsModel()
        model.apply(tables: [5])
        XCTAssertEqual(model.tap(table: 5), .confirmWithdraw)
        model.apply(tables: []) // TABLE_FULL arrived while the alert was open
        XCTAssertTrue(model.beginWithdraw(table: 5)) // still sent; the server answers with the set
        model.apply(tables: [])
        XCTAssertFalse(model.isAwaiting(5))
    }
}
