@testable import penteLive
import XCTest

/// Replies to every position-stats request with one scripted body.
/// Never touches the network.
private final class DBResultsTransport: Transport, @unchecked Sendable {
    private let lock = NSLock()
    private var _body = "{}"
    private var _gamesBody = "{}"
    private var _count = 0

    var body: String {
        get { lock.lock(); defer { lock.unlock() }; return _body }
        set { lock.lock(); defer { lock.unlock() }; _body = newValue }
    }

    /// Reply to /games/search.
    var gamesBody: String {
        get { lock.lock(); defer { lock.unlock() }; return _gamesBody }
        set { lock.lock(); defer { lock.unlock() }; _gamesBody = newValue }
    }

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return _count
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.lock()
        _count += 1
        let b = request.url?.path.hasSuffix("/games/search") == true ? _gamesBody : _body
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
        let client = DBClient(endpoint: DBEndpoint(useLocalhost: false),
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

    private func tapRow(_ vc: DBResultsViewController, _ row: Int) {
        vc.tableView(vc.tableView, didSelectRowAt: IndexPath(row: row, section: 0))
    }

    func testTappingRowSelectsItWithoutAnyRequest() async {
        let vc = await load(stats([(181, 50, 25, 50), (200, 50, 30, 60)]))
        let requests = transport.count
        var changes: [Int] = []
        vc.onSelectionChanged = { changes.append($0) }
        tapRow(vc, 0)
        XCTAssertEqual(vc.selectedCell, vc.rows[0].cell)
        XCTAssertEqual(changes, [vc.rows[0].cell])
        await Task.yield()
        XCTAssertEqual(transport.count, requests, "selecting never queries the server")
    }

    func testTappingSelectedRowAgainUnselects() async {
        let vc = await load(stats([(181, 50, 25, 50), (200, 50, 30, 60)]))
        var changes: [Int] = []
        vc.onSelectionChanged = { changes.append($0) }
        tapRow(vc, 0)
        tapRow(vc, 0)
        XCTAssertNil(vc.selectedCell)
        XCTAssertEqual(changes, [vc.rows[0].cell, -1])
    }

    func testTappingAnotherRowMovesTheSelection() async {
        let vc = await load(stats([(181, 50, 25, 50), (200, 50, 30, 60)]))
        var changes: [Int] = []
        vc.onSelectionChanged = { changes.append($0) }
        tapRow(vc, 0)
        tapRow(vc, 1)
        XCTAssertEqual(vc.selectedCell, vc.rows[1].cell)
        XCTAssertEqual(changes, [vc.rows[0].cell, vc.rows[1].cell])
    }

    func testReloadSortAndShowCountClearTheSelection() async {
        let many = (0 ..< 15).map { (100 + $0, 50, 25, Double(40 + $0)) }
        let vc = await load(stats(many))
        var changes: [Int] = []
        vc.onSelectionChanged = { changes.append($0) }
        tapRow(vc, 2)
        vc.reload()
        XCTAssertNil(vc.selectedCell)
        tapRow(vc, 2)
        vc.selectSort(.games)
        XCTAssertNil(vc.selectedCell)
        tapRow(vc, 2)
        vc.selectShowCount(10)
        XCTAssertNil(vc.selectedCell)
        tapRow(vc, 2)
        vc.showState(.loading)
        XCTAssertNil(vc.selectedCell)
        XCTAssertEqual(changes.filter { $0 == -1 }.count, 4)
        vc.clearSelection()
        XCTAssertEqual(changes.filter { $0 == -1 }.count, 4, "nothing selected: no notification")
    }

    func testSelectedRowIsMarkedInTheTable() async {
        let vc = await load(stats([(181, 50, 25, 50), (200, 50, 30, 60)]))
        tapRow(vc, 1)
        let selected = vc.tableView(vc.tableView, cellForRowAt: IndexPath(row: 1, section: 0)) as! DBMoveRowCell
        let other = vc.tableView(vc.tableView, cellForRowAt: IndexPath(row: 0, section: 0)) as! DBMoveRowCell
        XCTAssertTrue(selected.isMarked)
        XCTAssertFalse(other.isMarked)
        XCTAssertTrue(selected.accessibilityTraits.contains(.selected))
        XCTAssertNotEqual(selected.contentView.backgroundColor, other.contentView.backgroundColor)
    }

    func testBarIsFilledWithTheMovesBoardColour() async {
        let vc = await load(stats([(181, 50, 25, 50), (200, 50, 30, 60), (201, 50, 40, 80)]))
        for i in 0 ..< vc.rows.count {
            let cell = vc.tableView(vc.tableView, cellForRowAt: IndexPath(row: i, section: 0)) as! DBMoveRowCell
            XCTAssertEqual(cell.barFill.backgroundColor, vc.rows[i].color, "row \(i)")
            XCTAssertEqual(cell.barFill.backgroundColor, service.currentHeat[NSNumber(value: vc.rows[i].cell)])
        }
    }

    func testSortControlOffersWinPercentAndPopularityAndDefaultsToWinPercent() {
        let vc = DBResultsViewController(service: service)
        vc.loadViewIfNeeded()
        XCTAssertEqual(vc.sortControl.numberOfSegments, 2)
        XCTAssertEqual(vc.sortControl.titleForSegment(at: 0), "Win %")
        XCTAssertEqual(vc.sortControl.titleForSegment(at: 1), "Popularity")
        XCTAssertEqual(vc.sortControl.selectedSegmentIndex, 0)
    }

    func testInfoButtonExistsAndPresentsWinRateExplanation() {
        let vc = DBResultsViewController(service: service)
        vc.loadViewIfNeeded()
        XCTAssertEqual(vc.infoButton.accessibilityLabel, "About win %")
        XCTAssertNotNil(vc.infoButton.image(for: .normal))
        var presented: UIViewController?
        vc.presentInfo = { presented = $0 }
        vc.infoButton.sendActions(for: .touchUpInside)
        guard let p = presented else { return XCTFail("nothing presented") }
        XCTAssertEqual(p.modalPresentationStyle, .popover)
        p.loadViewIfNeeded()
        let text = p.view.subviews.compactMap { ($0 as? UILabel)?.text }.joined()
        XCTAssertTrue(text.contains("Popularity"), text)
        XCTAssertTrue(text.contains("few games"), text)
    }

    func testSortControlReflectsSavedPreference() {
        prefs.moveSort = .games
        let vc = DBResultsViewController(service: service)
        vc.loadViewIfNeeded()
        XCTAssertEqual(vc.sortControl.selectedSegmentIndex, 1)
    }

    func testSortChangeResortsLocallyAndSavesPreference() async {
        // 181 is the most played (1000), 200 has the better rate (70% of 400).
        let vc = await load(stats([(220, 5, 4, 80), (181, 1000, 500, 50), (200, 400, 280, 70)]))
        XCTAssertEqual(vc.rows.map(\.cell), [200, 181, 220])
        let requests = transport.count
        var notified = 0
        vc.onSortChanged = { notified += 1 }
        vc.sortControl.selectedSegmentIndex = 1
        vc.sortControl.sendActions(for: .valueChanged)
        XCTAssertEqual(prefs.moveSort, .games)
        XCTAssertEqual(notified, 1)
        vc.reload()
        XCTAssertEqual(vc.rows.map(\.cell), [181, 200, 220])
        vc.sortControl.selectedSegmentIndex = 0
        vc.sortControl.sendActions(for: .valueChanged)
        XCTAssertEqual(prefs.moveSort, .winRate)
        XCTAssertEqual(notified, 2)
        vc.reload()
        XCTAssertEqual(vc.rows.map(\.cell), [200, 181, 220])
        await Task.yield()
        XCTAssertEqual(transport.count, requests, "re-sorting never queries the server")
    }

    func testPopularSortOrdersListAndBoardHeatByGames() async {
        let vc = await load(stats([(220, 50, 45, 90), (181, 400, 100, 25), (200, 100, 60, 60)]))
        XCTAssertEqual(vc.rows.map(\.cell), [220, 200, 181])
        vc.selectSort(.games)
        vc.reload()
        XCTAssertEqual(vc.rows.map(\.cell), [181, 200, 220])
        for r in vc.rows { XCTAssertEqual(r.color, service.currentHeat[NSNumber(value: r.cell)]) }
    }

    func testSortAndShowCountControlsBelongToTheMovesTab() async {
        let vc = await load(stats([(181, 50, 25, 50)]))
        XCTAssertFalse(vc.sortControl.isHidden)
        vc.segmented.selectedSegmentIndex = 1
        vc.segmented.sendActions(for: .valueChanged)
        XCTAssertTrue(vc.sortControl.isHidden)
        XCTAssertTrue(vc.showButton.isHidden)
    }

    func testRowCellShowsLabelPctAndGames() async {
        let vc = await load(stats([(181, 1234, 716, 58.04)]))
        let cell = vc.tableView(vc.tableView, cellForRowAt: IndexPath(row: 0, section: 0))
        let texts = Self.labels(cell).compactMap(\.text)
        XCTAssertTrue(texts.contains("L10"), "\(texts)")
        XCTAssertTrue(texts.contains("58%"), "\(texts)")
        XCTAssertTrue(texts.contains(vc.rows[0].gamesText), "\(texts)")
    }

    func testSegmentsShowGamesTotalFromSearch() async {
        transport.gamesBody = games(total: 1234, count: 2)
        let vc = await load(stats([(181, 50, 25, 50)], total: 99))
        let done = await waitUntil { self.service.pager.total == 1234 }
        XCTAssertTrue(done)
        vc.reloadGames()
        vc.showGamesState(.loaded, isLoadMore: false)
        XCTAssertEqual(vc.segmented.numberOfSegments, 2)
        XCTAssertEqual(vc.segmented.titleForSegment(at: 0), "Moves")
        let title = vc.segmented.titleForSegment(at: 1) ?? ""
        XCTAssertTrue(title.hasPrefix("Games · "), title)
        XCTAssertTrue(title.hasSuffix("234"), title)
        XCTAssertTrue(vc.segmented.isEnabledForSegment(at: 1))
        XCTAssertEqual(vc.segmented.selectedSegmentIndex, 0)
    }

    func testGamesTitleDropsPreviousTotalWhileLoadingOrFailed() async {
        transport.gamesBody = games(total: 1234, count: 2)
        let vc = await load(stats([(181, 50, 25, 50)]))
        _ = await waitUntil { self.service.pager.total == 1234 }
        vc.reloadGames()
        vc.showGamesState(.loaded, isLoadMore: false)
        vc.showGamesState(.loading, isLoadMore: false)
        XCTAssertEqual(vc.segmented.titleForSegment(at: 1), "Games")
        vc.showGamesState(.failed, isLoadMore: false)
        XCTAssertEqual(vc.segmented.titleForSegment(at: 1), "Games")
    }

    func testGamesRowsShowPlayersScoreAndDate() async {
        transport.gamesBody = games(total: 1, count: 1)
        let vc = await loadGames()
        XCTAssertEqual(vc.gamesTableView.numberOfRows(inSection: 0), 1)
        let cell = vc.tableView(vc.gamesTableView, cellForRowAt: IndexPath(row: 0, section: 0))
        let texts = Self.labels(cell).compactMap { $0.attributedText?.string ?? $0.text }
        XCTAssertTrue(texts.contains { $0.hasPrefix("alice0") }, "\(texts)")
        XCTAssertTrue(texts.contains { $0.hasPrefix("bob0") }, "\(texts)")
        XCTAssertTrue(texts.contains("1 \u{2013} 0"), "\(texts)")
        XCTAssertTrue(texts.contains("\u{25A0} 1950"), "\(texts)")
        XCTAssertTrue(texts.contains { $0.contains("2019") }, "other-year date shows the year: \(texts)")
        XCTAssertEqual(vc.gamesHeaderTitles, ["Player 1", "Newest first", "Player 2"])
    }

    func testShowMoreFooterAndLoadMoreFailureKeepsRows() async {
        transport.gamesBody = games(total: 30, count: 25)
        let vc = await loadGames()
        XCTAssertEqual(vc.gamesFooterTitle, "Show more")
        var more = 0
        vc.onLoadMore = { more += 1 }
        vc.footerButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(more, 1)
        vc.showGamesState(.loading, isLoadMore: true)
        XCTAssertEqual(vc.gamesTableView.numberOfRows(inSection: 0), 25)
        vc.showGamesState(.failed, isLoadMore: true)
        XCTAssertEqual(vc.gamesFooterTitle, "Couldn't load more. Retry")
        XCTAssertEqual(vc.gamesTableView.numberOfRows(inSection: 0), 25, "a page-2 failure keeps the rows")
        XCTAssertFalse(vc.gamesTableView.isHidden)
        vc.footerButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(more, 2)
    }

    func testNoFooterWhenAllLoaded() async {
        transport.gamesBody = games(total: 2, count: 2)
        let vc = await loadGames()
        XCTAssertNil(vc.gamesFooterTitle)
    }

    func testGamesFirstPageStates() {
        let vc = DBResultsViewController(service: service)
        vc.loadViewIfNeeded()
        vc.segmented.selectedSegmentIndex = 1
        vc.segmented.sendActions(for: .valueChanged)
        let cases: [(DBLoadState, String)] = [
            (.empty, "No games"),
            (.blocked, "Database unavailable during your rated game"),
            (.failed, "Couldn't load"),
        ]
        for (state, text) in cases {
            vc.showGamesState(state, isLoadMore: false)
            XCTAssertEqual(vc.messageLabel.text, text)
            XCTAssertFalse(vc.messageLabel.isHidden)
            XCTAssertTrue(vc.gamesTableView.isHidden)
            XCTAssertEqual(vc.retryButton.isHidden, state != .failed, "\(state)")
        }
        vc.showGamesState(.loading, isLoadMore: false)
        XCTAssertTrue(vc.spinner.isAnimating)
        XCTAssertTrue(vc.gamesTableView.isHidden)
        XCTAssertTrue(vc.showButton.isHidden, "Show N belongs to the Moves tab")
    }

    func testTabsKeepTheirOwnState() {
        let vc = DBResultsViewController(service: service)
        vc.loadViewIfNeeded()
        vc.showState(.empty)
        vc.showGamesState(.failed, isLoadMore: false)
        XCTAssertEqual(vc.messageLabel.text, "No moves from this position")
        vc.segmented.selectedSegmentIndex = 1
        vc.segmented.sendActions(for: .valueChanged)
        XCTAssertEqual(vc.messageLabel.text, "Couldn't load")
        XCTAssertTrue(vc.tableView.isHidden)
    }

    func testSelectingGameRowOpensLongGid() async {
        transport.gamesBody = games(total: 1, count: 1, firstGid: 50_000_000_000_123)
        let vc = await loadGames()
        var opened: [Int64] = []
        var mine: [Bool] = []
        vc.onOpenGame = { opened.append($0); mine.append($1) }
        vc.tableView(vc.gamesTableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(opened, [50_000_000_000_123])
        XCTAssertEqual(mine, [false])
    }

    func testSelectingMineRowOpensCollectionGame() async {
        transport.gamesBody = "{\"total\":1,\"games\":[{\"gid\":42,\"source\":\"mine\",\"game\":1," +
            "\"winner\":1,\"moveCount\":3}],\"blocked\":false}"
        let vc = await loadGames()
        var opened: [(Int64, Bool)] = []
        vc.onOpenGame = { opened.append(($0, $1)) }
        vc.tableView(vc.gamesTableView, didSelectRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(opened.first?.0, 42)
        XCTAssertEqual(opened.first?.1, true)
    }

    func testListHeaderLabelMatchesWeb() {
        typealias R = DBResultsViewController
        XCTAssertEqual(R.listHeaderLabel(scope: "archive", moveCount: 3), "Games through this position (3 moves)")
        XCTAssertEqual(R.listHeaderLabel(scope: "archive", moveCount: 0), "All matching games")
        XCTAssertEqual(R.listHeaderLabel(scope: "mine", moveCount: 3), "My games (position and filters not applied)")
        XCTAssertEqual(R.listHeaderLabel(scope: "both", moveCount: 3),
                       "Games through this position (3 moves), plus all your games (personal games not position-filtered)")
    }

    func testScopeLabelSitsAboveGamesHeader() async {
        transport.gamesBody = games(total: 1, count: 1)
        let vc = await loadGames()
        XCTAssertFalse(vc.scopeLabel.isHidden)
        XCTAssertEqual(vc.scopeLabel.text, "Games through this position (1 moves)")
        vc.view.frame = CGRect(x: 0, y: 0, width: 400, height: 600)
        vc.view.layoutIfNeeded()
        XCTAssertGreaterThan(vc.scopeLabel.frame.height, 0)
        XCTAssertLessThanOrEqual(vc.scopeLabel.frame.maxY, vc.gamesHeader.frame.minY)
        vc.segmented.selectedSegmentIndex = 0
        vc.segmented.sendActions(for: .valueChanged)
        XCTAssertTrue(vc.scopeLabel.isHidden, "Games tab only")
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
        XCTAssertNil(service.onGamesState)
        XCTAssertNil(service.onGamesChanged)
    }

    private func games(total: Int, count: Int, firstGid: Int64 = 1000) -> String {
        let rows = (0 ..< count).map { i in
            "{\"gid\":\(firstGid + Int64(i)),\"game\":1,\"player1\":{\"name\":\"alice\(i)\",\"rating\":1950}," +
                "\"player2\":{\"name\":\"bob\(i)\",\"rating\":1500},\"winner\":1," +
                "\"playDate\":\"2019-03-04T10:00:00Z\",\"moveCount\":40}"
        }.joined(separator: ",")
        return "{\"total\":\(total),\"games\":[\(rows)],\"blocked\":false}"
    }

    /// Loads a position, then shows the Games tab with the first page.
    private func loadGames() async -> DBResultsViewController {
        let vc = await load(stats([(181, 50, 25, 50)]))
        let done = await waitUntil { self.service.pager.total > 0 }
        XCTAssertTrue(done)
        vc.segmented.selectedSegmentIndex = 1
        vc.segmented.sendActions(for: .valueChanged)
        vc.reloadGames()
        vc.showGamesState(.loaded, isLoadMore: false)
        return vc
    }

    private static func labels(_ v: UIView) -> [UILabel] {
        var out: [UILabel] = []
        if let l = v as? UILabel { out.append(l) }
        for s in v.subviews { out += labels(s) }
        return out
    }
}
