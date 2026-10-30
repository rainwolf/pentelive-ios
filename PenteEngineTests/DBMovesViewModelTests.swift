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

    func testNineByNineLabelsAndOffBoardRowsDropped() {
        let s = stats([DBNextMove(move: 0, games: 10, wins: 6, winPct: 60),
                       DBNextMove(move: 81, games: 30, wins: 20, winPct: 66),
                       DBNextMove(move: 40, games: 20, wins: 10, winPct: 50)])
        let rows = DBMovesViewModel.rows(stats: s, occupied: [], limit: nil, game: 22)
        XCTAssertEqual(rows.map { $0.label }, ["A9", "E5"])
        let renju = DBMovesViewModel.rows(stats: stats([DBNextMove(move: 113, games: 10, wins: 5, winPct: 50)]),
                                          occupied: [], limit: nil, game: 31)
        XCTAssertEqual(renju.map { $0.label }, ["J8"])
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

    func testPopularSortOrdersRowsByGamesAndShowNAppliesAfterSorting() {
        let moves = [
            DBNextMove(move: 180, games: 10, wins: 9, winPct: 90),
            DBNextMove(move: 181, games: 500, wins: 200, winPct: 40),
            DBNextMove(move: 182, games: 300, wins: 150, winPct: 50),
        ]
        let all = DBMovesViewModel.rows(stats: stats(moves), occupied: [], limit: nil, game: 1, sort: .games)
        XCTAssertEqual(all.map { $0.cell }, [181, 182, 180])
        let top2 = DBMovesViewModel.rows(stats: stats(moves), occupied: [], limit: 2, game: 1, sort: .games)
        XCTAssertEqual(top2.map { $0.cell }, [181, 182])
        // Colour domain is the two displayed moves (min-max), not all three.
        let colors = DBHeatScale.colors(for: DBHeatScale.displayed(moves, occupied: [], limit: 2, sort: .games))
        for r in top2 { XCTAssertEqual(r.color, colors[r.cell]) }
    }

    func testDefaultSortIsWinRate() {
        let moves = [
            DBNextMove(move: 180, games: 4, wins: 4, winPct: 100),
            DBNextMove(move: 181, games: 500, wins: 300, winPct: 60),
        ]
        let rows = DBMovesViewModel.rows(stats: stats(moves), occupied: [], limit: nil, game: 1)
        XCTAssertEqual(rows.map { $0.cell }, [181, 180]) // low-sample row last
    }
}
