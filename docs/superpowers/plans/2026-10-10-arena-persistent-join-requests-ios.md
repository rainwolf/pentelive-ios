# Arena Persistent Join Requests (iOS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the iOS arena client render server-held join-request state: an owner list driven only by `dsgArenaJoinRequestsEvent` snapshots (with freeze and minimum interactive window), a requester lobby driven by `dsgArenaMyRequestsEvent`, withdraw support, and notices for `dsgArenaRequestEndedEvent`. All client countdowns go away.

**Architecture:** Three plain Swift types carry all logic and are unit-tested in the hosted `PenteEngineTests` target:
- `ArenaWire.swift` decodes the three new server events into an `ArenaInbound` enum, builds the four client events (`ArenaOutbound`), and holds the notice texts.
- `ArenaJoinRequestListModel` is the owner list's state machine (freeze, window, in-flight). Its clock is an injected `schedule` closure.
- `ArenaMyRequestsModel` is the requester lobby's state (marks, taps waiting for an answer).

UIKit code (`ArenaJoinRequestList`, `TableViewController`, `RoomViewController`) only forwards events into these types and renders them. `PenteLiveSocket.processEvent` runs on the socket's background serial queue, so `RoomViewController.arenaEvent(_:)` hops to main before it touches any model or view.

**Tech Stack:** Swift 5 / UIKit, XCTest (hosted target `PenteEngineTests`, `@testable import penteLive`), CocoaPods workspace `penteLive.xcworkspace`, scheme `test1`, `xcodeproj` Ruby gem via `Scripts/add_swift_file.rb`.

**Spec:** `/Users/waliedothman/mariposa/coding/pente.org-project/pente.org/docs/superpowers/specs/2026-10-10-arena-persistent-join-requests-design.md`. Read it first. The "Wire protocol" section is the contract with the server, React and Android. This plan covers only the iOS part: C1, C2, C3, C4 and C5-iOS, plus the iOS share of Testing.

**Repo:** `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS` (abbreviated `$IOS` below; always expand it to the absolute path in commands). Work on the already-checked-out branch `arena-persistent-join-requests`. Line numbers are from `main` @ `624948f`. Earlier tasks shift lines in shared files, so always match edits by the quoted code, not by the number alone.

## Global Constraints

- Wire keys are lowercase and verbatim:
  - C→S: `dsgArenaRequestJoinTableEvent {table}`, `dsgArenaAcceptTableJoinEvent {table, playerToAccept}`, `dsgArenaRejectTableJoinEvent {table, playerToReject}`, `dsgArenaWithdrawJoinRequestEvent {table}`.
  - S→C: `dsgArenaJoinRequestsEvent {table, requests: [{player, seq}]}`, `dsgArenaMyRequestsEvent {tables: [int]}`, `dsgArenaRequestEndedEvent {table, player, owner, reason}`.
- `reason` values verbatim: `DECLINED`, `TABLE_FULL`, `TABLE_CLOSED`, `DUPLICATE`, `BLOCKED`, `NOT_AVAILABLE`, `GUEST_RATED`, `NO_LONGER_AVAILABLE`.
- No client sends the capital key `DSGArenaRejectTableJoinEvent` any more.
- S→C `dsgArenaRequestJoinTableEvent` and `dsgArenaRejectTableJoinEvent` are no longer sent. iOS stops handling them.
- Freeze is 400 ms (milliseconds). Minimum interactive window is 1000 ms. Only the newest held snapshot is applied.
- No client expiry timers (C1). The only timers left are the freeze/window timers and a UI re-present retry.
- Notice texts are verbatim from spec C4, with `<n>` the table number:
  - "<owner> declined your request"
  - "Table <n> is no longer available"
  - "Table <n> was closed"
  - "You already requested table <n>"
  - "You can't request table <n> again until its next game"
  - "You can't join table <n> right now"
  - "Guests can't join rated tables"
  - "<player> is no longer available"
- Withdraw confirm text, verbatim: "Withdraw your request to table <n>? You won't be able to request it again until its next game."
- Socket callbacks run on the background queue `penteLiveDelegateQueue`. All model and UI work runs on main.
- All UI must work on iPhone and iPad, including rotation (`$IOS/CLAUDE.md`).
- Old app builds are not supported (spec Non-goals).
- Build only through the workspace: `-workspace $IOS/penteLive.xcworkspace -scheme test1`, never the `.xcodeproj`.
- Canonical unit test command (verified on 2026-10-10: `MessageAuthorLabelTests` ran 5 tests, `** TEST SUCCEEDED **`):
  `xcodebuild test -workspace $IOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests/<TestClass> 2>&1 | grep -E 'error:|Executed|TEST (SUCCEEDED|FAILED)'`
- Add new files to targets with `Scripts/add_swift_file.rb <path> <target> <group-dir>`, run from `$IOS` (verified on a scratch copy of the project):
  `cd $IOS && ruby Scripts/add_swift_file.rb test1/X.swift penteLive test1` (app),
  `cd $IOS && ruby Scripts/add_swift_file.rb PenteEngineTests/XTests.swift PenteEngineTests PenteEngineTests` (tests).
  The script prints `added X.swift to <target> via group … (new)`. It also prints harmless "Ignoring … extensions are not built" gem warnings.
- Formatting: run `swiftformat` (it reads `$IOS/.swiftformat`, `--indent 4`) only on files this plan creates or fully rewrites. Never run it on `RoomViewController.swift`, `TableViewController.swift` or `PenteLiveSocket.swift`. Hand-match their style instead.
- Commits: `git -C $IOS add <files>` then `git -C $IOS commit -S -m "<message>"`. No co-author, "generated by" or similar trailer lines. Never commit the `development` flag flip used in E2E.
- Scratch output (derived data, logs) goes under `/private/tmp/claude-501/arena-ios/`, never inside the repo.

## Review Focus

1. **Malformed or partial server payloads.** Examples: a missing `requests` or `tables`, a `null` player, a string `seq` or `table`, an unknown `reason`. Bad entries must be skipped or the event ignored, never a crash (the old code used `as!` everywhere). Pinned in Task 1 by `testJoinRequestsSkipsMalformedEntries`, `testMissingRequestsIsEmptySnapshot`, `testJoinRequestsWithoutIntegerTableIsIgnored`, `testMyRequestsSkipsNonIntegers` and `testRequestEndedWithUnknownReasonOrNoTableIsIgnored`.
2. **A snapshot with a repeated player or out-of-order `seq`.** It must render one row per player, in `seq` order, so rows never jump. Pinned in Task 1 by `testJoinRequestsSnapshotIsSortedBySeq` and `testJoinRequestsKeepsOneRowPerPlayer`.
3. **An owner snapshot that arrives while the popover cannot be presented.** Examples: the table screen is still animating in, or the popover's own dismissal is still animating. The rows must appear as soon as presenting is possible. They must not wait for the next snapshot. Pinned in Task 2 by `testPopoverIsShownExactlyWhileThereAreRows` and `testPopoverWaitsUntilPresentingIsPossible` (the decision), and in Task 4 Step 7 and Task 6 E14 (the retry wiring).
4. **A withdraw confirmed after the table already left the requested set.** Example: the table filled or closed while the alert was open. The withdraw must still send, the app must not crash, and the server's answer clears the state. Pinned in Task 3 by `testWithdrawConfirmedAfterTableLeftTheSetStillSends`.
5. **iPad layout and rotation of the request popover, the freeze overlay and the withdraw alert.** The popover view is sized to its content before subviews are added, its width is capped, the overlay tracks the list, and the anchor is recomputed on rotation (`willRepositionPopoverTo`). The alert style needs no anchor. Pinned in Task 6 Step 7 (iPad pass) on the iPad Pro 13-inch (M5) simulator.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `test1/ArenaWire.swift` | Create | `ArenaJoinRequest`, `ArenaRequestEnded` (+ `noticeText`), `ArenaInbound` (decode), `ArenaOutbound` (encode), `ArenaText.withdrawConfirm` |
| `test1/ArenaJoinRequestListModel.swift` | Create | Owner list state: rows, freeze, minimum window, in-flight action, new-request cue. No UIKit. |
| `test1/ArenaMyRequestsModel.swift` | Create | Requester lobby state: requested marks, taps awaiting an answer |
| `test1/ArenaJoinRequestList.swift` | Rewrite (1-148) | UITableView rendering `model.rows`, freeze overlay, row spinner, accept/decline through the model |
| `test1/TableViewController.swift` | Modify (83, 390-392, 395-436, 594-597, 1280-1281, 1390-1398) | Popover shown iff the list has rows, single presentation, retry, snapshot entry point |
| `test1/RoomViewController.swift` | Modify (57-60, 260-273, 277-339, 422-424, 519-530) | `arenaEvent(_:)` main-hop router, banner notices, lobby marks, request/withdraw taps; countdown removed |
| `test1/PenteLiveSocket.swift` | Modify (231-233) | Route the three new keys through `ArenaInbound` |
| `PenteEngineTests/ArenaWireTests.swift` | Create | Decode/encode/notice tests |
| `PenteEngineTests/ArenaJoinRequestListModelTests.swift` | Create | Freeze/window/in-flight tests with `FakeArenaClock` |
| `PenteEngineTests/ArenaMyRequestsModelTests.swift` | Create | Lobby state tests |
| `penteLive.xcodeproj/project.pbxproj` | Modify (via script) | Target membership for the six new files |

---

### Task 1: Arena wire types (decode, encode, notice texts)

**Files:**
- Create: `$IOS/test1/ArenaWire.swift`
- Create: `$IOS/PenteEngineTests/ArenaWireTests.swift`
- Modify: `$IOS/penteLive.xcodeproj/project.pbxproj` (script only)

