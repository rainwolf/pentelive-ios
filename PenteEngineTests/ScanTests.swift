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
}
