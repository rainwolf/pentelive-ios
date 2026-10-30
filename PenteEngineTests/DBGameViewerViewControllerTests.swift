@testable import penteLive
import XCTest

/// Scripted /games/{gid} replies. Never touches the network.
private final class DBViewerTransport: Transport, @unchecked Sendable {
    private let lock = NSLock()
    private var _reply: (body: String, status: Int) = ("{}", 200)
    private var _paths: [String] = []

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
        lock.unlock()
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
        client = DBClient(endpoint: DBEndpoint(useLocalhost: false, credentials: nil), transport: transport)
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
}
