import XCTest
@testable import penteLive

final class PenteGameCorpusTests: XCTestCase {

    /// Maps the corpus's stable variant string to the Swift `PenteVariant`. The golden
    /// JSON stores variants as names (decoupled from PenteVariant's integer ordering);
    /// note g-pente is `.gpente` (lowercase).
    private static let variantByName: [String: PenteVariant] = [
        "pente": .pente,
        "keryoPente": .keryoPente,
        "oPente": .oPente,
        "poofPente": .poofPente,
        "dPente": .dPente,
        "dkPente": .dkPente,
        "gpente": .gpente,
        "swap2Pente": .swap2Pente,
        "swap2Keryo": .swap2Keryo,
        "gomoku": .gomoku,
        "connect6": .connect6,
    ]

    func testEngineReproducesGoldenCorpus() throws {
        let cases = try Corpus.loadCases()
        XCTAssertEqual(cases.count, 8, "expected 8 committed golden fixtures")

        for corpusCase in cases {
            let variant = try XCTUnwrap(
                Self.variantByName[corpusCase.variant],
                "unmapped corpus variant '\(corpusCase.variant)'")

            // Drive the NEW Swift engine over the recorded move list (frozen engine API).
            let e = PenteGame(variant: variant)
            let result = e.replay(corpusCase.moves, until: corpusCase.moves.count)

            // Read all 361 cells via the frozen `stone(at:)` accessor (row-major).
            let flat = (0...360).map { e.stone(at: $0) }

            // Reshape to the 19x19 board the golden uses. The opening mask (-1) is a
            // render-only overlay the legacy replayMoves (the corpus source) never
            // wrote, so normalise it back to 0 before comparing.
            let board: [[Int]] = (0..<19).map { row in
                (0..<19).map { col -> Int in
                    let v = flat[row * 19 + col]
                    return v == -1 ? 0 : v
                }
            }

            let actual = EngineSnapshot(
                winner: result.winner,
                whiteCaptures: e.whiteCaptures,
                blackCaptures: e.blackCaptures,
                board: board)
            assertEngineMatchesCorpus(corpusCase, actual: actual)
        }
    }
}
