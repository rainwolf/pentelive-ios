import XCTest
@testable import penteLive

final class DBAPIModelsTests: XCTestCase {
    private func json(_ e: Encodable) throws -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return String(data: try enc.encode(AnyEncodable(e)), encoding: .utf8)!
    }
    private func object(_ e: Encodable) throws -> [String: Any] {
        let enc = JSONEncoder()
        let data = try enc.encode(AnyEncodable(e))
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
    private struct AnyEncodable: Encodable {
        let wrapped: Encodable
        init(_ w: Encodable) { wrapped = w }
        func encode(to encoder: Encoder) throws { try wrapped.encode(to: encoder) }
    }
    private func decode<T: Decodable>(_ type: T.Type, _ s: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(s.utf8))
    }

    func testDefaultFiltersEncodeAsNullFilters() throws {
        let req = DBPositionStatsRequest(game: 1, moves: [180], scope: "all", filters: DBFilters())
        let o = try object(req)
        XCTAssertTrue(o["filters"] is NSNull)
        let nilReq = DBPositionStatsRequest(game: 1, moves: [], scope: "all", filters: nil)
        XCTAssertTrue(try object(nilReq)["filters"] is NSNull)
    }

    func testFiltersEmitNullStringsNotEmpty() throws {
        let s = try json(DBFilters(player1Name: "alice"))
        XCTAssertTrue(s.contains("\"player1Name\":\"alice\""), s)
        XCTAssertTrue(s.contains("\"player2Name\":null"), s)
        XCTAssertTrue(s.contains("\"player1Seat\":1"), s)
        XCTAssertFalse(s.contains("excludeTimeouts"), s)
        XCTAssertFalse(s.contains("liveOrTurnBased"), s)
    }

    func testExtendedKeysOnlyWhenEnabled() throws {
        var f = DBFilters()
        f.includesExtendedKeys = true
        let s = try json(f)
        XCTAssertTrue(s.contains("\"excludeTimeouts\":false"), s)
        XCTAssertTrue(s.contains("\"liveOrTurnBased\":\"all\""), s)
        XCTAssertFalse(s.contains("includesExtendedKeys"), s)
    }

    func testIsDefaultIgnoresExtendedWhenDisabled() {
        var f = DBFilters(excludeTimeouts: true)
        XCTAssertTrue(f.isDefault)
        f.includesExtendedKeys = true
        XCTAssertFalse(f.isDefault)
        XCTAssertFalse(DBFilters(player1Name: "a").isDefault)
    }

    func testGidIsInt64() throws {
        let h = try decode(DBGameHeader.self, "{\"gid\": 50000000000123, \"game\": 1}")
        XCTAssertEqual(h.gid, Int64(50000000000123))
    }

    func testHeaderToleratesMissingFields() throws {
        let h = try decode(DBGameHeader.self,
            "{\"gid\":1,\"game\":1,\"player1\":null,\"player2\":{\"name\":\"bob\",\"rating\":1500},\"winner\":2,\"playDate\":null}")
        XCTAssertNil(h.player1)
        XCTAssertEqual(h.player2?.name, "bob")
        XCTAssertEqual(h.player2?.nameColor, 0)
        XCTAssertEqual(h.player2?.crown, 0)
        XCTAssertNil(h.playDate)
        XCTAssertEqual(h.moveCount, 0)
    }

    func testGameDetailBlockedWithoutHeader() throws {
        let d = try decode(DBGameDetail.self, "{\"blocked\":true}")
        XCTAssertNil(d.header)
        XCTAssertEqual(d.moves, [])
        XCTAssertTrue(d.blocked)
    }

    func testStatsMissingBlockedIsFalse() throws {
        let s = try decode(DBPositionStats.self, "{\"totalGames\":3,\"totalWinPct\":50.5,\"nextMoves\":[{\"move\":5,\"games\":2,\"wins\":1,\"winPct\":50}]}")
        XCTAssertFalse(s.blocked)
        XCTAssertEqual(s.nextMoves, [DBNextMove(move: 5, games: 2, wins: 1, winPct: 50)])
        let empty = try decode(DBPositionStats.self, "{}")
        XCTAssertEqual(empty.totalGames, 0)
        XCTAssertEqual(empty.nextMoves, [])
    }

    func testSearchLimitClampedTo100() throws {
        let r = DBGameSearchRequest(game: 1, moves: nil, scope: "all", filters: nil, offset: 0, limit: 500)
        XCTAssertEqual(r.limit, 100)
        let o = try object(r)
        XCTAssertEqual(o["limit"] as? Int, 100)
        XCTAssertNil(o["moves"])
        let r2 = DBGameSearchRequest(game: 1, moves: [1, 2], scope: "all", filters: nil, offset: 20, limit: 50)
        XCTAssertEqual(try object(r2)["moves"] as? [Int], [1, 2])
        XCTAssertEqual(r2.limit, 50)
    }

    func testUnknownFieldsIgnored() throws {
        let s = try decode(DBPositionStats.self, "{\"totalGames\":1,\"rotation\":3,\"extra\":{\"a\":1},\"nextMoves\":[]}")
        XCTAssertEqual(s.totalGames, 1)
        let p = try decode(DBPing.self, "{\"auth\":\"user\",\"dbAccess\":true,\"features\":[\"x\"]}")
        XCTAssertEqual(p.auth, "user")
        XCTAssertTrue(p.dbAccess)
        let e = try decode(DBErrorEnvelope.self, "{\"error\":{\"code\":\"blocked\",\"message\":\"m\",\"x\":1}}")
        XCTAssertEqual(e.error.code, "blocked")
        let pl = try decode(DBPlayersResult.self, "{\"players\":[\"a\",\"b\"]}")
        XCTAssertEqual(pl.players, ["a", "b"])
    }

    func testPingFeaturesDecoded() throws {
        let p = try decode(DBPing.self,
                           "{\"auth\":\"u\",\"dbAccess\":true,\"features\":[\"excludeTimeouts\",\"liveOrTurnBased\"]}")
        XCTAssertEqual(p.features, ["excludeTimeouts", "liveOrTurnBased"])
    }

    func testPingMissingFeaturesIsEmpty() throws {
        let p = try decode(DBPing.self, "{\"auth\":null}")
        XCTAssertEqual(p.features, [])
        XCTAssertNil(p.auth)
        XCTAssertFalse(p.dbAccess)
    }
}
