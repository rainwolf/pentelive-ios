@testable import penteLive
import XCTest

/// Manual clock for ArenaJoinRequestListModel: scheduled work runs only when the test advances time.
final class FakeArenaClock {
    private(set) var nowMs = 0
    private var pending: [(dueMs: Int, order: Int, work: () -> Void)] = []
    private var nextOrder = 0

    func schedule(_ delay: TimeInterval, _ work: @escaping () -> Void) {
        nextOrder += 1
        pending.append((dueMs: nowMs + Int((delay * 1000).rounded()), order: nextOrder, work: work))
    }

    func advance(ms: Int) {
        let endMs = nowMs + ms
        while let next = pending.filter({ $0.dueMs <= endMs }).min(by: { ($0.dueMs, $0.order) < ($1.dueMs, $1.order) }) {
            pending.removeAll { $0.order == next.order }
            nowMs = next.dueMs
            next.work()
        }
        nowMs = endMs
    }
}

final class ArenaJoinRequestListModelTests: XCTestCase {
    private func req(_ player: String, _ seq: Int) -> ArenaJoinRequest {
        return ArenaJoinRequest(player: player, seq: seq)
    }

    private func makeModel() -> (FakeArenaClock, ArenaJoinRequestListModel) {
        let clock = FakeArenaClock()
        return (clock, ArenaJoinRequestListModel(schedule: clock.schedule))
    }

    /// A model showing [alice] whose first window has ended (idle, visible) at t = 1400 ms.
    private func makeVisibleIdleModel() -> (FakeArenaClock, ArenaJoinRequestListModel) {
        let (clock, model) = makeModel()
        model.receive([req("alice", 1)])
        clock.advance(ms: 400 + 1000) // opens frozen for 400 ms, then the 1000 ms window
        return (clock, model)
    }

    func testFirstSnapshotWhileHiddenOpensFrozenThenInteractive() {
        let (clock, model) = makeModel()
        XCTAssertFalse(model.isVisible)
        model.receive([req("alice", 1)])
        XCTAssertEqual(model.rows, [req("alice", 1)]) // the popover can present at once
        XCTAssertTrue(model.isFrozen) // but no row is tappable yet
        XCTAssertFalse(model.isInteractive)
        XCTAssertFalse(model.beginAction(on: "alice"))
        clock.advance(ms: 399)
        XCTAssertTrue(model.isFrozen)
        clock.advance(ms: 1)
        XCTAssertFalse(model.isFrozen)
        XCTAssertTrue(model.isInteractive)
        XCTAssertTrue(model.beginAction(on: "alice"))
    }

    func testSnapshotsDuringTheOpeningFreezeReplaceTheHeldOne() {
        let (clock, model) = makeModel()
        model.receive([req("alice", 1)])
        clock.advance(ms: 200)
        model.receive([req("alice", 1), req("bob", 2)])
        clock.advance(ms: 200)
        XCTAssertFalse(model.isFrozen)
        XCTAssertEqual(model.rows, [req("alice", 1), req("bob", 2)])
    }

    func testSnapshotWhileVisibleFreezesFor400ms() {
        let (clock, model) = makeVisibleIdleModel()
        model.receive([req("alice", 1), req("bob", 2)])
        XCTAssertTrue(model.isFrozen)
        XCTAssertFalse(model.isInteractive)
        XCTAssertEqual(model.rows, [req("alice", 1)])
        clock.advance(ms: 399)
        XCTAssertTrue(model.isFrozen)
        XCTAssertEqual(model.rows, [req("alice", 1)])
        clock.advance(ms: 1)
        XCTAssertFalse(model.isFrozen)
        XCTAssertEqual(model.rows, [req("alice", 1), req("bob", 2)])
    }

    func testOnlyTheLastSnapshotDuringAFreezeIsApplied() {
        let (clock, model) = makeVisibleIdleModel()
        model.receive([req("alice", 1), req("bob", 2)])
        clock.advance(ms: 200)
        model.receive([req("carol", 3)])
        clock.advance(ms: 200)
        XCTAssertFalse(model.isFrozen)
        XCTAssertEqual(model.rows, [req("carol", 3)])
    }

