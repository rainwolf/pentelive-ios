import XCTest
@testable import penteLive

/// Records every request and answers with a canned status/body. Never touches the network.
private final class DBStubTransport: Transport, @unchecked Sendable {
    let body: Data
    let status: Int
    private(set) var requests: [URLRequest] = []

    init(_ body: String = "{}", status: Int = 200) {
        self.body = Data(body.utf8)
        self.status = status
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let resp = HTTPURLResponse(url: request.url!, statusCode: status,
                                   httpVersion: nil, headerFields: nil)!
        return (body, resp)
    }
}

private struct DBThrowingTransport: Transport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        throw URLError(.notConnectedToInternet)
    }
}

/// Answers after a delay; for ordering checks of in-flight requests.
private struct DBDelayedTransport: Transport {
    let body: String
    let delayNanos: UInt64
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await Task.sleep(nanoseconds: delayNanos)
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200,
                                   httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), resp)
    }
}

final class DBClientTests: XCTestCase {
    private let prod = DBEndpoint(useLocalhost: false, credentials: nil)

    private func client(_ t: Transport, endpoint: DBEndpoint? = nil) -> DBClient {
        DBClient(endpoint: endpoint ?? prod, transport: t)
    }

    private func statsRequest() -> DBPositionStatsRequest {
        DBPositionStatsRequest(game: 1, moves: [180], scope: "archive", filters: nil)
    }

    private func expectError<T>(_ expected: DBError, _ op: () async throws -> T,
                                file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await op()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch let e as DBError {
            XCTAssertEqual(e, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected \(error)", file: file, line: line)
        }
    }

    // MARK: Endpoint

    func testPositionStatsRequestShape() throws {
        let r = prod.positionStats(statsRequest())
        XCTAssertEqual(r.httpMethod, "POST")
        XCTAssertEqual(r.url?.absoluteString, "https://www.pente.org/api/db/position-stats")
        XCTAssertEqual(r.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(r.httpBody)) as? [String: Any])
        XCTAssertEqual(o["game"] as? Int, 1)
        XCTAssertEqual(o["moves"] as? [Int], [180])
        XCTAssertEqual(o["scope"] as? String, "archive")
        XCTAssertTrue(o["filters"] is NSNull)
    }

    func testSearchAndGetEndpoints() throws {
        let s = prod.searchGames(DBGameSearchRequest(game: 1, moves: nil, scope: "archive",
                                                     filters: nil, offset: 0, limit: 20))
        XCTAssertEqual(s.httpMethod, "POST")
        XCTAssertEqual(s.url?.absoluteString, "https://www.pente.org/api/db/games/search")
        let g = prod.game(gid: 50000000000123)
        XCTAssertEqual(g.httpMethod, "GET")
        XCTAssertEqual(g.url?.absoluteString, "https://www.pente.org/api/db/games/50000000000123")
        XCTAssertEqual(prod.ping().url?.absoluteString, "https://www.pente.org/api/db/ping")
    }

    func testPlayersQueryPercentEncoded() {
        let r = prod.players(query: "a b&c+d")
        XCTAssertEqual(r.url?.absoluteString, "https://www.pente.org/api/db/players?q=a%20b%26c%2Bd")
    }

    func testLocalhostBase() {
        let e = DBEndpoint(useLocalhost: true, credentials: nil)
        XCTAssertTrue(e.ping().url!.absoluteString.hasPrefix("https://localhost/api/db/"))
        XCTAssertTrue(e.positionStats(statsRequest()).url!.absoluteString.hasPrefix("https://localhost/api/db/"))
    }

    func testCookieHeaderWhenCredentials() {
        let e = DBEndpoint(useLocalhost: false, credentials: DBCredentials(username: "bob", password: "p@ss!"))
        let r = e.positionStats(statsRequest())
        XCTAssertEqual(r.value(forHTTPHeaderField: "Cookie"), "name2=bob; password2=p@ss!")
        XCTAssertFalse(r.httpShouldHandleCookies)
        XCTAssertNil(prod.ping().value(forHTTPHeaderField: "Cookie"))
    }

    func testCookieValuesSentRawForAllCookieOctets() {
        let pw = "!#$%&'()*+-./:<=>?@[]^_`{|}~Az09"
        let e = DBEndpoint(useLocalhost: false, credentials: DBCredentials(username: "a.b_c", password: pw))
        XCTAssertEqual(e.ping().value(forHTTPHeaderField: "Cookie"), "name2=a.b_c; password2=\(pw)")
    }

    func testNoCookieHeaderWhenCredentialsNotCookieSafe() {
        for (user, pw) in [("bob", "p;w"), ("bob", "p w"), ("bob", "p\"q"), ("bob", "p,w"),
                           ("bob", "p\\w"), ("bob", "p\u{7F}"), ("bob", "pé"), ("b;ob", "pw"), ("", "pw"), ("bob", "")] {
            let e = DBEndpoint(useLocalhost: false, credentials: DBCredentials(username: user, password: pw))
            XCTAssertNil(e.ping().value(forHTTPHeaderField: "Cookie"), "\(user)/\(pw)")
        }
    }

    // MARK: Error mapping