**Interfaces:**
- Consumes: nothing.
- Produces (used by Tasks 2-5):
  - `struct ArenaJoinRequest: Equatable { let player: String; let seq: Int }`
  - `struct ArenaRequestEnded: Equatable { enum Reason: String, CaseIterable { case declined = "DECLINED", tableFull = "TABLE_FULL", tableClosed = "TABLE_CLOSED", duplicate = "DUPLICATE", blocked = "BLOCKED", notAvailable = "NOT_AVAILABLE", guestRated = "GUEST_RATED", noLongerAvailable = "NO_LONGER_AVAILABLE" }; let table: Int; let player: String; let owner: String; let reason: Reason; var noticeText: String }`
  - `enum ArenaInbound: Equatable { case joinRequests(table: Int, requests: [ArenaJoinRequest]); case myRequests(tables: [Int]); case requestEnded(ArenaRequestEnded); init?(event: [String: Any]) }`. The `requests` come back sorted by `seq` ascending, with one entry per player.
  - `enum ArenaOutbound { static func requestJoin(table: Int) -> [String: Any]; static func withdraw(table: Int) -> [String: Any]; static func accept(table: Int, player: String) -> [String: Any]; static func reject(table: Int, player: String) -> [String: Any] }`
  - `enum ArenaText { static func withdrawConfirm(table: Int) -> String }`

- [ ] **Step 1: Write the failing tests**

Create `$IOS/PenteEngineTests/ArenaWireTests.swift`:

```swift
import XCTest
@testable import penteLive

final class ArenaWireTests: XCTestCase {
    /// Decodes a frame the way PenteLiveSocket.convertJSONStringToDictionary does.
    private func frame(_ json: String) -> [String: Any] {
        let object = try! JSONSerialization.jsonObject(with: Data(json.utf8), options: [])
        return object as! [String: Any]
    }

    private func ended(_ reason: ArenaRequestEnded.Reason, table: Int = 7) -> ArenaRequestEnded {
        return ArenaRequestEnded(table: table, player: "bob", owner: "alice", reason: reason)
    }

    // MARK: dsgArenaJoinRequestsEvent

    func testJoinRequestsSnapshotIsSortedBySeq() {
        let event = frame(#"{"dsgArenaJoinRequestsEvent":{"table":4,"requests":[{"player":"carol","seq":9},{"player":"bob","seq":3}]}}"#)
        XCTAssertEqual(ArenaInbound(event: event),
                       .joinRequests(table: 4, requests: [ArenaJoinRequest(player: "bob", seq: 3),
                                                          ArenaJoinRequest(player: "carol", seq: 9)]))
    }

    func testJoinRequestsKeepsOneRowPerPlayer() {
        let event = frame(#"{"dsgArenaJoinRequestsEvent":{"table":4,"requests":[{"player":"bob","seq":5},{"player":"amy","seq":4},{"player":"bob","seq":2}]}}"#)
        XCTAssertEqual(ArenaInbound(event: event),
                       .joinRequests(table: 4, requests: [ArenaJoinRequest(player: "bob", seq: 2),
                                                          ArenaJoinRequest(player: "amy", seq: 4)]))
    }

    func testJoinRequestsSkipsMalformedEntries() {
        let event = frame(#"{"dsgArenaJoinRequestsEvent":{"table":4,"requests":[{"player":"bob"},{"seq":4},{"player":null,"seq":5},{"player":"dan","seq":"6"},3,{"player":"eve","seq":8}]}}"#)
        XCTAssertEqual(ArenaInbound(event: event),
                       .joinRequests(table: 4, requests: [ArenaJoinRequest(player: "eve", seq: 8)]))
    }

    func testMissingRequestsIsEmptySnapshot() {
        XCTAssertEqual(ArenaInbound(event: frame(#"{"dsgArenaJoinRequestsEvent":{"table":4,"requests":[]}}"#)),
                       .joinRequests(table: 4, requests: []))
        XCTAssertEqual(ArenaInbound(event: frame(#"{"dsgArenaJoinRequestsEvent":{"table":4}}"#)),
                       .joinRequests(table: 4, requests: []))
    }

    func testJoinRequestsWithoutIntegerTableIsIgnored() {
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgArenaJoinRequestsEvent":{"requests":[]}}"#)))
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgArenaJoinRequestsEvent":{"table":"4","requests":[]}}"#)))
    }

    // MARK: dsgArenaMyRequestsEvent

    func testMyRequests() {
        XCTAssertEqual(ArenaInbound(event: frame(#"{"dsgArenaMyRequestsEvent":{"tables":[2,5]}}"#)),
                       .myRequests(tables: [2, 5]))
        XCTAssertEqual(ArenaInbound(event: frame(#"{"dsgArenaMyRequestsEvent":{}}"#)),
                       .myRequests(tables: []))
    }

    func testMyRequestsSkipsNonIntegers() {
        XCTAssertEqual(ArenaInbound(event: frame(#"{"dsgArenaMyRequestsEvent":{"tables":[2,"x",null,5]}}"#)),
                       .myRequests(tables: [2, 5]))
    }

    // MARK: dsgArenaRequestEndedEvent

    func testRequestEndedDecodesEveryReason() {
        for reason in ArenaRequestEnded.Reason.allCases {
            let event = frame("{\"dsgArenaRequestEndedEvent\":{\"table\":7,\"player\":\"bob\",\"owner\":\"alice\",\"reason\":\"\(reason.rawValue)\"}}")
            XCTAssertEqual(ArenaInbound(event: event), .requestEnded(ended(reason)), reason.rawValue)
        }
    }

    func testRequestEndedWithUnknownReasonOrNoTableIsIgnored() {
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgArenaRequestEndedEvent":{"table":7,"player":"bob","owner":"alice","reason":"EXPIRED"}}"#)))
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgArenaRequestEndedEvent":{"player":"bob","owner":"alice","reason":"DECLINED"}}"#)))
    }

    func testRequestEndedToleratesMissingNames() {
        XCTAssertEqual(ArenaInbound(event: frame(#"{"dsgArenaRequestEndedEvent":{"table":7,"reason":"TABLE_CLOSED"}}"#)),
                       .requestEnded(ArenaRequestEnded(table: 7, player: "", owner: "", reason: .tableClosed)))
    }

    // MARK: not arena events

    func testOtherEventsAreNotArenaEvents() {
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgJoinTableEvent":{"table":4,"player":"bob"}}"#)))
        // No longer sent by the server, so no longer handled.
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgArenaRequestJoinTableEvent":{"table":4,"player":"bob"}}"#)))
        XCTAssertNil(ArenaInbound(event: frame(#"{"dsgArenaRejectTableJoinEvent":{"table":4,"playerToReject":"bob"}}"#)))
    }

    // MARK: notices (spec C4)

    func testNoticeTexts() {
        XCTAssertEqual(ended(.declined).noticeText, "alice declined your request")
        XCTAssertEqual(ended(.tableFull).noticeText, "Table 7 is no longer available")
        XCTAssertEqual(ended(.tableClosed).noticeText, "Table 7 was closed")
        XCTAssertEqual(ended(.duplicate).noticeText, "You already requested table 7")
        XCTAssertEqual(ended(.blocked).noticeText, "You can't request table 7 again until its next game")
        XCTAssertEqual(ended(.notAvailable).noticeText, "You can't join table 7 right now")
        XCTAssertEqual(ended(.guestRated).noticeText, "Guests can't join rated tables")
        XCTAssertEqual(ended(.noLongerAvailable).noticeText, "bob is no longer available")
    }

    func testWithdrawConfirmText() {
        XCTAssertEqual(ArenaText.withdrawConfirm(table: 12),
                       "Withdraw your request to table 12? You won't be able to request it again until its next game.")
    }

    // MARK: outbound (spec Wire protocol, C→S)

    func testOutboundEvents() {
        XCTAssertEqual(ArenaOutbound.requestJoin(table: 3) as NSDictionary,
                       ["dsgArenaRequestJoinTableEvent": ["table": 3, "time": 0]] as NSDictionary)
        XCTAssertEqual(ArenaOutbound.withdraw(table: 3) as NSDictionary,
                       ["dsgArenaWithdrawJoinRequestEvent": ["table": 3, "time": 0]] as NSDictionary)
        XCTAssertEqual(ArenaOutbound.accept(table: 3, player: "bob") as NSDictionary,
                       ["dsgArenaAcceptTableJoinEvent": ["table": 3, "playerToAccept": "bob", "time": 0] as [String: Any]] as NSDictionary)
        XCTAssertEqual(ArenaOutbound.reject(table: 3, player: "bob") as NSDictionary,
                       ["dsgArenaRejectTableJoinEvent": ["table": 3, "playerToReject": "bob", "time": 0] as [String: Any]] as NSDictionary)
        for event in [ArenaOutbound.requestJoin(table: 3), ArenaOutbound.withdraw(table: 3),
                      ArenaOutbound.accept(table: 3, player: "bob"), ArenaOutbound.reject(table: 3, player: "bob")] {
            XCTAssertTrue(JSONSerialization.isValidJSONObject(event))
        }
    }

    func testDeclineUsesLowercaseKey() {
        // The capital "DSGArenaRejectTableJoinEvent" key decoded to null on the server and disconnected the owner.
        XCTAssertEqual(Array(ArenaOutbound.reject(table: 3, player: "bob").keys), ["dsgArenaRejectTableJoinEvent"])
    }
}
```

- [ ] **Step 2: Add the test file to the test target, then run it to verify it fails**

Run:
```bash
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && ruby Scripts/add_swift_file.rb PenteEngineTests/ArenaWireTests.swift PenteEngineTests PenteEngineTests 2>&1 | grep added
xcodebuild test -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests/ArenaWireTests 2>&1 | grep -E 'error:|Executed|TEST (SUCCEEDED|FAILED)'
```
Expected: `added ArenaWireTests.swift to PenteEngineTests via group PenteEngineTests (new)`, then `error: cannot find 'ArenaInbound' in scope` (and similar) and `** TEST FAILED **`.

- [ ] **Step 3: Write the implementation**

Create `$IOS/test1/ArenaWire.swift`:

```swift
//
//  ArenaWire.swift
//  penteLive
//
//  Arena join-request wire protocol: the server events the client decodes and the
//  client events it sends (pente.org spec 2026-10-10-arena-persistent-join-requests).
//  Foundation only, so the hosted tests exercise it without UI.
//

import Foundation

/// One pending request in an owner snapshot. `seq` is server-assigned and increasing.
struct ArenaJoinRequest: Equatable {
    let player: String
    let seq: Int
}

/// Body of dsgArenaRequestEndedEvent. `player` is the requester, `owner` the table owner.
struct ArenaRequestEnded: Equatable {
    enum Reason: String, CaseIterable {
        case declined = "DECLINED"
        case tableFull = "TABLE_FULL"
        case tableClosed = "TABLE_CLOSED"
        case duplicate = "DUPLICATE"
        case blocked = "BLOCKED"
        case notAvailable = "NOT_AVAILABLE"
        case guestRated = "GUEST_RATED"
        case noLongerAvailable = "NO_LONGER_AVAILABLE"
    }

    let table: Int
    let player: String
    let owner: String
    let reason: Reason

    /// The short notice shown for this ending (spec C4).
    var noticeText: String {
        switch reason {
        case .declined:
            return String(format: NSLocalizedString("%@ declined your request", comment: "arena notice; %@ is the table owner"), owner)
        case .tableFull:
            return String(format: NSLocalizedString("Table %ld is no longer available", comment: "arena notice"), table)
        case .tableClosed:
            return String(format: NSLocalizedString("Table %ld was closed", comment: "arena notice"), table)
        case .duplicate:
            return String(format: NSLocalizedString("You already requested table %ld", comment: "arena notice"), table)
        case .blocked:
            return String(format: NSLocalizedString("You can't request table %ld again until its next game", comment: "arena notice"), table)
        case .notAvailable:
            return String(format: NSLocalizedString("You can't join table %ld right now", comment: "arena notice"), table)
        case .guestRated:
            return NSLocalizedString("Guests can't join rated tables", comment: "arena notice")
        case .noLongerAvailable:
            return String(format: NSLocalizedString("%@ is no longer available", comment: "arena notice to the owner; %@ is the requester"), player)
        }
    }
}

/// The arena events the server sends. Anything else (including the old S→C
/// dsgArenaRequestJoinTableEvent / dsgArenaRejectTableJoinEvent) is not an arena event.
enum ArenaInbound: Equatable {
    case joinRequests(table: Int, requests: [ArenaJoinRequest])
    case myRequests(tables: [Int])
    case requestEnded(ArenaRequestEnded)

    /// nil when `event` carries none of the three keys, or its payload is unusable.
    /// Bad list entries are skipped; the snapshot comes back in `seq` order, one row per player.
    init?(event: [String: Any]) {
        if let body = event["dsgArenaJoinRequestsEvent"] as? [String: Any] {
            guard let table = body["table"] as? Int else { return nil }
            var seen = Set<String>()
            let requests = (body["requests"] as? [Any] ?? [])
                .compactMap { entry -> ArenaJoinRequest? in
                    guard let fields = entry as? [String: Any],
                          let player = fields["player"] as? String,
                          let seq = fields["seq"] as? Int else { return nil }
                    return ArenaJoinRequest(player: player, seq: seq)
                }
                .sorted { $0.seq < $1.seq }
                .filter { seen.insert($0.player).inserted }
            self = .joinRequests(table: table, requests: requests)
        } else if let body = event["dsgArenaMyRequestsEvent"] as? [String: Any] {
            let tables = (body["tables"] as? [Any] ?? []).compactMap { $0 as? Int }
            self = .myRequests(tables: tables)
        } else if let body = event["dsgArenaRequestEndedEvent"] as? [String: Any] {
            guard let table = body["table"] as? Int,
                  let rawReason = body["reason"] as? String,
                  let reason = ArenaRequestEnded.Reason(rawValue: rawReason) else { return nil }
            self = .requestEnded(ArenaRequestEnded(table: table,
                                                   player: body["player"] as? String ?? "",
                                                   owner: body["owner"] as? String ?? "",
                                                   reason: reason))
        } else {
            return nil
        }
    }
}

/// The arena events the client sends. `player` is filled in by the server from the session.
enum ArenaOutbound {
    static func requestJoin(table: Int) -> [String: Any] {
        return ["dsgArenaRequestJoinTableEvent": ["table": table, "time": 0]]
    }

    static func withdraw(table: Int) -> [String: Any] {
        return ["dsgArenaWithdrawJoinRequestEvent": ["table": table, "time": 0]]
    }

    static func accept(table: Int, player: String) -> [String: Any] {
        return ["dsgArenaAcceptTableJoinEvent": ["table": table, "playerToAccept": player, "time": 0] as [String: Any]]
    }

    static func reject(table: Int, player: String) -> [String: Any] {
        return ["dsgArenaRejectTableJoinEvent": ["table": table, "playerToReject": player, "time": 0] as [String: Any]]
    }
}

enum ArenaText {
    /// The confirm shown before withdrawing (spec C3).
    static func withdrawConfirm(table: Int) -> String {
        return String(format: NSLocalizedString("Withdraw your request to table %ld? You won't be able to request it again until its next game.", comment: "arena withdraw confirm"), table)
    }
}
```

- [ ] **Step 4: Add it to the app target, format, and run the tests to verify they pass**

