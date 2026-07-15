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

    // Finding 1: on a bulk restore-from-scratch (rejoin/poll), the pente-family branch of
    // addMoves(moves:) must feed the engine STONES ONLY while keeping the FULL history —
    // passes included — in `moves`. A renju history with a mid-history 225 pass must
    // reconstruct byte-for-byte the same board as the single-move addMove path, keep every
    // move (pass included) in the list, and still resolve opening tracking to complete.
    func testBulkRestoreWithMidHistoryPassMatchesIncremental() {
        // Reuse the completed-opening move list, then append a stone, a mid-history pass,
        // and a stone. gridSize² (225 for renju) is the pass sentinel.
        let opening = makeRenjuTableWithCompletedOpening().moves
        let pass = 15 * 15
        let history = opening + [150, pass, 151]
        XCTAssertTrue(history.contains(pass), "history must carry a mid-history pass")

        // Reference: rebuild move-by-move through the single-move addMove path (isPass guard).
        let ref = Table(table: 5); ref.game = 31; ref.state.state = .started
        history.forEach { ref.addMove(move: $0) }

        // Under test: restore from scratch through the BULK addMoves(moves:) path.
        let bulk = Table(table: 5); bulk.game = 31; bulk.state.state = .started
        bulk.addMoves(moves: history)

        // Full move list preserved verbatim, pass included.
        XCTAssertEqual(bulk.moves.count, history.count)
        XCTAssertEqual(bulk.moves, history)
        XCTAssertEqual(bulk.moves, ref.moves)

        // Board identical to the incrementally-built reference across the whole grid.
        let cells = bulk.gridSize * bulk.gridSize
        let refBoard = (0..<cells).map { ref.stone(at: $0) }
        let bulkBoard = (0..<cells).map { bulk.stone(at: $0) }
        XCTAssertEqual(bulkBoard, refBoard)

        // Opening tracking resolved on the bulk rejoin path.
        XCTAssertTrue(bulk.state.renju.complete)
    }
}
