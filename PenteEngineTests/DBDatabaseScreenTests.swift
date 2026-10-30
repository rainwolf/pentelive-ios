@testable import penteLive
import XCTest

/// Scripted position-stats transport keyed by the last move in the request
/// body. Never touches the network.
private final class DBScreenTransport: Transport, @unchecked Sendable {
    // data(for:) runs off the main actor (DBClient is nonisolated), so a
    // superseded request and its replacement can hit it concurrently.
    private let lock = NSLock()
    private var _replies: [Int: (body: String, status: Int)] = [:]
    private var _delays: [Int: UInt64] = [:]
    private var _searchReply: (body: String, status: Int)?
    private var _requests: [URLRequest] = []

    var replies: [Int: (body: String, status: Int)] {
        get { lock.lock(); defer { lock.unlock() }; return _replies }
        set { lock.lock(); defer { lock.unlock() }; _replies = newValue }
    }

    /// Per-key reply delay (nanoseconds), so a request stays in flight.
    var delays: [Int: UInt64] {
        get { lock.lock(); defer { lock.unlock() }; return _delays }
        set { lock.lock(); defer { lock.unlock() }; _delays = newValue }
    }

    /// When set, every /games/search gets this reply instead of `replies`.
    var searchReply: (body: String, status: Int)? {
        get { lock.lock(); defer { lock.unlock() }; return _searchReply }
        set { lock.lock(); defer { lock.unlock() }; _searchReply = newValue }
    }

    /// Position-stats calls only; the games search fired alongside is
    /// covered by DBPositionServiceTests.
    var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests.filter { $0.url?.path.hasSuffix("/position-stats") == true }
    }

    var searchRequests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests.filter { $0.url?.path.hasSuffix("/games/search") == true }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let key = DBScreenTransport.moves(of: request).last ?? -1
        lock.lock()
        _requests.append(request)
        var r = _replies[key] ?? (body: "{}", status: 200)
        if request.url?.path.hasSuffix("/games/search") == true, let s = _searchReply { r = s }
        let delay = _delays[key] ?? 0
        lock.unlock()
        if delay > 0 { try? await Task.sleep(nanoseconds: delay) }
        let resp = HTTPURLResponse(url: request.url!, statusCode: r.status,
                                   httpVersion: nil, headerFields: nil)!
        return (Data(r.body.utf8), resp)
    }

    static func moves(of request: URLRequest) -> [Int] {
        guard let b = request.httpBody,
              let o = try? JSONSerialization.jsonObject(with: b) as? [String: Any],
              let m = o["moves"] as? [Int] else { return [] }
        return m
    }
}

/// A long press whose state and location the test sets.
private final class FakeLongPress: UILongPressGestureRecognizer {
    var fakeState: UIGestureRecognizer.State = .possible
    var point: CGPoint = .zero
    override var state: UIGestureRecognizer.State {
        get { fakeState }
        set { fakeState = newValue }
    }

    override func location(in _: UIView?) -> CGPoint {
        point
    }
}

/// DatabaseViewController wiring: line + redo, position-stats heat, tap-dot.
/// The controller is driven through KVC and selectors, never shown, so
/// viewDidAppear (and its legacy HTML search) never runs.
@MainActor
final class DBDatabaseScreenTests: XCTestCase {
    private let suite = "DBDatabaseScreenTests.suite"
    private var transport: DBScreenTransport!
    private var prefs: DBPreferences!
    private var service: DBPositionService!

    override func setUp() {
        super.setUp()
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        transport = DBScreenTransport()
        let client = DBClient(endpoint: DBEndpoint(useLocalhost: false),
                              transport: transport)
        prefs = DBPreferences(defaults: UserDefaults(suiteName: suite)!)
        service = DBPositionService(client: client, preferences: prefs)
    }

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    // MARK: helpers

    private func makeVC(game: String?, moves: [Int]) -> UIViewController {
        let sb = UIStoryboard(name: "MainStoryboard", bundle: Bundle.main)
        let vc = sb.instantiateViewController(withIdentifier: "databaseViewController")
        vc.setValue(service, forKey: "dbService")
        vc.setValue(NSMutableArray(array: moves.map { NSNumber(value: $0) }), forKey: "movesList")
        vc.setValue(game, forKey: "game")
        vc.loadViewIfNeeded()
        return vc
    }

    private func line(_ vc: UIViewController) -> DBLine {
        return vc.value(forKey: "line") as! DBLine
    }

    private func mirror(_ vc: UIViewController) -> [Int] {
        return (vc.value(forKey: "movesList") as! [NSNumber]).map { $0.intValue }
    }

    private func board(_ vc: UIViewController, _ key: String) -> UIView {
        return vc.value(forKey: key) as! UIView
    }

    private func dbOptions(_ vc: UIViewController, _ key: String = "board") -> [NSNumber: UIColor]? {
        return board(vc, key).value(forKey: "dbOptions") as? [NSNumber: UIColor]
    }

    private func back(_ vc: UIViewController) {
        vc.perform(NSSelectorFromString("goBackOneMoveSwipe:"), with: nil)
    }

    private func forward(_ vc: UIViewController) {
        vc.perform(NSSelectorFromString("goForwardOneMoveSwipe:"), with: nil)
    }

    private func tap(_ vc: UIViewController, cell: Int, state: UIGestureRecognizer.State) {
        let b = board(vc, "board")
        let cs = b.bounds.width / 19
        let rec = FakeLongPress()
        rec.point = CGPoint(x: (CGFloat(cell % 19) + 0.5) * cs, y: (CGFloat(cell / 19) + 0.5) * cs)
        rec.fakeState = state
        vc.perform(NSSelectorFromString("boardTap:"), with: rec)
    }

    private func stats(_ moves: [(Int, Double)]) -> String {
        let nm = moves.map { "{\"move\":\($0.0),\"games\":50,\"wins\":1,\"winPct\":\($0.1)}" }
            .joined(separator: ",")
        return "{\"totalGames\":10,\"totalWinPct\":50,\"nextMoves\":[\(nm)],\"blocked\":false}"
    }