Run:
```bash
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && ruby Scripts/add_swift_file.rb test1/ArenaWire.swift penteLive test1 2>&1 | grep added
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && swiftformat test1/ArenaWire.swift PenteEngineTests/ArenaWireTests.swift
xcodebuild test -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests/ArenaWireTests 2>&1 | grep -E 'error:|Executed|TEST (SUCCEEDED|FAILED)'
```
Expected: `Executed 15 tests, with 0 failures` and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS add test1/ArenaWire.swift PenteEngineTests/ArenaWireTests.swift penteLive.xcodeproj/project.pbxproj
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS commit -S -m "Add arena join-request wire types and notice texts"
```

---

### Task 2: Owner list model (freeze, minimum window, in-flight)

**Files:**
- Create: `$IOS/test1/ArenaJoinRequestListModel.swift`
- Create: `$IOS/PenteEngineTests/ArenaJoinRequestListModelTests.swift`
- Modify: `$IOS/penteLive.xcodeproj/project.pbxproj` (script only)

**Interfaces:**
- Consumes: `ArenaJoinRequest` (Task 1).
- Produces (used by Task 4):
  - `final class ArenaJoinRequestListModel`
  - `typealias Schedule = (_ delay: TimeInterval, _ work: @escaping () -> Void) -> Void`
  - `static let freezeDuration: TimeInterval = 0.4`, `static let interactiveWindow: TimeInterval = 1.0`, `static let mainQueueSchedule: Schedule`
  - `init(schedule: @escaping Schedule = ArenaJoinRequestListModel.mainQueueSchedule)`
  - `private(set) var rows: [ArenaJoinRequest]`, `private(set) var inFlightPlayer: String?`, `var onChange: (() -> Void)?`
  - `var isVisible: Bool`, `var isFrozen: Bool`, `var isInteractive: Bool`
  - `@discardableResult func receive(_ snapshot: [ArenaJoinRequest]) -> Bool` (true means play the new-request cue)
  - `func beginAction(on player: String) -> Bool`
  - `func reset()`
  - `enum ArenaPopoverStep: Equatable { case nothing, present, dismiss, retryLater }`
  - `static func popoverStep(hasRows: Bool, isPresented: Bool, isOnScreen: Bool, isAnotherPresentationUp: Bool) -> ArenaPopoverStep` (Review Focus 3: what the table screen does with the request popover)

**Behaviour (spec C2, with the choices this plan makes):**
- **Visibility.** The list is visible exactly when `rows` is non-empty.
- **Hidden list.** A snapshot that arrives while the list is hidden (idle, or inside a window) applies at once.
- **Visible list, idle.** A snapshot starts a 400 ms freeze. When the freeze ends, the newest held snapshot is applied.
- **Window.** Every apply opens a 1000 ms interactive window. Snapshots that arrive in the window are held, and when it ends they start a freeze.
- **In-flight.** `inFlightPlayer` is cleared when a snapshot is *applied*, not when it arrives, so a row that may already be gone cannot be re-tapped.
- **New-request cue.** It compares against the previous *received* snapshot.
- **Popover step.** With rows: present when the popover is not up, the table screen is in a window and nothing else is presented; retry later when something else is presented (another sheet, or our own popover still animating out); otherwise do nothing (`viewDidAppear` calls again). Without rows: dismiss when up, otherwise nothing.

- [ ] **Step 1: Write the failing tests**

Create `$IOS/PenteEngineTests/ArenaJoinRequestListModelTests.swift`:

```swift
import XCTest
@testable import penteLive

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

    /// A model showing [alice] whose first window has ended (idle, visible) at t = 1000 ms.
    private func makeVisibleIdleModel() -> (FakeArenaClock, ArenaJoinRequestListModel) {
        let (clock, model) = makeModel()
        model.receive([req("alice", 1)])
        clock.advance(ms: 1000)
        return (clock, model)
    }

    func testFirstSnapshotWhileHiddenAppliesImmediately() {
        let (_, model) = makeModel()
        XCTAssertFalse(model.isVisible)
        model.receive([req("alice", 1)])
        XCTAssertEqual(model.rows, [req("alice", 1)])
        XCTAssertFalse(model.isFrozen)
        XCTAssertTrue(model.isInteractive)
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
        let (clock, model) = makeVisibleIdleModel()           // t = 1000
        model.receive([req("alice", 1), req("bob", 2)])        // freeze 1000-1400
        clock.advance(ms: 400)                                 // applied at 1400, window to 2400
        clock.advance(ms: 100)                                 // t = 1500
        model.receive([req("alice", 1), req("bob", 2), req("carol", 3)])
        model.receive([req("bob", 2), req("carol", 3)])        // replaces the held one
        XCTAssertFalse(model.isFrozen)
        XCTAssertTrue(model.isInteractive)
        XCTAssertEqual(model.rows, [req("alice", 1), req("bob", 2)])
        clock.advance(ms: 899)                                 // t = 2399
        XCTAssertFalse(model.isFrozen)
        XCTAssertEqual(model.rows, [req("alice", 1), req("bob", 2)])
        clock.advance(ms: 1)                                   // t = 2400: window ends, freeze starts
        XCTAssertTrue(model.isFrozen)
        clock.advance(ms: 400)
        XCTAssertFalse(model.isFrozen)
        XCTAssertEqual(model.rows, [req("bob", 2), req("carol", 3)])
    }

    func testListThatJustAppearedStaysInteractiveForTheWindow() {
        let (clock, model) = makeModel()
        model.receive([req("alice", 1)])                       // shown at 0, window to 1000
        clock.advance(ms: 500)
        model.receive([req("alice", 1), req("bob", 2)])
        XCTAssertFalse(model.isFrozen)
        XCTAssertEqual(model.rows, [req("alice", 1)])
        clock.advance(ms: 500)
        XCTAssertTrue(model.isFrozen)
    }

    func testBurstOfSnapshotsCannotLockOwnerOut() {
        let (clock, model) = makeModel()
        model.receive([req("alice", 1)])
        var transitions: [(atMs: Int, frozen: Bool)] = [(atMs: 0, frozen: false)]
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

    func testHiddenListShowsTheNextSnapshotImmediatelyEvenInsideAWindow() {
        let (clock, model) = makeVisibleIdleModel()
        model.receive([])
        clock.advance(ms: 400)                                 // hidden, window running
        clock.advance(ms: 100)
        model.receive([req("carol", 3)])
        XCTAssertFalse(model.isFrozen)
        XCTAssertEqual(model.rows, [req("carol", 3)])
    }

    func testNewRequesterCue() {
        let (_, model) = makeModel()
        XCTAssertTrue(model.receive([req("alice", 1)]))
        XCTAssertFalse(model.receive([req("alice", 1)]))
        XCTAssertTrue(model.receive([req("alice", 1), req("bob", 2)]))
        XCTAssertFalse(model.receive([req("bob", 2)]))
        XCTAssertTrue(model.receive([req("alice", 5), req("bob", 2)]))  // alice is back
        XCTAssertFalse(model.receive([]))
    }

    func testActionLocksTheWholeListUntilTheAnswerIsApplied() {
        let (clock, model) = makeVisibleIdleModel()
        model.receive([req("alice", 1), req("bob", 2)])
        clock.advance(ms: 400 + 1000)                          // applied, window over
        XCTAssertTrue(model.beginAction(on: "alice"))
        XCTAssertEqual(model.inFlightPlayer, "alice")
        XCTAssertFalse(model.isInteractive)
        XCTAssertFalse(model.beginAction(on: "bob"))
        model.receive([req("bob", 2)])                         // the server's answer (R11)
        XCTAssertEqual(model.inFlightPlayer, "alice")
        clock.advance(ms: 400)
        XCTAssertNil(model.inFlightPlayer)
        XCTAssertTrue(model.isInteractive)
        XCTAssertEqual(model.rows, [req("bob", 2)])
    }

    func testActionInsideTheWindowStaysLockedUntilTheHeldAnswerIsApplied() {
        let (clock, model) = makeModel()
        model.receive([req("alice", 1), req("bob", 2)])        // shown at 0, window to 1000
        XCTAssertTrue(model.beginAction(on: "bob"))
        clock.advance(ms: 300)
        model.receive([req("alice", 1)])                       // held by the window
        XCTAssertFalse(model.isInteractive)
        clock.advance(ms: 700)                                 // window ends, freeze starts
        XCTAssertTrue(model.isFrozen)
        clock.advance(ms: 400)
        XCTAssertNil(model.inFlightPlayer)
        XCTAssertEqual(model.rows, [req("alice", 1)])
    }

    func testActionIsRefusedWhileFrozenOrForAPlayerWithoutARow() {
        let (_, model) = makeVisibleIdleModel()
        XCTAssertFalse(model.beginAction(on: "zed"))
        model.receive([req("alice", 1), req("bob", 2)])        // frozen
        XCTAssertFalse(model.beginAction(on: "alice"))
        XCTAssertNil(model.inFlightPlayer)
    }

    func testResetDropsRowsAndPendingTimers() {
        let (clock, model) = makeVisibleIdleModel()
        model.receive([req("alice", 1), req("bob", 2)])        // frozen, freeze timer pending
        model.reset()
        XCTAssertFalse(model.isVisible)
        XCTAssertFalse(model.isFrozen)
        clock.advance(ms: 2000)                                // stale timers must do nothing
        XCTAssertFalse(model.isVisible)
        model.receive([req("carol", 3)])
        XCTAssertEqual(model.rows, [req("carol", 3)])
        XCTAssertFalse(model.isFrozen)
    }

    func testOnChangeReportsEveryVisibleChange() {
        let (clock, model) = makeModel()
        var calls = 0
        model.onChange = { calls += 1 }
        model.receive([req("alice", 1)])                       // applied
        clock.advance(ms: 1000)                                // window ends with nothing held: no change
        model.receive([req("bob", 2)])                         // freeze starts
        clock.advance(ms: 400)                                 // freeze ends
        XCTAssertTrue(model.beginAction(on: "bob"))
        model.reset()
        XCTAssertEqual(calls, 5)
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
```

- [ ] **Step 2: Add the test file to the test target, then run it to verify it fails**

Run:
```bash
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && ruby Scripts/add_swift_file.rb PenteEngineTests/ArenaJoinRequestListModelTests.swift PenteEngineTests PenteEngineTests 2>&1 | grep added
xcodebuild test -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests/ArenaJoinRequestListModelTests 2>&1 | grep -E 'error:|Executed|TEST (SUCCEEDED|FAILED)'
```
Expected: `error: cannot find 'ArenaJoinRequestListModel' in scope` and `** TEST FAILED **`.

- [ ] **Step 3: Write the implementation**

Create `$IOS/test1/ArenaJoinRequestListModel.swift`:

```swift
//
//  ArenaJoinRequestListModel.swift
//  penteLive
//
//  Owner-side arena request list state (spec C2). Applies server snapshots behind a
//  400 ms freeze and keeps the list interactive for at least 1000 ms after every
//  apply, so rows never move under a finger and a burst cannot lock the owner out.
//  Main-thread only. Time comes from the injected `schedule`, so tests use a fake clock.
//

import Foundation

final class ArenaJoinRequestListModel {
    typealias Schedule = (_ delay: TimeInterval, _ work: @escaping () -> Void) -> Void

    static let freezeDuration: TimeInterval = 0.4
    static let interactiveWindow: TimeInterval = 1.0
    static let mainQueueSchedule: Schedule = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private enum Phase {
        case idle // interactive, no window running
        case frozen // spinner up, taps ignored; `held` is applied when the freeze ends
        case window // interactive; snapshots wait in `held` until the window ends
    }

    /// The rows on screen, in `seq` order. Empty means the list is hidden.
    private(set) var rows: [ArenaJoinRequest] = []
    /// The player whose accept or decline waits for the server's snapshot.
    private(set) var inFlightPlayer: String?
    /// Called after every change to `rows`, `isFrozen` or `inFlightPlayer`.
    var onChange: (() -> Void)?

    private var phase = Phase.idle
    private var held: [ArenaJoinRequest]?
    private var lastReceivedPlayers = Set<String>()
    private var timerToken = 0
    private let schedule: Schedule

    init(schedule: @escaping Schedule = ArenaJoinRequestListModel.mainQueueSchedule) {
        self.schedule = schedule
    }

    var isVisible: Bool { !rows.isEmpty }
    var isFrozen: Bool { phase == .frozen }
    var isInteractive: Bool { phase != .frozen && inFlightPlayer == nil }

    /// Takes the newest snapshot for this table, already in `seq` order (ArenaInbound sorts).
    /// Returns true when it names a player the previous snapshot did not (the new-request cue).
    @discardableResult
    func receive(_ snapshot: [ArenaJoinRequest]) -> Bool {
        let players = Set(snapshot.map { $0.player })
        let hasNewPlayer = !players.subtracting(lastReceivedPlayers).isEmpty
        lastReceivedPlayers = players
        switch phase {
        case .frozen:
            held = snapshot
        case .window:
            if isVisible {
                held = snapshot
            } else {
                apply(snapshot) // nothing on screen to protect
            }
        case .idle:
            if isVisible {
                freeze(holding: snapshot)
            } else {
                apply(snapshot)
            }
        }
        onChange?()
        return hasNewPlayer
    }

    /// Marks `player`'s row in flight before an accept or decline is sent. Returns false,
    /// and the caller sends nothing, while the list is not interactive or has no such row.
    func beginAction(on player: String) -> Bool {
        guard isInteractive, rows.contains(where: { $0.player == player }) else { return false }
        inFlightPlayer = player
        onChange?()
        return true
    }

    /// Clears everything and turns pending timers into no-ops (table left or filled).
    func reset() {
        timerToken += 1
        rows = []
        held = nil
        inFlightPlayer = nil
        lastReceivedPlayers = []
        phase = .idle
        onChange?()
    }

    private func freeze(holding snapshot: [ArenaJoinRequest]) {
        phase = .frozen
        held = snapshot
        startTimer(after: ArenaJoinRequestListModel.freezeDuration) { $0.endFreeze() }
    }

    /// Shows `snapshot`, ends any in-flight action (this is the server's answer) and opens the window.
    private func apply(_ snapshot: [ArenaJoinRequest]) {
        rows = snapshot
        held = nil
        inFlightPlayer = nil
        phase = .window
        startTimer(after: ArenaJoinRequestListModel.interactiveWindow) { $0.endWindow() }
    }

    private func endFreeze() {
        apply(held ?? rows)
        onChange?()
    }

    private func endWindow() {
        guard let next = held else {
            phase = .idle
            return
        }
        if isVisible {
            freeze(holding: next)
        } else {
            apply(next)
        }
        onChange?()
    }

    /// Only the most recently started timer may fire; reset() and newer timers cancel older ones.
    private func startTimer(after delay: TimeInterval, _ fire: @escaping (ArenaJoinRequestListModel) -> Void) {
        timerToken += 1
        let token = timerToken
        schedule(delay) { [weak self] in
            guard let self = self, self.timerToken == token else { return }
            fire(self)
        }
    }
}

/// What the table screen does with the request popover after a model change or appearance.
enum ArenaPopoverStep: Equatable {
    case nothing, present, dismiss, retryLater
}

extension ArenaJoinRequestListModel {
    /// The popover is up exactly while the list has rows (spec C2), and is never presented twice.
    /// - isPresented: our popover is up.
    /// - isOnScreen: the table screen is in a window; when it is not, viewDidAppear asks again.
    /// - isAnotherPresentationUp: something is presented on the table screen (another sheet,
    ///   or our own popover still animating out), so presenting must be retried shortly.
    static func popoverStep(hasRows: Bool, isPresented: Bool, isOnScreen: Bool, isAnotherPresentationUp: Bool) -> ArenaPopoverStep {
        guard hasRows else { return isPresented ? .dismiss : .nothing }
        if isPresented || !isOnScreen {
            return .nothing
        }
        return isAnotherPresentationUp ? .retryLater : .present
    }
}
```

- [ ] **Step 4: Add it to the app target, format, and run the tests to verify they pass**

Run:
```bash
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && ruby Scripts/add_swift_file.rb test1/ArenaJoinRequestListModel.swift penteLive test1 2>&1 | grep added
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && swiftformat test1/ArenaJoinRequestListModel.swift PenteEngineTests/ArenaJoinRequestListModelTests.swift
xcodebuild test -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests/ArenaJoinRequestListModelTests 2>&1 | grep -E 'error:|Executed|TEST (SUCCEEDED|FAILED)'
```
Expected: `Executed 16 tests, with 0 failures` and `** TEST SUCCEEDED **`.

If `testOnChangeReportsEveryVisibleChange` fails, recount against the code, do not tune the number blindly. The expected `onChange` calls are:
1. `receive` (applied)
2. `receive` (freeze starts)
3. `endFreeze`
4. `beginAction`
5. `reset`

The window that ends with nothing held does not call `onChange`.

- [ ] **Step 5: Commit**

```bash
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS add test1/ArenaJoinRequestListModel.swift PenteEngineTests/ArenaJoinRequestListModelTests.swift penteLive.xcodeproj/project.pbxproj
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS commit -S -m "Add the arena owner request-list model with freeze and interactive window"
```

---

### Task 3: Requester lobby model

**Files:**
- Create: `$IOS/test1/ArenaMyRequestsModel.swift`
- Create: `$IOS/PenteEngineTests/ArenaMyRequestsModelTests.swift`
- Modify: `$IOS/penteLive.xcodeproj/project.pbxproj` (script only)

**Interfaces:**
- Consumes: nothing.
- Produces (used by Tasks 4 and 5):
  - `struct ArenaMyRequestsModel`
  - `enum TapAction: Equatable { case ignore, request, confirmWithdraw }`
  - `private(set) var requested: Set<Int>`, `private(set) var awaiting: Set<Int>`
  - `func isRequested(_ table: Int) -> Bool`, `func isAwaiting(_ table: Int) -> Bool`
  - `mutating func apply(tables: [Int])`
  - `mutating func tap(table: Int) -> TapAction`
  - `mutating func beginWithdraw(table: Int) -> Bool`

Spec C3 says to ignore taps "until the next `dsgArenaMyRequestsEvent` arrives". This plan reads that literally: any `dsgArenaMyRequestsEvent` clears every awaiting table. A withdraw also marks its table awaiting, so a double confirm sends one withdraw. Known edge of the literal reading: tap table 1, then table 2; table 1's answer clears table 2's spinner before table 2's own answer arrives, and a re-tap of table 2 in that gap draws a `DUPLICATE` notice. It is harmless (the server keeps one request) and matches the other clients; correlating answers is left to the user's call.

- [ ] **Step 1: Write the failing tests**

Create `$IOS/PenteEngineTests/ArenaMyRequestsModelTests.swift`:

```swift
import XCTest
@testable import penteLive

final class ArenaMyRequestsModelTests: XCTestCase {
    func testTapOnUnmarkedTableRequestsOnceUntilAnswered() {
        var model = ArenaMyRequestsModel()
        XCTAssertEqual(model.tap(table: 3), .request)
        XCTAssertTrue(model.isAwaiting(3))
        XCTAssertEqual(model.tap(table: 3), .ignore) // a double tap never sends a DUPLICATE request
        model.apply(tables: [3])
        XCTAssertFalse(model.isAwaiting(3))
        XCTAssertTrue(model.isRequested(3))
    }

    func testTapOnMarkedTableAsksToWithdraw() {
        var model = ArenaMyRequestsModel()
        model.apply(tables: [5])
        XCTAssertEqual(model.tap(table: 5), .confirmWithdraw)
        XCTAssertFalse(model.isAwaiting(5)) // nothing is sent until the confirm
    }

    func testWithdrawWaitsForTheAnswer() {
        var model = ArenaMyRequestsModel()
        model.apply(tables: [5])
        XCTAssertTrue(model.beginWithdraw(table: 5))
        XCTAssertEqual(model.tap(table: 5), .ignore)
        XCTAssertFalse(model.beginWithdraw(table: 5))
        model.apply(tables: [])
        XCTAssertFalse(model.isRequested(5))
        XCTAssertEqual(model.tap(table: 5), .request)
    }

    func testAnAnswerClearsEveryOutstandingTap() {
        var model = ArenaMyRequestsModel()
        XCTAssertEqual(model.tap(table: 1), .request)
        XCTAssertEqual(model.tap(table: 2), .request)
        model.apply(tables: [1])
        XCTAssertFalse(model.isAwaiting(1))
        XCTAssertFalse(model.isAwaiting(2))
        XCTAssertEqual(model.requested, [1])
        XCTAssertEqual(model.tap(table: 2), .request)
    }

    func testRefusedRequestLeavesNoMark() {
        var model = ArenaMyRequestsModel()
        XCTAssertEqual(model.tap(table: 4), .request)
        model.apply(tables: []) // refused (e.g. BLOCKED); R11 still answers with the set
        XCTAssertFalse(model.isRequested(4))
        XCTAssertFalse(model.isAwaiting(4))
    }

    func testWithdrawConfirmedAfterTableLeftTheSetStillSends() {
        var model = ArenaMyRequestsModel()
        model.apply(tables: [5])
        XCTAssertEqual(model.tap(table: 5), .confirmWithdraw)
        model.apply(tables: []) // TABLE_FULL arrived while the alert was open
        XCTAssertTrue(model.beginWithdraw(table: 5)) // still sent; the server answers with the set
        model.apply(tables: [])
        XCTAssertFalse(model.isAwaiting(5))
    }
}
```

- [ ] **Step 2: Add the test file to the test target, then run it to verify it fails**

Run:
```bash
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && ruby Scripts/add_swift_file.rb PenteEngineTests/ArenaMyRequestsModelTests.swift PenteEngineTests PenteEngineTests 2>&1 | grep added
xcodebuild test -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests/ArenaMyRequestsModelTests 2>&1 | grep -E 'error:|Executed|TEST (SUCCEEDED|FAILED)'
```
Expected: `error: cannot find 'ArenaMyRequestsModel' in scope` and `** TEST FAILED **`.

- [ ] **Step 3: Write the implementation**

Create `$IOS/test1/ArenaMyRequestsModel.swift`:

```swift
//
//  ArenaMyRequestsModel.swift
//  penteLive
//
//  Requester-side arena lobby state (spec C3): which tables carry the "Requested"
//  mark, and which taps wait for the server's dsgArenaMyRequestsEvent answer.
//  Main-thread only.
//

import Foundation

struct ArenaMyRequestsModel {
    enum TapAction: Equatable {
        case ignore // an answer for this table is still outstanding
        case request // send dsgArenaRequestJoinTableEvent
        case confirmWithdraw // ask before sending dsgArenaWithdrawJoinRequestEvent
    }

    /// Tables in the latest dsgArenaMyRequestsEvent.
    private(set) var requested = Set<Int>()
    /// Tables tapped since that event; further taps on them are ignored.
    private(set) var awaiting = Set<Int>()

    func isRequested(_ table: Int) -> Bool {
        return requested.contains(table)
    }

    func isAwaiting(_ table: Int) -> Bool {
        return awaiting.contains(table)
    }

    /// The server's full set. R11 answers every request and withdraw with one.
    mutating func apply(tables: [Int]) {
        requested = Set(tables)
        awaiting.removeAll()
    }

    mutating func tap(table: Int) -> TapAction {
        if awaiting.contains(table) {
            return .ignore
        }
        if requested.contains(table) {
            return .confirmWithdraw
        }
        awaiting.insert(table)
        return .request
    }

    /// Called when the withdraw confirm is accepted. Returns false, and the caller
    /// sends nothing, when an answer for this table is already outstanding.
    mutating func beginWithdraw(table: Int) -> Bool {
        guard !awaiting.contains(table) else { return false }
        awaiting.insert(table)
        return true
    }
}
```

- [ ] **Step 4: Add it to the app target, format, and run the tests to verify they pass**

Run:
```bash
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && ruby Scripts/add_swift_file.rb test1/ArenaMyRequestsModel.swift penteLive test1 2>&1 | grep added
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && swiftformat test1/ArenaMyRequestsModel.swift PenteEngineTests/ArenaMyRequestsModelTests.swift
xcodebuild test -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests/ArenaMyRequestsModelTests 2>&1 | grep -E 'error:|Executed|TEST (SUCCEEDED|FAILED)'
```
Expected: `Executed 6 tests, with 0 failures` and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS add test1/ArenaMyRequestsModel.swift PenteEngineTests/ArenaMyRequestsModelTests.swift penteLive.xcodeproj/project.pbxproj
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS commit -S -m "Add the arena requester lobby model"
```

---

### Task 4: Inbound routing and the owner request list UI

This task wires the models into UIKit for the owner side and routes all three new server events. It removes the C1 owner timers and fixes the three C5-iOS bugs:
- **Off-main force-unwrap.** `RoomViewController.swift:521` force-unwrapped `tableViewController` off the main thread.
- **Rows never removed.** Rows were not removed after accept/decline; they now come only from snapshots.
- **Double present.** The request popover was presented twice.

**Files:**
- Rewrite: `$IOS/test1/ArenaJoinRequestList.swift:1-148`
- Modify: `$IOS/test1/TableViewController.swift:83` (after `super.init`), `:390-392`, `:395-436`, `:594-597`, `:1280-1281`, `:1390-1398`
- Modify: `$IOS/test1/RoomViewController.swift:57-58` (new property), `:422-424` (stale comment), `:519-530`
- Modify: `$IOS/test1/PenteLiveSocket.swift:231-233`

**Interfaces:**
- Consumes:
  - From Task 1: `ArenaInbound`, `ArenaOutbound.accept(table:player:)`, `ArenaOutbound.reject(table:player:)`, `ArenaRequestEnded.noticeText`.
  - From Task 2: `ArenaJoinRequestListModel` (`receive`, `beginAction(on:)`, `reset`, `rows`, `inFlightPlayer`, `isFrozen`, `isInteractive`, `isVisible`, `onChange`, `popoverStep(hasRows:isPresented:isOnScreen:isAnotherPresentationUp:)`), `ArenaPopoverStep`.
  - From Task 3: `ArenaMyRequestsModel.apply(tables:)`.
- Produces (used by Task 5):
  - `RoomViewController.arenaMyRequests: ArenaMyRequestsModel` (main-thread only).
  - `RoomViewController.arenaEvent(_ inbound: ArenaInbound)`, callable from the socket queue.
  - `TableViewController.arenaJoinRequestsEvent(requests: [ArenaJoinRequest]) -> Bool`, `TableViewController.updateArenaJoinRequestPresentation()` and `TableViewController.arenaJoinRequestSourceRect() -> CGRect`.
  - `ArenaJoinRequestList.model`, `.freezeOverlay` and `.onModelChange`.
- Removes: `RoomViewController.arenaRequestJoinTableEvent(event:)`, `TableViewController.arenaTableRequestJoinEvent(event:)`, `ArenaJoinRequestList.addPlayer(player:)`, `.addPlayer(name:)`, `.reset()`, `.data`, `.joinTimeout` and every `Timer` in the list.

**Choice made for spec C2 "Empty snapshot. The list hides".** On iOS the list lives in a popover that also holds the red "Exit Table" button. The popover is presented exactly while the model has rows, and is dismissed when it has none. An owner sitting alone with no requests therefore sees the board, and leaves through the navigation bar "Exit" button (`backToMainRoom`). Before this change the popover appeared whenever the owner was alone.

- [ ] **Step 1: Rewrite `ArenaJoinRequestList.swift`**

Replace the whole of `$IOS/test1/ArenaJoinRequestList.swift` (lines 1-148) with:

```swift
//
//  ArenaJoinRequestList.swift
//  penteLive
//
//  Created by rainwolf on 06/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

/// The arena owner's request list. Rows come only from server snapshots through `model`;
/// taps and swipes go through the model, so a frozen or in-flight list sends nothing.
class ArenaJoinRequestList: UITableView, UITableViewDelegate, UITableViewDataSource {
    private static let cellId = "ArenaJoinRequestCell"

    var me: String!
    var socket: PenteLiveSocket!
    var tableAndPlayers: TablesAndPlayer!
    var tableId: Int!
    var gameId: Int!
    let model: ArenaJoinRequestListModel
    /// Dims the list and spins while a snapshot is frozen. The presenter adds it above the list.
    let freezeOverlay = UIView()
    /// Called after every model change, so the presenter can show or hide the popover.
    var onModelChange: (() -> Void)?
    private let freezeSpinner = UIActivityIndicatorView(style: .large)

    init(socket: PenteLiveSocket, me: String, tableAndPlayers: TablesAndPlayer, tableId: Int, gameId: Int, model: ArenaJoinRequestListModel = ArenaJoinRequestListModel()) {
        self.me = me
        self.socket = socket
        self.tableAndPlayers = tableAndPlayers
        self.tableId = tableId
        self.gameId = gameId
        self.model = model

        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0), style: UITableView.Style.plain)
        delegate = self
        dataSource = self
        layer.borderWidth = 1.0
        layer.cornerRadius = 1.0

        freezeOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        freezeOverlay.isHidden = true
        freezeSpinner.translatesAutoresizingMaskIntoConstraints = false
        freezeOverlay.addSubview(freezeSpinner)
        NSLayoutConstraint.activate([
            freezeSpinner.centerXAnchor.constraint(equalTo: freezeOverlay.centerXAnchor),
            freezeSpinner.centerYAnchor.constraint(equalTo: freezeOverlay.centerYAnchor),
        ])
        model.onChange = { [weak self] in
            self?.modelChanged()
        }
    }

    required init(coder aDecoder: NSCoder) {
        model = ArenaJoinRequestListModel()
        super.init(coder: aDecoder)!
    }

    private func modelChanged() {
        if model.isFrozen {
            setEditing(false, animated: true) // close an open swipe-to-reject
            freezeOverlay.isHidden = false
            freezeSpinner.startAnimating()
        } else {
            freezeSpinner.stopAnimating()
            freezeOverlay.isHidden = true
        }
        reloadData()
        onModelChange?()
    }

    func tableView(_: UITableView, canEditRowAt _: IndexPath) -> Bool {
        return model.isInteractive
    }

    func tableView(_: UITableView, editingStyleForRowAt _: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    func tableView(_: UITableView, titleForDeleteConfirmationButtonForRowAt _: IndexPath) -> String? {
        return NSLocalizedString("Reject", comment: "")
    }

    func tableView(_: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, indexPath.row < model.rows.count else { return }
        let player = model.rows[indexPath.row].player
        // No optimistic removal: the row keeps a spinner until the server's snapshot (R11).
        guard model.beginAction(on: player) else { return }
        socket.sendEvent(eventDictionary: ArenaOutbound.reject(table: tableId, player: player))
    }

    func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return model.rows.count
    }

    func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        return NSLocalizedString("Tap player to accept", comment: "")
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ArenaJoinRequestList.cellId) ?? UITableViewCell(style: .value1, reuseIdentifier: ArenaJoinRequestList.cellId)
        cell.selectionStyle = .none

        let playerName = model.rows[indexPath.row].player
        let player = tableAndPlayers.player(name: playerName)
        cell.textLabel?.attributedText = player?.getNameString() ?? NSAttributedString(string: playerName)
        cell.detailTextLabel?.attributedText = player?.getRatingString(game: gameId)
        if playerName == model.inFlightPlayer {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            cell.accessoryView = spinner
        } else {
            cell.accessoryView = nil
        }
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < model.rows.count else { return }
        let player = model.rows[indexPath.row].player
        guard model.beginAction(on: player) else { return }
        socket.sendEvent(eventDictionary: ArenaOutbound.accept(table: tableId, player: player))
    }
}
```

Then run `cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && swiftformat test1/ArenaJoinRequestList.swift`.

- [ ] **Step 2: Rewire `TableViewController.swift`**

(a) Find the `init(table:socket:tablesAndPlayers:pente_player:me:isArenaTable:)` body. Directly after `super.init(nibName: nil, bundle: nil)` (line 83), insert:

```swift
        arenaJoinRequestView?.onModelChange = { [weak self] in
            self?.updateArenaJoinRequestPresentation()
        }
```

(b) In `viewDidAppear(_:)` (lines 390-392), replace:

```swift
        if isArenaTable && table.players.count == 1 {
            showArenaJoinRequest()
        }
```
with:
```swift
        updateArenaJoinRequestPresentation()
```

(c) Replace `showArenaJoinRequest()` and `dismissArenaJoinRequest()` (lines 395-436) with:

```swift
    private var arenaPresentRetryScheduled = false

    /// Shows the request popover while the owner's list has rows and hides it when the
    /// list is empty (spec C2). Safe to call any number of times.
    func updateArenaJoinRequestPresentation() {
        guard isArenaTable, let requestView = arenaJoinRequestView else { return }
        // isViewLoaded first: a snapshot can arrive before the view loads, and view.window would load it.
        let step = ArenaJoinRequestListModel.popoverStep(hasRows: requestView.model.isVisible,
                                                         isPresented: arenaJoinRequestVC != nil,
                                                         isOnScreen: isViewLoaded && view.window != nil,
                                                         isAnotherPresentationUp: isViewLoaded && presentedViewController != nil)
        switch step {
        case .nothing:
            return
        case .dismiss:
            arenaJoinRequestVC?.dismiss(animated: true)
            arenaJoinRequestVC = nil
        case .retryLater:
            // Another sheet, or our own popover's dismissal, is still up: try again shortly.
            guard !arenaPresentRetryScheduled else { return }
            arenaPresentRetryScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.arenaPresentRetryScheduled = false
                self?.updateArenaJoinRequestPresentation()
            }
        case .present:
            presentArenaJoinRequest(requestView)
        }
    }

    /// Anchor at the board's top-right. Recomputed on rotation (popoverPresentationController(_:willRepositionPopoverTo:in:)).
    func arenaJoinRequestSourceRect() -> CGRect {
        return CGRect(x: view.bounds.size.width - 20, y: board.frame.origin.y, width: 0, height: 0)
    }

    private func presentArenaJoinRequest(_ requestView: ArenaJoinRequestList) {
        // Capped so the popover does not stretch across an iPad screen.
        let contentWidth = min(4 * view.frame.width / 5, 420)
        let contentHeight: CGFloat = 214
        let buttonHeight: CGFloat = 44

        let requestVC = UIViewController()
        requestVC.preferredContentSize = CGSize(width: contentWidth, height: contentHeight)
        // A plain view controller's view loads at screen size. Size it to the content first, or the
        // autoresizing masks below would pass the whole shrink to the popover size on to the subviews
        // (the list would end up with a negative height and the button above the top).
        requestVC.view.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)

        requestView.frame = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight - buttonHeight)
        requestView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        requestVC.view.addSubview(requestView)
        requestView.freezeOverlay.frame = requestView.frame
        requestView.freezeOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        requestVC.view.addSubview(requestView.freezeOverlay)

        let exitButton = UIButton(type: .system)
        exitButton.setTitle(NSLocalizedString("Exit Table", comment: ""), for: .normal)
        exitButton.setTitleColor(.red, for: .normal)
        exitButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 22)
        exitButton.frame = CGRect(x: 0, y: contentHeight - buttonHeight, width: contentWidth, height: buttonHeight)
        exitButton.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        exitButton.addTarget(self, action: #selector(exitTableFromArena), for: .touchUpInside)
        requestVC.view.addSubview(exitButton)

        requestVC.modalPresentationStyle = .popover
        requestVC.isModalInPresentation = true
        if let popover = requestVC.popoverPresentationController {
            popover.delegate = self
            popover.sourceView = view
            popover.sourceRect = arenaJoinRequestSourceRect()
            popover.permittedArrowDirections = .up
        }
        arenaJoinRequestVC = requestVC
        present(requestVC, animated: true)
    }

    func dismissArenaJoinRequest() {
        arenaJoinRequestView?.model.reset()
        updateArenaJoinRequestPresentation()
    }
```

(d) Replace `arenaTableRequestJoinEvent(event:)` (lines 594-597) with:

```swift
    /// Applies an owner snapshot (dsgArenaJoinRequestsEvent). Returns true when it names a new requester.
    func arenaJoinRequestsEvent(requests: [ArenaJoinRequest]) -> Bool {
        guard let requestView = arenaJoinRequestView else { return false }
        return requestView.model.receive(requests)
    }
```

(e) In `tableExitEvent(event:)` (lines 1280-1281), delete the branch:

```swift
        } else if isArenaTable && table.players.count == 1 {
            showArenaJoinRequest()
```
The `if playerName == me { … }` part stays. The popover now follows snapshots: R6b sends the reopened table's owner a fresh snapshot. Leave `tableJoinEvent`'s `dismissArenaJoinRequest()` at 2 players (lines 1288-1289) as it is.

(f) Keep the popover anchored at the board's top-right after rotation. In `extension TableViewController: UIPopoverPresentationControllerDelegate` (lines 1390-1398), after `popoverPresentationControllerShouldDismissPopover(_:)`, add:

```swift

    func popoverPresentationController(_ popoverPresentationController: UIPopoverPresentationController, willRepositionPopoverTo rect: UnsafeMutablePointer<CGRect>, in _: AutoreleasingUnsafeMutablePointer<UIView>) {
        // The anchor is computed from the view's width, which changes on an iPad rotation.
        if popoverPresentationController.presentedViewController === arenaJoinRequestVC {
            rect.pointee = arenaJoinRequestSourceRect()
        }
    }
```

- [ ] **Step 3: Route the three new events in `PenteLiveSocket.swift`**

Replace lines 231-233:

```swift
        } else if let content = event?["dsgArenaRequestJoinTableEvent"] {
            room.arenaRequestJoinTableEvent(event: content as! [String: Any])
        }
```
with:
```swift
        } else if let event = event, let arena = ArenaInbound(event: event) {
            room.arenaEvent(arena)
        }
```

- [ ] **Step 4: Add `arenaEvent(_:)` and the lobby model to `RoomViewController.swift`**

(a) After `var setupView: ArenaTableSetupView?` (line 58), add:

```swift
    // Requester lobby state (spec C3). Main thread only.
    var arenaMyRequests = ArenaMyRequestsModel()
```

(b) Replace `arenaRequestJoinTableEvent(event:)` (lines 519-530) with:

```swift
    // Arena join-request events arrive on the socket queue; every model and UI touch hops to main.
    func arenaEvent(_ inbound: ArenaInbound) {
        DispatchQueue.main.async {
            switch inbound {
            case let .joinRequests(tableId, requests):
                guard let tableViewController = self.tableViewController, tableViewController.table.table == tableId else { return }
                // Play the new-player sound when a snapshot names a new requester.
                if tableViewController.arenaJoinRequestsEvent(requests: requests), self.playSounds {
                    AudioServicesPlaySystemSound(self.newplayerSndID)
                }
            case let .myRequests(tables):
                self.arenaMyRequests.apply(tables: tables)
                self.tableView.reloadData()
            case let .requestEnded(ended):
                // NO_LONGER_AVAILABLE goes to the owner, whose request popover sits over the strip
                // below the navigation bar where a top banner slides in; show that one at the bottom.
                let position: PenteBannerPosition = ended.reason == .noLongerAvailable ? .bottom : .top
                PenteBanner.showNotification(in: self, title: ended.noticeText, subtitle: nil, image: nil, type: PenteBannerType.message, duration: TimeInterval(PenteBannerDuration.automatic.rawValue), callback: nil, buttonTitle: nil, buttonCallback: nil, at: position, canBeDismissedByUser: true)
            }
        }
    }
```

(c) In `joinMainRoomEvent(event:)`'s main-queue block, the comment at lines 422-424 names the removed handler. Replace:

```swift
            // In an arena room, don't play the new-player sound when other players
            // join the main room. It plays instead when you receive a join request
            // (arenaRequestJoinTableEvent) and when a player joins your table (joinTableEvent).
```
with:
```swift
            // In an arena room, don't play the new-player sound when other players
            // join the main room. It plays instead when a request snapshot names a new
            // requester (arenaEvent) and when a player joins your table (joinTableEvent).
```

- [ ] **Step 5: Verify that no old owner path or capital key is left**

Run:
```bash
grep -rn "DSGArena\|arenaRequestJoinTableEvent\|arenaTableRequestJoinEvent\|addPlayer(name\|joinTimeout\|expiryTimers\|showArenaJoinRequest" /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1
```
Expected: no output.

- [ ] **Step 6: Build for iPhone and iPad and run all unit tests**

Run:
```bash
xcodebuild test -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests 2>&1 | grep -E 'error:|Executed .* tests|TEST (SUCCEEDED|FAILED)' | tail -3
xcodebuild build -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' SWIFT_ENABLE_EXPLICIT_MODULES=NO 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'
```
Expected: `** TEST SUCCEEDED **` with 0 failures, then `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Manual check of the presentation retry (Review Focus 3)**

The end-to-end check runs in Task 6 (E14) against the local server. Here, read `presentArenaJoinRequest` once more and confirm two things:
- The decision itself is pinned by `testPopoverIsShownExactlyWhileThereAreRows` and `testPopoverWaitsUntilPresentingIsPossible` (Task 2). Here, check only the wiring: `.nothing` with rows (not on screen) is retried by `viewDidAppear`, and `.retryLater` is retried by the 0.5 s `asyncAfter`, which calls `updateArenaJoinRequestPresentation()` again.
- The retry stops once the list is empty, because `popoverStep` then returns `.dismiss` or `.nothing`, never `.retryLater`.
- `requestVC.view.frame` is set to the content size before any subview is added (otherwise the autoresizing masks collapse the list and the button).

- [ ] **Step 8: Commit**

```bash
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS add test1/ArenaJoinRequestList.swift test1/TableViewController.swift test1/RoomViewController.swift test1/PenteLiveSocket.swift
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS commit -S -m "Drive the arena owner list from server snapshots and route the new arena events"
```

---

### Task 5: Requester lobby (marks, request, withdraw) and countdown removal

This task covers spec C3 and the requester half of C1: the `RoomViewController` countdown overlay goes away.

**Files:**
- Modify: `$IOS/test1/RoomViewController.swift`:
  - lines 59-60 (countdown properties);
  - lines 265-270 (the table cell accessory in `cellForRowAt`);
  - lines 277-339 (`didSelectRowAt`, `showJoinCountdown`, `hideJoinCountdown`).

  Task 4 added two lines after line 58, so these lines have moved down; match the edits by the quoted code.

**Interfaces:**
- Consumes:
  - From Task 1: `ArenaOutbound.requestJoin(table:)`, `ArenaOutbound.withdraw(table:)`, `ArenaText.withdrawConfirm(table:)`.
  - From Task 3: `ArenaMyRequestsModel.tap(table:)`, `.beginWithdraw(table:)`, `.isRequested(_:)`, `.isAwaiting(_:)`.
  - From Task 4: `RoomViewController.arenaMyRequests`. Its `.myRequests` case already reloads the lobby.
- Produces: nothing new for other tasks.

- [ ] **Step 1: Remove the countdown properties**

Delete these two lines (lines 59-60):

```swift
    private var joinCountdownOverlay: UIView?
    private let joinCountdownDuration: CFTimeInterval = 6
```

- [ ] **Step 2: Show the "Requested" mark and the awaiting spinner in arena table cells**

In `tableView(_:cellForRowAt:)`, tables branch (lines 265-270), replace:

```swift
            if table.open {
                cell.accessoryView = nil
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.accessoryView = lockView
            }
```
with:
```swift
            if isArena && arenaMyRequests.isAwaiting(table.table) {
                let spinner = UIActivityIndicatorView(style: .medium)
                spinner.startAnimating()
                cell.accessoryView = spinner
            } else if isArena && arenaMyRequests.isRequested(table.table) {
                cell.accessoryView = arenaRequestedMark()
            } else if table.open {
                cell.accessoryView = nil
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.accessoryView = lockView
            }
```

- [ ] **Step 3: Replace the tap handler and the countdown with request/withdraw**

Replace `tableView(_:didSelectRowAt:)`, `showJoinCountdown()` and `hideJoinCountdown()` (lines 277-339; the block runs from `func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {` through the closing brace of `hideJoinCountdown`) with:

```swift
    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isArena {
            arenaTableTapped(tableId: displayedTableKeys[indexPath.row])
        } else if segmentControl.selectedSegmentIndex == 1 {
            let table = playersAndTables.tables[displayedTableKeys[indexPath.row]]!
            if table.open {
                let eventDictionary = ["dsgJoinTableEvent": ["table": table.table, "time": 0]]
                socket.sendEvent(eventDictionary: eventDictionary)
            }
        }
    }

    // Spec C3: an unmarked table sends one request (further taps wait for the server's
    // dsgArenaMyRequestsEvent); a marked table asks before withdrawing.
    private func arenaTableTapped(tableId: Int) {
        guard let table = playersAndTables.tables[tableId], table.open else { return }
        switch arenaMyRequests.tap(table: tableId) {
        case .ignore:
            return
        case .request:
            socket.sendEvent(eventDictionary: ArenaOutbound.requestJoin(table: tableId))
            tableView.reloadData()
        case .confirmWithdraw:
            confirmArenaWithdraw(tableId: tableId)
        }
    }

    private func confirmArenaWithdraw(tableId: Int) {
        // .alert needs no popover anchor, so it presents the same on iPhone and iPad.
        let alert = UIAlertController(title: nil, message: ArenaText.withdrawConfirm(table: tableId), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Withdraw", comment: "arena: withdraw a join request"), style: .destructive) { [weak self] _ in
            guard let self = self, self.arenaMyRequests.beginWithdraw(table: tableId) else { return }
            self.socket.sendEvent(eventDictionary: ArenaOutbound.withdraw(table: tableId))
            self.tableView.reloadData()
        })
        present(alert, animated: true)
    }

    private func arenaRequestedMark() -> UILabel {
        let mark = UILabel()
        mark.text = NSLocalizedString("Requested", comment: "arena lobby: you have a pending join request at this table")
        mark.font = UIFont.boldSystemFont(ofSize: 13)
        mark.textColor = .black
        mark.sizeToFit()
        return mark
    }
```

- [ ] **Step 4: Verify that the countdown is gone**

Run:
```bash
grep -rn "joinCountdown\|showJoinCountdown\|hideJoinCountdown\|CABasicAnimation(keyPath: \"strokeEnd\")" /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1/RoomViewController.swift
```
Expected: no output.

- [ ] **Step 5: Build for iPhone and iPad and run all unit tests**

Run:
```bash
xcodebuild test -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests 2>&1 | grep -E 'error:|Executed .* tests|TEST (SUCCEEDED|FAILED)' | tail -3
xcodebuild build -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)' SWIFT_ENABLE_EXPLICIT_MODULES=NO 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'
```
Expected: `** TEST SUCCEEDED **` with 0 failures, then `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS add test1/RoomViewController.swift
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS commit -S -m "Mark requested arena tables, add withdraw, and drop the join countdown"
```

---

### Task 6: Verification: full test suite, iPhone/iPad builds, E2E on the local stack

**Files:** none changed. One temporary edit, `test1/PentePlayer.h:17`, is reverted in Step 9.

**Prerequisites:**
- The pente.org server plan for this spec is implemented and running on the local stack. Run `./justCompile` in `pente.org/`; it compiles and restarts the container. The local stack is the isolated development backend.
- The React live room plan is implemented, for the two React instances.

- [ ] **Step 1: Run the full unit test suite**

Run:
```bash
mkdir -p /private/tmp/claude-501/arena-ios
xcodebuild test -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO > /private/tmp/claude-501/arena-ios/full-test.log 2>&1; grep -E 'error:|Executed .* tests|TEST (SUCCEEDED|FAILED)' /private/tmp/claude-501/arena-ios/full-test.log | tail -3
```
Expected: the last `Executed N tests, with 0 failures` (N includes the 37 new arena tests: 15 wire, 16 list model, 6 lobby model) and `** TEST SUCCEEDED **`. Record N and the success line as evidence.

- [ ] **Step 2: Build for both form factors**

Run:
```bash
for dest in 'iPhone 18 Pro' 'iPad Pro 13-inch (M5)'; do xcodebuild build -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -sdk iphonesimulator -destination "platform=iOS Simulator,name=$dest" SWIFT_ENABLE_EXPLICIT_MODULES=NO 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'; done
```
Expected: `** BUILD SUCCEEDED **` twice.

- [ ] **Step 3: Static checks against the spec**

Run:
```bash
grep -rn "DSGArena\|joinTimeout\|joinCountdown\|expiryTimers" /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1 ; grep -rn '"dsgArena' /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/test1 | grep -v ArenaWire.swift
```
Expected:
- The first grep prints nothing.
- The second greps quoted string literals only; doc comments that name keys have no leading quote. It prints only `ArenaTableSetupView.swift` (`"dsgArenaCreateTableEvent"`, unchanged). Every other arena wire key lives in `ArenaWire.swift`.

- [ ] **Step 4: Point the app at the local backend (temporary, never committed)**

In `$IOS/test1/PentePlayer.h:17` change `#define development NO` to `#define development YES`. Then confirm it is the only diff:
```bash
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS status --porcelain
```
Expected: ` M test1/PentePlayer.h` only.

