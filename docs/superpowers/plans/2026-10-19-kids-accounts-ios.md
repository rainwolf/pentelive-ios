# Kids Accounts (iOS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a parent create and manage kid accounts from native iOS screens (Settings > More > "Kid accounts"), and give a kid login the kid-mode UI: `Kid accounts` row hidden (the blocked-players row and block buttons stay), composer suggests only the parent and approved players, refusal strings shown, broadcast hidden, and in the native live room a chat hint, no invite text fields and no empty invite quote.

**Architecture:** Two pure Swift files carry all logic and are unit-tested in the hosted `PenteEngineTests` target:
- `KidAccounts.swift` decodes `/gameServer/kids` replies into `KidAccountsState`, builds the POST parameters for each action (`KidAction`), and derives the kid's allowed recipients.
- `KidMode.swift` holds the kid-mode decisions the UI asks for: kid flag from the live login echo, refusal-string matching, invite alert text, Settings hidden keys, and the hint texts.

`KidAccountsService` (network, modelled on `BlockedPlayersService`) and two `UITableViewController`s (`KidAccountsViewController`, `KidDetailViewController`, modelled on `BlockedPlayersViewController`) are thin. The dashboard flag flows `WirePlayer.parentPid` → `DashboardFlags.isKid` → `PentePlayer.isKid` (set in `applyDashboard`). The live room reads kid status only from its own `dsgLoginEvent.me.parentPid`.

**Tech Stack:** Swift 5 / UIKit + Objective-C, InAppSettingsKit (IASK) plists, XCTest (hosted target `PenteEngineTests`, `@testable import penteLive`), CocoaPods workspace `penteLive.xcworkspace`, scheme `test1`, `xcodeproj` Ruby gem via `Scripts/add_swift_file.rb`.

**Spec:** `/Users/waliedothman/mariposa/coding/pente.org-project/pente.org/docs/superpowers/specs/2026-10-19-kids-accounts-design.md`. Read it first. This plan covers only the iOS bullets of its "Clients" section and Goal 6 for iOS.

**Server contract:** the "Server API contract" section of `/Users/waliedothman/mariposa/coding/pente.org-project/pente.org/docs/superpowers/plans/2026-10-19-kids-accounts-server.md`. Every endpoint, field and error string below is copied from it. Do not assume anything beyond that section.

**Repo:** `/Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS` (abbreviated `$IOS` below; always expand it to the absolute path in commands). Work on the already-created branch `kids-accounts`. Line numbers are from `main` @ `63ba07b`. Earlier tasks shift lines in shared files, so match edits by the quoted code, not by the number alone.

## Global Constraints

- Kid flag: a player is a kid exactly when `parentPid` is present (non-null) in the logged-in player's own data. A missing field means "not a kid" (old servers never send it). Never read it from `dsgJoinMainRoomEvent` or `dsgUpdatePlayerDataEvent` player data.
  - Dashboard: top-level `"player": {"parentPid": <number>, ...}` of `GET /gameServer/mobile/json/index.jsp`.
  - Live room: `{"dsgLoginEvent": {"me": {"parentPid": <number>, ...}}}`.
- Endpoint `/gameServer/kids`. Auth params `name2` + `password2` from `NSUserDefaults` keys `username` / `password` (same as `BlockedPlayersService`). GET returns the caller's view. POST is form-encoded with `action=` one of `create`, `convert`, `password`, `whitelistAdd`, `whitelistRemove`, `settings`, `release`, with params exactly:
  - `create`: `kidName`, `kidPassword`; `convert`: `kidName`; `password`: `kidPid`, `kidPassword`; `whitelistAdd`: `kidPid`, `playerName`; `whitelistRemove`: `kidPid`, `playerPid`; `settings`: `kidPid`, optional `copyMessages`, optional `copyLiveChat` (`Y`/`N`); `release`: `kidPid`.
- Reply fields: `success`, `isKid`, `emailVerified`, `parentName` (kid only), `whitelist` (kid only, `[{pid, name, nameColor, tourneyWinner}]`), `kids` (`[{kidPid, name, copyMessages, copyLiveChat, whitelist}]`), `message` (convert only), `error` (failure). Any non-JSON body or `"success": false` is a failure; show the server's `error` string verbatim when present.
  - No credentials at all: HTTP 401 with JSON `{"success":false,"error":"Login required"}` (so the client shows `Login required`). Wrong `name2`/`password2`: the HTML login page with status 200 (no `error`; the client shows `Please try again.`). Read the body whatever the status code.
  - The `Request origin not allowed` (403) check applies only to cookie/session POSTs; app POSTs send `name2`/`password2` and are not checked.
  - `convert`: success carries `"message": "Confirmation email sent to <name>"`. When the target is already a kid, has kids or is an admin, the server returns the **same** success body and does nothing (neutral, kid status stays private); the client shows `message` the same way in every case. `That account can't become a kid account` now only comes for computer accounts.
  - `create`: the kid's email is the parent's, stored as not verified (no client effect).
- Refusal strings matched verbatim:
  - `/gameServer/mymessages` create: `You can only send messages to players your parent approved.` and `Player is ignoring your messages.`
  - `/gameServer/broadcast`: `Kid accounts can't broadcast.`
  - Composer (contract): a kid's new-message composer limits only its suggestions/autocomplete to `parentName` plus the `whitelist` names. It never blocks a send on the client; whatever the kid types is sent and the server's refusal string is shown as-is.
