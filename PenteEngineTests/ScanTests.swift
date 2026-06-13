import XCTest
@testable import penteLive

final class ScanTests: XCTestCase {

    /// 19x19 board of empties; board[row][col], 0 empty / 1 white / 2 black / -1 masked.
    private func emptyBoard() -> [[Int]] {
        Array(repeating: Array(repeating: 0, count: 19), count: 19)
    }

    private func rc(_ row: Int, _ col: Int) -> Int { row * 19 + col }

    // MARK: - captures (run = 2 Pente, run = 3 Keryo)

    func testTwoStoneCustodialCapture() {
        var board = emptyBoard()
        // white(1) places at (9,9); two black(2) at (10,9),(11,9); white flanker (12,9).
        board[9][9] = 1
        board[10][9] = 2
        board[11][9] = 2
        board[12][9] = 1
        let captures = Scan.captures(on: board, at: rc(9, 9), color: 1, run: 2)
        XCTAssertEqual(captures.count, 2)
        XCTAssertEqual(captures.map { $0.position }, [rc(10, 9), rc(11, 9)])
        XCTAssertEqual(captures.map { $0.color }, [2, 2])
        // purity: the caller's board is untouched.
        XCTAssertEqual(board[10][9], 2)
        XCTAssertEqual(board[11][9], 2)
    }

    func testNoCaptureWhenOwnColourAtEndOfPair() {
        var board = emptyBoard()
        // white places at (9,9); (10,9) black, (11,9) WHITE (own colour), (12,9) white.
        board[9][9] = 1
        board[10][9] = 2
        board[11][9] = 1   // own colour where the 2nd captured stone would have to be
        board[12][9] = 1
        let captures = Scan.captures(on: board, at: rc(9, 9), color: 1, run: 2)
        XCTAssertTrue(captures.isEmpty)
    }

    func testThreeStoneKeryoCapture() {
        var board = emptyBoard()
        // white places at (9,9); three black at (10,9),(11,9),(12,9); white flanker (13,9).
        board[9][9] = 1
        board[10][9] = 2
        board[11][9] = 2
        board[12][9] = 2
        board[13][9] = 1
        let captures = Scan.captures(on: board, at: rc(9, 9), color: 1, run: 3)
        XCTAssertEqual(captures.count, 3)
        XCTAssertEqual(captures.map { $0.position }, [rc(10, 9), rc(11, 9), rc(12, 9)])
        XCTAssertEqual(captures.map { $0.color }, [2, 2, 2])
        // purity
        XCTAssertEqual(board[10][9], 2)
        XCTAssertEqual(board[13][9], 1)
    }

    func testKeryoRunDoesNotFireOnTwoStoneLine() {
        var board = emptyBoard()
        // Only two black stones; a run=3 scan must NOT capture them.
        board[9][9] = 1
        board[10][9] = 2
        board[11][9] = 2
        board[12][9] = 1   // flanker at distance 3, but keryo needs it at distance 4
        let captures = Scan.captures(on: board, at: rc(9, 9), color: 1, run: 3)
        XCTAssertTrue(captures.isEmpty)
    }

    func testNoCaptureWhenFarFlankerIsOpponentColour() {
        var board = emptyBoard()
        // white places at (9,9); three black at (10,9),(11,9),(12,9);
        // far flanker (13,9) is ALSO black (opponent) — keryo run must NOT capture.
        board[9][9] = 1
        board[10][9] = 2
        board[11][9] = 2
        board[12][9] = 2
        board[13][9] = 2   // far flanker is opponent (not white) — must NOT capture
        let captures = Scan.captures(on: board, at: rc(9, 9), color: 1, run: 3)
        XCTAssertTrue(captures.isEmpty)
    }

    // MARK: - poof (run = 2)

    func testPoofSelfCapture() {
        var board = emptyBoard()
        // white pair (8,9) + (9,9 placed) flanked by black ends at (7,9) and (10,9).
        board[7][9] = 2
        board[8][9] = 1
        board[9][9] = 1   // placed
        board[10][9] = 2
        let poofed = Scan.poof(on: board, at: rc(9, 9), color: 1, run: 2)
        XCTAssertEqual(poofed.count, 2)
        // placed stone recorded first, then its partner.
        XCTAssertEqual(poofed.map { $0.position }, [rc(9, 9), rc(8, 9)])
        XCTAssertEqual(poofed.map { $0.color }, [1, 1])
        // purity
        XCTAssertEqual(board[8][9], 1)
        XCTAssertEqual(board[9][9], 1)
    }

    func testNoPoofWithoutBothOpponentEnds() {
        var board = emptyBoard()
        board[7][9] = 2   // one end is opponent
        board[8][9] = 1
        board[9][9] = 1   // placed
        board[10][9] = 0  // other end is EMPTY -> no poof
        let poofed = Scan.poof(on: board, at: rc(9, 9), color: 1, run: 2)
        XCTAssertTrue(poofed.isEmpty)
    }

    // MARK: - keryo-poof (run = 3)

    func testKeryoPoofThreeInLine() {
        var board = emptyBoard()
        // Three white in a column from the placed stone: (9,9),(8,9),(7,9),
        // flanked by black at (6,9) [far end] and (10,9) [opposite end].
        board[6][9] = 2
        board[7][9] = 1
        board[8][9] = 1
        board[9][9] = 1   // placed
        board[10][9] = 2
        let poofed = Scan.poof(on: board, at: rc(9, 9), color: 1, run: 3)
        XCTAssertEqual(poofed.count, 3)
        // placed first, then far partner (7,9), then near partner (8,9).
        XCTAssertEqual(poofed.map { $0.position }, [rc(9, 9), rc(7, 9), rc(8, 9)])
        XCTAssertEqual(poofed.map { $0.color }, [1, 1, 1])
    }

    func testKeryoPoofCentredBothPartnersPresent() {
        var board = emptyBoard()
        // placed (9,9) centred between partners (10,8) & (8,10), opponent ends
        // at (11,7) & (7,11) — the centred anti-diagonal case.
        board[9][9] = 1
        board[10][8] = 1
        board[8][10] = 1
        board[11][7] = 2
        board[7][11] = 2
        let poofed = Scan.poof(on: board, at: rc(9, 9), color: 1, run: 3)
        XCTAssertEqual(poofed.count, 3)
        XCTAssertEqual(poofed.map { $0.position }, [rc(9, 9), rc(10, 8), rc(8, 10)])
        XCTAssertEqual(poofed.map { $0.color }, [1, 1, 1])
    }

    func testKeryoPoofRequiresBothEndsNotOnePartnerTwice() {
        // Regression guard for commit 63986f7: the centred anti-diagonal case once
        // checked board[i+1][j-1] (one partner) twice instead of also checking the
        // other partner board[i-1][j+1]. Here that other partner (8,10) is MISSING,
        // so the buggy single-partner logic would still poof. Correct logic requires
        // BOTH partners present -> no poof.
        var board = emptyBoard()
        board[9][9] = 1
        board[10][8] = 1
        // board[8][10] intentionally left empty
        board[11][7] = 2
        board[7][11] = 2
        let poofed = Scan.poof(on: board, at: rc(9, 9), color: 1, run: 3)
        XCTAssertTrue(poofed.isEmpty)
    }
}