    /// Fixed sleep, only for asserting that something did NOT happen.
    private func settle(_ seconds: Double = 0.3) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    /// Polls `condition` on the main actor until it holds or ~2 s pass.
    private func waitUntil(timeout: Double = 2, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return true
    }

    private func sentMoves() -> [[Int]] {
        return transport.requests.map(DBScreenTransport.moves(of:))
    }

    private func heatKeys(_ vc: UIViewController, _ key: String = "board") -> Set<NSNumber>? {
        return dbOptions(vc, key).map { Set($0.keys) }
    }

    private func visibleView(_ vc: UIViewController, id: String) -> UIView? {
        func find(_ v: UIView) -> UIView? {
            if v.accessibilityIdentifier == id {
                return v
            }
            for s in v.subviews {
                if let f = find(s) {
                    return f
                }
            }
            return nil
        }
        guard let v = find(vc.view), !v.isHidden else { return nil }
        return v
    }

    // MARK: tests

    func testInjectedMovesSeedTheLine() {
        let vc = makeVC(game: "Keryo-Pente", moves: [180, 181, 200])
        XCTAssertEqual(line(vc).cells, [180, 181, 200])
        XCTAssertEqual(line(vc).game, DBGameCatalog.gameId(forName: "Keryo-Pente"))
        XCTAssertEqual(line(vc).redoCount, 0)
    }

    func testSwipeBackThenForwardMirrorsLineAndRefetches() async {
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        XCTAssertEqual(mirror(vc), [180, 181])
        XCTAssertEqual(line(vc).redoCount, 1)
        let firstSent = await waitUntil { self.transport.requests.count == 1 }
        XCTAssertTrue(firstSent)
        forward(vc)
        XCTAssertEqual(mirror(vc), [180, 181, 200])
        XCTAssertEqual(line(vc).redoCount, 0)
        let secondSent = await waitUntil { self.transport.requests.count == 2 }
        XCTAssertTrue(secondSent)
        XCTAssertEqual(sentMoves(), [[180, 181], [180, 181, 200]])
    }

    func testBackStopsAtFixedCentreStone() {
        let vc = makeVC(game: "Pente", moves: [180])
        back(vc)
        XCTAssertEqual(mirror(vc), [180])
    }

    func testTapAfterBackPlaysAndClearsRedo() async {
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        tap(vc, cell: 0, state: .ended)
        XCTAssertEqual(mirror(vc), [180, 181, 0])
        XCTAssertEqual(line(vc).cells, [180, 181, 0])
        XCTAssertEqual(line(vc).redoCount, 0)
        // The superseded [180, 181] request may still reach the transport
        // late (the stale gate drops its reply); the new position must be sent.
        let sent = await waitUntil { self.sentMoves().contains([180, 181, 0]) }
        XCTAssertTrue(sent, "sent: \(sentMoves())")
    }