- [ ] **Step 5: Build, install and launch on the iPhone simulator**

Run:
```bash
xcodebuild build -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /private/tmp/claude-501/arena-ios/dd SWIFT_ENABLE_EXPLICIT_MODULES=NO 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'
xcrun simctl boot 'iPhone 18 Pro' 2>/dev/null; xcrun simctl bootstatus 'iPhone 18 Pro' -b
xcrun simctl install 'iPhone 18 Pro' /private/tmp/claude-501/arena-ios/dd/Build/Products/Debug-iphonesimulator/penteLive.app
xcrun simctl launch 'iPhone 18 Pro' be.submanifold.penteLive
```
Log in as `iostest`. The credentials are in `pente-react-native/.env.local`; never print or commit them. Open the Arena room.

Set up two React live room instances, React A and React B. Follow the react-live-e2e-setup recipe: comment out the `connectSocket` 'pente.org' host override locally and never commit it. Each instance needs its own env credentials: `graviton` for A, and another local account for B. If no third account exists, ask the user for one.

Take a simulator screenshot for each scenario (`xcrun simctl io 'iPhone 18 Pro' screenshot /private/tmp/claude-501/arena-ios/<name>.png`), look at it, and record the observed result next to the expected one.

- [ ] **Step 6: Run the spec E2E scenarios that iOS takes part in**

