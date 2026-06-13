import XCTest

final class CorpusHelperTests: XCTestCase {

    func testLoadsAllGoldenCases() throws {
        let cases = try Corpus.loadCases()
        XCTAssertGreaterThanOrEqual(cases.count, 2,
                                    "expected at least the committed golden fixtures")
        let names = Set(cases.map { $0.name })
        XCTAssertTrue(names.contains("keryo_poof_antidiagonal"))
        XCTAssertTrue(names.contains("pente_capture_threshold_win"))
    }

    func testMatchingSnapshotHasNoMismatch() throws {
        let cases = try Corpus.loadCases()
        let c = try XCTUnwrap(cases.first { $0.name == "pente_pair_capture" })
        let actual = EngineSnapshot(
            winner: c.expected.winner,
            whiteCaptures: c.expected.whiteCaptures,
            blackCaptures: c.expected.blackCaptures,
            board: c.expected.board)
        XCTAssertNil(corpusMismatchReason(c.expected, actual))
    }

    func testDetectsBoardMismatch() throws {
        let cases = try Corpus.loadCases()
        let c = try XCTUnwrap(cases.first { $0.name == "pente_pair_capture" })
        var board = c.expected.board
        board[0][0] = (board[0][0] == 0) ? 1 : 0   // flip one cell
        let actual = EngineSnapshot(
            winner: c.expected.winner,
            whiteCaptures: c.expected.whiteCaptures,
            blackCaptures: c.expected.blackCaptures,
            board: board)
        let reason = corpusMismatchReason(c.expected, actual)
        XCTAssertNotNil(reason)
        XCTAssertTrue(reason!.contains("board[0][0]"))
    }

    func testMaskedCellsAreDontCare() throws {
        func emptyBoard() -> [[Int]] {
            Array(repeating: Array(repeating: 0, count: 19), count: 19)
        }

        // A masked (-1) expected cell faces a real (1) actual cell. The masked
        // rule must treat this as don't-care, so there is no mismatch.
        var maskedExpectedBoard = emptyBoard()
        maskedExpectedBoard[3][4] = -1
        var realActualBoard = emptyBoard()
        realActualBoard[3][4] = 1
        let maskedExpected = ExpectedSnapshot(
            winner: 0, whiteCaptures: 0, blackCaptures: 0,
            board: maskedExpectedBoard)
        let realActual = EngineSnapshot(
            winner: 0, whiteCaptures: 0, blackCaptures: 0,
            board: realActualBoard)
        XCTAssertNil(corpusMismatchReason(maskedExpected, realActual),
                     "masked (-1) cell must be treated as don't-care")

        // A genuine 1-vs-2 difference at the same cell must still be reported.
        var whiteBoard = emptyBoard()
        whiteBoard[3][4] = 1
        var blackBoard = emptyBoard()
        blackBoard[3][4] = 2
        let realExpected = ExpectedSnapshot(
            winner: 0, whiteCaptures: 0, blackCaptures: 0, board: whiteBoard)
        let realDiffActual = EngineSnapshot(
            winner: 0, whiteCaptures: 0, blackCaptures: 0, board: blackBoard)
        let reason = corpusMismatchReason(realExpected, realDiffActual)
        XCTAssertNotNil(reason, "genuine 1-vs-2 difference must be reported")
        XCTAssertTrue(reason!.contains("board[3][4]"))
    }

    func testDetectsCaptureMismatch() throws {
        let cases = try Corpus.loadCases()
        let c = try XCTUnwrap(cases.first { $0.name == "keryo_triple_capture" })
        let actual = EngineSnapshot(
            winner: c.expected.winner,
            whiteCaptures: c.expected.whiteCaptures,
            blackCaptures: c.expected.blackCaptures + 1,
            board: c.expected.board)
        XCTAssertEqual(
            corpusMismatchReason(c.expected, actual)?.contains("blackCaptures"),
            true)
    }
}
