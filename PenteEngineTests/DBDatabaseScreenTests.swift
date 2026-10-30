@testable import penteLive
import XCTest

/// Scripted position-stats transport keyed by the last move in the request
/// body. Never touches the network.
private final class DBScreenTransport: Transport, @unchecked Sendable {
    // data(for:) runs off the main actor (DBClient is nonisolated), so a
    // superseded request and its replacement can hit it concurrently.
    private let lock = NSLock()
    private var _replies: [Int: (body: String, status: Int)] = [:]
    private var _requests: [URLRequest] = []

    var replies: [Int: (body: String, status: Int)] {
        get { lock.lock(); defer { lock.unlock() }; return _replies }
        set { lock.lock(); defer { lock.unlock() }; _replies = newValue }
    }

    var requests: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let key = DBScreenTransport.moves(of: request).last ?? -1
        lock.lock()
        _requests.append(request)
        let r = _replies[key] ?? (body: "{}", status: 200)
        lock.unlock()
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
        let client = DBClient(endpoint: DBEndpoint(useLocalhost: false, credentials: nil),
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
}
