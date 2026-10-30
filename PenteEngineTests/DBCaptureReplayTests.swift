import XCTest
import UIKit
@testable import penteLive

final class DBCaptureReplayTests: XCTestCase {
    func testPenteCaptureCounted() {
        // White 180, black 181, white 200, black 182, white 183 captures 181 and 182.
        let s = DBCaptureReplay.summary(game: 1, moves: [180, 181, 200, 182, 183])
        XCTAssertEqual(s.blackStonesCaptured, 2)
        XCTAssertEqual(s.whiteStonesCaptured, 0)
        XCTAssertTrue(s.showsIcons)
    }

    func testGomokuHidesIcons() {
        XCTAssertFalse(DBCaptureReplay.summary(game: 5, moves: [180, 181]).showsIcons)
    }

    func testConnect6HidesIcons() {
        XCTAssertFalse(DBCaptureReplay.summary(game: 13, moves: [180, 181, 182]).showsIcons)
    }

    func testGoCaptureCountedWithIcons() {
        let s = DBCaptureReplay.summary(game: 21, moves: [0, 1, 2, 40, 10])
        XCTAssertEqual(s, DBCaptureSummary(whiteStonesCaptured: 1, blackStonesCaptured: 0, showsIcons: true))
        XCTAssertTrue(DBCaptureReplay.summary(game: 19, moves: []).showsIcons)
    }

    func testGoPassDoesNotBreakParity() {
        // B A9, W B9, B C9, W passes, B B8 captures W B9. Dropping the pass
        // would make B8 white and capture nothing.
        let s = DBCaptureReplay.summary(game: 22, moves: [0, 1, 2, 81, 10])
        XCTAssertEqual(s.whiteStonesCaptured, 1)
    }

    func testRenjuHidesIcons() {
        XCTAssertFalse(DBCaptureReplay.summary(game: 31, moves: [112, 113]).showsIcons)
    }

    private func subtitle(_ game: Int, _ moves: [Int]) -> NSAttributedString {
        DBSubtitleFormatter.attributedSubtitle(game: game, moves: moves.map { NSNumber(value: $0) },
                                               font: .systemFont(ofSize: 13))
    }

    func testSubtitleTextPente() {
        XCTAssertEqual(subtitle(1, [180, 181, 200, 182, 183]).string, "Pente  ● × 0  ● × 2")
    }

    func testSubtitleIconColours() {
        let a = subtitle(1, [180, 181, 200, 182, 183])
        let ns = a.string as NSString
        let first = ns.range(of: "●")
        let second = ns.range(of: "●", options: [], range: NSRange(location: first.location + 1,
                                                                    length: ns.length - first.location - 1))
        let c1 = a.attribute(.foregroundColor, at: first.location, effectiveRange: nil) as? UIColor
        let c2 = a.attribute(.foregroundColor, at: second.location, effectiveRange: nil) as? UIColor
        XCTAssertEqual(c1?.dbHexString, "#FFFFFF")
        XCTAssertEqual(c2?.dbHexString, "#16181D")
    }

    func testSubtitleGoAndRenju() {
        XCTAssertEqual(subtitle(21, [0, 1, 2, 40, 10]).string, "Go (9x9)  ● × 1  ● × 0")
        XCTAssertEqual(subtitle(32, [112, 113]).string, "Speed Renju")
    }

    func testSubtitleNameOnlyForGomoku() {
        XCTAssertEqual(subtitle(5, [180, 181]).string, "Gomoku")
    }

    func testOutOfRangeCellsAreIgnored() {
        // Pass sentinel (gridSize^2), negatives and huge values must never reach the board.
        let clean = DBCaptureReplay.summary(game: 1, moves: [180, 181, 200, 182, 183])
        let dirty = DBCaptureReplay.summary(game: 1, moves: [180, 361, 181, -1, 200, 999, 182, 183])
        XCTAssertEqual(dirty, clean)
        XCTAssertEqual(DBCaptureReplay.summary(game: 1, moves: [361]).blackStonesCaptured, 0)
    }

    func testFirstSubtitleDotHasInkStroke() {
        let a = subtitle(1, [180, 181, 200, 182, 183])
        let at = (a.string as NSString).range(of: "●").location
        let stroke = a.attribute(.strokeColor, at: at, effectiveRange: nil) as? UIColor
        let width = a.attribute(.strokeWidth, at: at, effectiveRange: nil) as? NSNumber
        XCTAssertEqual(stroke?.dbHexString, "#16181D")
        XCTAssertLessThan(width?.doubleValue ?? 0, 0, "negative width = stroke and fill")
    }
}