- Live room: no new events. `dsgInviteTableEvent.inviteText` and `dsgInviteResponseTableEvent.responseText` can arrive as `""`; render no message line for an empty text.
- Turn-based open invitations: for a kid viewer whose inviter is not allowed, the server itself omits the inviter's text on `/gameServer/tb/replyInvitation` (`mobile=`) and the TB game pages (`mobile/json/game.jsp`). The app needs no code change; it must simply render a missing text as no message. Checked in E2E K9.
- iOS kid-mode texts (verbatim, this plan's choice):
  - Chat hint (lobby and table input placeholder): `Only approved players see your messages`
  - Composer recipient placeholder: `Approved players only`
  - Live-chat copy footer (the website's string, so parents read the same caveat everywhere): `Live chat copies are best effort: if the server's chat buffer is unavailable, that session isn't copied.`
  - Kid's own view of the Kid accounts screen: `Your account is managed by your parent, <parentName>.` (the website's wording).
- Logged-out users never see the `kidAccountsButton` row. Kids do not see it once the dashboard has loaded (`PentePlayer.isKid` is set in `applyDashboard`); before that, or with a stale flag after a conversion, the row can show, and `KidAccountsViewController` then handles the kid reply itself (Task 4) and sets `PentePlayer.isKid`. Kids keep the `blockedPlayersButton` row and every block button (blocking only restricts further).
- Socket callbacks (`PenteLiveSocket.processEvent`) run on the background queue `penteLiveDelegateQueue`. All UI and controller state changes run on main.
- All UI must work on iPhone and iPad, including rotation (`$IOS/CLAUDE.md`). Alerts use `.alert` style (no popover anchor needed).
- Build only through the workspace: `-workspace $IOS/penteLive.xcworkspace -scheme test1`, never the `.xcodeproj`.
- Canonical unit test command:
  `xcodebuild test -workspace $IOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests/<TestClass> 2>&1 | grep -E 'error:|Executed|TEST (SUCCEEDED|FAILED)'`
- Canonical build command (both form factors):
  `for dest in 'iPhone 18 Pro' 'iPad Pro 13-inch (M5)'; do xcodebuild build -workspace $IOS/penteLive.xcworkspace -scheme test1 -sdk iphonesimulator -destination "platform=iOS Simulator,name=$dest" SWIFT_ENABLE_EXPLICIT_MODULES=NO 2>&1 | grep -E 'error:|BUILD (SUCCEEDED|FAILED)'; done`
- Add new files to targets with `Scripts/add_swift_file.rb`, run from `$IOS`. New app files go flat in `test1/` (group `test1`), tests in `PenteEngineTests/`:
  `cd $IOS && ruby Scripts/add_swift_file.rb test1/X.swift penteLive test1`
  `cd $IOS && ruby Scripts/add_swift_file.rb PenteEngineTests/XTests.swift PenteEngineTests PenteEngineTests`
  Expected output: `added X.swift to <target> via group … (new)` (ignore the "Ignoring … extensions are not built" gem warnings).
- Formatting: run `swiftformat <file>` (reads `$IOS/.swiftformat`) only on files this plan creates. Never on existing files; hand-match their style.
- Commits: `git -C $IOS add <files>` then `git -C $IOS commit -S -m "<message>"`. No co-author, "generated by" or similar trailer lines. Never commit the `development` flag flip used in E2E.
- Scratch output (derived data, logs, screenshots) goes under `/private/tmp/claude-501/kids-ios/`, never inside the repo.

## Review Focus

1. **Odd `parentPid` shapes on the dashboard.** A string, `null` or object `parentPid` must never make the whole dashboard fail to decode (that would blank the games list for every user). Pinned in Task 1 by `testParentPidOfAnyShapeNeverBreaksDecoding` and `testNullParentPidIsNotKid`.
2. **Malformed or partial `/gameServer/kids` replies.** The HTML login page, `success:false`, a kid entry missing `kidPid`, a whitelist entry missing `pid`, missing `whitelist` / `kids`. Bad entries are skipped, the reply is never a crash. Pinned in Task 2 by `testParseHtmlLoginPageIsNil`, `testParseFailureIsNilAndErrorIsRead`, `testParseSkipsMalformedEntries`, `testParseMissingListsAreEmpty`.
3. **A kid who must still reach the parent or an admin.** The composer only suggests names; it never blocks a typed name client-side, so a reply to an admin message, the `needHelp` "rainwolf" message or a message to the parent still sends; the server decides. Pinned in Task 2 by `testAllowedRecipientsIncludesParentAndDedupes` and Task 6 Step 1 (no client-side block, reviewed in the diff) and E2E K5.
4. **The live login echo arriving on the socket queue.** `isKid` and the placeholder are set only inside `DispatchQueue.main.async`; a `me` without `parentPid`, with `NSNull`, or no `me` at all means not a kid. Pinned in Task 3 by `testIsKidFromLoginEvent` and in Task 7 Step 2.
5. **iPad layout and rotation of the kid screens and alerts.** Insetgrouped tables pushed on the Settings navigation stack, `.alert` style dialogs with text fields, switches in rows. Pinned in Task 8 Step 6 (iPad pass, both orientations).
6. **The `Player is ignoring your messages.` alert changes behaviour for non-kids too.** Today that body is treated as success (composer pops, message silently lost, `MessagesViewController.m:667-703`). After Task 6 every blocked sender, kid or not, sees `Message not sent` and keeps the text. Intended (a non-kid writing to a kid gets this string), but it is user-visible for everyone. Pinned in Task 6 Step 2 and its commit message, and `testMessageSendError` in Task 3.
7. **A kid reaching the Kid accounts screen before the dashboard flag is set.** `isKid` is set only in `applyDashboard` (`GamesTableViewController.m:3459`); `PentePlayer` starts at NO. The screen must show the managed-by-parent text, no add button, and set the flag. Pinned in Task 4 Step 2 (kid state) and E2E K4.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `test1/Dashboard/DashboardWire.swift` | Modify (20-29) | `WirePlayer.parentPid` (lenient) |
| `test1/Dashboard/Dashboard.swift` | Modify (3-29) | `DashboardFlags.isKid` |
| `test1/Dashboard/DashboardMapping.swift` | Modify (139-149) | map `parentPid` → `isKid` |
| `test1/PentePlayer.h` | Modify (~115) | `@property(atomic, assign) BOOL isKid;` |
| `test1/GamesTableViewController.m` | Modify (3463-3470) | copy `flags.isKid` onto `self.player` |
| `test1/KidAccounts.swift` | Create | `KidPlayer`, `KidAccount`, `KidAccountsState`, `KidAction`, `KidAccounts` (parse, parseError, kid(_:in:), allowedRecipients) |
| `test1/KidMode.swift` | Create | `KidMode` (texts, `isKid(loginEvent:)`, `messageSendError`, `isBroadcastRefused`, `inviteAlertMessage`, `settingsHiddenKeys`) |
| `test1/KidAccountsService.swift` | Create | GET/POST `/gameServer/kids`, `allowedRecipients` for the composer |
| `test1/KidAccountsViewController.swift` | Create | Parent's kid list, create, convert |
| `test1/KidDetailViewController.swift` | Create | One kid: approved players, copy toggles, password, release |
| `test1/Settings.bundle/MoreSettings.plist` | Modify (after 140-148) | `kidAccountsButton` row |
| `test1/SettingsViewController.m` | Modify (218-235, 270-275) | hidden keys via `KidMode`, push `KidAccountsViewController` |
| `test1/MessagesViewController.m` | Modify (120-122 area, 652-681) | kid composer suggestions + hint, refusal strings |
| `test1/LobbyViewController.swift` | Modify (38-39, 189-199) | hide broadcast for kids, match refusal |
| `test1/RoomViewController.swift` | Modify (39-60, 356-367, 538-590, 637) | `isKid` from login echo, hint, invite alert text/reply field |
| `test1/TableViewController.swift` | Modify (65-98, 581-610) | `isKid` init param, hint, no invite message field |
| `PenteEngineTests/DashboardMappingTests.swift` | Modify | kid flag tests |
| `PenteEngineTests/KidAccountsTests.swift` | Create | parse/actions/recipients tests |
| `PenteEngineTests/KidModeTests.swift` | Create | kid-mode helper tests |
| `penteLive.xcodeproj/project.pbxproj` | Modify (script only) | target membership for the 7 new files |

---

### Task 1: Kid flag from the dashboard

**Files:**
- Modify: `$IOS/test1/Dashboard/DashboardWire.swift:20-29`
- Modify: `$IOS/test1/Dashboard/Dashboard.swift:3-29`
- Modify: `$IOS/test1/Dashboard/DashboardMapping.swift:139-149`
- Modify: `$IOS/test1/PentePlayer.h` (property list ~L115)
- Modify: `$IOS/test1/GamesTableViewController.m:3463-3470` (`applyDashboard:wantsAvatars:`)
- Test: `$IOS/PenteEngineTests/DashboardMappingTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces (used by Tasks 4, 6):
  - `WirePlayer.parentPid: FlexibleString?` (lenient: any scalar decodes; null is nil; object/array collapses to `""`).
  - `DashboardFlags.isKid: Bool` (`@objc let`), new init parameter `isKid: Bool = false` placed last, so the existing `DashboardResultTests` call compiles unchanged.
  - `PentePlayer.isKid` (`@property(atomic, assign) BOOL isKid;`), visible to Swift as `isKid`.

- [ ] **Step 1: Write the failing tests**

Append to `DashboardMappingTests`:

```swift
    private func flags(_ playerJSON: String) throws -> DashboardFlags {
        let json = #"{"player":"# + playerJSON + "}"
        return DashboardMapping.map(try JSONDecoder().decode(WireDashboard.self, from: Data(json.utf8))).flags
    }

    func testSampleWithoutParentPidIsNotKid() throws {
        XCTAssertFalse(try loadDashboard().flags.isKid)
    }

    func testParentPidMakesKid() throws {
        XCTAssertTrue(try flags(#"{"name":"kid_one","parentPid":23000000012345}"#).isKid)
    }

    func testNullParentPidIsNotKid() throws {
        XCTAssertFalse(try flags(#"{"name":"bob","parentPid":null}"#).isKid)
    }

    func testParentPidOfAnyShapeNeverBreaksDecoding() throws {
        XCTAssertTrue(try flags(#"{"name":"kid_one","parentPid":"23000000012345"}"#).isKid)
        let f = try flags(#"{"name":"bob","parentPid":{"x":1}}"#)
        XCTAssertFalse(f.isKid)
        XCTAssertEqual(f.playerName, "bob")
    }
```

- [ ] **Step 2: Run the tests and see them fail**

Run the canonical test command with `-only-testing:PenteEngineTests/DashboardMappingTests`.
Expected: `error:` lines — `value of type 'DashboardFlags' has no member 'isKid'`.

- [ ] **Step 3: Implement**
  - `WirePlayer`: add `let parentPid: FlexibleString?`.
  - `DashboardFlags`: add `@objc let isKid: Bool` and the trailing `isKid: Bool = false` init parameter.
  - `DashboardMapping.map`: pass `isKid: !(p?.parentPid?.value ?? "").isEmpty`.
  - `PentePlayer.h`: add `@property(atomic, assign) BOOL isKid;` next to `dbAccess, emailMe, personalizeAds` (auto-synthesized, default `NO`).
  - `applyDashboard:` after `[self.player setEmailMe:flags.emailMe];` add `[self.player setIsKid:flags.isKid];`. This runs after every login, so switching accounts resets it.

- [ ] **Step 4: Run the tests and see them pass**

Run the canonical test command with `-only-testing:PenteEngineTests/DashboardMappingTests -only-testing:PenteEngineTests/DashboardResultTests -only-testing:PenteEngineTests/DashboardRealPayloadTests`.
Expected: `** TEST SUCCEEDED **`, 0 failures.

- [ ] **Step 5: Commit**

```bash
git -C $IOS add test1/Dashboard/DashboardWire.swift test1/Dashboard/Dashboard.swift test1/Dashboard/DashboardMapping.swift test1/PentePlayer.h test1/GamesTableViewController.m PenteEngineTests/DashboardMappingTests.swift
git -C $IOS commit -S -m "Kid accounts: read the kid flag (parentPid) from the dashboard"
```

---

### Task 2: Kid accounts model (parse, actions, allowed recipients)

**Files:**
- Create: `$IOS/test1/KidAccounts.swift`
- Create: `$IOS/PenteEngineTests/KidAccountsTests.swift`
- Modify: `$IOS/penteLive.xcodeproj/project.pbxproj` (script only)

**Interfaces:**
- Consumes: `DashboardMapping.uiColor(fromRGB:)`, `Message.attributedName()` (for `styledName`, same as `IgnoreEntry.styledName` in `test1/BlockedPlayers/BlockedPlayers.swift:40-46`).
- Produces (used by Tasks 4, 5, 6):
  - `struct KidPlayer: Decodable, Equatable { let pid: Int64; let name: String; let nameColor: Int; let tourneyWinner: Int; init(pid: Int64, name: String, nameColor: Int = 0, tourneyWinner: Int = 0); var styledName: NSAttributedString }` — `nameColor`/`tourneyWinner` default 0 when absent.
  - `struct KidAccount: Decodable, Equatable { let kidPid: Int64; let name: String; let copyMessages: Bool; let copyLiveChat: Bool; let whitelist: [KidPlayer] }` — `copyMessages`/`copyLiveChat` default false, `whitelist` default `[]`, malformed whitelist entries skipped. Declare `init(kidPid:name:copyMessages:copyLiveChat:whitelist:)` explicitly (the tests use it, and a custom `init(from:)` in the struct body hides the memberwise one).
  - `struct KidAccountsState: Equatable { let isKid: Bool; let emailVerified: Bool; let parentName: String?; let whitelist: [KidPlayer]; let kids: [KidAccount]; let message: String? }`
  - `enum KidAction: Equatable { case create(name: String, password: String); case convert(name: String); case password(kidPid: Int64, password: String); case whitelistAdd(kidPid: Int64, playerName: String); case whitelistRemove(kidPid: Int64, playerPid: Int64); case settings(kidPid: Int64, copyMessages: Bool?, copyLiveChat: Bool?); case release(kidPid: Int64); var params: [(String, String)] }`
  - `enum KidAccounts { static func parse(_ data: Data?) -> KidAccountsState?; static func parseError(_ data: Data?) -> String?; static func kid(_ pid: Int64, in state: KidAccountsState) -> KidAccount?; static func allowedRecipients(_ state: KidAccountsState) -> [String] }`

- [ ] **Step 1: Write the failing tests**

Create `$IOS/PenteEngineTests/KidAccountsTests.swift`:

```swift
import XCTest
@testable import penteLive

final class KidAccountsTests: XCTestCase {
    private func parse(_ json: String) -> KidAccountsState? { KidAccounts.parse(Data(json.utf8)) }

    func testParseParentView() {
        let s = parse(#"{"success":true,"isKid":false,"emailVerified":true,"kids":[{"kidPid":23000000012345,"name":"kid_one","copyMessages":true,"copyLiveChat":false,"whitelist":[{"pid":777,"name":"graviton","nameColor":16711680,"tourneyWinner":2}]}]}"#)
        XCTAssertEqual(s?.isKid, false)
        XCTAssertEqual(s?.emailVerified, true)
        XCTAssertEqual(s?.kids, [KidAccount(kidPid: 23000000012345, name: "kid_one", copyMessages: true, copyLiveChat: false,
                                            whitelist: [KidPlayer(pid: 777, name: "graviton", nameColor: 16711680, tourneyWinner: 2)])])
        XCTAssertNil(s?.parentName)
        XCTAssertNil(s?.message)
    }

    func testParseKidView() {
        let s = parse(#"{"success":true,"isKid":true,"emailVerified":true,"parentName":"iostest","whitelist":[{"pid":777,"name":"graviton","nameColor":0,"tourneyWinner":0}],"kids":[]}"#)
        XCTAssertEqual(s?.isKid, true)
        XCTAssertEqual(s?.parentName, "iostest")
        XCTAssertEqual(s?.whitelist, [KidPlayer(pid: 777, name: "graviton")])
        XCTAssertEqual(s?.kids, [])
    }

    func testParseConvertMessage() {
        XCTAssertEqual(parse(#"{"success":true,"isKid":false,"emailVerified":true,"kids":[],"message":"Confirmation email sent to bob"}"#)?.message,
                       "Confirmation email sent to bob")
    }

    func testParseHtmlLoginPageIsNil() {
        XCTAssertNil(KidAccounts.parse(Data("<html>login</html>".utf8)))
        XCTAssertNil(KidAccounts.parse(nil))
        XCTAssertNil(KidAccounts.parseError(Data("<html>login</html>".utf8)))
    }

    func testParseFailureIsNilAndErrorIsRead() {
        let data = Data(#"{"success":false,"error":"Kid not found"}"#.utf8)
        XCTAssertNil(KidAccounts.parse(data))
        XCTAssertEqual(KidAccounts.parseError(data), "Kid not found")
        // 401 body when no credentials reached the server.
        XCTAssertEqual(KidAccounts.parseError(Data(#"{"success":false,"error":"Login required"}"#.utf8)), "Login required")
    }

    func testParseSkipsMalformedEntries() {
        let s = parse(#"{"success":true,"isKid":false,"emailVerified":true,"kids":[{"name":"no_pid"},{"kidPid":5,"name":"ok","whitelist":[{"name":"no_pid"},{"pid":9,"name":"amy"}]}]}"#)
        XCTAssertEqual(s?.kids, [KidAccount(kidPid: 5, name: "ok", copyMessages: false, copyLiveChat: false,
                                            whitelist: [KidPlayer(pid: 9, name: "amy")])])
    }

    func testParseMissingListsAreEmpty() {
        let s = parse(#"{"success":true}"#)
        XCTAssertEqual(s, KidAccountsState(isKid: false, emailVerified: false, parentName: nil, whitelist: [], kids: [], message: nil))
    }

    func testActionParams() {
        func p(_ a: KidAction) -> [String] { a.params.map { "\($0.0)=\($0.1)" } }
        XCTAssertEqual(p(.create(name: "kid", password: "pw123")), ["action=create", "kidName=kid", "kidPassword=pw123"])
        XCTAssertEqual(p(.convert(name: "bob")), ["action=convert", "kidName=bob"])
        XCTAssertEqual(p(.password(kidPid: 5, password: "pw123")), ["action=password", "kidPid=5", "kidPassword=pw123"])
        XCTAssertEqual(p(.whitelistAdd(kidPid: 5, playerName: "graviton")), ["action=whitelistAdd", "kidPid=5", "playerName=graviton"])
        XCTAssertEqual(p(.whitelistRemove(kidPid: 5, playerPid: 777)), ["action=whitelistRemove", "kidPid=5", "playerPid=777"])
        XCTAssertEqual(p(.settings(kidPid: 5, copyMessages: true, copyLiveChat: nil)), ["action=settings", "kidPid=5", "copyMessages=Y"])
        XCTAssertEqual(p(.settings(kidPid: 5, copyMessages: nil, copyLiveChat: false)), ["action=settings", "kidPid=5", "copyLiveChat=N"])
        XCTAssertEqual(p(.release(kidPid: 5)), ["action=release", "kidPid=5"])
    }

    func testKidLookup() {
        let k = KidAccount(kidPid: 5, name: "ok", copyMessages: false, copyLiveChat: false, whitelist: [])
        let s = KidAccountsState(isKid: false, emailVerified: true, parentName: nil, whitelist: [], kids: [k], message: nil)
        XCTAssertEqual(KidAccounts.kid(5, in: s), k)
        XCTAssertNil(KidAccounts.kid(6, in: s))
    }

    func testAllowedRecipientsIncludesParentAndDedupes() {
        let s = KidAccountsState(isKid: true, emailVerified: true, parentName: "iostest",
                                 whitelist: [KidPlayer(pid: 1, name: "Zed"), KidPlayer(pid: 2, name: "amy"), KidPlayer(pid: 3, name: "IOSTEST")],
                                 kids: [], message: nil)
        XCTAssertEqual(KidAccounts.allowedRecipients(s), ["amy", "IOSTEST", "Zed"])
    }

    func testAllowedRecipientsEmptyForNonKid() {
        let s = KidAccountsState(isKid: false, emailVerified: true, parentName: nil, whitelist: [], kids: [], message: nil)
        XCTAssertEqual(KidAccounts.allowedRecipients(s), [])
    }
}
```

Register both files:
```bash
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && touch test1/KidAccounts.swift && ruby Scripts/add_swift_file.rb test1/KidAccounts.swift penteLive test1 && ruby Scripts/add_swift_file.rb PenteEngineTests/KidAccountsTests.swift PenteEngineTests PenteEngineTests
```

- [ ] **Step 2: Run the tests and see them fail**

Run the canonical test command with `-only-testing:PenteEngineTests/KidAccountsTests`.
Expected: `error:` lines — `cannot find 'KidAccounts' in scope`.

- [ ] **Step 3: Implement `KidAccounts.swift`**
  - `parse`: decode a private `Reply` (`success`, `isKid`, `emailVerified`, `parentName`, `whitelist`, `kids`, `message`, `error`, all optional); return nil unless `success == true`; missing bools are false, missing lists empty, empty `parentName`/`message` become nil.
  - Skip malformed array entries with a private lossy wrapper (`struct Lossy<T: Decodable>: Decodable { let value: T? }` whose `init(from:)` uses `try? T(from: decoder)`), then `compactMap`.
  - `parseError`: the reply's non-empty `error`, else nil (same as `BlockedPlayers.parseError`).
  - `params`: first pair is always `("action", <case name>)`; pids via `String(Int64)`; settings flags `Y`/`N`, omitted when nil; order exactly as in the test.
  - `allowedRecipients`: empty unless `isKid`; whitelist names plus `parentName`, deduplicated case-insensitively (first spelling wins, whitelist before parent), sorted with `localizedCaseInsensitiveCompare`.
  - `styledName`: same body as `IgnoreEntry.styledName`.
  - Run `swiftformat test1/KidAccounts.swift PenteEngineTests/KidAccountsTests.swift`.

- [ ] **Step 4: Run the tests and see them pass**

Run the canonical test command with `-only-testing:PenteEngineTests/KidAccountsTests`.
Expected: `Executed 11 tests, with 0 failures` and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git -C $IOS add test1/KidAccounts.swift PenteEngineTests/KidAccountsTests.swift penteLive.xcodeproj/project.pbxproj
git -C $IOS commit -S -m "Kid accounts: model for /gameServer/kids replies and actions"
```

---

### Task 3: Kid-mode helpers

**Files:**
- Create: `$IOS/test1/KidMode.swift`
- Create: `$IOS/PenteEngineTests/KidModeTests.swift`
- Modify: `$IOS/penteLive.xcodeproj/project.pbxproj` (script only)

**Interfaces:**
- Consumes: nothing.
- Produces (used by Tasks 4, 6, 7):
  - `@objc final class KidMode: NSObject` with:
    - `@objc static let chatHint = "Only approved players see your messages"`
    - `@objc static let composerHint = "Approved players only"`
    - `@objc static let liveChatCopyNote = "Live chat copies are best effort: if the server's chat buffer is unavailable, that session isn't copied."` (the website's exact string)
    - `static let broadcastRefusedText = "Kid accounts can't broadcast."`
    - `static func managedByParentText(_ parentName: String?) -> String` (`"Your account is managed by your parent, <parentName>."`; `"Your account is managed by your parent."` when the name is nil or empty)
    - `static func approvedCountText(_ count: Int) -> String` (`"1 approved player"`, otherwise `"<n> approved players"`)
    - `static func isKid(loginEvent: [String: Any]) -> Bool`
    - `@objc static func messageSendError(_ body: String?) -> String?`
    - `static func isBroadcastRefused(_ body: String) -> Bool`
    - `static func inviteAlertMessage(_ inviteText: String) -> String?`
    - `@objc static func settingsHiddenKeys(loggedIn: Bool, subscriber: Bool, isKid: Bool) -> Set<String>` (ObjC: `settingsHiddenKeysWithLoggedIn:subscriber:isKid:` returning `NSSet<NSString *> *`)

- [ ] **Step 1: Write the failing tests**

Create `$IOS/PenteEngineTests/KidModeTests.swift`:

```swift
import XCTest
@testable import penteLive

final class KidModeTests: XCTestCase {
    private func login(_ json: String) -> [String: Any] {
        let object = try! JSONSerialization.jsonObject(with: Data(json.utf8), options: [])
        return (object as! [String: Any])["dsgLoginEvent"] as! [String: Any]
    }

    func testIsKidFromLoginEvent() {
        XCTAssertTrue(KidMode.isKid(loginEvent: login(#"{"dsgLoginEvent":{"player":"kid_one","me":{"name":"kid_one","parentPid":23000000012345}}}"#)))
        XCTAssertFalse(KidMode.isKid(loginEvent: login(#"{"dsgLoginEvent":{"player":"bob","me":{"name":"bob"}}}"#)))
        XCTAssertFalse(KidMode.isKid(loginEvent: login(#"{"dsgLoginEvent":{"player":"bob","me":{"name":"bob","parentPid":null}}}"#)))
        XCTAssertFalse(KidMode.isKid(loginEvent: login(#"{"dsgLoginEvent":{"player":"bob"}}"#)))
        XCTAssertFalse(KidMode.isKid(loginEvent: login(#"{"dsgLoginEvent":{"player":"bob","me":"x"}}"#)))
    }

    func testMessageSendError() {
        XCTAssertEqual(KidMode.messageSendError("<html>You can only send messages to players your parent approved.</html>"),
                       "You can only send messages to players your parent approved.")
        XCTAssertEqual(KidMode.messageSendError("<p>Player is ignoring your messages.</p>"), "Player is ignoring your messages.")
        XCTAssertNil(KidMode.messageSendError("Error: Player bob not found."))
        XCTAssertNil(KidMode.messageSendError(""))
        XCTAssertNil(KidMode.messageSendError(nil))
    }

    func testBroadcastRefused() {
        XCTAssertTrue(KidMode.isBroadcastRefused("<p>Kid accounts can't broadcast.</p>"))
        XCTAssertFalse(KidMode.isBroadcastRefused("You can't broadcast more than once per hour"))
    }

    func testManagedByParentText() {
        XCTAssertEqual(KidMode.managedByParentText("iostest"), "Your account is managed by your parent, iostest.")
        XCTAssertEqual(KidMode.managedByParentText(nil), "Your account is managed by your parent.")
        XCTAssertEqual(KidMode.managedByParentText(""), "Your account is managed by your parent.")
    }

    func testApprovedCountText() {
        XCTAssertEqual(KidMode.approvedCountText(0), "0 approved players")
        XCTAssertEqual(KidMode.approvedCountText(1), "1 approved player")
        XCTAssertEqual(KidMode.approvedCountText(2), "2 approved players")
    }

    func testInviteAlertMessage() {
        XCTAssertNil(KidMode.inviteAlertMessage(""))
        XCTAssertEqual(KidMode.inviteAlertMessage("hi there"), "message: hi there")
    }

    func testSettingsHiddenKeysMatchExistingRulesForNonKids() {
        XCTAssertEqual(KidMode.settingsHiddenKeys(loggedIn: false, subscriber: false, isKid: false),
                       ["SubscribeButton", "StoreButton", "blockedPlayersButton", "kidAccountsButton"])
        XCTAssertEqual(KidMode.settingsHiddenKeys(loggedIn: true, subscriber: true, isKid: false),
                       ["SubscribeButton", "SignUpButton", "SignUpLabel", "personalizeAds"])
        XCTAssertEqual(KidMode.settingsHiddenKeys(loggedIn: true, subscriber: false, isKid: false),
                       ["SignUpButton", "SignUpLabel"])
    }

    func testSettingsHiddenKeysForKids() {
        // Kids keep the Blocked players row (blocking only restricts further); only Kid accounts is hidden.
        XCTAssertEqual(KidMode.settingsHiddenKeys(loggedIn: true, subscriber: false, isKid: true),
                       ["SignUpButton", "SignUpLabel", "kidAccountsButton"])
        XCTAssertEqual(KidMode.settingsHiddenKeys(loggedIn: true, subscriber: true, isKid: true),
                       ["SubscribeButton", "SignUpButton", "SignUpLabel", "personalizeAds", "kidAccountsButton"])
        // isKid is ignored when logged out (a stale flag from the previous login).
        XCTAssertEqual(KidMode.settingsHiddenKeys(loggedIn: false, subscriber: false, isKid: true),
                       ["SubscribeButton", "StoreButton", "blockedPlayersButton", "kidAccountsButton"])
    }
}
```

Register both files:
```bash
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && touch test1/KidMode.swift && ruby Scripts/add_swift_file.rb test1/KidMode.swift penteLive test1 && ruby Scripts/add_swift_file.rb PenteEngineTests/KidModeTests.swift PenteEngineTests PenteEngineTests
```

- [ ] **Step 2: Run the tests and see them fail**

Run the canonical test command with `-only-testing:PenteEngineTests/KidModeTests`.
Expected: `error:` — `cannot find 'KidMode' in scope`.

- [ ] **Step 3: Implement `KidMode.swift`**
  - `isKid(loginEvent:)`: `me = loginEvent["me"] as? [String: Any]`; true iff `me["parentPid"]` is an `NSNumber`, or a non-empty `String`.
  - `messageSendError`: return the first of the two contract strings (in the order of the test) that `body` contains, else nil.
  - `inviteAlertMessage`: nil for `""`, else `"message: \(text)"` (the existing alert's format, `RoomViewController.swift:556`).
  - `settingsHiddenKeys`: logged out → the logged-out set plus `kidAccountsButton`; logged in → the existing subscriber / non-subscriber set (`SettingsViewController.m:221-230`), plus `kidAccountsButton` when `isKid` (never `blockedPlayersButton` for a logged-in kid: decision D1).
  - Run `swiftformat test1/KidMode.swift PenteEngineTests/KidModeTests.swift`.

- [ ] **Step 4: Run the tests and see them pass**

Run the canonical test command with `-only-testing:PenteEngineTests/KidModeTests`.
Expected: `Executed 6 tests, with 0 failures` and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git -C $IOS add test1/KidMode.swift PenteEngineTests/KidModeTests.swift penteLive.xcodeproj/project.pbxproj
git -C $IOS commit -S -m "Kid accounts: kid-mode helpers (login flag, refusals, hidden settings rows)"
```

---

### Task 4: Service, Settings row and the kid list screen

**Files:**
- Create: `$IOS/test1/KidAccountsService.swift`
- Create: `$IOS/test1/KidAccountsViewController.swift`
- Modify: `$IOS/test1/Settings.bundle/MoreSettings.plist` (new dict after the `blockedPlayersButton` dict, L139-148)
- Modify: `$IOS/test1/SettingsViewController.m:218-235` (hidden keys) and `:270-275` (button tap)
- Modify: `$IOS/penteLive.xcodeproj/project.pbxproj` (script only)

**Interfaces:**
- Consumes: Task 2 `KidAccounts`, `KidAction`, `KidAccountsState`; Task 3 `KidMode.settingsHiddenKeys`, `KidMode.managedByParentText`, `KidMode.approvedCountText`; Task 1 `PentePlayer.isKid`; `BlockedPlayers.formEncode`, `PenteHTTPClient.send`, `developmentEnabled()`, `PenteAlert`.
- Produces (used by Tasks 5, 6):
  - `@objc final class KidAccountsService: NSObject` with
    - `static func load(_ completion: @escaping (KidAccountsState?, String?) -> Void)`
    - `static func perform(_ action: KidAction, _ completion: @escaping (KidAccountsState?, String?) -> Void)` (POST; the reply is the caller's GET view after the change)
    - `@objc static func allowedRecipients(completion: @escaping ([String]) -> Void)` (`[]` on any failure)
    - Completions run on main (as `PenteHTTPClient` guarantees). A failure passes `nil` and the server `error` or `"Please try again."`.
  - `@objc final class KidAccountsViewController: UITableViewController` with `@objc convenience init()` (style `.insetGrouped`), and `func show(_ state: KidAccountsState)` used by the detail screen to hand back a fresh state.
  - Settings key `kidAccountsButton`, title `Kid accounts`.

- [ ] **Step 1: Service**

Copy the structure of `test1/BlockedPlayers/BlockedPlayersService.swift:6-52`: URL `https://www.pente.org/gameServer/kids` (or `https://localhost` when `developmentEnabled()`), credentials `name2`/`password2`, timeout 7.0, GET with `.reloadIgnoringLocalCacheData`, POST body `BlockedPlayers.formEncode(action.params + credentials())`. Run `swiftformat` on the new file.

- [ ] **Step 2: Kid list screen**

`KidAccountsViewController` (title `Kid accounts`), modelled on `BlockedPlayersViewController`:
- One section of kids: cell text `kid.name`, secondary text `KidMode.approvedCountText(kid.whitelist.count)` (`1 approved player` / `<n> approved players`); disclosure indicator; tap pushes `KidDetailViewController(kid:list:)` from Task 5 (until Task 5 lands, leave the tap as a no-op with a `// Task 5` marker so this task builds).
- Empty state label `No kid accounts yet` (same background-view technique as `BlockedPlayersViewController:31-45`).
- Footer of the section when `!state.emailVerified`: `Verify your email address before adding kids` (the server's own string; the server still enforces it).
- Right bar button `UIBarButtonItem(systemItem: .add)` with a `UIMenu` of two actions:
  - `Create kid account` → `.alert` with text fields `username` and `password` (`isSecureTextEntry`), button `Create` → `perform(.create(name:password:))`.
  - `Convert existing account` → `.alert` with text field `username`, message `We'll email that account to confirm.`, button `Send` → `perform(.convert(name:))`; on success show an alert with `state.message`.
- Every reply goes through one `apply(state:error:)`: on state, store, reload, update empty/footer; on error, `PenteAlert.show(withTitle: title, message: error, cancelButtonTitle: "OK")`.
- **Kid state** (a kid can reach this screen before the first dashboard reply sets `PentePlayer.isKid`, or with a stale flag after a conversion confirms while the app is open). In `apply`, when `state.isKid`:
  - remove the add button (`navigationItem.rightBarButtonItem = nil`) and show no kid rows;
  - show the empty-state label `KidMode.managedByParentText(state.parentName)` instead of `No kid accounts yet`, and no email footer;
  - set `(navigationController as? PenteNavigationViewController)?.player?.isKid = true` (the same `navC.player` Settings reads at `SettingsViewController.m:140`), so the next Settings `viewWillAppear` hides the `Kid accounts` row. The `Blocked players` row stays (D1).
  - When `!state.isKid`, restore the add button (a released kid who reopens the screen gets the parent view).
- `viewWillAppear` reloads (so returning from detail shows fresh data).
- Run `swiftformat` on the new file.

- [ ] **Step 3: Settings row**

In `MoreSettings.plist`, insert after the `blockedPlayersButton` dict a dict with `Key` `kidAccountsButton`, `Title` `Kid accounts`, `IASKTextAlignment` `IASKUITextAlignmentCenter`, `Type` `IASKButtonSpecifier`. Verify with `plutil -lint $IOS/test1/Settings.bundle/MoreSettings.plist` (expected `OK`).

In `SettingsViewController.m viewWillAppear:` replace the `if/else` that assigns `self.hiddenKeys` (L218-235) with one call:
```objc
    BOOL loggedIn = [[NSUserDefaults standardUserDefaults] boolForKey:@"registrationSuccess"];
    self.hiddenKeys = [KidMode settingsHiddenKeysWithLoggedIn:loggedIn
                                                   subscriber:(self.navC.player && self.navC.player.subscriber)
                                                        isKid:self.navC.player.isKid];
```
In `settingsViewController:buttonTappedForSpecifier:` add, next to the `blockedPlayersButton` branch, a `kidAccountsButton` branch pushing `[[KidAccountsViewController alloc] init]`.

- [ ] **Step 4: Register and build**

```bash
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && ruby Scripts/add_swift_file.rb test1/KidAccountsService.swift penteLive test1 && ruby Scripts/add_swift_file.rb test1/KidAccountsViewController.swift penteLive test1
```
Run the canonical build command. Expected: `** BUILD SUCCEEDED **` twice. Then run `-only-testing:PenteEngineTests/KidModeTests -only-testing:PenteEngineTests/KidAccountsTests`; expected `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git -C $IOS add test1/KidAccountsService.swift test1/KidAccountsViewController.swift test1/Settings.bundle/MoreSettings.plist test1/SettingsViewController.m penteLive.xcodeproj/project.pbxproj
git -C $IOS commit -S -m "Kid accounts: Settings row, service and kid list screen"
```

---

### Task 5: Kid detail screen (approved players, copies, password, release)

**Files:**
- Create: `$IOS/test1/KidDetailViewController.swift`
- Modify: `$IOS/test1/KidAccountsViewController.swift` (wire the row tap)
- Modify: `$IOS/penteLive.xcodeproj/project.pbxproj` (script only)

**Interfaces:**
- Consumes: Task 4 `KidAccountsService.perform`, `KidAccountsViewController.show(_:)`; Task 2 `KidAction`, `KidAccounts.kid(_:in:)`, `KidPlayer.styledName`; Task 3 `KidMode.liveChatCopyNote`.
- Produces: `final class KidDetailViewController: UITableViewController` with `init(kid: KidAccount, list: KidAccountsViewController)` (style `.insetGrouped`).

- [ ] **Step 1: Build the screen** (title = kid name). Sections:
  1. **Approved players**: one row per `kid.whitelist` entry (`styledName`), trailing swipe `Remove` (destructive) → confirm alert `Remove <name>?` / `<kid> won't be able to chat with <name>.` → `perform(.whitelistRemove(kidPid:playerPid:))`. Last row `Add player…` (tint color) → `.alert` with `username` field, button `Add` → `perform(.whitelistAdd(kidPid:playerName:))`. Footer: `Your kid can always chat with you and with pente.org admins.`
  2. **Email copies to you**: two rows with a `UISwitch` accessory, `Private messages` (`copyMessages`) and `Live-room chat` (`copyLiveChat`). Toggling sends `perform(.settings(kidPid:copyMessages:copyLiveChat:))` with only the toggled flag non-nil; on failure the switch reverts. Footer: `KidMode.liveChatCopyNote`.
  3. **Account**: `Change password…` → `.alert` with a secure field, button `Save` → `perform(.password(kidPid:password:))`, success alert `Password changed`. `Release kid account…` (red) → confirm `Release <kid>?` / `<kid> becomes a normal account. Approved players and copy settings are deleted.` destructive `Release` → `perform(.release(kidPid:))`.
- Every success: `list.show(state)`, then find `KidAccounts.kid(kid.kidPid, in: state)`; if found, replace `kid` and reload; if not found (released), pop to the list. Every failure: `PenteAlert` with the error.
- In `KidAccountsViewController`, replace the Task 4 no-op with pushing `KidDetailViewController(kid:list: self)`.
- Run `swiftformat` on the new file.

- [ ] **Step 2: Register and build**

```bash
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && ruby Scripts/add_swift_file.rb test1/KidDetailViewController.swift penteLive test1
```
Run the canonical build command. Expected: `** BUILD SUCCEEDED **` twice.

- [ ] **Step 3: Commit**

```bash
git -C $IOS add test1/KidDetailViewController.swift test1/KidAccountsViewController.swift penteLive.xcodeproj/project.pbxproj
git -C $IOS commit -S -m "Kid accounts: per-kid screen for approved players, copies, password and release"
```

---

### Task 6: Kid mode in messages and broadcast

**Files:**
- Modify: `$IOS/test1/MessagesViewController.m` (new-message branch of `viewDidAppear:` L121-122; send completion L652-681)
- Modify: `$IOS/test1/LobbyViewController.swift:38-39, 189-199`

**Interfaces:**
- Consumes: Task 1 `PentePlayer.isKid`; Task 3 `KidMode.composerHint`, `KidMode.messageSendError`, `KidMode.isBroadcastRefused`, `KidMode.broadcastRefusedText`; Task 4 `KidAccountsService.allowedRecipients(completion:)`.
- Produces: nothing new.

- [ ] **Step 1: Composer suggestions for a kid**

In `viewDidAppear:`, inside the `else` (new message) branch after `self.toField.textColor = ...`, when `navController.player.isKid`:
- `toField.placeholder = KidMode.composerHint`;
- set `self.toHistory = [NSMutableArray array]` **synchronously first**: `viewDidLoad` (`MessagesViewController.m:331`) has already filled it from `invitedHistory`, which can hold non-approved names, and the request below is asynchronous;
- then call `[KidAccountsService allowedRecipientsWithCompletion:]` and, with a weak/strong self, set `strongSelf.toHistory = [names mutableCopy]` so `textField:completionForPrefix:` only completes the parent and approved names (`parentName` + `whitelist`, per the contract).
Do not block sending a typed name on the client (decision D2): whatever the kid types is sent, and the server's refusal string is shown (Step 2). Admins are allowed by the server and are not listed (Review Focus 3).

- [ ] **Step 2: Refusal strings**

In the `sendMessage:` completion, add a branch after `if (error) {...}` and before the `Error: Player %@ not found.` branch:
```objc
        } else if ([KidMode messageSendError:dashboardString]) {
            [PenteAlert showWithTitle:NSLocalizedString(@"Message not sent", nil)
                              message:[KidMode messageSendError:dashboardString]
                    cancelButtonTitle:@"OK"];
```
(Do not pop the view, so the kid keeps the text.) Behaviour change for non-kids, on purpose: `Player is ignoring your messages.` today falls into the success branch (`MessagesViewController.m:667-703`), so the composer pops and the message is silently lost. After this branch, any sender blocked by the recipient (kid or not) gets the `Message not sent` alert instead (Review Focus 6).

- [ ] **Step 3: Broadcast**

In `LobbyViewController.viewDidLoad`, after `pentePlayer = ...`, set `navigationItem.rightBarButtonItem = nil` when `pentePlayer?.isKid == true`. In `broadcastNow`, add first branch `if KidMode.isBroadcastRefused(htmlString) { showErrorAlert(alertMessage: KidMode.broadcastRefusedText) }`.

- [ ] **Step 4: Build and test**

Run the canonical build command (expected `** BUILD SUCCEEDED **` twice) and the canonical test command with `-only-testing:PenteEngineTests/KidModeTests` (expected `** TEST SUCCEEDED **`).

- [ ] **Step 5: Commit**

```bash
git -C $IOS add test1/MessagesViewController.m test1/LobbyViewController.swift
git -C $IOS commit -S -m "Kid accounts: approved-only composer suggestions, refusal alerts, no broadcast for kids" -m "A sender blocked by the recipient (kid or not) now gets a 'Message not sent' alert for 'Player is ignoring your messages.' instead of the composer closing as if the message was sent."
```

---

### Task 7: Kid mode in the native live room

**Files:**
- Modify: `$IOS/test1/RoomViewController.swift` (properties L39-60; `loginEvent` L356-367; `inviteTableEvent` L538-593; `TableViewController(` call L637)
- Modify: `$IOS/test1/TableViewController.swift` (init L65-98; `showInvitationDialog` L581-617)

**Interfaces:**
- Consumes: Task 3 `KidMode.isKid(loginEvent:)`, `KidMode.chatHint`, `KidMode.inviteAlertMessage`.
- Produces: `RoomViewController.isKid: Bool` (main-thread only); `TableViewController.init(table:socket:tablesAndPlayers:pente_player:me:isArenaTable:isKid:)` with `isKid: Bool = false` last, stored as `let isKid: Bool`.

- [ ] **Step 1: TableViewController**
  - Add the `isKid` init parameter and property. After the `textField` setup in `init`, `textField.placeholder = isKid ? KidMode.chatHint : nil`.
  - In `showInvitationDialog`, add the `optional message` text field only when `!isKid`. Read the player from `textFields!.last!` and the message as `isKid ? "" : textFields![0].text!`.

- [ ] **Step 2: RoomViewController**
  - Add `var isKid = false` (main thread only).
  - In `loginEvent`, compute `let kid = KidMode.isKid(loginEvent: event)` on the socket queue, and inside the existing `DispatchQueue.main.async` block set `self.isKid = kid` and `self.textField.placeholder = kid ? KidMode.chatHint : nil`.
  - Pass `isKid: self.isKid` in the `TableViewController(` call at L637.
  - In `inviteTableEvent`: build the alert with `message: KidMode.inviteAlertMessage(inviteText)` (no `message: ` line for an empty text, for every player). Add the `reply message` text field only when `!self.isKid`; in the three actions read `self.invitationAlertController!.textFields?.first?.text ?? ""` instead of `textFields![0]`.
  - `inviteResponseTableEvent` already skips an empty `responseText`; leave it.

- [ ] **Step 3: Build and test**

Run the canonical build command (expected `** BUILD SUCCEEDED **` twice) and the canonical test command with `-only-testing:PenteEngineTests/KidModeTests -only-testing:PenteEngineTests/RoomEventOrderingTests` (expected `** TEST SUCCEEDED **`).

- [ ] **Step 4: Commit**

```bash
git -C $IOS add test1/RoomViewController.swift test1/TableViewController.swift
git -C $IOS commit -S -m "Kid accounts: live room chat hint and no invite text for kids"
```

---

### Task 8: Verification: full suite, both form factors, E2E on the local stack

**Files:** none changed. One temporary edit, `test1/PentePlayer.h:17`, is reverted in Step 8.

**Prerequisites:** the server plan (`pente.org/docs/superpowers/plans/2026-10-19-kids-accounts-server.md`) is implemented on the local stack (`./justCompile` in `pente.org/` compiles and restarts the container; the local stack is the isolated dev backend). Test accounts `iostest` and `graviton` (credentials in `pente-react-native/.env.local`; never print or commit them). `iostest`'s email is swapped to an `@example.invalid` address with `email_valid = 'Y'` in Step 3b and restored in Step 8: local mail is real SMTP (server plan Global Constraints), and K1 (create), K2 (copy switches on), K5 (PM copies) and K6 (live-chat copy) all make the server send mail to the parent. For the live-room steps, one React live room instance logged in as `graviton` (react-live-e2e-setup recipe: comment out the `connectSocket` 'pente.org' host override locally, never commit it).

- [ ] **Step 1: Full unit suite**

```bash
mkdir -p /private/tmp/claude-501/kids-ios
xcodebuild test -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' SWIFT_ENABLE_EXPLICIT_MODULES=NO > /private/tmp/claude-501/kids-ios/full-test.log 2>&1; grep -E 'error:|Executed .* tests|TEST (SUCCEEDED|FAILED)' /private/tmp/claude-501/kids-ios/full-test.log | tail -3
```
Expected: `Executed N tests, with 0 failures` (N includes the 4 + 11 + 8 new tests) and `** TEST SUCCEEDED **`. Record both lines.

- [ ] **Step 2: Both form factors build** — run the canonical build command. Expected `** BUILD SUCCEEDED **` twice.

- [ ] **Step 3: Static checks**

```bash
cd /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS && grep -rn '"/gameServer/kids"\|gameServer/kids' test1 | grep -v KidAccountsService.swift ; grep -rn 'parentPid' test1 | grep -v 'KidMode.swift\|DashboardWire.swift\|DashboardMapping.swift'
```
Expected: both print nothing (endpoint only in the service; `parentPid` read only from the login echo helper and the dashboard).

- [ ] **Step 3b: Swap iostest's email to a safe address**

Local SQL runs as `docker compose -f /Users/waliedothman/mariposa/coding/pente.org-project/pente.org/docker-compose.yml exec -T main_db sh -c 'mariadb -uroot -p"$MYSQL_ROOT_PASSWORD" dsg'` with SQL on stdin (never print `.env` values).
- Write iostest's current values as an `UPDATE dsg_player SET email=…, email_valid=… WHERE pid=(SELECT pid FROM player WHERE name_lower='iostest');` statement (`dsg_player` has no name column; the name lives in `player`) to `/private/tmp/claude-501/kids-ios/restore.sql` (select them with `-N` and build the statement; do not echo the address into the report).
- Then `UPDATE dsg_player SET email='kids-e2e-parent@example.invalid', email_valid='Y' WHERE pid=(SELECT pid FROM player WHERE name_lower='iostest');`, then restart the app container (`docker compose -f /Users/waliedothman/mariposa/coding/pente.org-project/pente.org/docker-compose.yml restart pente.org`) so the server's cached player object picks up the new address (the server plan swaps before `./justCompile` for the same reason)
- Check: `SELECT email, email_valid FROM dsg_player WHERE pid=(SELECT pid FROM player WHERE name_lower='iostest');` gives `kids-e2e-parent@example.invalid	Y`.
- Do not run Step 5 until this check passes.

- [ ] **Step 4: Point the app at the local backend (temporary)** — `#define development NO` → `YES` in `$IOS/test1/PentePlayer.h:17`; `git -C $IOS status --porcelain` must show only ` M test1/PentePlayer.h`.

- [ ] **Step 5: E2E on the iPhone 18 Pro simulator**

Build with `-derivedDataPath /private/tmp/claude-501/kids-ios/dd`, then `xcrun simctl boot`, `install` `.../Debug-iphonesimulator/penteLive.app`, `launch be.submanifold.penteLive`. Screenshot each scenario to `/private/tmp/claude-501/kids-ios/<id>.png`, look at it, and record observed vs expected.
- **K1 parent setup:** log in as `iostest`. Settings > More shows `Kid accounts` below `Blocked players`. Create kid `kidtest<4 digits>` with a 5-16 character password: it appears with `0 approved players`. Create the same name again: alert `Requested name <name> is already taken, please choose another.`
- **K2 kid detail:** open the kid, add `graviton`: row appears styled. Add `nosuchplayer123`: alert `Player not found`. Toggle both copy switches on, leave and re-enter: still on. Change the password: `Password changed`.
- **K3 convert:** `Convert existing account` with `iostest`: alert `You can't add yourself as a kid`. Convert the kid created in K1 (already a kid): the neutral success alert `Confirmation email sent to <kid>`, and SQL shows no new `dsg_kid_link_request` row for it (nothing is sent). Do not convert any other real account (that would mail its real address).
- **K4 kid login:** log in as the kid and open Settings > More **before** the games list finishes loading if possible (or right after login): if `Kid accounts` shows, tap it: the screen shows `Your account is managed by your parent, iostest.` and no add button; going back, the `Kid accounts` row is gone. After the dashboard has loaded: `Blocked players` is shown (D1), `Kid accounts` is not. Lobby has no broadcast button.
- **K5 kid messages:** new message: To placeholder `Approved players only`; typing `g` completes `graviton`. Send to `graviton`: success. Remove `graviton` from the whitelist (as `iostest` on the website `https://localhost/gameServer/myprofile/kids` or by logging back in), log in as the kid again and send to `graviton`: alert `Message not sent` / `You can only send messages to players your parent approved.`, and the composer stays open. Send to `iostest` (the parent): success.
- **K6 kid live room:** re-add `graviton`. Kid joins a live room: the chat input shows `Only approved players see your messages`. Open a table: same placeholder; Invite shows only the `player` field. `graviton` (React) invites the kid with text: the alert shows `message: <text>` and has no reply field. Remove `graviton` from the whitelist, reconnect, invite again with text: the alert has no `message:` line.
- **K7 non-kid unchanged:** log in as `iostest`: blocked players row, broadcast button, invite message field and chat input without placeholder are all as before.
- **K8 release:** as `iostest`, release the kid: it leaves the list; the detail screen pops. (Do this after K9.)
- **K9 open TB invitation text (D3, server-side):** with `graviton` not whitelisted, `graviton` creates an open turn-based invitation (no invitee) with message `hello-open` on the website (`https://localhost/gameServer/tb/new`). As the kid in the app, open that invitation (the app loads `/gameServer/tb/replyInvitation` with `mobile=`): `hello-open` is not shown anywhere and the invitation can still be accepted (do not accept). As `iostest`, the same invitation shows `hello-open`. Then cancel it as `graviton`. If the app shows no inviter text for open invitations at all, record K9 as "not visible in iOS, nothing to check".
- **Broadcast refusal: unit-only.** `broadcastNow` always calls `www.pente.org` and ignores `development` (`LobbyViewController.swift:192`), so the `isBroadcastRefused` branch cannot run against the local stack. Its only proof is `testBroadcastRefused` (Task 3); record it as "unit-only" in Step 7. Do not change the URL.
- **401 `Login required`: unit-only.** The app always sends `name2`/`password2`; the reply is covered by `testParseFailureIsNilAndErrorIsRead` (Task 2).

- [ ] **Step 6: iPad pass** — repeat K1, K2 and K6 on `iPad Pro 13-inch (M5)` in portrait and landscape (rotate with `xcrun simctl` UI or the simulator menu while the kid detail screen and an alert are open). Expected: rows fill the readable width, switches stay right-aligned, alerts stay centred, nothing clipped.

- [ ] **Step 7: Record evidence** — list each scenario with its screenshot path and observed result in the task report.

- [ ] **Step 8: Restore iostest's email, revert the development flag and check the tree**

Run `/private/tmp/claude-501/kids-ios/restore.sql` through the local SQL command from Step 3b, then restart the app container as in Step 3b, then `SELECT email_valid, email LIKE '%@example.invalid' FROM dsg_player WHERE pid=(SELECT pid FROM player WHERE name_lower='iostest');` must show the original `email_valid` and `0` (state the check passed; do not print the address).
```bash
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS checkout -- test1/PentePlayer.h && git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS status --porcelain
```
Expected: no output. Remove nothing outside `/private/tmp/claude-501/kids-ios/` (all scratch is there).

---

## Self-review notes

- **Spec coverage (iOS bullets):** native Kid accounts screens from a `MoreSettings.plist` row handled in `SettingsViewController` (Tasks 4-5); all parent actions — list, create, convert, set password, whitelist add/remove, two copy toggles, release (Tasks 4-5); live-chat best-effort note in the parent UI (Task 5); kid flag from the index JSON (Task 1) and the live login echo (Tasks 3, 7); kids keep blocked players (D1, Task 3 test); kid's own view of the Kid accounts screen (Task 4); composer suggestions limited to parent + whitelist, never blocking a send (D2, Task 6); open TB invitation text hidden server-side, checked in E2E K9 (D3); chat hint (Task 7); broadcast hidden (Task 6); server refusal strings where the app matches strings (Task 6); native live room hint, hidden invite text and empty-text rendering (Task 7); no refusal event to handle (contract: none sent); iPhone and iPad (Task 8).
- **Decisions:** D1 (controller): kids keep the Blocked players row and every block button. D2 (controller, also in the server contract): the composer only suggests the parent and approved names and never blocks a send; admins are allowed by the server but not listed. **Judgment call for the user:** the spec says the composer "limits recipients"; this plan limits suggestions only and relies on the server refusal. Settled here: the `Kid accounts` row is hidden for kids once the dashboard has loaded (every kid POST is refused), and the screen handles a kid reply itself before that; `parentPid` is decoded leniently so a bad value can never break the dashboard.
- **Type consistency:** `KidAccountsState`, `KidAccount`, `KidPlayer`, `KidAction`, `KidAccountsService.perform/load/allowedRecipients`, `KidMode.*` names match across Tasks 2-7.