    func testMinimumInteractiveWindowHoldsSnapshots() {
        let (clock, model) = makeVisibleIdleModel() // t = 1000
        model.receive([req("alice", 1), req("bob", 2)]) // freeze 1000-1400
        clock.advance(ms: 400) // applied at 1400, window to 2400
        clock.advance(ms: 100) // t = 1500
        model.receive([req("alice", 1), req("bob", 2), req("carol", 3)])
        model.receive([req("bob", 2), req("carol", 3)]) // replaces the held one
        XCTAssertFalse(model.isFrozen)
        XCTAssertTrue(model.isInteractive)
        XCTAssertEqual(model.rows, [req("alice", 1), req("bob", 2)])
        clock.advance(ms: 899) // t = 2399
        XCTAssertFalse(model.isFrozen)
        XCTAssertEqual(model.rows, [req("alice", 1), req("bob", 2)])
        clock.advance(ms: 1) // t = 2400: window ends, freeze starts
        XCTAssertTrue(model.isFrozen)
        clock.advance(ms: 400)
        XCTAssertFalse(model.isFrozen)
        XCTAssertEqual(model.rows, [req("bob", 2), req("carol", 3)])
    }

    func testListThatJustAppearedStaysInteractiveForTheWindow() {
        let (clock, model) = makeModel()
        model.receive([req("alice", 1)]) // opens frozen 0-400, window to 1400
        clock.advance(ms: 500)
        model.receive([req("alice", 1), req("bob", 2)])
        XCTAssertFalse(model.isFrozen)
        XCTAssertEqual(model.rows, [req("alice", 1)])
        clock.advance(ms: 900)
        XCTAssertTrue(model.isFrozen)
    }

    func testBurstOfSnapshotsCannotLockOwnerOut() {
        let (clock, model) = makeModel()
        model.receive([req("alice", 1)])
        clock.advance(ms: 400) // opening freeze over, window running
        var transitions = [(atMs: clock.nowMs, frozen: false)]
        model.onChange = { [unowned model] in
            if transitions.last?.frozen != model.isFrozen {
                transitions.append((atMs: clock.nowMs, frozen: model.isFrozen))
            }
        }
        for i in 0 ..< 60 { // a new snapshot every 100 ms for 6 s
            model.receive([req("alice", 1), req("p\(i)", i + 2)])
            clock.advance(ms: 100)
        }
        XCTAssertGreaterThanOrEqual(transitions.filter { $0.frozen }.count, 3)
        for k in 0 ..< transitions.count - 1 {
            let lengthMs = transitions[k + 1].atMs - transitions[k].atMs
            if transitions[k].frozen {
                XCTAssertEqual(lengthMs, 400, "freeze starting at \(transitions[k].atMs) ms")
            } else {
                XCTAssertGreaterThanOrEqual(lengthMs, 1000, "interactive stretch starting at \(transitions[k].atMs) ms")
            }
        }
    }

    func testEmptySnapshotHidesTheListAfterTheFreeze() {
        let (clock, model) = makeVisibleIdleModel()
        model.receive([])
        XCTAssertTrue(model.isVisible)
        XCTAssertTrue(model.isFrozen)
        clock.advance(ms: 400)
        XCTAssertFalse(model.isVisible)
    }

    func testHiddenListOpensFrozenEvenInsideAWindow() {
        let (clock, model) = makeVisibleIdleModel()
        model.receive([])
        clock.advance(ms: 400) // hidden, window running
        clock.advance(ms: 100)
        model.receive([req("carol", 3)])
        XCTAssertEqual(model.rows, [req("carol", 3)])
        XCTAssertTrue(model.isFrozen)
        XCTAssertFalse(model.isInteractive)
        clock.advance(ms: 400)
        XCTAssertFalse(model.isFrozen)
        XCTAssertTrue(model.isInteractive)
    }

    func testNewRequesterCue() {
        let (_, model) = makeModel()
        XCTAssertTrue(model.receive([req("alice", 1)]))
        XCTAssertFalse(model.receive([req("alice", 1)]))
        XCTAssertTrue(model.receive([req("alice", 1), req("bob", 2)]))
        XCTAssertFalse(model.receive([req("bob", 2)]))
        XCTAssertTrue(model.receive([req("alice", 5), req("bob", 2)])) // alice is back
        XCTAssertFalse(model.receive([]))
    }

    func testActionLocksTheWholeListUntilTheAnswerIsApplied() {
        let (clock, model) = makeVisibleIdleModel()
        model.receive([req("alice", 1), req("bob", 2)])
        clock.advance(ms: 400 + 1000) // applied, window over
        XCTAssertTrue(model.beginAction(on: "alice"))
        XCTAssertEqual(model.inFlightPlayer, "alice")
        XCTAssertFalse(model.isInteractive)
        XCTAssertFalse(model.beginAction(on: "bob"))
        model.receive([req("bob", 2)]) // the server's answer (R11)
        XCTAssertEqual(model.inFlightPlayer, "alice")
        clock.advance(ms: 400)
        XCTAssertNil(model.inFlightPlayer)
        XCTAssertTrue(model.isInteractive)
        XCTAssertEqual(model.rows, [req("bob", 2)])
    }

