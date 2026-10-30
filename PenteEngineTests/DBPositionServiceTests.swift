import XCTest
@testable import penteLive

/// Answers by the first move in the request body; never touches the network.
private final class DBScriptedTransport: Transport, @unchecked Sendable {
    struct Reply {
        var body: String
        var status: Int = 200
        var delay: UInt64 = 0
    }
    var replies: [Int: Reply] = [:]
    private(set) var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        var key = -1
        if let b = request.httpBody,
           let o = try? JSONSerialization.jsonObject(with: b) as? [String: Any],
           let m = o["moves"] as? [Int], let last = m.last { key = last }
        let r = replies[key] ?? Reply(body: "{}")
        if r.delay > 0 {
            // Ignores Task cancellation, like the production URLSession transport:
            // a superseded request still delivers its body, so only the
            // service's stale-response gate keeps it from painting.
            await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                DispatchQueue.main.asyncAfter(deadline: .now() + .nanoseconds(Int(r.delay))) { c.resume() }
            }
        }
        let resp = HTTPURLResponse(url: request.url!, statusCode: r.status,
                                   httpVersion: nil, headerFields: nil)!
        return (Data(r.body.utf8), resp)
    }
}

@MainActor
final class DBPositionServiceTests: XCTestCase {
    private let suite = "DBPositionServiceTests.suite"
    private var transport: DBScriptedTransport!
    private var service: DBPositionService!
    private var heats: [[NSNumber: UIColor]] = []
    private var states: [DBLoadState] = []

    override func setUp() {
        super.setUp()
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        transport = DBScriptedTransport()
        let client = DBClient(endpoint: DBEndpoint(useLocalhost: false, credentials: nil),
                              transport: transport)
        let prefs = DBPreferences(defaults: UserDefaults(suiteName: suite)!)
        service = DBPositionService(client: client, preferences: prefs)
        heats = []
        states = []
        service.onHeat = { [unowned self] in self.heats.append($0) }
        service.onStatsState = { [unowned self] in self.states.append($0) }
    }

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func stats(_ moves: [(Int, Int, Double)], blocked: Bool = false) -> String {
        let nm = moves.map { "{\"move\":\($0.0),\"games\":\($0.1),\"wins\":1,\"winPct\":\($0.2)}" }
            .joined(separator: ",")
        return "{\"totalGames\":10,\"totalWinPct\":50,\"nextMoves\":[\(nm)],\"blocked\":\(blocked)}"
    }

    private func settle(_ seconds: Double = 0.5) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    func testRapidPositionChangesRenderOnlyLatest() async {
        transport.replies[10] = .init(body: stats([(100, 50, 20)]), delay: 200_000_000)
        transport.replies[11] = .init(body: stats([(101, 50, 80)]))
        service.positionDidChange(game: 1, moves: [180, 10], occupied: [180, 10])
        service.positionDidChange(game: 1, moves: [180, 11], occupied: [180, 11])
        await settle(0.6)
        XCTAssertEqual(heats.last.map { Set($0.keys) }, [NSNumber(value: 101)])
        XCTAssertFalse(heats.contains { $0[NSNumber(value: 100)] != nil })
        XCTAssertEqual(states.last, .loaded)
    }

    func testToggleDuringInFlightDoesNotPaintOldStats() async {
        transport.replies[10] = .init(body: stats([(100, 50, 20)]))
        transport.replies[11] = .init(body: stats([(101, 50, 80)]), delay: 300_000_000)
        service.positionDidChange(game: 1, moves: [180, 10], occupied: [180, 10])
        await settle(0.2)
        XCTAssertEqual(heats.last?.count, 1)
        heats = []
        service.positionDidChange(game: 1, moves: [180, 11], occupied: [180, 11])
        service.recomputeHeat()
        XCTAssertTrue(heats.allSatisfy { $0.isEmpty })
        XCTAssertFalse(heats.isEmpty)
        XCTAssertTrue(service.displayedMoves().isEmpty)
        await settle(0.5)
        XCTAssertEqual(heats.last.map { Set($0.keys) }, [NSNumber(value: 101)])
    }

    func testBlockedResponseSetsBlockedState() async {
        transport.replies[10] = .init(body: stats([], blocked: true))
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        XCTAssertEqual(states, [.loading, .blocked])
    }

    func testBlocked403SetsBlockedState() async {
        transport.replies[10] = .init(body: "{\"error\":{\"code\":\"blocked\"}}", status: 403)
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        XCTAssertEqual(states.last, .blocked)
    }

    func testEmptyNextMovesSetsEmptyState() async {
        transport.replies[10] = .init(body: stats([]))
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        XCTAssertEqual(states, [.loading, .empty])
    }

    func test401SetsUnauthorized() async {
        transport.replies[10] = .init(body: "{}", status: 401)
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        XCTAssertEqual(states, [.loading, .unauthorized])
    }

    func testSubscriptionRequiredAndFailedStates() async {
        transport.replies[10] = .init(body: "{\"error\":{\"code\":\"subscription_required\"}}", status: 403)
        transport.replies[11] = .init(body: "{}", status: 500)
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        XCTAssertEqual(states.last, .subscriptionRequired)
        service.positionDidChange(game: 1, moves: [11], occupied: [11])
        await settle()
        XCTAssertEqual(states.last, .failed)
    }

    func testUnsupportedGameMakesNoRequest() async {
        service.positionDidChange(game: 0, moves: [10], occupied: [10])
        await settle(0.1)
        XCTAssertEqual(states, [.unsupported])
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(heats.first?.count, 0)
    }

    func testOccupiedCandidateNotInHeat() async {
        transport.replies[10] = .init(body: stats([(100, 50, 20), (101, 50, 80)]))
        service.positionDidChange(game: 1, moves: [180, 10], occupied: [180, 10, 101])
        await settle()
        XCTAssertEqual(heats.last.map { Set($0.keys) }, [NSNumber(value: 100)])
        XCTAssertEqual(service.displayedMoves().map { $0.move }, [100])
    }

    func testCapturedCellIsNotOccupied() async {
        transport.replies[10] = .init(body: stats([(200, 50, 60)]))
        service.positionDidChange(game: 1, moves: [200, 10], occupied: [10])
        await settle()
        XCTAssertNotNil(heats.last?[NSNumber(value: 200)])
    }

    func testMovesShownLimitsHeat() async {
        service.preferences.movesShown = 1
        transport.replies[10] = .init(body: stats([(100, 50, 20), (101, 50, 80)]))
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        XCTAssertEqual(heats.last?.count, 1)
    }

    func testSetLegacyFiltersReachesRequest() async {
        service.setLegacyFilters(p1Name: "alice", p2Name: nil, p1Rating: nil, p2Rating: nil,
                                 eitherSeat: false, winner: 0, after: nil, before: nil)
        transport.replies[10] = .init(body: stats([]))
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        let body = String(decoding: transport.requests.first?.httpBody ?? Data(), as: UTF8.self)
        XCTAssertTrue(body.contains("\"player1Name\":\"alice\""))
    }
}
