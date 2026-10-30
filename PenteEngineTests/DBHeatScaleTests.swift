import XCTest
import UIKit
@testable import penteLive

final class DBHeatScaleTests: XCTestCase {
    func mv(_ cell: Int, _ pct: Double, games: Int = 100) -> DBNextMove {
        DBNextMove(move: cell, games: games, wins: Int(pct), winPct: pct)
    }

    private func comps(_ c: UIColor) -> (Int, Int, Int) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    func testThreeCandidates() {
        let a = DBHeatScale.rgb(winPct: 40, min: 40, max: 60)
        let b = DBHeatScale.rgb(winPct: 50, min: 40, max: 60)
        let c = DBHeatScale.rgb(winPct: 60, min: 40, max: 60)
        XCTAssertTrue(a == (255, 0, 0)); XCTAssertTrue(b == (255, 255, 0)); XCTAssertTrue(c == (0, 255, 0))
    }

    func testSingleCandidateUsesRawPct() {
        let c = DBHeatScale.rgb(winPct: 55, min: 55, max: 55)
        XCTAssertTrue(c == (230, 255, 0))
        let colors = DBHeatScale.colors(for: [mv(1, 55)])
        XCTAssertTrue(comps(colors[1]!) == (230, 255, 0))
    }

    func testOccupiedExcludedFromDomain() {
        let moves = [mv(0, 0), mv(1, 40), mv(2, 60)]
        let shown = DBHeatScale.displayed(moves, occupied: [0], limit: nil)
        XCTAssertEqual(shown.count, 2)
        let colors = DBHeatScale.colors(for: shown)
        XCTAssertTrue(comps(colors[1]!) == (255, 0, 0))
        XCTAssertTrue(comps(colors[2]!) == (0, 255, 0))
        XCTAssertNil(colors[0])
    }

    func testLimitAppliesAfterSort() {
        let moves = (0..<25).map { mv($0, Double($0)) }
        XCTAssertEqual(DBHeatScale.displayed(moves, occupied: [], limit: 20).count, 20)
    }

    func testAllOccupiedYieldsEmpty() {
        let moves = [mv(0, 10), mv(1, 20)]
        let shown = DBHeatScale.displayed(moves, occupied: [0, 1], limit: 5)
        XCTAssertEqual(shown, [])
        XCTAssertTrue(DBHeatScale.colors(for: shown).isEmpty)
    }
}
