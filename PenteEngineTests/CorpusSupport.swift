import Foundation
import XCTest

/// One decoded golden fixture: the variant + move list that were replayed,
/// plus the snapshot the engine produced. `variant` is a STABLE STRING name so
/// the corpus is decoupled from PenteVariant's integer ordering.
struct CorpusCase: Decodable {
    let name: String
    let variant: String
    let moves: [Int]
    let expected: ExpectedSnapshot
}

struct ExpectedSnapshot: Decodable, Equatable {
    let winner: Int          // 0 none / 1 white / 2 black
    let whiteCaptures: Int
    let blackCaptures: Int
    let board: [[Int]]       // 19x19, 0 empty / 1 white / 2 black / -1 masked
}

/// Plain snapshot a later phase builds by driving the NEW Swift engine, kept
/// free of any engine type (the engine types do not exist in this phase).
struct EngineSnapshot: Equatable {
    let winner: Int
    let whiteCaptures: Int
    let blackCaptures: Int
    let board: [[Int]]
}

enum Corpus {
    /// golden/ sits next to this source file (committed alongside the tests).
    static var goldenDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("golden")
    }

    static func loadCases() throws -> [CorpusCase] {
        let urls = try FileManager.default
            .contentsOfDirectory(at: goldenDirectory,
                                 includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        let decoder = JSONDecoder()
        return try urls.map {
            try decoder.decode(CorpusCase.self, from: Data(contentsOf: $0))
        }
    }
}

/// Pure comparison: nil on match, else a human-readable reason. Phase 2 uses
/// this to diff the NEW Swift engine's output against the golden corpus.
func corpusMismatchReason(_ expected: ExpectedSnapshot,
                          _ actual: EngineSnapshot) -> String? {
    if expected.winner != actual.winner {
        return "winner: expected \(expected.winner), got \(actual.winner)"
    }
    if expected.whiteCaptures != actual.whiteCaptures {
        return "whiteCaptures: expected \(expected.whiteCaptures), "
             + "got \(actual.whiteCaptures)"
    }
    if expected.blackCaptures != actual.blackCaptures {
        return "blackCaptures: expected \(expected.blackCaptures), "
             + "got \(actual.blackCaptures)"
    }
    for r in 0..<19 {
        for c in 0..<19 {
            let e = expected.board[r][c]
            let a = actual.board[r][c]
            if e != a {
                return "board[\(r)][\(c)] (rowCol \(r * 19 + c)): "
                     + "expected \(e), got \(a)"
            }
        }
    }
    return nil
}

/// Asserts the NEW engine's snapshot matches a golden case. Used by Phase 2.
func assertEngineMatchesCorpus(_ corpusCase: CorpusCase,
                               actual: EngineSnapshot,
                               file: StaticString = #filePath,
                               line: UInt = #line) {
    if let reason = corpusMismatchReason(corpusCase.expected, actual) {
        XCTFail("corpus '\(corpusCase.name)' [\(corpusCase.variant)] "
              + "mismatch — \(reason)", file: file, line: line)
    }
}
