import XCTest
@testable import penteLive

final class DBGamesPagerTests: XCTestCase {
    private func result(gids: [Int], total: Int) -> DBGameSearchResult {
        let rows = gids.map { "{\"gid\":\($0),\"game\":1}" }.joined(separator: ",")
        let json = "{\"total\":\(total),\"games\":[\(rows)]}"
        return try! JSONDecoder().decode(DBGameSearchResult.self, from: Data(json.utf8))
    }

    func testFirstPageReplaces() {
        var p = DBGamesPager()
        p.apply(result(gids: [1, 2], total: 5), offset: 0)
        p.apply(result(gids: [7], total: 1), offset: 0)
        XCTAssertEqual(p.games.map { $0.gid }, [7])
        XCTAssertEqual(p.total, 1)
        XCTAssertEqual(p.nextOffset, 1)
    }

    func testShowMoreAppends() {
        var p = DBGamesPager()
        p.apply(result(gids: [1, 2], total: 5), offset: 0)
        XCTAssertTrue(p.hasMore)
        p.apply(result(gids: [3, 4], total: 5), offset: 2)
        XCTAssertEqual(p.games.map { $0.gid }, [1, 2, 3, 4])
        XCTAssertEqual(p.nextOffset, 4)
    }

    func testStopsAtTotal() {
        var p = DBGamesPager()
        p.apply(result(gids: [1, 2], total: 2), offset: 0)
        XCTAssertFalse(p.hasMore)
    }

    func testMismatchedOffsetIgnored() {
        var p = DBGamesPager()
        p.apply(result(gids: [1, 2], total: 9), offset: 0)
        p.apply(result(gids: [9], total: 9), offset: 5)
        XCTAssertEqual(p.games.map { $0.gid }, [1, 2])
    }

    func testResetClears() {
        var p = DBGamesPager()
        p.apply(result(gids: [1], total: 3), offset: 0)
        p.reset()
        XCTAssertTrue(p.games.isEmpty)
        XCTAssertEqual(p.total, 0)
        XCTAssertFalse(p.hasMore)
    }
}
