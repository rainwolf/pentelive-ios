import XCTest
@testable import penteLive

final class DBMoveRankingTests: XCTestCase {
    private func mv(_ cell: Int, games: Int, wins: Int) -> DBNextMove {
        DBNextMove(move: cell, games: games, wins: wins, winPct: games == 0 ? 0 : Double(wins) * 100 / Double(games))
    }

    func testLabels() {
        XCTAssertEqual(DBMoveRanking.label(cell: 180, gridSize: 19), "K10")
        XCTAssertEqual(DBMoveRanking.label(cell: 0, gridSize: 19), "A19")
        XCTAssertEqual(DBMoveRanking.label(cell: 360, gridSize: 19), "T1")
    }

    func testPassLabel() {
        XCTAssertEqual(DBMoveRanking.label(cell: 361, gridSize: 19), "PASS")
        XCTAssertEqual(DBMoveRanking.label(cell: 81, gridSize: 9), "PASS")
    }

    func testLowSampleRowsSortLast() {
        let r = DBMoveRanking.sorted([mv(1, games: 4, wins: 4), mv(2, games: 100, wins: 40)])
        XCTAssertEqual(r.map { $0.move }, [2, 1])
    }

    func testWilsonOrderWithinGroup() {
        let r = DBMoveRanking.sorted([mv(1, games: 10, wins: 7), mv(2, games: 100, wins: 60)])
        XCTAssertEqual(r.map { $0.move }, [2, 1])
    }

    func testTieBreakGamesDesc() {
        // Both rows have games >= 5 and Wilson == 0, so only games-descending decides the order.
        let sorted = DBMoveRanking.sorted([mv(1, games: 6, wins: 0), mv(2, games: 10, wins: 0)])
        XCTAssertEqual(sorted.map { $0.move }, [2, 1])
    }

    func testWilsonZeroGames() {
        XCTAssertEqual(DBMoveRanking.wilsonLowerBound(wins: 0, games: 0), 0)
    }

    func testWilsonKnownValue() {
        XCTAssertEqual(DBMoveRanking.wilsonLowerBound(wins: 50, games: 100), 0.4038, accuracy: 0.0005)
    }
}
