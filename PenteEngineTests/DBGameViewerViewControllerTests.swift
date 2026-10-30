@testable import penteLive
import XCTest

/// Scripted /games/{gid} replies. Never touches the network.
private final class DBViewerTransport: Transport, @unchecked Sendable {
    private let lock = NSLock()
    private var _reply: (body: String, status: Int) = ("{}", 200)
    private var _paths: [String] = []
    private var _delay: UInt64 = 0
    var delay: UInt64 {
        get { lock.lock(); defer { lock.unlock() }; return _delay }
        set { lock.lock(); defer { lock.unlock() }; _delay = newValue }
    }

    var reply: (body: String, status: Int) {
        get { lock.lock(); defer { lock.unlock() }; return _reply }
        set { lock.lock(); defer { lock.unlock() }; _reply = newValue }
    }

    var paths: [String] {
        lock.lock(); defer { lock.unlock() }
        return _paths
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        lock.lock()
        _paths.append(request.url?.path ?? "")
        let r = _reply
        let d = _delay
        lock.unlock()
        if d > 0 { try? await Task.sleep(nanoseconds: d) }
        let resp = HTTPURLResponse(url: request.url!, statusCode: r.status, httpVersion: nil, headerFields: nil)!
        return (Data(r.body.utf8), resp)
    }
}

/// The viewer is driven directly, never put in a window.
@MainActor
final class DBGameViewerViewControllerTests: XCTestCase {
    private static let longGid: Int64 = 50_000_000_000_123
    private var transport: DBViewerTransport!
    private var client: DBClient!

    override func setUp() {
        super.setUp()
        transport = DBViewerTransport()
        client = DBClient(endpoint: DBEndpoint(useLocalhost: false), transport: transport)
    }

    private func detail(gid: Int64 = longGid, game: Int = 1, moves: [Int]) -> String {
        "{\"header\":{\"gid\":\(gid),\"game\":\(game),\"player1\":{\"name\":\"alice\",\"rating\":1950}," +
            "\"player2\":{\"name\":\"bob\",\"rating\":1500},\"winner\":1,\"moveCount\":\(moves.count)}," +
            "\"moves\":\(moves),\"blocked\":false}"
    }

    private func waitUntil(timeout: Double = 2, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return true
    }

    private func open(_ reply: (String, Int)) async -> DBGameViewerViewController {
        transport.reply = reply
        let vc = DBGameViewerViewController(gid: Self.longGid, client: client)
        vc.loadViewIfNeeded()
        let settled = await waitUntil { vc.state != .loading }
        XCTAssertTrue(settled)
        return vc
    }

    func testLoadsLongGidAndStartsAtEnd() async {
        let vc = await open((detail(moves: [180, 181, 200]), 200))
        XCTAssertEqual(vc.state, .loaded)
        XCTAssertEqual(transport.paths, ["/api/db/games/50000000000123"])
        XCTAssertEqual(vc.cursor?.index, 3)
        XCTAssertNotEqual(vc.stone(at: 180), 0)
        XCTAssertNotEqual(vc.stone(at: 200), 0)
        XCTAssertEqual(vc.boardView.backgroundColor, DBPalette.boardColor(forGame: 1))
    }

    func testSwipesStepBackAndForward() async {
        let vc = await open((detail(moves: [180, 181, 200]), 200))
        vc.stepBack()
        XCTAssertEqual(vc.cursor?.index, 2)
        XCTAssertEqual(vc.stone(at: 200), 0)
        vc.stepForward()
        XCTAssertEqual(vc.cursor?.index, 3)
        XCTAssertNotEqual(vc.stone(at: 200), 0)
        let left = vc.view.gestureRecognizers?.compactMap { $0 as? UISwipeGestureRecognizer }
            .map(\.direction) ?? []
        XCTAssertTrue(left.contains(.left))
        XCTAssertTrue(left.contains(.right))
    }

