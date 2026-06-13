//
//  TableEngineRoutingTests.swift
//  PenteEngineTests
//

import XCTest
@testable import penteLive

final class TableEngineRoutingTests: XCTestCase {

    // White plays both flanking stones of a 1-3-1 row; the two black stones between
    // them are captured. Move order alternates white, black, white, black, white.
    //   idx0 white (9,5)=176   idx1 black (9,6)=177   idx2 white (0,0)=0
    //   idx3 black (9,7)=178   idx4 white (9,8)=179  -> captures (9,6),(9,7)
    func testCaptureSequenceDelegatesToEngine() {
        let table = Table(table: 1)
        table.game = GameEnum.pente.rawValue

        var animated: [Capture] = []
        table.onCaptures = { captures in animated = captures }

        for move in [9 * 19 + 5, 9 * 19 + 6, 0, 9 * 19 + 7, 9 * 19 + 8] {
            table.addMove(move: move)
        }

        // Board is the engine's board, read via Table.stone(at:).
        XCTAssertEqual(table.stone(at: 9 * 19 + 5), 1)
        XCTAssertEqual(table.stone(at: 9 * 19 + 8), 1)
        XCTAssertEqual(table.stone(at: 9 * 19 + 6), 0)
        XCTAssertEqual(table.stone(at: 9 * 19 + 7), 0)

        // Counters are the engine's counters (whiteCaptures/blackCaptures count
        // captured stones of that colour: two black stones were captured).
        XCTAssertEqual(table.blackCaptures, 2)
        XCTAssertEqual(table.whiteCaptures, 0)

        // The capture animation seam received exactly the two captured cells.
        XCTAssertEqual(animated.count, 2)
        XCTAssertEqual(Set(animated.map { $0.position }), [9 * 19 + 6, 9 * 19 + 7])
        XCTAssertTrue(animated.allSatisfy { $0.color == 2 })
    }

    // Undo must reset the stateful engine before replaying the surviving moves.
    // Without the reset the engine accumulates stale state (undone stones persist,
    // colours invert, captures double-count). The undone Table must therefore match
    // a fresh Table that played only the remaining moves.
    func testUndoLastMoveReplaysThroughEngine() {
        // Same 1-3-1 sequence as above: the 5th move (9,8) captures (9,6) and (9,7).
        let full = [9 * 19 + 5, 9 * 19 + 6, 0, 9 * 19 + 7, 9 * 19 + 8]

        let table = Table(table: 1)
        table.game = GameEnum.pente.rawValue
        for move in full { table.addMove(move: move) }

        // Sanity: the capturing move removed the two black stones.
        XCTAssertEqual(table.blackCaptures, 2)
        XCTAssertEqual(table.stone(at: 9 * 19 + 6), 0)
        XCTAssertEqual(table.stone(at: 9 * 19 + 7), 0)

        // Undo the capturing move.
        table.undoLastMove()

        // Reference: a fresh Table that only ever played the first four moves.
        let reference = Table(table: 1)
        reference.game = GameEnum.pente.rawValue
        for move in full[0 ..< 4] { reference.addMove(move: move) }

        assertBoardsMatch(table, reference)
        XCTAssertEqual(table.moves.count, 4)
        XCTAssertEqual(table.blackCaptures, reference.blackCaptures)   // back to 0
        XCTAssertEqual(table.whiteCaptures, reference.whiteCaptures)
        XCTAssertEqual(table.blackCaptures, 0)
        // The previously-captured stones are back on the board.
        XCTAssertEqual(table.stone(at: 9 * 19 + 6), 2)
        XCTAssertEqual(table.stone(at: 9 * 19 + 7), 2)

        // A second undo still works (engine reset again, not corrupted).
        table.undoLastMove()
        let reference2 = Table(table: 1)
        reference2.game = GameEnum.pente.rawValue
        for move in full[0 ..< 3] { reference2.addMove(move: move) }
        assertBoardsMatch(table, reference2)
        XCTAssertEqual(table.moves.count, 3)
    }

