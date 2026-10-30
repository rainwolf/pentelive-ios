@testable import penteLive
import XCTest

/// Replies to every position-stats request with one scripted body.
/// Never touches the network.
private final class DBResultsTransport: Transport, @unchecked Sendable {
    private let lock = NSLock()
    private var _body = "{}"
    private var _count = 0

    var body: String {
        get { lock.lock(); defer { lock.unlock() }; return _body }
        set { lock.lock(); defer { lock.unlock() }; _body = newValue }
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return _count
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.lock()
        _count += 1
        let b = _body
        lock.unlock()
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil,
                                   headerFields: nil)!
        return (Data(b.utf8), resp)
    }
}

/// The results VC is driven directly, never put in a window.
@MainActor
final class DBResultsViewControllerTests: XCTestCase {
    private let suite = "DBResultsViewControllerTests.suite"
    private var transport: DBResultsTransport!
    private var prefs: DBPreferences!
    private var service: DBPositionService!

    override func setUp() {
        super.setUp()
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        transport = DBResultsTransport()
        let client = DBClient(endpoint: DBEndpoint(useLocalhost: false, credentials: nil),
                              transport: transport)
        prefs = DBPreferences(defaults: UserDefaults(suiteName: suite)!)
        service = DBPositionService(client: client, preferences: prefs)
    }