    func testBlockedShowsMessage() async {
        let vc = await open(("{\"blocked\":true}", 200))
        XCTAssertEqual(vc.state, .blocked)
        XCTAssertEqual(vc.messageLabel.text, "Database unavailable during your rated game")
        XCTAssertTrue(vc.retryButton.isHidden)
    }

    func testNotFoundShowsRetryThatReloads() async {
        let vc = await open(("{\"error\":{\"code\":\"not_found\"}}", 404))
        XCTAssertEqual(vc.state, .failed)
        XCTAssertEqual(vc.messageLabel.text, "Couldn't load this game")
        XCTAssertFalse(vc.retryButton.isHidden)
        transport.reply = (detail(moves: [180]), 200)
        vc.retryButton.sendActions(for: .touchUpInside)
        let loaded = await waitUntil { vc.state == .loaded }
        XCTAssertTrue(loaded)
        XCTAssertTrue(vc.messageLabel.isHidden)
    }

    func testMismatchedHeaderIsAFailure() async {
        let vc = await open((detail(gid: 7, moves: [180]), 200))
        XCTAssertEqual(vc.state, .failed)
    }

    func testUnauthorizedHandsOffToHost() async {
        var calls: [UIViewController] = []
        transport.reply = ("{}", 401)
        let vc = DBGameViewerViewController(gid: Self.longGid, client: client)
        vc.onUnauthorized = { calls.append($0) }
        vc.loadViewIfNeeded()
        let done = await waitUntil { vc.state == .unauthorized }
        XCTAssertTrue(done)
        XCTAssertEqual(calls.count, 1)
        XCTAssertTrue(calls.first === vc)
    }

    func testSubscriptionRequiredHandsOffToHost() async {
        var calls = 0
        transport.reply = ("{\"error\":{\"code\":\"subscription_required\"}}", 403)
        let vc = DBGameViewerViewController(gid: Self.longGid, client: client)
        vc.onSubscriptionRequired = { _ in calls += 1 }
        vc.loadViewIfNeeded()
        let done = await waitUntil { vc.state == .subscriptionRequired }
        XCTAssertTrue(done)
        XCTAssertEqual(calls, 1)
    }

    // MARK: Task 23

    func testBackChipReplacesDefaultBackButton() async {
        let vc = await open((detail(moves: [180, 181, 200]), 200))
        XCTAssertTrue(vc.navigationItem.hidesBackButton)
        XCTAssertNotNil(vc.navigationItem.leftBarButtonItem)
        XCTAssertEqual(vc.navigationItem.leftBarButtonItem?.title, "\u{2190} Position search")
    }

    func testHeaderShowsNamesScoreAndColumns() async {
        let vc = await open((detail(moves: [180, 181, 200]), 200))
        XCTAssertEqual(vc.headerLabels.p1Name.attributedText?.string.contains("alice"), true)
        XCTAssertEqual(vc.headerLabels.p2Name.attributedText?.string.contains("bob"), true)
        XCTAssertFalse(vc.headerLabels.score.text?.isEmpty ?? true)
        XCTAssertFalse(vc.headerView.isHidden)
    }

    func testGridHasOneCellPerMoveAndStatesFollowCursor() async {
        let vc = await open((detail(moves: [180, 181, 200]), 200))
        XCTAssertEqual(vc.moveGrid.numberOfItems(inSection: 0), 3)
        XCTAssertEqual(vc.gridCells.map(\.state), [.past, .past, .current])
        vc.stepBack()
        XCTAssertEqual(vc.gridCells.map(\.state), [.past, .current, .future])
    }

    func testGridCellColoursCurrentAndFuture() async {
        let vc = await open((detail(moves: [180, 181, 200]), 200))
        vc.stepBack()
        vc.moveGrid.layoutIfNeeded()
        let cur = vc.moveGrid.dataSource?.collectionView(vc.moveGrid, cellForItemAt: IndexPath(item: 1, section: 0)) as? DBMoveGridCell
        let fut = vc.moveGrid.dataSource?.collectionView(vc.moveGrid, cellForItemAt: IndexPath(item: 2, section: 0)) as? DBMoveGridCell
        XCTAssertEqual(cur?.label.textColor, UIColor(dbHex: DBMoveCell.currentHex))
        XCTAssertEqual(fut?.label.textColor, UIColor(dbHex: DBMoveCell.futureHex))
    }