Each scenario lists the iOS role and the expected iOS behaviour.

- **E1, request → decline → re-request refused (iOS requester, A owner).**
  - Tap A's table. A spinner appears in the row, then "Requested".
  - A declines. A banner reads "graviton declined your request" and the mark disappears.
  - Tap the table again. A banner reads "You can't request table <n> again until its next game", and no mark appears.
- **E2, decline from iOS (iOS owner, A requester).** This pins the decline fix in C2/C5.
  - A requests iOS's table. The popover appears with A's row and the new-player sound plays.
  - Swipe A's row and tap Reject. The row shows a spinner, the list dims with a spinner for about 400 ms, the row disappears and the popover hides.
  - iOS stays connected and stays at its table. Before this change the owner was disconnected.
- **E3, withdraw → re-request refused (iOS requester).**
  - Tap A's table to get "Requested", then tap it again. An alert reads exactly "Withdraw your request to table <n>? You won't be able to request it again until its next game."
  - Cancel. The mark stays.
  - Tap again and choose Withdraw. The mark disappears and A's list loses iOS.
  - Tap again. The BLOCKED banner appears.
- **E4, accept → other requests cancelled, other requesters see TABLE_FULL.**
  - iOS as owner: A then B request. Rows are in request order, A first.
    - Tap A. A's row shows a spinner and the list ignores taps.
    - A joins and the popover hides. B sees "Table <n> is no longer available".
  - iOS as requester: iOS requests A's table and B's table, and both are marked.
    - A accepts. iOS is seated at A's table.
    - B's list drops iOS silently, and iOS shows no banner about B.