    func testHeatPaintsBothBoardsAndDotTapSkipsMagnifier() async {
        transport.replies[181] = (stats([(10, 60), (11, 40)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let painted = await waitUntil { self.heatKeys(vc) == [NSNumber(value: 10), NSNumber(value: 11)] }
        XCTAssertTrue(painted)
        XCTAssertEqual(heatKeys(vc), [NSNumber(value: 10), NSNumber(value: 11)])
        XCTAssertEqual(dbOptions(vc, "zoomedBoard").map { Set($0.keys) },
                       [NSNumber(value: 10), NSNumber(value: 11)])

        tap(vc, cell: 10, state: .began)
        XCTAssertTrue(board(vc, "zoomedBoard").isHidden)
        XCTAssertTrue(board(vc, "zoomedStone").isHidden)
        tap(vc, cell: 10, state: .ended)
        XCTAssertEqual(mirror(vc), [180, 181, 10])
        XCTAssertNil(dbOptions(vc), "a new position clears the old heat at once")
    }

    func testEmptyCellTapStillShowsMagnifier() {
        let vc = makeVC(game: "Pente", moves: [180, 181])
        tap(vc, cell: 30, state: .began)
        XCTAssertFalse(board(vc, "zoomedBoard").isHidden)
    }

    func testHeatOffLeavesBoardsBare() async {
        prefs.heatOnBoard = false
        transport.replies[181] = (stats([(10, 60)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let loaded = await waitUntil { self.service.lastStats != nil }
        XCTAssertTrue(loaded)
        XCTAssertTrue(dbOptions(vc)?.isEmpty ?? true)
        XCTAssertTrue(dbOptions(vc, "zoomedBoard")?.isEmpty ?? true)
    }

    func testCapturedCellsAreNotOccupied() {
        // White 180,300,183 vs black 181,182: 183 captures 181+182.
        let vc = makeVC(game: "Pente", moves: [180, 181, 300, 182, 183, 5])
        back(vc)
        XCTAssertEqual(service.occupied, [180, 300, 183])
    }

    func testUnsupportedGameShowsLabelAndSendsNothing() async {
        let vc = makeVC(game: "Go", moves: [180, 181])
        back(vc)
        await settle()
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertNil(dbOptions(vc))
        let label = visibleView(vc, id: "dbStatusLabel") as? UILabel
        XCTAssertEqual(label?.text, "Not supported yet")
    }

    func testFailureShowsRetryThatRefetches() async {
        transport.replies[181] = ("{\"error\":{\"code\":\"oops\"}}", 500)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let failed = await waitUntil { self.visibleView(vc, id: "dbRetryButton") != nil }
        XCTAssertTrue(failed)
        let retry = visibleView(vc, id: "dbRetryButton") as? UIButton
        XCTAssertNotNil(retry)
        transport.replies[181] = (stats([(10, 60)]), 200)
        retry?.sendActions(for: .touchUpInside)
        let recovered = await waitUntil {
            self.visibleView(vc, id: "dbRetryButton") == nil && self.heatKeys(vc) == [NSNumber(value: 10)]
        }
        XCTAssertTrue(recovered)
        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertNil(visibleView(vc, id: "dbRetryButton"))
        XCTAssertEqual(dbOptions(vc).map { Set($0.keys) }, [NSNumber(value: 10)])
    }
    // MARK: Task 12

    private func allLabels(_ v: UIView) -> [UILabel] {
        var out: [UILabel] = []
        if let l = v as? UILabel { out.append(l) }
        for s in v.subviews { out += allLabels(s) }
        return out
    }

    func testHeatToggleHidesAndShowsDotsWithoutRefetch() async {
        transport.replies[181] = (stats([(10, 60), (11, 40)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let painted = await waitUntil { self.heatKeys(vc) == [NSNumber(value: 10), NSNumber(value: 11)] }
        XCTAssertTrue(painted)
        let items = vc.navigationItem.rightBarButtonItems ?? []
        XCTAssertTrue(items.contains { $0.accessibilityIdentifier == "dbHeatToggle" }, "heat button")
        let requestsBefore = transport.requests.count

        vc.perform(NSSelectorFromString("toggleHeat"))
        XCTAssertFalse(prefs.heatOnBoard)
        XCTAssertNil(dbOptions(vc))
        XCTAssertNil(dbOptions(vc, "zoomedBoard"))

        vc.perform(NSSelectorFromString("toggleHeat"))
        XCTAssertTrue(prefs.heatOnBoard)
        XCTAssertEqual(heatKeys(vc), [NSNumber(value: 10), NSNumber(value: 11)])
        XCTAssertEqual(transport.requests.count, requestsBefore, "toggle must not refetch")
    }

    func testToggleWhileInFlightPaintsNothing() async {
        // The previous position's dots are loaded and painted first, so a
        // toggle that repainted stale stats would show them.
        transport.replies[200] = (stats([(10, 60), (11, 40)]), 200)
        transport.replies[181] = (stats([(12, 60)]), 200)
        transport.delays[181] = 400_000_000
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        vc.perform(NSSelectorFromString("positionChanged"))
        let painted = await waitUntil { self.heatKeys(vc) == [NSNumber(value: 10), NSNumber(value: 11)] }
        XCTAssertTrue(painted)
        back(vc)
        // [180, 181] is in flight: currentHeat is empty, so nothing may paint.
        vc.perform(NSSelectorFromString("toggleHeat"))
        vc.perform(NSSelectorFromString("toggleHeat"))
        XCTAssertNil(dbOptions(vc))
        // The delayed reply then paints its own dot only.
        let fresh = await waitUntil { self.heatKeys(vc) == [NSNumber(value: 12)] }
        XCTAssertTrue(fresh)
    }

    // MARK: response alerts (M7)

    private func captureAlerts(_ vc: UIViewController, key: String) -> () -> [UIAlertController] {
        final class Box { var alerts: [UIAlertController] = [] }
        let box = Box()
        let presenter: @convention(block) (UIAlertController) -> Void = { box.alerts.append($0) }
        vc.setValue(presenter, forKey: key)
        return { box.alerts }
    }

    func testUnauthorizedResponseRaisesOneLoginAlert() async {
        transport.replies[181] = ("{\"error\":{\"code\":\"unauthorized\"}}", 401)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        let alerts = captureAlerts(vc, key: "logInAlertPresenter")
        back(vc) // stats and games search both answer 401
        let shown = await waitUntil { alerts().count == 1 }
        XCTAssertTrue(shown)
        await settle()
        XCTAssertEqual(alerts().count, 1)
        XCTAssertEqual(alerts().first?.title, "Please log in again")
    }

    func testSubscriptionRequiredResponseRaisesOneSubscriptionAlert() async {
        transport.replies[181] = ("{\"error\":{\"code\":\"subscription_required\"}}", 403)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        let alerts = captureAlerts(vc, key: "subscriptionAlertPresenter")
        back(vc)
        let shown = await waitUntil { alerts().count == 1 }
        XCTAssertTrue(shown)
        await settle()
        XCTAssertEqual(alerts().count, 1)
        XCTAssertEqual(alerts().first?.title, "Level up your game")
    }

    // MARK: subscription bought on iPad (M1)

    func testEntitlementChangeAfterSubscriptionRequiredRefetches() async {
        transport.replies[181] = ("{\"error\":{\"code\":\"subscription_required\"}}", 403)
        let center = NotificationCenter() // the games list observes the real one
        let sb = UIStoryboard(name: "MainStoryboard", bundle: Bundle.main)
        let vc = sb.instantiateViewController(withIdentifier: "databaseViewController")
        vc.setValue(service, forKey: "dbService")
        vc.setValue(NSMutableArray(array: [180, 181, 200].map { NSNumber(value: $0) }), forKey: "movesList")
        vc.setValue("Pente", forKey: "game")
        vc.setValue(center, forKey: "notificationCenter")
        vc.loadViewIfNeeded()
        let alerts = captureAlerts(vc, key: "subscriptionAlertPresenter")
        back(vc)
        let shown = await waitUntil { alerts().count == 1 }
        XCTAssertTrue(shown)
        transport.replies[181] = (stats([(10, 60)]), 200)
        center.post(name: StoreService.entitlementsChangedNotification, object: nil)
        let painted = await waitUntil { self.heatKeys(vc) == [NSNumber(value: 10)] }
        XCTAssertTrue(painted)
    }

    func testEntitlementChangeWithoutSubscriptionErrorDoesNotRefetch() async {
        transport.replies[181] = (stats([(10, 60)]), 200)
        let center = NotificationCenter()
        let sb = UIStoryboard(name: "MainStoryboard", bundle: Bundle.main)
        let vc = sb.instantiateViewController(withIdentifier: "databaseViewController")
        vc.setValue(service, forKey: "dbService")
        vc.setValue(NSMutableArray(array: [180, 181, 200].map { NSNumber(value: $0) }), forKey: "movesList")
        vc.setValue("Pente", forKey: "game")
        vc.setValue(center, forKey: "notificationCenter")
        vc.loadViewIfNeeded()
        back(vc)
        let painted = await waitUntil { self.heatKeys(vc) == [NSNumber(value: 10)] }
        XCTAssertTrue(painted)
        let before = transport.requests.count
        center.post(name: StoreService.entitlementsChangedNotification, object: nil)
        await settle()
        XCTAssertEqual(transport.requests.count, before)
    }

    // MARK: failed games list on return (M2)

    func testReappearRefetchesFailedGamesListOnly() async {
        transport.replies[181] = (stats([(10, 60)]), 200)
        transport.searchReply = ("{\"error\":{\"code\":\"oops\"}}", 500)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let failed = await waitUntil { self.results(vc).gamesState == .failed }
        XCTAssertTrue(failed)
        let statsBefore = transport.requests.count
        let searchBefore = transport.searchRequests.count
        transport.searchReply = ("{\"total\":0,\"games\":[],\"blocked\":false}", 200)
        vc.viewDidAppear(false)
        let recovered = await waitUntil { self.results(vc).gamesState == .empty }
        XCTAssertTrue(recovered)
        XCTAssertEqual(transport.searchRequests.count, searchBefore + 1)
        XCTAssertEqual(transport.requests.count, statsBefore, "loaded stats are kept")
    }

    // MARK: AI move vs a changed line (F1)

    private func aiStart(_ vc: UIViewController) {
        vc.perform(NSSelectorFromString("aiWillThink"))
    }

    private func aiFinish(_ vc: UIViewController, _ cell: Int) {
        vc.perform(NSSelectorFromString("aiDidChooseMove:"), with: NSNumber(value: cell))
    }

    func testAIMovePlaysOnUnchangedLine() {
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        aiStart(vc)
        aiFinish(vc, 5)
        XCTAssertEqual(mirror(vc), [180, 181, 200, 5])
    }

    func testAIMoveDroppedWhenLineChangedWhileThinking() {
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        aiStart(vc)
        back(vc)
        aiFinish(vc, 5)
        XCTAssertEqual(mirror(vc), [180, 181])
        XCTAssertEqual(line(vc).cells, [180, 181])
    }

    func testAIMoveOnOccupiedCellDropped() {
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        vc.perform(NSSelectorFromString("replayGame")) // viewDidAppear's replay
        aiStart(vc)
        aiFinish(vc, 200)
        XCTAssertEqual(mirror(vc), [180, 181, 200])
    }

    private func flashing(_ vc: UIViewController) -> DBBoardView {
        return board(vc, "board") as! DBBoardView
    }

    func testSelectionDoesNotAffectTheLineAndAIGuardStillHolds() {
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        var pushed: [UIViewController] = []
        let pusher: @convention(block) (UIViewController) -> Void = { pushed.append($0) }
        vc.setValue(pusher, forKey: "gameViewerPusher")
        aiStart(vc)
        results(vc).onSelectionChanged?(10)
        results(vc).onOpenGame?(77, false)
        XCTAssertEqual(mirror(vc), [180, 181, 200])
        XCTAssertEqual(flashing(vc).flashCell, -1, "no flashing while the AI thinks")
        XCTAssertTrue(pushed.isEmpty)
        aiFinish(vc, 5)
        XCTAssertEqual(mirror(vc), [180, 181, 200, 5])
        results(vc).onSelectionChanged?(10)
        XCTAssertEqual(mirror(vc), [180, 181, 200, 5], "selecting never plays")
        XCTAssertEqual(Int(flashing(vc).flashCell), 10)
        XCTAssertEqual(line(vc).redoCount, 0)
    }

    func testAIStartClearsSelectionAndFlashing() async {
        transport.replies[181] = (stats([(10, 60), (11, 40)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let shown = await waitUntil { self.results(vc).rows.count == 2 }
        XCTAssertTrue(shown)
        results(vc).tableView(results(vc).tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(Int(flashing(vc).flashCell), results(vc).rows[0].cell)
        aiStart(vc)
        XCTAssertNil(results(vc).selectedCell)
        XCTAssertEqual(flashing(vc).flashCell, -1)
        XCTAssertFalse(flashing(vc).isFlashAnimating)
    }

    // MARK: injected Go/Renju (F2)

    func testInjectedGoIsNotReplayedWithPenteRules() {
        // Under Pente rules 183 would capture 181+182; 361 is a Go pass.
        let vc = makeVC(game: "Go", moves: [180, 181, 300, 182, 183, 361])
        vc.perform(NSSelectorFromString("replayGame"))
        vc.perform(NSSelectorFromString("positionChanged"))
        XCTAssertEqual(service.occupied, [])
        vc.perform(NSSelectorFromString("setBoardColor"))
        for key in ["whiteStoneCaptures", "blackStoneCaptures",
                    "whiteCapturesCountLabel", "blackCapturesCountLabel"] {
            XCTAssertTrue(board(vc, key).isHidden, key)
        }
        let texts = allLabels(vc.navigationItem.titleView ?? UIView()).map { $0.attributedText?.string ?? $0.text ?? "" }
        XCTAssertTrue(texts.contains("Go"), "\(texts)")
        XCTAssertFalse(texts.contains { $0.contains("●") }, "\(texts)")
    }

    // MARK: strip states on compact width (M3)

    func testEmptyAndBlockedStatesShowInStrip() async {
        transport.replies[181] = (stats([]), 200)
        transport.replies[200] = ("{\"totalGames\":0,\"nextMoves\":[],\"blocked\":true}", 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let empty = await waitUntil {
            (self.visibleView(vc, id: "dbStatusLabel") as? UILabel)?.text == "No moves from this position"
        }
        XCTAssertTrue(empty)
        forward(vc)
        let blocked = await waitUntil {
            (self.visibleView(vc, id: "dbStatusLabel") as? UILabel)?.text
                == "Database unavailable during your rated game"
        }
        XCTAssertTrue(blocked)
    }

    // MARK: injected Go then Apply (M6)

    func testApplyUnchangedFiltersAfterInjectedGoSwitchesToFilterGame() {
        let vc = makeVC(game: "Go", moves: [180, 181])
        guard let sheet = openFilters(vc) else { return XCTFail("no filters sheet") }
        sheet.applyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(game(vc), "Pente")
        XCTAssertEqual(line(vc).game, 1)
        XCTAssertEqual(mirror(vc), [180])
    }

    func testTitleViewShowsDatabaseOverSubtitle() {
        let vc = makeVC(game: "Pente", moves: [180, 181, 200, 182, 183])
        vc.perform(NSSelectorFromString("replayGame"))
        XCTAssertEqual(vc.title, "Database")
        guard let tv = vc.navigationItem.titleView else { return XCTFail("no titleView") }
        let texts = allLabels(tv).map { $0.attributedText?.string ?? $0.text ?? "" }
        XCTAssertTrue(texts.contains("Database"), "\(texts)")
        XCTAssertTrue(texts.contains { $0.hasPrefix("Pente") }, "\(texts)")
    }

    func testTitleViewSubtitleHasNoCapturesForGomoku() {
        let vc = makeVC(game: "Gomoku", moves: [180, 181])
        vc.perform(NSSelectorFromString("replayGame"))
        let texts = allLabels(vc.navigationItem.titleView ?? UIView()).map { $0.attributedText?.string ?? $0.text ?? "" }
        XCTAssertTrue(texts.contains("Gomoku"), "\(texts)")
        XCTAssertFalse(texts.contains { $0.contains("●") })
    }

    func testRepeated401sPresentOnlyOneLoginAlert() {
        // No window: alerts are captured through the presenter seam.
        let vc = makeVC(game: "Pente", moves: [180, 181])
        var presented: [UIAlertController] = []
        let presenter: @convention(block) (UIAlertController) -> Void = { presented.append($0) }
        vc.setValue(presenter, forKey: "logInAlertPresenter")
        let sel = NSSelectorFromString("showLogInAgain")
        vc.perform(sel)
        vc.perform(sel)
        vc.perform(sel)
        XCTAssertEqual(presented.count, 1)
        XCTAssertEqual(presented.first?.title, "Please log in again")
    }

    // MARK: results panel/sheet (Task 14)

    private func results(_ vc: UIViewController) -> DBResultsViewController {
        return vc.value(forKey: "resultsVC") as! DBResultsViewController
    }

    func testHostOwnsOneResultsVCAndForwardsLoadedRows() async {
        transport.replies[181] = (stats([(10, 60), (11, 40)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        let first = results(vc)
        back(vc)
        let shown = await waitUntil { self.results(vc).rows.count == 2 }
        XCTAssertTrue(shown)
        XCTAssertTrue(results(vc) === first, "one results VC for the screen's lifetime")
        XCTAssertEqual(Set(results(vc).rows.map(\.cell)), [10, 11])
    }

    func testHostForwardsEmptyAndBlockedStates() async {
        transport.replies[181] = (stats([]), 200)
        transport.replies[200] = ("{\"totalGames\":0,\"nextMoves\":[],\"blocked\":true}", 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let empty = await waitUntil { self.results(vc).messageLabel.text == "No moves from this position" }
        XCTAssertTrue(empty)
        forward(vc)
        let blocked = await waitUntil {
            self.results(vc).messageLabel.text == "Database unavailable during your rated game"
        }
        XCTAssertTrue(blocked)
    }

    func testResultsRowTapSelectsAndFlashesWithoutPlayingOrSearching() async {
        transport.replies[181] = (stats([(10, 60), (11, 40)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let shown = await waitUntil { self.results(vc).rows.count == 2 }
        XCTAssertTrue(shown)
        let sent = transport.requests.count
        let searches = transport.searchRequests.count
        let r = results(vc)
        r.tableView(r.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        let cell = r.rows[0].cell
        XCTAssertEqual(mirror(vc), [180, 181], "selecting never plays")
        XCTAssertEqual(line(vc).redoCount, 1)
        XCTAssertEqual(Int(flashing(vc).flashCell), cell)
        XCTAssertEqual(flashing(vc).flashColor, dbOptions(vc)?[NSNumber(value: cell)])
        XCTAssertEqual(flashing(vc).reduceMotion, UIAccessibility.isReduceMotionEnabled)
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(transport.requests.count, sent, "no stats query")
        XCTAssertEqual(transport.searchRequests.count, searches, "no games query")
        // Same row again: unselect and stop.
        r.tableView(r.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(flashing(vc).flashCell, -1)
        XCTAssertFalse(flashing(vc).isFlashAnimating)
    }

    func testFlashStoneIsTheSideToMove() async {
        transport.replies[181] = (stats([(10, 60)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc) // two moves played: white to move
        let shown = await waitUntil { self.results(vc).rows.count == 1 }
        XCTAssertTrue(shown)
        flashing(vc).reduceMotionOverride = NSNumber(value: false)
        let r = results(vc)
        r.tableView(r.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(flashing(vc).flashStoneIsWhite)
        XCTAssertTrue(flashing(vc).isFlashAnimating)
        XCTAssertTrue(flashing(vc).flashStoneVisible)
        flashing(vc).flashTick()
        XCTAssertFalse(flashing(vc).flashStoneVisible, "alternates with the heat colour")
        flashing(vc).flashTick()
        XCTAssertTrue(flashing(vc).flashStoneVisible)
    }

    func testReduceMotionShowsStaticHighlightWithoutTimer() async {
        transport.replies[181] = (stats([(10, 60)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let shown = await waitUntil { self.results(vc).rows.count == 1 }
        XCTAssertTrue(shown)
        flashing(vc).reduceMotionOverride = NSNumber(value: true)
        let r = results(vc)
        r.tableView(r.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(Int(flashing(vc).flashCell), 10)
        XCTAssertFalse(flashing(vc).isFlashAnimating, "no animation under Reduce Motion")
        flashing(vc).flashTick()
        XCTAssertTrue(flashing(vc).flashStoneVisible, "tick is inert under Reduce Motion")
    }

    func testPlacingAStoneOrNavigatingClearsSelection() async {
        transport.replies[181] = (stats([(10, 60), (11, 40)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let shown = await waitUntil { self.results(vc).rows.count == 2 }
        XCTAssertTrue(shown)
        let r = results(vc)
        r.tableView(r.tableView, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertGreaterThanOrEqual(flashing(vc).flashCell, 0)
        layout(vc, CGSize(width: 390, height: 844))
        tap(vc, cell: 250, state: .ended) // a stone placed on the board
        XCTAssertNil(r.selectedCell)
        XCTAssertEqual(flashing(vc).flashCell, -1)
        back(vc)
        XCTAssertNil(r.selectedCell)
    }

    private func selectFirstRow(_ vc: UIViewController) async {
        transport.replies[181] = (stats([(10, 60), (11, 40)]), 200)
        back(vc)
        let shown = await waitUntil { self.results(vc).rows.count == 2 }
        XCTAssertTrue(shown)
        let r = results(vc)
        r.tableView(r.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertNotNil(r.selectedCell)
        XCTAssertGreaterThanOrEqual(flashing(vc).flashCell, 0)
    }

    func testViewWillDisappearAloneClearsSelection() async {
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        await selectFirstRow(vc)
        vc.viewWillDisappear(false)
        XCTAssertNil(results(vc).selectedCell)
        XCTAssertEqual(flashing(vc).flashCell, -1)
    }

    func testBackNavigationAloneClearsSelection() async {
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        transport.replies[181] = (stats([(10, 60), (11, 40)]), 200)
        back(vc)
        let shown = await waitUntil { self.results(vc).rows.count == 2 }
        XCTAssertTrue(shown)
        transport.replies[180] = (stats([(12, 60), (13, 40)]), 200)
        let r = results(vc)
        r.tableView(r.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertNotNil(r.selectedCell)
        back(vc)
        XCTAssertNil(r.selectedCell)
        XCTAssertEqual(flashing(vc).flashCell, -1)
    }

    func testReduceMotionChangeWhileFlashingSwitchesTimerMode() async {
        transport.replies[181] = (stats([(10, 60)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let shown = await waitUntil { self.results(vc).rows.count == 1 }
        XCTAssertTrue(shown)
        let fb = flashing(vc)
        fb.reduceMotionOverride = NSNumber(value: false)
        let r = results(vc)
        r.tableView(r.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertTrue(fb.isFlashAnimating)
        fb.reduceMotionOverride = NSNumber(value: true)
        NotificationCenter.default.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        XCTAssertEqual(Int(fb.flashCell), 10, "still flashing the same cell")
        XCTAssertFalse(fb.isFlashAnimating, "timer off after Reduce Motion turns on")
        fb.reduceMotionOverride = NSNumber(value: false)
        NotificationCenter.default.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        XCTAssertEqual(Int(fb.flashCell), 10)
        XCTAssertTrue(fb.isFlashAnimating, "timer back on after Reduce Motion turns off")
        // Not flashing: a notification must not start anything.
        fb.stopFlashing()
        NotificationCenter.default.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        XCTAssertEqual(fb.flashCell, -1)
        XCTAssertFalse(fb.isFlashAnimating)
    }

    func testSortChangeResortsListAndBoardHeatWithoutRefetch() async {
        // Win % and game counts rank the two moves in opposite order.
        let json = "{\"totalGames\":10,\"totalWinPct\":50,\"nextMoves\":[" +
            "{\"move\":10,\"games\":20,\"wins\":1,\"winPct\":60}," +
            "{\"move\":11,\"games\":90,\"wins\":1,\"winPct\":40}],\"blocked\":false}"
        transport.replies[181] = (json, 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let shown = await waitUntil { self.results(vc).rows.count == 2 }
        XCTAssertTrue(shown)
        let before = results(vc).rows.map(\.cell)
        XCTAssertEqual(before, [10, 11])
        results(vc).selectSort(.games)
        XCTAssertEqual(prefs.moveSort, .games)
        XCTAssertEqual(results(vc).rows.count, 2)
        XCTAssertEqual(results(vc).rows.map(\.cell), [11, 10], "order flips, not just the set")
        XCTAssertEqual(Set(results(vc).rows.map(\.cell)), Set(before))
        XCTAssertEqual(heatKeys(vc), Set(before.map { NSNumber(value: $0) }))
        XCTAssertEqual(transport.requests.count, 1, "no refetch")
    }

    func testResultsRetryRefetches() async {
        let vc = makeVC(game: "Pente", moves: [180, 181])
        results(vc).onRetry?()
        let sent = await waitUntil { self.transport.requests.count == 1 }
        XCTAssertTrue(sent)
        XCTAssertEqual(sentMoves(), [[180, 181]])
    }

    func testShowCountChangeRecomputesBoardHeatWithoutRefetch() async {
        let many = (0 ..< 15).map { (100 + $0, Double(40 + $0)) }
        transport.replies[181] = (stats(many), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let loaded = await waitUntil { (self.dbOptions(vc)?.count ?? 0) == 15 }
        XCTAssertTrue(loaded)
        results(vc).selectShowCount(10)
        XCTAssertEqual(prefs.movesShown, 10)
        XCTAssertEqual(dbOptions(vc)?.count, 10)
        XCTAssertEqual(results(vc).rows.count, 10)
        XCTAssertEqual(transport.requests.count, 1, "no refetch")
    }

    private func layout(_ vc: UIViewController, _ size: CGSize) {
        vc.view.frame = CGRect(origin: .zero, size: size)
        vc.view.setNeedsLayout()
        vc.view.layoutIfNeeded()
    }

    func testTallScreenBoardIsCappedAndCentred() {
        let vc = makeVC(game: "Pente", moves: [180])
        layout(vc, CGSize(width: 1032, height: 1300))
        let b = board(vc, "board").frame
        let side = (1300 * 0.62).rounded(.down)
        XCTAssertEqual(b.width, side, accuracy: 1)
        XCTAssertEqual(b.height, b.width, accuracy: 0.5)
        XCTAssertEqual(b.midX, 516, accuracy: 1)
        XCTAssertEqual(board(vc, "zoomedBoard").bounds.width, 2 * b.width, accuracy: 1)
        XCTAssertEqual(board(vc, "stone").bounds.width, 1.2 * b.width / 19, accuracy: 0.5)
    }

    func testMagnifierCentresInBoardCoordinatesWhenBoardIsCentred() {
        let vc = makeVC(game: "Pente", moves: [180])
        layout(vc, CGSize(width: 1032, height: 1300))
        let b = board(vc, "board")
        XCTAssertGreaterThan(b.frame.minX, 0, "board is centred with side margins")
        tap(vc, cell: 0, state: .began)
        let cs = b.bounds.width / 19
        let mid = b.bounds.width / 2
        let p = 0.5 * cs
        let z = board(vc, "zoomedBoard").center
        XCTAssertEqual(z.x, mid - (p - mid), accuracy: 0.5)
        XCTAssertEqual(z.y, mid - (p - mid), accuracy: 0.5)
    }

    func testPhoneBoardStaysFullWidth() {
        let vc = makeVC(game: "Pente", moves: [180])
        layout(vc, CGSize(width: 402, height: 734))
        let b = board(vc, "board").frame
        XCTAssertEqual(b.width, 402, accuracy: 0.5)
        XCTAssertEqual(b.minX, 0, accuracy: 0.5)
    }

    func testUnderBoardStripSitsBelowBoard() {
        let vc = makeVC(game: "Pente", moves: [180])
        layout(vc, CGSize(width: 1032, height: 1300))
        let boardMaxY = board(vc, "board").frame.maxY
        let stripMaxY = (vc.value(forKey: "stripMaxY") as? NSNumber)?.doubleValue ?? 0
        for key in ["aiButton", "whiteCapturesCountLabel", "blackCapturesCountLabel",
                    "whiteStoneCaptures", "blackStoneCaptures"] {
            let f = board(vc, key).frame
            XCTAssertGreaterThanOrEqual(f.minY, boardMaxY, key)
            XCTAssertLessThanOrEqual(f.maxY, CGFloat(stripMaxY), key)
        }
        for id in ["dbStatusLabel", "dbRetryButton"] {
            guard let v = findView(vc.view, id: id) else { return XCTFail(id) }
            XCTAssertGreaterThanOrEqual(v.frame.minY, boardMaxY, id)
            XCTAssertLessThanOrEqual(v.frame.maxY, CGFloat(stripMaxY), id)
        }
    }

    private func findView(_ v: UIView, id: String) -> UIView? {
        if v.accessibilityIdentifier == id { return v }
        for s in v.subviews { if let f = findView(s, id: id) { return f } }
        return nil
    }

    private func movesButton(_ vc: UIViewController) -> UIBarButtonItem? {
        return vc.navigationItem.rightBarButtonItems?.first { $0.accessibilityIdentifier == "dbMovesButton" }
    }

    func testRegularWidthEmbedsResultsBelowStrip() throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("traitOverrides needs iOS 17") }
        let vc = makeVC(game: "Pente", moves: [180])
        vc.traitOverrides.horizontalSizeClass = .regular
        layout(vc, CGSize(width: 1032, height: 1300))
        let r = results(vc)
        XCTAssertTrue(r.parent === vc)
        XCTAssertTrue(r.view.superview === vc.view)
        let stripMaxY = (vc.value(forKey: "stripMaxY") as? NSNumber)?.doubleValue ?? 0
        XCTAssertGreaterThanOrEqual(r.view.frame.minY, CGFloat(stripMaxY))
        XCTAssertEqual(r.view.frame.maxY, 1300, accuracy: 0.5)
        XCTAssertNil(movesButton(vc), "no Moves button on iPad")
    }

    func testCompactAutoPresentsOnceAndMovesButtonRePresents() async {
        transport.replies[181] = (stats([(10, 60)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        // No window: presentations are captured through the presenter seam.
        var presented: [UIViewController] = []
        let presenter: @convention(block) (UIViewController) -> Void = { presented.append($0) }
        vc.setValue(presenter, forKey: "resultsSheetPresenter")
        if #available(iOS 17.0, *) {
            vc.traitOverrides.horizontalSizeClass = .compact // also on the iPad simulator
        }
        layout(vc, CGSize(width: 402, height: 734))
        back(vc)
        forward(vc)
        XCTAssertEqual(presented.count, 1, "auto-presented once, after the first position change")
        XCTAssertTrue(presented.first === results(vc))
        guard let item = movesButton(vc) else { return XCTFail("no Moves button") }
        _ = (item.target as? NSObject)?.perform(item.action)
        XCTAssertEqual(presented.count, 2)
        XCTAssertNil(results(vc).parent, "not embedded in compact width")
    }

    // MARK: games list + viewer (Task 18)

    func testHostForwardsGamesStateToResults() async {
        // The stats body decodes as an empty games page (total 0).
        transport.replies[181] = (stats([(10, 60)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let forwarded = await waitUntil { self.results(vc).gamesState == .empty }
        XCTAssertTrue(forwarded)
    }

    func testOpeningAGamePushesViewerForThatGid() {
        let vc = makeVC(game: "Pente", moves: [180])
        var pushed: [UIViewController] = []
        let pusher: @convention(block) (UIViewController) -> Void = { pushed.append($0) }
        vc.setValue(pusher, forKey: "gameViewerPusher")
        results(vc).onOpenGame?(50_000_000_000_123, false)
        XCTAssertEqual(pushed.count, 1)
        XCTAssertEqual((pushed.first as? DBGameViewerViewController)?.gid, 50_000_000_000_123)
        XCTAssertEqual((pushed.first as? DBGameViewerViewController)?.isMine, false)
    }

    func testOpeningAMineRowPushesCollectionViewer() {
        let vc = makeVC(game: "Pente", moves: [180])
        var pushed: [UIViewController] = []
        let pusher: @convention(block) (UIViewController) -> Void = { pushed.append($0) }
        vc.setValue(pusher, forKey: "gameViewerPusher")
        results(vc).onOpenGame?(42, true)
        XCTAssertEqual((pushed.first as? DBGameViewerViewController)?.gid, 42)
        XCTAssertEqual((pushed.first as? DBGameViewerViewController)?.isMine, true)
    }

    func testCompactSheetUsesBelowBoardDetentWithUndimmedSmallDetent() {
        let vc = makeVC(game: "Pente", moves: [180])
        layout(vc, CGSize(width: 402, height: 734))
        vc.perform(NSSelectorFromString("configureResultsSheet"))
        guard let sheet = results(vc).sheetPresentationController else { return XCTFail("no sheet") }
        XCTAssertTrue(sheet.prefersGrabberVisible)
        XCTAssertEqual(sheet.detents.count, 2)
        if #available(iOS 16.0, *) {
            let small = UISheetPresentationController.Detent.Identifier("belowBoard")
            XCTAssertEqual(sheet.detents.first?.identifier, small)
            XCTAssertEqual(sheet.largestUndimmedDetentIdentifier, small)
            XCTAssertEqual(sheet.detents.last?.identifier, .large)
        }
    }

    // MARK: filters sheet + chip row (Task 21)

    private var filterStore: DBFilterStore { DBFilterStore(defaults: UserDefaults(suiteName: suite)!) }

    private func game(_ vc: UIViewController) -> String? {
        return vc.value(forKey: "game") as? String
    }

    private func gamesOfRequests() -> [Int] {
        return transport.requests.compactMap { r in
            guard let b = r.httpBody,
                  let o = try? JSONSerialization.jsonObject(with: b) as? [String: Any] else { return nil }
            return o["game"] as? Int
        }
    }

    func testNilGameUsesSavedFilterGame() {
        var s = DBFilterState()
        s.setGame(id: 3)
        filterStore.save(s)
        service = DBPositionService(client: DBClient(endpoint: DBEndpoint(useLocalhost: false),
                                                     transport: transport),
                                    preferences: prefs)
        let vc = makeVC(game: nil, moves: [180])
        XCTAssertEqual(game(vc), "Keryo-Pente")
        XCTAssertEqual(line(vc).game, 3)
    }

    func testInjectedGameIsAdoptedIntoFilters() {
        let vc = makeVC(game: "Speed Pente", moves: [180, 181])
        XCTAssertEqual(game(vc), "Speed Pente")
        XCTAssertEqual(service.filterGameId, 2)
        XCTAssertEqual(filterStore.load().gameId, 2)
    }

    func testInjectedUnsupportedGameKeepsNameAndFilters() {
        let vc = makeVC(game: "Go", moves: [180, 181])
        XCTAssertEqual(game(vc), "Go")
        XCTAssertEqual(service.filterGameId, 1)
    }

    func testChipRowShowsSummaryInsideStrip() {
        var s = DBFilterState()
        s.player1 = "alice"
        s.p1MinRating = 1700
        service.filterState = s
        let vc = makeVC(game: "Pente", moves: [180])
        layout(vc, CGSize(width: 402, height: 734))
        guard let chip = visibleView(vc, id: "dbFilterChips") as? UIButton else { return XCTFail("no chip row") }
        XCTAssertEqual(chip.title(for: .normal), "Pente · alice 1700+")
        let boardMaxY = board(vc, "board").frame.maxY
        let stripMaxY = (vc.value(forKey: "stripMaxY") as? NSNumber)?.doubleValue ?? 0
        XCTAssertGreaterThanOrEqual(chip.frame.minY, boardMaxY)
        XCTAssertLessThanOrEqual(chip.frame.maxY, CGFloat(stripMaxY))
    }

    private func openFilters(_ vc: UIViewController) -> DBFiltersViewController? {
        var presented: [UIViewController] = []
        let presenter: @convention(block) (UIViewController) -> Void = { presented.append($0) }
        vc.setValue(presenter, forKey: "filtersPresenter")
        vc.perform(NSSelectorFromString("showSetup"))
        XCTAssertEqual(presented.count, 1)
        let sheet = presented.first as? DBFiltersViewController
        sheet?.loadViewIfNeeded()
        return sheet
    }

    func testApplyWithNewGameResetsLineRecoloursAndRefetches() async {
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        layout(vc, CGSize(width: 402, height: 734))
        guard let sheet = openFilters(vc) else { return XCTFail("no filters sheet") }
        sheet.gameChips.first { $0.tag == 3 }!.sendActions(for: .touchUpInside)
        sheet.applyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(game(vc), "Keryo-Pente")
        XCTAssertEqual(line(vc).game, 3)
        XCTAssertEqual(line(vc).cells, [180])
        XCTAssertEqual(mirror(vc), [180])
        XCTAssertEqual(board(vc, "board").backgroundColor, DBPalette.boardColor(forGame: 3))
        XCTAssertEqual(filterStore.load().gameId, 3)
        let chip = visibleView(vc, id: "dbFilterChips") as? UIButton
        XCTAssertEqual(chip?.title(for: .normal), "Keryo-Pente")
        let sent = await waitUntil { self.gamesOfRequests().contains(3) }
        XCTAssertTrue(sent)
        XCTAssertEqual(sentMoves().last, [180])
    }

    func testApplySameGameKeepsLineAndRefetchesWithFilters() async {
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        guard let sheet = openFilters(vc) else { return XCTFail("no filters sheet") }
        sheet.winnerControl.selectedSegmentIndex = 1
        sheet.winnerControl.sendActions(for: .valueChanged)
        sheet.applyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(line(vc).cells, [180, 181, 200])
        let sent = await waitUntil {
            self.transport.requests.contains { String(decoding: $0.httpBody ?? Data(), as: UTF8.self)
                .contains("\"winner\":1") }
        }
        XCTAssertTrue(sent)
        XCTAssertEqual(sentMoves().last, [180, 181, 200])
    }

    func testFiltersSheetOpensFromChipRow() {
        let vc = makeVC(game: "Pente", moves: [180])
        layout(vc, CGSize(width: 402, height: 734))
        var presented: [UIViewController] = []
        let presenter: @convention(block) (UIViewController) -> Void = { presented.append($0) }
        vc.setValue(presenter, forKey: "filtersPresenter")
        (visibleView(vc, id: "dbFilterChips") as? UIButton)?.sendActions(for: .touchUpInside)
        XCTAssertTrue(presented.first is DBFiltersViewController)
    }
}