    func testActionInsideTheWindowStaysLockedUntilTheHeldAnswerIsApplied() {
        let (clock, model) = makeModel()
        model.receive([req("alice", 1), req("bob", 2)]) // opens frozen 0-400, window to 1400
        clock.advance(ms: 400)
        XCTAssertTrue(model.beginAction(on: "bob"))
        clock.advance(ms: 300)
        model.receive([req("alice", 1)]) // held by the window
        XCTAssertFalse(model.isInteractive)
        clock.advance(ms: 700) // window ends, freeze starts
        XCTAssertTrue(model.isFrozen)
        clock.advance(ms: 400)
        XCTAssertNil(model.inFlightPlayer)
        XCTAssertEqual(model.rows, [req("alice", 1)])
    }

    func testActionIsRefusedWhileFrozenOrForAPlayerWithoutARow() {
        let (_, model) = makeVisibleIdleModel()
        XCTAssertFalse(model.beginAction(on: "zed"))
        model.receive([req("alice", 1), req("bob", 2)]) // frozen
        XCTAssertFalse(model.beginAction(on: "alice"))
        XCTAssertNil(model.inFlightPlayer)
    }

    func testResetDropsRowsAndPendingTimers() {
        let (clock, model) = makeVisibleIdleModel()
        model.receive([req("alice", 1), req("bob", 2)]) // frozen, freeze timer pending
        model.reset()
        XCTAssertFalse(model.isVisible)
        XCTAssertFalse(model.isFrozen)
        clock.advance(ms: 2000) // stale timers must do nothing
        XCTAssertFalse(model.isVisible)
        model.receive([req("carol", 3)])
        XCTAssertEqual(model.rows, [req("carol", 3)])
        XCTAssertTrue(model.isFrozen) // a fresh list opens frozen again
    }

    func testOnChangeReportsEveryVisibleChange() {
        let (clock, model) = makeModel()
        var calls = 0
        model.onChange = { calls += 1 }
        model.receive([req("alice", 1)]) // rows set, opens frozen
        clock.advance(ms: 400) // freeze ends, applied
        clock.advance(ms: 1000) // window ends with nothing held: no change
        model.receive([req("bob", 2)]) // freeze starts
        clock.advance(ms: 400) // freeze ends
        XCTAssertTrue(model.beginAction(on: "bob"))
        model.reset()
        XCTAssertEqual(calls, 6)
    }

    // MARK: presenting freeze (controller ruling: present = freeze start)

    func testPresentingAfterTheOpeningFreezeFreezesAgain() {
        let (clock, model) = makeModel()
        model.receive([req("alice", 1)])
        clock.advance(ms: 400 + 300) // presenting was delayed past the opening freeze
        XCTAssertTrue(model.isInteractive)
        model.freezeForPresenting()
        XCTAssertTrue(model.isFrozen)
        XCTAssertFalse(model.beginAction(on: "alice"))
        XCTAssertEqual(model.rows, [req("alice", 1)])
        clock.advance(ms: 399)
        XCTAssertTrue(model.isFrozen)
        clock.advance(ms: 1)
        XCTAssertFalse(model.isFrozen)
        XCTAssertTrue(model.beginAction(on: "alice"))
    }

    func testPresentingFreezeAppliesTheSnapshotHeldByTheWindow() {
        let (clock, model) = makeModel()
        model.receive([req("alice", 1)])
        clock.advance(ms: 400 + 300) // inside the window
        model.receive([req("alice", 1), req("bob", 2)]) // held until the window ends
        model.freezeForPresenting()
        clock.advance(ms: 400)
        XCTAssertFalse(model.isFrozen)
        XCTAssertEqual(model.rows, [req("alice", 1), req("bob", 2)])
    }

    func testPresentingDuringTheOpeningFreezeDoesNotExtendIt() {
        let (clock, model) = makeModel()
        model.receive([req("alice", 1)])
        clock.advance(ms: 200)
        var calls = 0
        model.onChange = { calls += 1 }
        model.freezeForPresenting()
        XCTAssertEqual(calls, 0)
        clock.advance(ms: 200)
        XCTAssertFalse(model.isFrozen)
    }

