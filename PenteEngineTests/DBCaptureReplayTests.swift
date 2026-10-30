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

    func testSubtitleNameOnlyForGomoku() {
        XCTAssertEqual(subtitle(5, [180, 181]).string, "Gomoku")
    }
}