    // Legacy surfaced the centre opening mask (-1 cells) only when `rated ||
    // (speed)gPente`. The engine masks intrinsically, so syncFromEngine must drop
    // those -1 cells for unrated non-gPente games — keeping the centre tappable.
    func testOpeningMaskGatedByRatedFlag() {
        // Two played moves trigger the engine's tournament mask (moveCount == 2).
        // The first stone takes the centre (9,9); (8,8) stays empty -> would be masked.
        func playTwo(_ table: Table) {
            table.addMove(move: 9 * 19 + 9)   // centre (kept, never masked)
            table.addMove(move: 0)            // corner (far from centre)
        }

        // Unrated Pente: the mask must NOT surface -> no -1 anywhere.
        let unrated = Table(table: 1)
        unrated.game = GameEnum.pente.rawValue
        unrated.rated = false
        playTwo(unrated)
        XCTAssertEqual(unrated.abstractBoard[8][8], 0)
        XCTAssertFalse(unrated.abstractBoard.contains { $0.contains(-1) })

        // Rated Pente: the mask DOES surface.
        let rated = Table(table: 1)
        rated.game = GameEnum.pente.rawValue
        rated.rated = true
        playTwo(rated)
        XCTAssertEqual(rated.abstractBoard[8][8], -1)
        XCTAssertTrue(rated.abstractBoard.contains { $0.contains(-1) })

        // gPente surfaces the mask even when unrated (the `|| (speed)gPente` term).
        let gpente = Table(table: 1)
        gpente.game = GameEnum.gPente.rawValue
        gpente.rated = false
        playTwo(gpente)
        XCTAssertEqual(gpente.abstractBoard[8][8], -1)
    }

    // Undoing a NON-capturing move must rebuild via engine.replay and leave the
    // earlier captures intact (blackCaptures stays 2, the captured cells stay empty).
    // (The plan names this testUndoLastMoveReplaysThroughEngine; that name is already
    // taken by the broader Task 3.1 regression above, so this carries the plan's exact
    // assertions under a distinct name.)
    func testUndoLastNonCapturingMoveReplaysThroughEngine() {
        let table = Table(table: 1)
        table.game = GameEnum.pente.rawValue

        // Capture sequence, then one extra (non-capturing) black move at idx5.
        for move in [9 * 19 + 5, 9 * 19 + 6, 0, 9 * 19 + 7, 9 * 19 + 8] {
            table.addMove(move: move)
        }
        XCTAssertEqual(table.blackCaptures, 2)

        table.addMove(move: 1) // black at (0,1), no capture
        XCTAssertEqual(table.moves.count, 6)

        table.undoLastMove()

        // Back to the post-capture position, rebuilt by engine.replay.
        XCTAssertEqual(table.moves, [9 * 19 + 5, 9 * 19 + 6, 0, 9 * 19 + 7, 9 * 19 + 8])
        XCTAssertEqual(table.blackCaptures, 2)
        XCTAssertEqual(table.whiteCaptures, 0)
        XCTAssertEqual(table.stone(at: 9 * 19 + 6), 0)
        XCTAssertEqual(table.stone(at: 9 * 19 + 7), 0)
        XCTAssertEqual(table.stone(at: 9 * 19 + 8), 1)
        XCTAssertEqual(table.stone(at: 0), 1)
    }

    // Undo on a fresh Table with no moves must be a safe no-op. Without the guard,
    // undoLastMove() computes moves[0 ..< -1] and fatal-errors at runtime.
    func testUndoOnEmptyMovesIsSafeNoOp() {
        let table = Table(table: 1)
        table.game = GameEnum.pente.rawValue

        // No moves played: undo must not crash.
        table.undoLastMove()

        // State stays empty.
        XCTAssertTrue(table.moves.isEmpty)
        XCTAssertEqual(table.whiteCaptures, 0)
        XCTAssertEqual(table.blackCaptures, 0)
        for cell in 0 ..< 361 {
            XCTAssertEqual(table.stone(at: cell), 0, "board not empty at cell \(cell)")
        }
    }

    private func assertBoardsMatch(_ a: Table, _ b: Table,
                                   file: StaticString = #filePath, line: UInt = #line) {
        for cell in 0 ..< 361 {
            XCTAssertEqual(a.stone(at: cell), b.stone(at: cell),
                           "board mismatch at cell \(cell)", file: file, line: line)
        }
    }
}
