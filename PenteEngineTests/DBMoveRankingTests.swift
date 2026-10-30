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

    func testSmallSampleHighPctRanksBelowLargerSampleLowerPct() {
        // 7 of 10 (70%) is below 120 of 200 (60%): 10 games are too few to trust the rate.
        let r = DBMoveRanking.sorted([mv(1, games: 10, wins: 7), mv(2, games: 200, wins: 120)], by: .winRate)
        XCTAssertEqual(r.map { $0.move }, [2, 1])
    }

    func testTieBreakGamesDesc() {
        // Both rows have games >= 5 and Wilson == 0, so only games-descending decides the order.
        let sorted = DBMoveRanking.sorted([mv(1, games: 6, wins: 0), mv(2, games: 10, wins: 0)])
        XCTAssertEqual(sorted.map { $0.move }, [2, 1])
    }

    func testGamesSortOrdersByGameCountDescending() {
        let r = DBMoveRanking.sorted([mv(1, games: 10, wins: 9), mv(2, games: 100, wins: 40), mv(3, games: 50, wins: 25)],
                                     by: .games)
        XCTAssertEqual(r.map { $0.move }, [2, 3, 1])
    }

    func testGamesSortTieBreaksByWilsonOrder() {
        // Equal game counts: the higher win rate (Wilson order) comes first.
        let r = DBMoveRanking.sorted([mv(1, games: 40, wins: 10), mv(2, games: 40, wins: 30), mv(3, games: 40, wins: 20)],
                                     by: .games)
        XCTAssertEqual(r.map { $0.move }, [2, 3, 1])
    }

    func testWinRateSortIsTheWilsonRanking() {
        let moves = [mv(1, games: 4, wins: 4), mv(2, games: 100, wins: 40), mv(3, games: 10, wins: 7)]
        XCTAssertEqual(DBMoveRanking.sorted(moves, by: .winRate).map { $0.move },
                       DBMoveRanking.sorted(moves).map { $0.move })
    }

    func testWilsonZeroGames() {
        XCTAssertEqual(DBMoveRanking.wilsonLowerBound(wins: 0, games: 0), 0)
    }

    func testWilsonKnownValue() {
        XCTAssertEqual(DBMoveRanking.wilsonLowerBound(wins: 50, games: 100), 0.4038, accuracy: 0.0005)
    }
}