- **E5, game ends, table open → a previously blocked player can request.** After a decline (E1) on an owner's table, play that table's game to the end and have the second player leave. The blocked player (iOS or A) can now request successfully.
- **E6, table close (iOS requester).** iOS requests A's table, then A exits. A banner reads "Table <n> was closed" and the mark disappears.
- **E7, owner leaves a finished 2-player table (iOS joiner).**
  - A owns the table. iOS is accepted, and the game finishes.
  - A leaves. iOS becomes owner, gets an empty snapshot, and no popover shows.
  - B, previously declined by A, requests. The popover appears on iOS with B.
- **E8, a waiting set is cancelled or force-resigned (iOS owner).**
  - During a game with A, A disconnects, so the table waits for the player to return.
  - iOS cancels the set or force-resigns. The table reopens with its memory wiped.
  - B, previously blocked, can request, and the row appears on iOS.
- **E9, requester disconnect.**
  - iOS as owner with A's row showing: close A's tab. The row disappears after the freeze and the popover hides.
  - iOS as requester: request A's table, then terminate the app (`xcrun simctl terminate 'iPhone 18 Pro' be.submanifold.penteLive`). A's list drops iOS.
- **E10, owner exits right after accept (iOS requester).**
  - iOS requests A's table. A accepts and immediately exits.
  - iOS shows "Table <n> was closed", is not seated, and does not crash.
