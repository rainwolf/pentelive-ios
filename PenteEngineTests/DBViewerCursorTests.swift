@testable import penteLive
import XCTest

final class DBViewerCursorTests: XCTestCase {
    override func tearDown() {
        DBStepPolicy.connect6StepsPerTurn = false
        super.tearDown()
    }

    func testStartsAtEnd() {
        let c = DBViewerCursor(moves: [180, 181, 200], game: 1)
        XCTAssertEqual(c.index, 3)
        XCTAssertEqual(c.visibleMoves, [180, 181, 200])
        let empty = DBViewerCursor(moves: [], game: 1)
        XCTAssertEqual(empty.index, 0)
        XCTAssertEqual(empty.visibleMoves, [])
    }

    func testBackForward() {
        var c = DBViewerCursor(moves: [180, 181, 200], game: 1)
        XCTAssertFalse(c.forward(), "already at the end")
        XCTAssertTrue(c.back())
        XCTAssertEqual(c.index, 2)
        XCTAssertEqual(c.visibleMoves, [180, 181])
        XCTAssertTrue(c.back())
        XCTAssertTrue(c.back())
        XCTAssertEqual(c.index, 0)
        XCTAssertFalse(c.back(), "already at the start")
        XCTAssertTrue(c.forward())
        XCTAssertEqual(c.visibleMoves, [180])
    }

    func testJumpClamps() {
        var c = DBViewerCursor(moves: [180, 181, 200], game: 1)
        c.jump(to: 1)
        XCTAssertEqual(c.index, 1)
        c.jump(to: -5)
        XCTAssertEqual(c.index, 0)
        c.jump(to: 99)
        XCTAssertEqual(c.index, 3)
    }

    func testConnect6TurnStepping() {
        let moves = [180, 181, 182, 183, 184, 185, 186]
        // Default (shared ruling): Connect6 steps one stone at a time.
        var single = DBViewerCursor(moves: moves, game: 13)
        XCTAssertTrue(single.back())
        XCTAssertEqual(single.index, 6)

        // Turn mode: black's opening stone, then two stones per turn, so the
        // turn boundaries are 0, 1, 3, 5, 7.
        DBStepPolicy.connect6StepsPerTurn = true
        var c = DBViewerCursor(moves: moves, game: 13)
        var backs: [Int] = []
        while c.back() { backs.append(c.index) }
        XCTAssertEqual(backs, [5, 3, 1, 0])
        var forwards: [Int] = []
        while c.forward() { forwards.append(c.index) }
        XCTAssertEqual(forwards, [1, 3, 5, 7])

        // From a mid-turn index each step lands on a boundary.
        c.jump(to: 4)
        XCTAssertTrue(c.forward())
        XCTAssertEqual(c.index, 5)
        c.jump(to: 4)
        XCTAssertTrue(c.back())
        XCTAssertEqual(c.index, 3)

        // A trailing half turn is still reachable.
        var odd = DBViewerCursor(moves: Array(moves.prefix(6)), game: 13)
        odd.jump(to: 5)
        XCTAssertTrue(odd.forward())
        XCTAssertEqual(odd.index, 6)

        // Other games never turn-step.
        var pente = DBViewerCursor(moves: moves, game: 1)
        XCTAssertTrue(pente.back())
        XCTAssertEqual(pente.index, 6)
    }
}
