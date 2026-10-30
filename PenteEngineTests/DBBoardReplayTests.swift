import XCTest
@testable import penteLive

final class DBBoardReplayTests: XCTestCase {
    /// Flat 19x19 buffer (row stride 19), like AbstractBoard.
    private var cells = [Int32](repeating: 7, count: 361)

    @discardableResult
    private func replay(_ game: Int, _ moves: [Int], until: Int? = nil) -> DBReplayResult {
        cells.withUnsafeMutableBufferPointer {
            DBBoardReplayer.replay(game: game, moves: moves, until: until ?? moves.count, into: $0.baseAddress!)
        }
    }

    private func at(_ row: Int, _ col: Int) -> Int32 { cells[row * 19 + col] }

    func testClearsTheWholeBufferFirst() {
        replay(21, [])
        XCTAssertEqual(cells.filter { $0 != 0 }.count, 0, "stale values outside the 9x9 corner too")
    }

    func testGoNineByNineEdgeCapture() {
        // B A9 (0), W B9 (1), B C9 (2), W E5 (40), B B8 (10): W B9 has no liberties.
        let r = replay(21, [0, 1, 2, 40, 10])
        XCTAssertEqual(at(0, 1), 0)
        XCTAssertEqual(at(0, 0), 2)
        XCTAssertEqual(at(1, 1), 2)
        XCTAssertEqual(at(4, 4), 1)
        XCTAssertEqual(r.whiteCaptures, 1)
        XCTAssertEqual(r.blackCaptures, 0)
        XCTAssertEqual(r.koCell, -1)
    }

    func testUntilStopsBeforeTheCapture() {
        replay(21, [0, 1, 2, 40, 10], until: 4)
        XCTAssertEqual(at(0, 1), 1)
        XCTAssertEqual(at(1, 1), 0)
    }

    private let koLine = [1, 2, 9, 20, 19, 12, 40, 10, 11]

    func testGoKoCellIsMarkedBlocked() {
        // B 11 takes the lone W stone at 10; W may not retake at 10 at once.
        let r = replay(21, koLine)
        XCTAssertEqual(r.koCell, 10)
        XCTAssertEqual(at(1, 1), -1, "blocked, not drawn (> 0 only), not tappable (== 0 only)")
        XCTAssertEqual(at(1, 2), 2)
        XCTAssertEqual(r.whiteCaptures, 1)
    }

    func testKoIsNotMarkedAfterAPass() {
        let r = replay(21, koLine + [81])
        XCTAssertEqual(at(1, 1), 0)
        XCTAssertEqual(r.koCell, -1)
    }

    func testPassKeepsColourParityAndIsNeverPlaced() {
        replay(21, [40, 81, 41])
        XCTAssertEqual(at(4, 4), 2)
        XCTAssertEqual(at(4, 5), 2, "black again after white passed")
        XCTAssertEqual(cells.filter { $0 != 0 }.count, 2)
    }

    func testGoJunkIsSkipped() {
        replay(21, [40, -3, 999, 82, 41])
        XCTAssertEqual(at(4, 4), 2)
        XCTAssertEqual(at(4, 5), 1)
        XCTAssertEqual(cells.filter { $0 != 0 }.count, 2)
    }

    func testDeadStonesAreRemovedAfterDoublePass() {
        replay(21, [40, 41, 81, 81, 41])
        XCTAssertEqual(at(4, 4), 2)
        XCTAssertEqual(at(4, 5), 0)
    }

    func testGoNineteenAndThirteenUseTheirGrid() {
        replay(19, [360, 0])
        XCTAssertEqual(at(18, 18), 2)
        XCTAssertEqual(at(0, 0), 1)
        replay(24, [168, 13])
        XCTAssertEqual(at(12, 12), 2)
        XCTAssertEqual(at(1, 0), 1, "13 = row 1 col 0 on 13x13")
    }

    func testRenjuIsBlackFirstWithoutCaptures() {
        let r = replay(31, [112, 113])
        XCTAssertEqual(at(7, 7), 2)
        XCTAssertEqual(at(7, 8), 1)
        XCTAssertEqual(r, DBReplayResult(whiteCaptures: 0, blackCaptures: 0, koCell: -1))
        replay(31, [112, 225, 224])
        XCTAssertEqual(at(14, 14), 2, "224 is P1; the pass keeps the parity")
        XCTAssertEqual(cells.filter { $0 != 0 }.count, 2)
    }

    func testRenjuSurroundedStoneIsNotCaptured() {
        // No Pente pair captures in Renju: B 112, W 113 W 114, B 115 keeps both.
        replay(31, [112, 113, 0, 114, 115])
        XCTAssertEqual(at(7, 8), 1)
        XCTAssertEqual(at(7, 9), 1)
        XCTAssertEqual(at(7, 10), 2)
    }

    func testPenteMatchesLegacyEngine() {
        let moves = [180, 181, 200, 182, 183, 361, -1]
        let r = replay(1, moves)
        let ref = UnsafeMutablePointer<AbstractBoard>.allocate(capacity: 19)
        defer { ref.deallocate() }
        ref.initialize(repeating: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), count: 19)
        let g = LegacyPenteGame()
        g.abstractBoard = ref
        let clean = [180, 181, 200, 182, 183]
        g.replayMoves(clean.map { NSNumber(value: $0) }, variant: .pente, untilMove: clean.count)
        let flat = UnsafeMutableRawPointer(ref).assumingMemoryBound(to: Int32.self)
        XCTAssertEqual(cells, (0 ..< 361).map { flat[$0] })
        XCTAssertEqual(r.blackCaptures, Int(g.blackCaptures))
        XCTAssertEqual(r.blackCaptures, 2)
        XCTAssertEqual(at(9, 10), 0)
        g.abstractBoard = nil
    }

    func testObjCEntryReportsCaptures() {
        var w: Int32 = 9, b: Int32 = 9
        cells.withUnsafeMutableBufferPointer {
            DBBoardReplayer.replay(game: 21, moves: [0, 1, 2, 40, 10].map { NSNumber(value: $0) },
                                   until: 5, into: $0.baseAddress!, whiteCaptures: &w, blackCaptures: &b)
        }
        XCTAssertEqual(w, 1)
        XCTAssertEqual(b, 0)
        XCTAssertEqual(at(0, 1), 0)
    }
}