    func testTappingGridCellJumpsCursor() async {
        let vc = await open((detail(moves: [180, 181, 200]), 200))
        vc.moveGrid.delegate?.collectionView?(vc.moveGrid, didSelectItemAt: IndexPath(item: 0, section: 0))
        XCTAssertEqual(vc.cursor?.index, 1)
        XCTAssertEqual(vc.stone(at: 181), 0)
        XCTAssertNotEqual(vc.stone(at: 180), 0)
        vc.moveGrid.delegate?.collectionView?(vc.moveGrid, didSelectItemAt: IndexPath(item: 2, section: 0))
        XCTAssertEqual(vc.cursor?.index, 3)
    }

    func testPoppedViewerIgnoresLateAuthFailure() async {
        var calls = 0
        transport.reply = ("{}", 401)
        transport.delay = 200_000_000
        let vc = DBGameViewerViewController(gid: Self.longGid, client: client)
        vc.onUnauthorized = { _ in calls += 1 }
        vc.loadViewIfNeeded()
        vc.cancelLoadForPop()
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(calls, 0)
    }

    func testViewerNotRetainedByInFlightRequest() async {
        transport.reply = (detail(moves: [180]), 200)
        transport.delay = 300_000_000
        weak var weakVC: DBGameViewerViewController?
        autoreleasepool {
            let vc = DBGameViewerViewController(gid: Self.longGid, client: client)
            vc.loadViewIfNeeded()
            weakVC = vc
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertNil(weakVC)
    }

    // MARK: personal games (F3)

    func testMineRowLoadsFromCollection() async {
        transport.reply = (detail(gid: 42, moves: [180, 181]), 200)
        let vc = DBGameViewerViewController(gid: 42, client: client, isMine: true)
        vc.loadViewIfNeeded()
        let done = await waitUntil { vc.state != .loading }
        XCTAssertTrue(done)
        XCTAssertEqual(vc.state, .loaded)
        XCTAssertEqual(transport.paths, ["/api/db/collection/42"])
        XCTAssertNotEqual(vc.stone(at: 181), 0)
    }

    func testMineRowWithMismatchedHeaderIsAFailure() async {
        transport.reply = (detail(gid: 43, moves: [180]), 200)
        let vc = DBGameViewerViewController(gid: 42, client: client, isMine: true)
        vc.loadViewIfNeeded()
        let done = await waitUntil { vc.state != .loading }
        XCTAssertTrue(done)
        XCTAssertEqual(vc.state, .failed)
    }

    // MARK: interactive pop (M5)

    func testCancelledInteractivePopKeepsLoading() async {
        transport.reply = (detail(moves: [180]), 200)
        transport.delay = 200_000_000
        let vc = DBGameViewerViewController(gid: Self.longGid, client: client)
        vc.loadViewIfNeeded()
        vc.movingFromParentOverride = true
        vc.viewWillDisappear(true) // the edge swipe starts a pop
        vc.movingFromParentOverride = false
        vc.viewWillAppear(true) // ... and is cancelled
        vc.viewDidAppear(true)
        let loaded = await waitUntil { vc.state == .loaded }
        XCTAssertTrue(loaded, "state \(vc.state)")
    }

    func testCompletedPopCancelsLoad() async {
        var calls = 0
        transport.reply = ("{}", 401)
        transport.delay = 200_000_000
        let vc = DBGameViewerViewController(gid: Self.longGid, client: client)
        vc.onUnauthorized = { _ in calls += 1 }
        vc.loadViewIfNeeded()
        vc.movingFromParentOverride = true
        vc.viewWillDisappear(true)
        vc.viewDidDisappear(true)
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(calls, 0)
        XCTAssertEqual(vc.state, .loading)
    }
}