- **E11, freeze under a burst (iOS owner).**
  - A and B request and withdraw as fast as they can.
  - The list dims with a spinner for about 400 ms at a time, and stays tappable for at least about 1 s between dims.
  - A tap while dimmed does nothing: no accept is sent and A/B stay unseated.
- **E14, request lands while the popover is still animating out (iOS owner, Review Focus 3).** An owner sitting alone has no other sheet to open: `showOptions()` presents only in a started game where iOS is seated (`TableViewController.swift:473`), and arena tables have no other bar items. The reachable blocker is the popover's own dismissal animation.
  - A requests, so the popover shows A. A withdraws; B requests about 0.5 s after A's withdraw (the list hides about 400 ms after the withdraw, and the dismissal animation runs about 0.3 s after that). Repeat up to five times; exact timing is not needed to check the invariant.
  - Every time, once things settle, the popover is up and shows B, with no further snapshot needed. It must never stay hidden while B's request is pending. Record whether any attempt visibly re-presented after a short gap (the 0.5 s retry); if none did, note that the retry path was not hit end to end and rests on `testPopoverWaitsUntilPresentingIsPossible`.
  - Then B withdraws: the popover hides.

- [ ] **Step 7: iPad pass (Review Focus 5)**

Repeat Step 5's install and launch on the `iPad Pro 13-inch (M5)` simulator, using the same derived data. Then repeat E2, E3 and E4 (owner variant) there.

- **Popover.** It is at most 420 pt (points) wide, anchored at the board's top-right. The freeze overlay covers exactly the list. The Exit Table button sits at the bottom.
- **Rotation.** With the popover open and with the withdraw alert open, rotate the simulator (`xcrun simctl io` cannot rotate; use the Simulator's Device → Rotate). The list, overlay and button stay laid out, the popover arrow stays at the board's top-right in both orientations, and the alert stays centred.
- **Owner notice (best effort, iPhone and iPad).** `NO_LONGER_AVAILABLE` needs a race (R5/R6): B owns a table, A requests both B's table and iOS's table, and iOS taps A at the same moment B accepts A. Try a few times. When it fires, the banner "<A> is no longer available" shows at the bottom of the screen, clear of the popover. If the race cannot be hit, record that this check did not run.

- [ ] **Step 8: Record evidence**

For every scenario, note in the task report:
- pass or fail;
- the screenshot path under `/private/tmp/claude-501/arena-ios/`;
- any mismatch, with the exact observed text.

A failure is reported as a failure with its evidence. Do not work around it.

- [ ] **Step 9: Revert the development flag and leave the repo clean**

Run:
```bash
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS checkout -- test1/PentePlayer.h
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS status --porcelain
```
Expected: no output. If the React `connectSocket` override was commented out for E2E, restore it in `react_live_game_room` the same way. Scratch stays under `/private/tmp/claude-501/arena-ios/`. Nothing is committed in this task.
