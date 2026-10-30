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
        // Ascending winPct input: a prefix taken before sorting would return cells 0..<20.
        let moves = (0..<25).map { mv($0, Double($0)) }
        let shown = DBHeatScale.displayed(moves, occupied: [], limit: 20)
        XCTAssertEqual(shown.map { $0.move }, Array((5...24).reversed()))
    }

    func testOccupiedDroppedBeforeLimitCut() {
        // Cell 99 ranks first but is occupied; it must not consume one of the 3 slots.
        let moves = [mv(99, 90), mv(1, 80), mv(2, 70), mv(3, 60), mv(4, 50)]
        let shown = DBHeatScale.displayed(moves, occupied: [99], limit: 3)
        XCTAssertEqual(shown.map { $0.move }, [1, 2, 3])
    }

    func testAllOccupiedYieldsEmpty() {
        let moves = [mv(0, 10), mv(1, 20)]
        let shown = DBHeatScale.displayed(moves, occupied: [0, 1], limit: 5)
        XCTAssertEqual(shown, [])
        XCTAssertTrue(DBHeatScale.colors(for: shown).isEmpty)
    }

    func testPopularSortKeepsMostPlayedAndLimitAppliesAfterSorting() {
        func g(_ cell: Int, games: Int, pct: Double) -> DBNextMove {
            DBNextMove(move: cell, games: games, wins: Int(Double(games) * pct / 100), winPct: pct)
        }
        let moves = [g(1, games: 10, pct: 90), g(2, games: 500, pct: 40), g(3, games: 300, pct: 50), g(4, games: 100, pct: 60)]
        let shown = DBHeatScale.displayed(moves, occupied: [], limit: 2, sort: .games)
        XCTAssertEqual(shown.map { $0.move }, [2, 3])
        let colors = DBHeatScale.colors(for: shown)
        XCTAssertEqual(Set(colors.keys), [2, 3], "heat covers exactly the displayed moves")
    }
}
