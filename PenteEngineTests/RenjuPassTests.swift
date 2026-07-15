import XCTest
@testable import penteLive

final class RenjuPassTests: XCTestCase {

    // Mirrors RenjuTrackingTests.testBranchAMove5ThenWindow5ThenMove6Completes: 6 stones,
    // no swaps, Branch A — advanceRenjuTracking marks tracking complete.
    func makeRenjuTableWithCompletedOpening() -> Table {
        let t = Table(table: 5); t.game = 31; t.state.state = .started
        [112, 113, 97, 98].forEach { t.addMove(move: $0) }
        t.applyRenjuSwap(swap: false, move: 129) // branch A
        t.addMove(move: 129)                     // move 5 -> window 5 opens
        t.applyRenjuSwap(swap: false, move: -1)  // bare window-5 decline
        t.addMove(move: 200)                     // move 6
        XCTAssertTrue(t.state.renju.complete, "fixture setup must reach completed tracking")
        return t
    }

    func testPassMoveKeptInListNotOnBoard() {
        let t = makeRenjuTableWithCompletedOpening()
        let n = t.moves.count
        let pass = t.gridSize * t.gridSize
        let boardBefore = (0..<(t.gridSize * t.gridSize)).map { t.stone(at: $0) }

        t.addMove(move: pass)            // must not trap

        XCTAssertEqual(t.moves.count, n + 1)
        XCTAssertTrue(t.isPass(pass))
        XCTAssertTrue(t.state.renju.complete) // tracking unaffected
        // no cell changed: stone(at:) over the full board equals the pre-pass snapshot
        let boardAfter = (0..<(t.gridSize * t.gridSize)).map { t.stone(at: $0) }
        XCTAssertEqual(boardAfter, boardBefore)
    }
}
