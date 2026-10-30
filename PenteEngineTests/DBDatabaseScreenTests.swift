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

    func testToggleWhileInFlightPaintsNothing() {
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        // Reply not yet processed: currentHeat is empty, so nothing may paint.
        vc.perform(NSSelectorFromString("toggleHeat"))
        vc.perform(NSSelectorFromString("toggleHeat"))
        XCTAssertNil(dbOptions(vc))
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

    func testResultsRowTapPlaysMoveOnHost() async {
        transport.replies[181] = (stats([(10, 60), (11, 40)]), 200)
        let vc = makeVC(game: "Pente", moves: [180, 181, 200])
        back(vc)
        let shown = await waitUntil { self.results(vc).rows.count == 2 }
        XCTAssertTrue(shown)
        results(vc).onPlayMove?(10)
        XCTAssertEqual(mirror(vc), [180, 181, 10])
        XCTAssertEqual(line(vc).redoCount, 0)
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
}
