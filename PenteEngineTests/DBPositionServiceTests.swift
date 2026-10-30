import XCTest
@testable import penteLive

/// Answers by the first move in the request body; never touches the network.
private final class DBScriptedTransport: Transport, @unchecked Sendable {
    struct Reply {
        var body: String
        var status: Int = 200
        var delay: UInt64 = 0
    }
    private let lock = NSLock()
    private var _replies: [Int: Reply] = [:]
    private var _searchReplies: [Int: Reply] = [:]
    private var _requests: [URLRequest] = []
    var replies: [Int: Reply] {
        get { lock.lock(); defer { lock.unlock() }; return _replies }
        set { lock.lock(); defer { lock.unlock() }; _replies = newValue }
    }
    /// Replies for /games/search, keyed by the request's offset.
    var searchReplies: [Int: Reply] {
        get { lock.lock(); defer { lock.unlock() }; return _searchReplies }
        set { lock.lock(); defer { lock.unlock() }; _searchReplies = newValue }
    }
    var requests: [URLRequest] { lock.lock(); defer { lock.unlock() }; return _requests }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.lock(); _requests.append(request); lock.unlock()
        var key = -1
        if let b = request.httpBody,
           let o = try? JSONSerialization.jsonObject(with: b) as? [String: Any],
           let m = o["moves"] as? [Int], let last = m.last { key = last }
        var r = replies[key] ?? Reply(body: "{}")
        if request.url?.path.hasSuffix("/games/search") == true {
            var offset = 0
            if let b = request.httpBody, let o = try? JSONSerialization.jsonObject(with: b) as? [String: Any] {
                offset = o["offset"] as? Int ?? 0
            }
            r = searchReplies[offset] ?? Reply(body: "{}")
        }
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
    private var gamesStates: [(DBLoadState, Bool)] = []
    private var gamesChanges = 0

