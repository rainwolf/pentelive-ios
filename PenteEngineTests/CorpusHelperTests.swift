import XCTest

final class CorpusHelperTests: XCTestCase {

    func testLoadsAllGoldenCases() throws {
        let cases = try Corpus.loadCases()
        XCTAssertEqual(cases.count, 8, "expected 8 committed golden fixtures")
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