    override func tearDown() {
        UserDefaults(suiteName: suite)?.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private func stats(_ moves: [(Int, Int, Int, Double)], total: Int = 99, blocked: Bool = false) -> String {
        let nm = moves.map { "{\"move\":\($0.0),\"games\":\($0.1),\"wins\":\($0.2),\"winPct\":\($0.3)}" }
            .joined(separator: ",")
        return "{\"totalGames\":\(total),\"totalWinPct\":50,\"nextMoves\":[\(nm)],\"blocked\":\(blocked)}"
    }

    private func waitUntil(timeout: Double = 2, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return true
    }

    private func load(_ body: String, game: Int = 1, occupied: [Int] = [180]) async -> DBResultsViewController {
        transport.body = body
        let vc = DBResultsViewController(service: service)
        vc.loadViewIfNeeded()
        service.positionDidChange(game: game, moves: [180], occupied: occupied.map { NSNumber(value: $0) })
        let done = await waitUntil { self.service.lastStats != nil }
        XCTAssertTrue(done)
        vc.reload()
        return vc
    }

    // MARK: tests

    func testRowsAreWilsonOrderedWithBoardColours() async {
        // Wilson lower bounds: 600/1000 > 220/400 > 4/5, despite 4/5's 80%.
        let vc = await load(stats([(220, 5, 4, 80), (181, 400, 220, 55), (200, 1000, 600, 60)]))
        XCTAssertEqual(vc.rows.map(\.cell), [200, 181, 220])
        XCTAssertEqual(vc.tableView.numberOfRows(inSection: 0), 3)
        let heat = service.currentHeat
        for r in vc.rows {
            XCTAssertEqual(r.color, heat[NSNumber(value: r.cell)], "row \(r.cell)")
        }
    }

    func testOccupiedCandidateIsNotListed() async {
        let vc = await load(stats([(180, 50, 25, 50), (181, 50, 25, 50)]))
        XCTAssertEqual(vc.rows.map(\.cell), [181])
    }

    func testShowCountChangeSavesPreferenceAndNotifies() async {
        let many = (0 ..< 15).map { (100 + $0, 50, 25, Double(40 + $0)) }
        let vc = await load(stats(many))
        XCTAssertEqual(vc.rows.count, 15)
        var notified = 0
        vc.onShowCountChanged = { notified += 1 }
        vc.selectShowCount(10)
        XCTAssertEqual(prefs.movesShown, 10)
        XCTAssertEqual(notified, 1)
        vc.reload()
        XCTAssertEqual(vc.rows.count, 10)
        XCTAssertEqual(service.currentHeat.count, 10, "board and list share one domain")
    }

    func testShowMenuOffersTheFourOptions() {
        let vc = DBResultsViewController(service: service)
        vc.loadViewIfNeeded()
        let titles = vc.showButton.menu?.children.map(\.title) ?? []
        XCTAssertEqual(titles, ["Show 10 moves", "Show 20 moves", "Show 40 moves", "Show all moves"])
        XCTAssertEqual(vc.showButton.title(for: .normal), "Show 20 moves")
    }

    func testSelectingRowPlaysMove() async {
        let vc = await load(stats([(181, 50, 25, 50), (200, 50, 30, 60)]))
        var played: [Int] = []
        vc.onPlayMove = { played.append($0) }
        vc.tableView(vc.tableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(played, [vc.rows[0].cell])
    }

    func testRowCellShowsLabelPctAndGames() async {
        let vc = await load(stats([(181, 1234, 716, 58.04)]))
        let cell = vc.tableView(vc.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        let texts = Self.labels(cell).compactMap(\.text)
        XCTAssertTrue(texts.contains("L10"), "\(texts)")
        XCTAssertTrue(texts.contains("58%"), "\(texts)")
        XCTAssertTrue(texts.contains(vc.rows[0].gamesText), "\(texts)")
    }

    func testSegmentsShowTotalAndGamesIsDisabled() async {
        let vc = await load(stats([(181, 50, 25, 50)], total: 1234))
        XCTAssertEqual(vc.segmented.numberOfSegments, 2)
        XCTAssertEqual(vc.segmented.titleForSegment(at: 0), "Moves")
        XCTAssertTrue(vc.segmented.titleForSegment(at: 1)?.hasPrefix("Games · ") ?? false)
        XCTAssertTrue(vc.segmented.titleForSegment(at: 1)?.hasSuffix("234") ?? false)
        XCTAssertFalse(vc.segmented.isEnabledForSegment(at: 1))
        XCTAssertEqual(vc.segmented.selectedSegmentIndex, 0)
    }

    func testStateMessages() {
        let vc = DBResultsViewController(service: service)
        vc.loadViewIfNeeded()
        let cases: [(DBLoadState, String)] = [
            (.blocked, "Database unavailable during your rated game"),
            (.empty, "No moves from this position"),
            (.failed, "Couldn't load"),
            (.unsupported, "Not supported yet"),
        ]
        for (state, text) in cases {
            vc.showState(state)
            XCTAssertFalse(vc.messageLabel.isHidden, "\(state)")
            XCTAssertEqual(vc.messageLabel.text, text)
            XCTAssertTrue(vc.tableView.isHidden, "\(state)")
            XCTAssertEqual(vc.retryButton.isHidden, state != .failed, "\(state)")
        }
        vc.showState(.loading)
        XCTAssertTrue(vc.spinner.isAnimating)
        XCTAssertTrue(vc.tableView.isHidden)
        vc.showState(.loaded)
        XCTAssertFalse(vc.spinner.isAnimating)
        XCTAssertFalse(vc.tableView.isHidden)
        XCTAssertTrue(vc.messageLabel.isHidden)
    }

    func testRetryCallsHost() {
        let vc = DBResultsViewController(service: service)
        vc.loadViewIfNeeded()
        var retried = 0
        vc.onRetry = { retried += 1 }
        vc.showState(.failed)
        vc.retryButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(retried, 1)
    }

    func testNeverSetsServiceCallbacks() {
        let vc = DBResultsViewController(service: service)
        vc.loadViewIfNeeded()
        vc.reload()
        XCTAssertNil(service.onHeat)
        XCTAssertNil(service.onStatsState)
    }

    private static func labels(_ v: UIView) -> [UILabel] {
        var out: [UILabel] = []
        if let l = v as? UILabel { out.append(l) }
        for s in v.subviews { out += labels(s) }
        return out
    }
}