    override func setUp() {
        super.setUp()
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        transport = DBScriptedTransport()
        let client = DBClient(endpoint: DBEndpoint(useLocalhost: false),
                              transport: transport)
        let prefs = DBPreferences(defaults: UserDefaults(suiteName: suite)!)
        service = DBPositionService(client: client, preferences: prefs)
        heats = []
        states = []
        gamesStates = []
        gamesChanges = 0
        service.onHeat = { [unowned self] in self.heats.append($0) }
        service.onStatsState = { [unowned self] in self.states.append($0) }
        service.onGamesChanged = { [unowned self] in self.gamesChanges += 1 }
        service.onGamesState = { [unowned self] state in
            self.gamesStates.append((state, self.service.gamesStateIsLoadMore))
        }
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

    func testGoNineByNineSendsGameIdAndDropsOffBoardHeat() async {
        transport.replies[40] = .init(body: stats([(30, 50, 40), (81, 50, 90), (90, 50, 10), (-3, 50, 70)]))
        service.positionDidChange(game: 22, moves: [40], occupied: [40])
        await settle()
        XCTAssertEqual(states.last, .loaded)
        XCTAssertEqual(heats.last.map { Set($0.keys) }, [NSNumber(value: 30)])
        XCTAssertEqual(service.displayedMoves().map { $0.move }, [30])
        let bodies = transport.requests.compactMap { $0.httpBody }
            .compactMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        XCTAssertFalse(bodies.isEmpty)
        for b in bodies { XCTAssertEqual(b["game"] as? Int, 22) }
    }

    func testEmptyGoStartIsQueriedAndRenjuIsSupported() async {
        service.positionDidChange(game: 19, moves: [], occupied: [])
        await settle()
        XCTAssertNotEqual(states.last, .unsupported)
        service.positionDidChange(game: 31, moves: [112], occupied: [112])
        await settle()
        XCTAssertNotEqual(states.last, .unsupported)
        let games = transport.requests.compactMap { $0.httpBody }
            .compactMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
            .compactMap { $0["game"] as? Int }
        XCTAssertEqual(Set(games), [19, 31])
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

    func testFilterStateReachesBothRequests() async {
        var s = DBFilterState()
        s.player1 = "alice"
        s.scope = "mine"
        service.filterState = s
        transport.replies[10] = .init(body: stats([]))
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        XCTAssertEqual(transport.requests.count, 2)
        for r in transport.requests {
            let body = String(decoding: r.httpBody ?? Data(), as: UTF8.self)
            XCTAssertTrue(body.contains("\"player1Name\":\"alice\""), body)
            XCTAssertTrue(body.contains("\"scope\":\"mine\""), body)
        }
    }

    private var store: DBFilterStore { DBFilterStore(defaults: UserDefaults(suiteName: suite)!) }

    func testFilterStateLoadsFromStoreOfSameDefaults() {
        var s = DBFilterState()
        s.setGame(id: 4)
        s.player2 = "bob"
        store.save(s)
        let client = DBClient(endpoint: DBEndpoint(useLocalhost: false), transport: transport)
        let fresh = DBPositionService(client: client,
                                      preferences: DBPreferences(defaults: UserDefaults(suiteName: suite)!))
        XCTAssertEqual(fresh.filterState, s)
        XCTAssertEqual(fresh.filterGameId, 4)
    }

    func testAdoptInjectedGoAndRenju() {
        service.adoptInjectedGame("Go (9x9)")
        XCTAssertEqual(service.filterGameId, 21)
        service.adoptInjectedGame("Speed Renju")
        XCTAssertEqual(service.filterGameId, 32)
        XCTAssertEqual(store.load().gameId, 32)
    }

    func testAdoptInjectedGameSavesSupportedOnly() {
        service.adoptInjectedGame("Speed Keryo-Pente")
        XCTAssertEqual(service.filterGameId, 4)
        XCTAssertEqual(store.load().gameId, 4)
        service.adoptInjectedGame("Tombstone")
        service.adoptInjectedGame(nil)
        XCTAssertEqual(service.filterGameId, 4, "unsupported names leave the filters alone")
        XCTAssertEqual(store.load().gameId, 4)
    }

    func testApplyFiltersSavesAndReportsGameChange() {
        var s = service.filterState
        s.winner = 1
        XCTAssertFalse(service.applyFilters(s))
        XCTAssertEqual(store.load().winner, 1)
        s.setGame(id: 5)
        XCTAssertTrue(service.applyFilters(s))
        XCTAssertEqual(service.filterGameId, 5)
        XCTAssertEqual(service.filterChipSummary, s.chipSummary())
    }

    func testFiltersSheetApplyGoesThroughService() {
        var changed: [Bool] = []
        let vc = service.makeFiltersViewController(regularWidth: false) { changed.append($0) }
        guard let sheet = vc as? DBFiltersViewController else { return XCTFail("\(vc)") }
        sheet.loadViewIfNeeded()
        XCTAssertEqual(sheet.draft, service.filterState)
        sheet.gameChips.first { $0.tag == 13 }!.sendActions(for: .touchUpInside)
        sheet.applyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(changed, [true])
        XCTAssertEqual(service.filterGameId, 13)
        XCTAssertEqual(store.load().gameId, 13)
    }

    private func page(_ gids: [Int], total: Int) -> String {
        let rows = gids.map { "{\"gid\":\($0),\"game\":1}" }.joined(separator: ",")
        return "{\"total\":\(total),\"games\":[\(rows)]}"
    }

    func testFirstPageLoadsGames() async {
        transport.searchReplies[0] = .init(body: page([1, 2], total: 30))
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        XCTAssertEqual(service.pager.games.map { $0.gid }, [1, 2])
        XCTAssertEqual(service.pager.total, 30)
        XCTAssertEqual(gamesStates.map { $0.0 }, [.loading, .loaded])
        XCTAssertTrue(gamesStates.allSatisfy { !$0.1 })
    }

    func testLoadMoreAppendsAndFlagsLoadMore() async {
        transport.searchReplies[0] = .init(body: page([1, 2], total: 4))
        transport.searchReplies[2] = .init(body: page([3, 4], total: 4))
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        service.loadMoreGames()
        XCTAssertEqual(gamesStates.last?.0, .loading)
        XCTAssertEqual(gamesStates.last?.1, true)
        await settle()
        XCTAssertEqual(service.pager.games.map { $0.gid }, [1, 2, 3, 4])
        XCTAssertEqual(gamesStates.last?.0, .loaded)
        XCTAssertFalse(service.pager.hasMore)
    }

    func testPageTwoFailureKeepsRows() async {
        transport.searchReplies[0] = .init(body: page([1, 2], total: 4))
        transport.searchReplies[2] = .init(body: "{}", status: 500)
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        service.loadMoreGames()
        await settle()
        XCTAssertEqual(service.pager.games.map { $0.gid }, [1, 2])
        XCTAssertEqual(gamesStates.last?.0, .failed)
        XCTAssertEqual(gamesStates.last?.1, true)
    }

    func testNewPositionDropsPendingPage() async {
        transport.searchReplies[0] = .init(body: page([1, 2], total: 4))
        transport.searchReplies[2] = .init(body: page([3, 4], total: 4), delay: 300_000_000)
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle(0.2)
        service.loadMoreGames()
        // New position: the delayed page 2 of the old query must not be appended.
        transport.searchReplies[0] = .init(body: page([9], total: 1))
        service.positionDidChange(game: 1, moves: [11], occupied: [11])
        XCTAssertTrue(service.pager.games.isEmpty)
        await settle(0.6)
        XCTAssertEqual(service.pager.games.map { $0.gid }, [9])
        XCTAssertEqual(gamesStates.last?.0, .loaded)
        XCTAssertEqual(gamesStates.last?.1, false)
    }

    func testZeroTotalSetsEmptyGamesState() async {
        transport.searchReplies[0] = .init(body: page([], total: 0))
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        XCTAssertEqual(gamesStates.last?.0, .empty)
    }

    func testBlockedGamesResponse() async {
        transport.searchReplies[0] = .init(body: "{\"total\":0,\"games\":[],\"blocked\":true}")
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        XCTAssertEqual(gamesStates.last?.0, .blocked)
    }

    func testBlocked403GamesResponse() async {
        transport.searchReplies[0] = .init(body: "{\"error\":{\"code\":\"blocked\"}}", status: 403)
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle()
        XCTAssertEqual(gamesStates.last?.0, .blocked)
    }

    func testUnsupportedGameSkipsGamesFetch() async {
        service.positionDidChange(game: 99, moves: [10], occupied: [10])
        await settle(0.2)
        XCTAssertEqual(gamesStates.last?.0, .unsupported)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testReappearAfterViewerDoesNotRefetch() async {
        transport.replies[200] = .init(body: stats([(100, 50, 20)]))
        XCTAssertTrue(service.shouldRefreshOnAppear(game: 1, moves: [180, 200]))
        service.positionDidChange(game: 1, moves: [180, 200], occupied: [180, 200])
        await settle()
        XCTAssertEqual(states.last, .loaded)
        XCTAssertFalse(service.shouldRefreshOnAppear(game: 1, moves: [180, 200]))
        XCTAssertTrue(service.shouldRefreshOnAppear(game: 1, moves: [180]))
        XCTAssertTrue(service.shouldRefreshOnAppear(game: 2, moves: [180, 200]))
    }

    func testReappearAfterFailureRefetches() async {
        transport.replies[200] = .init(body: "{}", status: 500)
        service.positionDidChange(game: 1, moves: [180, 200], occupied: [180, 200])
        await settle()
        XCTAssertEqual(states.last, .failed)
        XCTAssertTrue(service.shouldRefreshOnAppear(game: 1, moves: [180, 200]))
    }

    func testReappearWhileLoadingRefetches() {
        service.positionDidChange(game: 1, moves: [180, 200], occupied: [180, 200])
        XCTAssertTrue(service.shouldRefreshOnAppear(game: 1, moves: [180, 200]))
    }

    // MARK: failed games list on return (M2)

    private func gamesPage(gid: Int64 = 5) -> String {
        "{\"total\":1,\"games\":[{\"gid\":\(gid),\"game\":1,\"winner\":1,\"moveCount\":3}],\"blocked\":false}"
    }

    private var searchCount: Int {
        transport.requests.filter { $0.url?.path.hasSuffix("/games/search") == true }.count
    }

    func testRefetchFailedEndpointsRetriesFailedGamesOnly() async {
        transport.replies[200] = .init(body: stats([(100, 50, 20)]))
        transport.searchReplies[0] = .init(body: "{}", status: 500)
        service.positionDidChange(game: 1, moves: [180, 200], occupied: [180, 200])
        await settle()
        XCTAssertEqual(states.last, .loaded)
        XCTAssertEqual(gamesStates.last?.0, .failed)
        XCTAssertFalse(service.shouldRefreshOnAppear(game: 1, moves: [180, 200]))
        let total = transport.requests.count
        transport.searchReplies[0] = .init(body: gamesPage())
        service.refetchFailedGames()
        await settle()
        XCTAssertEqual(gamesStates.last?.0, .loaded)
        XCTAssertEqual(service.pager.games.map(\.gid), [5])
        XCTAssertEqual(transport.requests.count, total + 1, "games only")
    }

    func testRefetchFailedEndpointsRetriesBlockedGames() async {
        transport.replies[200] = .init(body: stats([(100, 50, 20)]))
        transport.searchReplies[0] = .init(body: "{\"total\":0,\"games\":[],\"blocked\":true}")
        service.positionDidChange(game: 1, moves: [180, 200], occupied: [180, 200])
        await settle()
        XCTAssertEqual(gamesStates.last?.0, .blocked)
        transport.searchReplies[0] = .init(body: gamesPage())
        service.refetchFailedGames()
        await settle()
        XCTAssertEqual(gamesStates.last?.0, .loaded)
    }

    func testRefetchFailedEndpointsSkipsLoadedGames() async {
        transport.replies[200] = .init(body: stats([(100, 50, 20)]))
        transport.searchReplies[0] = .init(body: gamesPage())
        service.positionDidChange(game: 1, moves: [180, 200], occupied: [180, 200])
        await settle()
        XCTAssertEqual(gamesStates.last?.0, .loaded)
        let before = searchCount
        service.refetchFailedGames()
        await settle(0.2)
        XCTAssertEqual(searchCount, before)
    }

    // MARK: invitedHistory (M4)

    func testApplyFiltersRecordsSearchedNamesInInvitedHistory() {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(["zed"], forKey: "invitedHistory")
        var s = service.filterState
        s.player1 = "Alice, Bob"
        s.player2 = "car*l"
        service.applyFilters(s)
        XCTAssertEqual(defaults.array(forKey: "invitedHistory") as? [String], ["alice", "bob", "zed"])
        s.player2 = "ALICE"
        service.applyFilters(s)
        XCTAssertEqual(defaults.array(forKey: "invitedHistory") as? [String], ["alice", "bob", "zed"])
    }

    func testApplyFiltersWithoutNamesLeavesInvitedHistoryAlone() {
        let defaults = UserDefaults(suiteName: suite)!
        var s = service.filterState
        s.winner = 1
        service.applyFilters(s)
        XCTAssertNil(defaults.object(forKey: "invitedHistory"))
    }

    // MARK: /ping features gate the extended filters (F4)

    private func lastStatsBody() -> String {
        let r = transport.requests.last { $0.url?.path.hasSuffix("/position-stats") == true }
        return String(decoding: r?.httpBody ?? Data(), as: UTF8.self)
    }

    func testPingFeaturesGateExtendedFiltersPerFeature() async {
        var s = DBFilterState()
        s.excludeTimeouts = true
        s.liveOrTurnBased = "live"
        service.applyFilters(s)
        service.positionDidChange(game: 1, moves: [10], occupied: [10])
        await settle(0.3)
        XCTAssertTrue(lastStatsBody().contains("\"filters\":null"), lastStatsBody())
        XCTAssertFalse(service.filterChipSummary.contains("no timeouts"))

        transport.replies[-1] = .init(body: "{\"auth\":\"bob\",\"dbAccess\":true,\"features\":[\"excludeTimeouts\"]}")
        var changes: [Bool] = []
        service.onFeaturesChanged = { changes.append($0) }
        service.refreshFeatures()
        await settle(0.3)
        XCTAssertEqual(changes, [true], "the wire filters changed")
        XCTAssertTrue(transport.requests.contains { $0.url?.path.hasSuffix("/ping") == true })
        service.positionDidChange(game: 1, moves: [11], occupied: [11])
        await settle(0.3)
        XCTAssertTrue(lastStatsBody().contains("\"excludeTimeouts\":true"), lastStatsBody())
        XCTAssertFalse(lastStatsBody().contains("liveOrTurnBased"), lastStatsBody())
        XCTAssertTrue(service.filterChipSummary.contains("no timeouts"))
        XCTAssertFalse(service.filterChipSummary.contains("live only"))
    }

    func testPingFailureKeepsExtendedFiltersHidden() async {
        transport.replies[-1] = .init(body: "{}", status: 500)
        var changes: [Bool] = []
        service.onFeaturesChanged = { changes.append($0) }
        service.refreshFeatures()
        await settle(0.3)
        XCTAssertTrue(changes.isEmpty)
        XCTAssertEqual(service.features, DBServerFeatures.none)
    }
}