    func test401MapsUnauthorized() async {
        let t = DBStubTransport("{\"error\":{\"code\":\"unauthorized\"}}", status: 401)
        await expectError(.unauthorized) { try await self.client(t).positionStats(self.statsRequest()) }
    }

    func test403SubscriptionRequired() async {
        let t = DBStubTransport("{\"error\":{\"code\":\"subscription_required\",\"message\":\"m\"}}", status: 403)
        await expectError(.subscriptionRequired) { try await self.client(t).ping() }
    }

    func test403BlockedMapsBlocked() async {
        let t = DBStubTransport("{\"error\":{\"code\":\"blocked\"}}", status: 403)
        await expectError(.blocked) { try await self.client(t).game(gid: 5) }
    }

    func test403OtherMapsHttp() {
        XCTAssertEqual(DBError.map(status: 403, body: Data("{\"error\":{\"code\":\"banned\"}}".utf8)),
                       .http(403, code: "banned"))
    }

    func test500MapsHttp() async {
        let t = DBStubTransport("<html>oops</html>", status: 500)
        await expectError(.http(500, code: nil)) { try await self.client(t).searchGames(
            DBGameSearchRequest(game: 1, moves: nil, scope: "archive", filters: nil, offset: 0, limit: 20)) }
    }

    func testTransportThrowMapsNetwork() async {
        await expectError(.network) { try await self.client(DBThrowingTransport()).ping() }
    }

    func testBadJsonMapsDecoding() async {
        await expectError(.decoding) { try await self.client(DBStubTransport("not json")).ping() }
    }

    // MARK: Client

    func testPositionStatsDecodes() async throws {
        let t = DBStubTransport("{\"totalGames\":3,\"nextMoves\":[{\"move\":181,\"games\":2,\"wins\":1,\"winPct\":50}]}")
        let s = try await client(t).positionStats(statsRequest())
        XCTAssertEqual(s.totalGames, 3)
        XCTAssertEqual(s.nextMoves.first?.move, 181)
        XCTAssertEqual(t.requests.count, 1)
    }

    func testGameGidMismatchThrows() async {
        let t = DBStubTransport("{\"header\":{\"gid\":7,\"game\":1},\"moves\":[180]}")
        await expectError(.decoding) { try await self.client(t).game(gid: 8) }
    }

    func testGameMissingHeaderThrows() async {
        let t = DBStubTransport("{\"moves\":[180]}")
        await expectError(.decoding) { try await self.client(t).game(gid: 8) }
    }

    func testGameMatchingGidReturns() async throws {
        let t = DBStubTransport("{\"header\":{\"gid\":50000000000123,\"game\":1},\"moves\":[180,181]}")
        let d = try await client(t).game(gid: 50000000000123)
        XCTAssertEqual(d.moves, [180, 181])
    }

    func testGameBlockedSkipsGidCheck() async throws {
        let d = try await client(DBStubTransport("{\"blocked\":true}")).game(gid: 8)
        XCTAssertTrue(d.blocked)
        XCTAssertNil(d.header)
    }

    func testGameGidZeroThrowsWithoutRequest() async {
        // Header gid missing decodes to 0; requesting 0 must not "match" it.
        let t = DBStubTransport("{\"header\":{\"game\":1},\"moves\":[180]}")
        await expectError(.decoding) { try await self.client(t).game(gid: 0) }
        await expectError(.decoding) { try await self.client(t).game(gid: -1) }
        XCTAssertEqual(t.requests.count, 0)
    }

    func testHeaderGidZeroIsNotARealGame() throws {
        let h = try JSONDecoder().decode(DBGameHeader.self, from: Data("{\"game\":1}".utf8))
        XCTAssertFalse(h.hasRealGid)
        let h2 = try JSONDecoder().decode(DBGameHeader.self, from: Data("{\"gid\":50000000000123}".utf8))
        XCTAssertTrue(h2.hasRealGid)
    }

    func testPlayersShortQueryMakesNoRequest() async throws {
        let t = DBStubTransport("{\"players\":[\"x\"]}")
        let c = client(t)
        let r0 = try await c.players(query: "")
        let r1 = try await c.players(query: "a")
        XCTAssertEqual(r0, [])
        XCTAssertEqual(r1, [])
        XCTAssertEqual(t.requests.count, 0)
        let r2 = try await c.players(query: "al")
        XCTAssertEqual(r2, ["x"])
        XCTAssertEqual(t.requests.count, 1)
    }

    func testDelayedTransportStillDecodes() async throws {
        let c = client(DBDelayedTransport(body: "{\"auth\":\"u\",\"dbAccess\":true}", delayNanos: 10_000_000))
        let p = try await c.ping()
        XCTAssertEqual(p.auth, "u")
    }

    // MARK: Gate

    func testGateOnlyLatestIsCurrent() {
        let gate = DBRequestGate()
        let id1 = gate.next(.stats)
        let id2 = gate.next(.stats)
        XCTAssertFalse(gate.isLatest(id1, .stats))
        XCTAssertTrue(gate.isLatest(id2, .stats))
    }

    func testGateKindsAreIndependent() {
        let gate = DBRequestGate()
        let s = gate.next(.stats)
        _ = gate.next(.games)
        XCTAssertTrue(gate.isLatest(s, .stats))
        XCTAssertFalse(gate.isLatest(s + 1000, .game))
    }
}
