import XCTest
import UIKit
@testable import penteLive

final class DBMovesViewModelTests: XCTestCase {
    private func stats(_ moves: [DBNextMove]) -> DBPositionStats {
        let moveJSON = moves.map {
            "{\"move\":\($0.move),\"games\":\($0.games),\"wins\":\($0.wins),\"winPct\":\($0.winPct)}"
        }.joined(separator: ",")
        let json = "{\"totalGames\":1,\"totalWinPct\":50,\"nextMoves\":[\(moveJSON)]}"
        return try! JSONDecoder().decode(DBPositionStats.self, from: Data(json.utf8))
    }

    func testRowFormatting() {
        let s = stats([DBNextMove(move: 180, games: 1234, wins: 716, winPct: 58.04)])
        let rows = DBMovesViewModel.rows(stats: s, occupied: [], limit: nil, game: 1,
                                         locale: Locale(identifier: "en_US"))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].cell, 180)
        XCTAssertEqual(rows[0].label, "K10")
        XCTAssertEqual(rows[0].pctText, "58%")
        XCTAssertEqual(rows[0].gamesText, "1,234")
        XCTAssertEqual(rows[0].barFraction, 0.5804, accuracy: 1e-9)
    }

    func testRowColourEqualsBoardColour() {
        let moves = [
            DBNextMove(move: 180, games: 100, wins: 70, winPct: 70),
            DBNextMove(move: 181, games: 100, wins: 60, winPct: 60),
            DBNextMove(move: 182, games: 100, wins: 50, winPct: 50),
            DBNextMove(move: 183, games: 100, wins: 40, winPct: 40),
            DBNextMove(move: 184, games: 100, wins: 30, winPct: 30),
        ]
        let rows = DBMovesViewModel.rows(stats: stats(moves), occupied: [], limit: nil, game: 1)
        let colors = DBHeatScale.colors(for: DBHeatScale.displayed(moves, occupied: [], limit: nil))
        XCTAssertEqual(rows.count, 5)
        for r in rows { XCTAssertEqual(r.color, colors[r.cell]) }
    }

    func testLimitChangesDomain() {
        let moves = [
            DBNextMove(move: 180, games: 100, wins: 70, winPct: 70),
            DBNextMove(move: 181, games: 100, wins: 60, winPct: 60),
            DBNextMove(move: 182, games: 100, wins: 50, winPct: 50),
        ]
        let rows = DBMovesViewModel.rows(stats: stats(moves), occupied: [], limit: 2, game: 1)
        XCTAssertEqual(rows.map { $0.cell }, [180, 181])
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        rows[1].color.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Int((r * 255).rounded()), 255)
        XCTAssertEqual(Int((g * 255).rounded()), 0)
    }

    func testOccupiedExcludedAndShowOptions() {
        let moves = [
            DBNextMove(move: 180, games: 100, wins: 70, winPct: 70),
            DBNextMove(move: 181, games: 100, wins: 60, winPct: 60),
        ]
        let rows = DBMovesViewModel.rows(stats: stats(moves), occupied: [180], limit: nil, game: 1)
        XCTAssertEqual(rows.map { $0.cell }, [181])
        XCTAssertEqual(DBMovesViewModel.showOptions, [10, 20, 40, 0])
    }
}