    func testPresentingKeepsAnInFlightActionUntilTheAnswer() {
        let (clock, model) = makeVisibleIdleModel()
        XCTAssertTrue(model.beginAction(on: "alice"))
        model.freezeForPresenting()
        clock.advance(ms: 400)
        XCTAssertEqual(model.inFlightPlayer, "alice")
        XCTAssertFalse(model.isInteractive)
    }

    func testPresentingAnEmptyListDoesNothing() {
        let (_, model) = makeModel()
        model.freezeForPresenting()
        XCTAssertFalse(model.isFrozen)
        XCTAssertFalse(model.isVisible)
    }

    // MARK: popover step (Review Focus 3)

    private func step(rows: Bool, up: Bool, onScreen: Bool = true, other: Bool = false) -> ArenaPopoverStep {
        return ArenaJoinRequestListModel.popoverStep(hasRows: rows, isPresented: up, isOnScreen: onScreen, isAnotherPresentationUp: other)
    }

    func testPopoverIsShownExactlyWhileThereAreRows() {
        XCTAssertEqual(step(rows: true, up: false), .present)
        XCTAssertEqual(step(rows: true, up: true, other: true), .nothing) // already up: never present twice
        XCTAssertEqual(step(rows: false, up: true, other: true), .dismiss)
        XCTAssertEqual(step(rows: false, up: false), .nothing)
        XCTAssertEqual(step(rows: false, up: false, other: true), .nothing) // empty list never retries
    }

    func testPopoverWaitsUntilPresentingIsPossible() {
        XCTAssertEqual(step(rows: true, up: false, onScreen: false), .nothing) // viewDidAppear calls again
        XCTAssertEqual(step(rows: true, up: false, onScreen: false, other: true), .nothing)
        XCTAssertEqual(step(rows: true, up: false, other: true), .retryLater) // another sheet, or our dismissal animating
    }
}

/// The owner's popover content: the list, the freeze overlay over exactly the list, the Exit Table band below.
final class ArenaPopoverLayoutTests: XCTestCase {
    private func layOut(width: CGFloat = 320, height: CGFloat = 214) -> (container: UIView, list: UIView, overlay: UIView, footer: UIView) {
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        let list = UIView(), overlay = UIView(), footer = UIView()
        ArenaJoinRequestList.layOutPopoverContent(list: list, overlay: overlay, footer: footer, footerHeight: 44, in: container)
        container.layoutIfNeeded()
        return (container, list, overlay, footer)
    }

    private func resize(_ container: UIView, width: CGFloat, height: CGFloat) {
        container.frame = CGRect(x: 0, y: 0, width: width, height: height)
        container.layoutIfNeeded()
    }

    func testOverlayCoversExactlyTheListAboveTheFooter() {
        let v = layOut()
        XCTAssertEqual(v.list.frame, CGRect(x: 0, y: 0, width: 320, height: 170))
        XCTAssertEqual(v.overlay.frame, v.list.frame)
        XCTAssertEqual(v.footer.frame, CGRect(x: 0, y: 170, width: 320, height: 44))
        XCTAssertEqual(v.container.subviews, [v.list, v.overlay, v.footer]) // the footer stays above the overlay
    }

    func testLayoutFollowsAContainerResize() {
        let v = layOut()
        resize(v.container, width: 420, height: 300)
        XCTAssertEqual(v.list.frame, CGRect(x: 0, y: 0, width: 420, height: 256))
        XCTAssertEqual(v.overlay.frame, v.list.frame)
        XCTAssertEqual(v.footer.frame, CGRect(x: 0, y: 256, width: 420, height: 44))
    }

    /// The popover's presentation passes the content view through a size shorter than the footer.
    /// With autoresizing masks the list and overlay clamped at zero height there and then regrew to
    /// the whole 214 pt, so the dim covered the Exit Table band (Task 6, Step 7 finding).
    func testLayoutSurvivesTheContainerShrinkingBelowTheFooterAndRegrowing() {
        let v = layOut()
        resize(v.container, width: 0, height: 0)
        resize(v.container, width: 320, height: 214)
        XCTAssertEqual(v.list.frame, CGRect(x: 0, y: 0, width: 320, height: 170))
        XCTAssertEqual(v.overlay.frame, v.list.frame)
        XCTAssertEqual(v.footer.frame, CGRect(x: 0, y: 170, width: 320, height: 44))
    }
}
