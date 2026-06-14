# Dashboard Intake Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract the dashboard request-building + JSON decoding + model mapping out of `GamesTableViewController.parseDashboard` into a headlessly-testable Swift `DashboardService`, leaving the view controller to apply the typed result (flags, `player.*`, UI diffing, alerts).

**Architecture:** A Swift `DashboardService` exposes `loadDashboard(username:password:) async throws -> Dashboard`. It builds the request (`DashboardEndpoint`), fetches via a `Transport` protocol (default wraps the existing `PenteHTTPClient`; tests inject a stub), decodes internal `Codable` wire structs, and maps them to a typed `@objc Dashboard` of the **existing ObjC** `Game`/`Message`/`Tournament`/`RatingStat`/`KingOfTheHill` objects plus a `DashboardFlags` value and an `avatarUsernames` list. The VC keeps all UIKit work (`updateSection` diffing, KOTH/rating row animations, badges, `NSUserDefaults`, alerts) in a new `applyDashboard:`.

**Tech Stack:** Swift 5 / `async`-`await`, ObjC interop via the bridging header & generated `penteLive-Swift.h`, `NSJSONSerialization`-equivalent `JSONDecoder`, XCTest (`PenteEngineTests` target), AFNetworking-backed `PenteHTTPClient`.

---

## Build & test facts (read before starting)

- Every `xcodebuild` MUST append `SWIFT_ENABLE_EXPLICIT_MODULES=NO` (else `module 'CocoaAsyncSocket' not found`).
- Simulator: `-destination 'platform=iOS Simulator,name=iPhone 17'` (no iPhone 16 installed).
- Canonical test command:
  ```bash
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests
  ```
- Build-only command (for non-test compile checkpoints):
  ```bash
  xcodebuild build -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 17' SWIFT_ENABLE_EXPLICIT_MODULES=NO
  ```
- Add a Swift file to the app target headlessly: `ruby Scripts/add_swift_file.rb <path-relative-to-test1> penteLive`. (Inspect the script first; if its arg shape differs, fall back to the `xcodeproj` gem with group-relative refs: `ref = group.new_file('X.swift'); target.add_file_references([ref])`, and for resources use `target.add_resources`.)
- Add a file to the **test** target: same approach but target `PenteEngineTests`. Resources (the JSON fixture) must be added to the `PenteEngineTests` target's **Copy Bundle Resources** build phase.
- SourceKit "No such module 'XCTest'/'UIKit'" / "Cannot find type" diagnostics in-editor are FALSE ALARMS; they resolve at `xcodebuild` time. Trust the build, not the editor.
- All new files live in a new group `test1/Dashboard/`. Tests live in `PenteEngineTests/`.

## Source-of-truth references (the code being ported)

- `test1/GamesTableViewController.m:3389-3930` — `parseDashboard` (the full intake + mapping + UI).
- `:32-36` — `parseStoneColor`.
- `:38-45` — section constants (`MESSAGESSECTION` 0, `INVITATIONSSECTION` 1, `ACTIVEGAMESSECTION` 2, `PUBLICINVITATIONSSECTION` 3, `KOTHSECTION` 4, `TOURNAMENTSSECTION` 5, `SENTINVITATIONSSECTION` 6, `NONACTIVEGAMESSECTION` 7).
- `:3362-3387` — `updateSection:newItems:oldItems:collapsed:setter:`.
- `:3338-3360` — `showErrorAlertWithMessage:`.
- `:3327-3336` — `dashboardParse` (detached-thread wrapper).
- `test1/PenteHTTPClient.h` — `+ sendRequest:completion:` (completion on main queue).
- `test1/PentePlayer.h:30-97` — the ObjC model `@interface`s (property names below).
- `test1/PentePlayer.h:28` — `BOOL developmentEnabled(void);` bridge.

### Model property names (set by the mapping; do not rename)

- `Game`: `gameID`, `gameType`, `opponentName`, `opponentRating`, `myColor`, `remainingTime`, `ratedNot`, `nameColor` (UIColor), `crown` (int).
- `Message`: `messageID`, `unread` (`@"unread"`/`@"read"`), `subject`, `author`, `timeStamp`, `nameColor` (UIColor), `crown` (int).
- `Tournament`: `name`, `tournamentID`, `round`, `game`, `tournamentState`, `date`.
- `RatingStat`: `rating`, `totalGames`, `lastPlayed`, `crown` (int), `gameId` (int), `game`.
- `KingOfTheHill`: `gameId` (int), `numPlayers`, `member` (BOOL), `king` (BOOL), `currentKing`, `canSendOpen` (BOOL), `game`.

### JSON → field map (exact, from `parseDashboard`)

- `player`: `color`(int)→`flags.myColorRGB`; `showAds`(bool); `name`→`playerName`; `subscriber`(bool); `dbAccess`(bool); `emailMe`(bool); `livePlayers`(num→str); `onlineFollowing`(num→str).
- `kingOfTheHill[]`: `gameId`(int); `numPlayers`(→str); `amIMember`(bool)→`member`; `iAmKing`(bool)→`king`; `kingName`→`currentKing`; `canChallenge`(bool)→`canSendOpen`. Derived `game` name + `tbHills` (count of `gameId>50`).
- `ratingStats[]`: `rating`(num→str); `totalGames`(num→str); `lastGameDate`(num→str)→`lastPlayed`; `tourneyWinner`(int)→`crown`; `gameId`(int). Derived `game` + `tbRatings`.
- `invitationsSent[]` and `invitationsReceived[]`: `setId`(num→str)→`gameID`; `gameName`→`gameType`; `opponentName`; `opponentRating`(num→str); `color`(str, **no** `parseStoneColor`)→`myColor`; `daysPerMove`→`"%@ days per move"`→`remainingTime`; `rated`→`ratedNot`; `opponentColor`(int)→`nameColor`; `opponentTourneyWinner`(int)→`crown`.
- `activeGamesMyTurn[]` and `activeGamesOpponentTurn[]`: `gid`(num→str)→`gameID`; `gameName`; `opponentName`; `opponentRating`(num→str); `color`→`parseStoneColor`→`myColor`; `timeLeft`→`remainingTime`; `rated`→`ratedNot`; `opponentColor`(int)→`nameColor`; `opponentTourneyWinner`(int)→`crown`.
- `openInvitationGames[]`: `setId`(num→str)→`gameID`; `gameName`; `inviterName`→`opponentName`; `inviterRating`(num→str)→`opponentRating`; `color`→`parseStoneColor`→`myColor`; `daysPerMove`→`"%@ days per move"`; `rated`→`ratedNot`; `inviterColor`(int)→`nameColor`; `inviterTourneyWinner`(int)→`crown`.
- `messages[]`: `mid`(num→str)→`messageID`; `read`(int)==0→`@"unread"` else `@"read"`; `subject`; `from`→`author`; `date`→`timeStamp`; `fromColor`(int)→`nameColor`; `fromTourneyWinner`(int)→`crown`.
- `tournaments[]`: `name`; `eventId`(num→str)→`tournamentID`; `numRounds`(num→str)→`round`; `gameName`→`game`; `status`(num→str)→`tournamentState`; `date`.
- `onlinePlayers`: array of name strings → `[name: ""]` dict.
- Avatar rule: for each game/message, if `nameColor != UIColorFromRGB(0)` (black), append `opponentName`/`author` to `avatarUsernames`. (The VC gates on `wantToSeeAvatars`.)
- Missing `invitationsReceived` key → `DashboardError.invalidCredentials` (legacy silent-reset path).

---

## Phase 1 — Service + tests (no wiring into the VC yet)

### Task 1: Result types — `Dashboard`, `DashboardFlags`, `DashboardError`

**Files:**
- Create: `test1/Dashboard/Dashboard.swift`
- Test: `PenteEngineTests/DashboardResultTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// PenteEngineTests/DashboardResultTests.swift
import XCTest
@testable import penteLive

final class DashboardResultTests: XCTestCase {
    func testFlagsAndDashboardHoldValues() {
        let flags = DashboardFlags(myColorRGB: 0x112233, playerName: "alice",
                                   showAds: true, subscriber: false, dbAccess: true,
                                   emailMe: true, tbHills: 2, tbRatings: 1,
                                   livePlayers: "5", onlineFollowing: "3")
        let g = Game(); g.gameID = "42"
        let dash = Dashboard(sentInvitations: [], invitations: [g], activeGames: [],
                             nonActiveGames: [], publicInvitations: [], messages: [],
                             tournaments: [], hills: [], ratingStats: [],
                             onlinePlayers: ["bob": ""], avatarUsernames: ["bob"], flags: flags)
        XCTAssertEqual(dash.invitations.first?.gameID, "42")
        XCTAssertEqual(dash.flags.tbHills, 2)
        XCTAssertEqual(dash.flags.playerName, "alice")
        XCTAssertEqual(dash.onlinePlayers["bob"], "")
    }

    func testErrorCodes() {
        let e = DashboardError.make(.http, "HTTP 503") as NSError
        XCTAssertEqual(e.code, DashboardErrorCode.http.rawValue)
        XCTAssertEqual(e.domain, DashboardError.domain)
        XCTAssertEqual(e.localizedDescription, "HTTP 503")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: the canonical test command above.
Expected: FAIL — `Cannot find 'DashboardFlags' / 'Dashboard' / 'DashboardError' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// test1/Dashboard/Dashboard.swift
import Foundation

enum DashboardErrorCode: Int {
    case network = 1
    case http = 2
    case decoding = 3
    case invalidCredentials = 4
}

enum DashboardError {
    static let domain = "org.pente.DashboardError"
    static func make(_ code: DashboardErrorCode, _ message: String) -> NSError {
        NSError(domain: domain, code: code.rawValue,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}

@objc final class DashboardFlags: NSObject {
    @objc let myColorRGB: Int
    @objc let playerName: String
    @objc let showAds: Bool
    @objc let subscriber: Bool
    @objc let dbAccess: Bool
    @objc let emailMe: Bool
    @objc let tbHills: Int
    @objc let tbRatings: Int
    @objc let livePlayers: String
    @objc let onlineFollowing: String

    @objc init(myColorRGB: Int, playerName: String, showAds: Bool, subscriber: Bool,
               dbAccess: Bool, emailMe: Bool, tbHills: Int, tbRatings: Int,
               livePlayers: String, onlineFollowing: String) {
        self.myColorRGB = myColorRGB; self.playerName = playerName
        self.showAds = showAds; self.subscriber = subscriber; self.dbAccess = dbAccess
        self.emailMe = emailMe; self.tbHills = tbHills; self.tbRatings = tbRatings
        self.livePlayers = livePlayers; self.onlineFollowing = onlineFollowing
    }
}

@objc final class Dashboard: NSObject {
    @objc let sentInvitations: [Game]
    @objc let invitations: [Game]
    @objc let activeGames: [Game]
    @objc let nonActiveGames: [Game]
    @objc let publicInvitations: [Game]
    @objc let messages: [Message]
    @objc let tournaments: [Tournament]
    @objc let hills: [KingOfTheHill]
    @objc let ratingStats: [RatingStat]
    @objc let onlinePlayers: [String: String]
    @objc let avatarUsernames: [String]
    @objc let flags: DashboardFlags

    @objc init(sentInvitations: [Game], invitations: [Game], activeGames: [Game],
               nonActiveGames: [Game], publicInvitations: [Game], messages: [Message],
               tournaments: [Tournament], hills: [KingOfTheHill], ratingStats: [RatingStat],
               onlinePlayers: [String: String], avatarUsernames: [String], flags: DashboardFlags) {
        self.sentInvitations = sentInvitations; self.invitations = invitations
        self.activeGames = activeGames; self.nonActiveGames = nonActiveGames
        self.publicInvitations = publicInvitations; self.messages = messages
        self.tournaments = tournaments; self.hills = hills; self.ratingStats = ratingStats
        self.onlinePlayers = onlinePlayers; self.avatarUsernames = avatarUsernames; self.flags = flags
    }
}
```

Note: `Game`/`Message`/`Tournament`/`RatingStat`/`KingOfTheHill` resolve through the bridging header (already imported app-wide). If the test target can't see them, ensure `#import "PentePlayer.h"` is in `penteLive-Bridging-Header.h` (it already is, since other Swift uses `Game`).

- [ ] **Step 4: Add files to targets**

```bash
ruby Scripts/add_swift_file.rb Dashboard/Dashboard.swift penteLive
ruby Scripts/add_swift_file.rb ../PenteEngineTests/DashboardResultTests.swift PenteEngineTests
```
(Adjust to the script's actual signature; verify with `git status` that both refs landed in `project.pbxproj`.)

- [ ] **Step 5: Run test to verify it passes**

Run: the canonical test command. Expected: PASS (both new tests).

- [ ] **Step 6: Commit**

```bash
git add test1/Dashboard/Dashboard.swift PenteEngineTests/DashboardResultTests.swift penteLive.xcodeproj/project.pbxproj
git commit -m "feat(dashboard): Dashboard result + flags + error types"
```

---

### Task 2: Golden fixture JSON

**Files:**
- Create: `PenteEngineTests/Fixtures/dashboard_sample.json`

This fixture exercises every section and every coercion (numbers-as-strings, missing keys,
empty arrays, black-vs-coloured names). Values are hand-authored; later mapping tests assert
the exact mapped output.

- [ ] **Step 1: Create the fixture**

```json
{
  "player": {
    "color": 1122867,
    "showAds": true,
    "name": "alice",
    "subscriber": false,
    "dbAccess": true,
    "emailMe": true,
    "livePlayers": 5,
    "onlineFollowing": 3
  },
  "kingOfTheHill": [
    { "gameId": 1, "numPlayers": 4, "amIMember": true, "iAmKing": false, "kingName": "kong", "canChallenge": true },
    { "gameId": 2, "numPlayers": 2, "amIMember": false, "iAmKing": false, "kingName": "kong2", "canChallenge": false },
    { "gameId": 53, "numPlayers": 8, "amIMember": true, "iAmKing": true, "kingName": "alice", "canChallenge": false }
  ],
  "ratingStats": [
    { "rating": 1500, "totalGames": 42, "lastGameDate": 1700000000, "tourneyWinner": 1, "gameId": 1 },
    { "gameId": 52, "rating": 1600, "totalGames": 10, "lastGameDate": 1700000001, "tourneyWinner": 0 }
  ],
  "invitationsSent": [
    { "setId": 9001, "gameName": "Pente", "opponentName": "bob", "opponentRating": 1400,
      "color": "white", "daysPerMove": 3, "rated": "rated", "opponentColor": 16711680, "opponentTourneyWinner": 0 }
  ],
  "invitationsReceived": [
    { "setId": 9002, "gameName": "Keryo-Pente", "opponentName": "carol", "opponentRating": 1450,
      "color": "black", "daysPerMove": 7, "rated": "unrated", "opponentColor": 0, "opponentTourneyWinner": 1 }
  ],
  "activeGamesMyTurn": [
    { "gid": 5001, "gameName": "Pente", "opponentName": "dave", "opponentRating": 1480,
      "color": "white_to_move", "timeLeft": "2 days", "rated": "rated", "opponentColor": 255, "opponentTourneyWinner": 0 }
  ],
  "activeGamesOpponentTurn": [
    { "gid": 5002, "gameName": "Pente", "opponentName": "erin", "opponentRating": 1490,
      "color": "black_to_move", "timeLeft": "5 hours", "rated": "rated", "opponentColor": 65280, "opponentTourneyWinner": 0 }
  ],
  "openInvitationGames": [
    { "setId": 7001, "gameName": "Pente", "inviterName": "frank", "inviterRating": 1300,
      "color": "white", "daysPerMove": 2, "rated": "rated", "inviterColor": 8388608, "inviterTourneyWinner": 0 }
  ],
  "messages": [
    { "mid": 3001, "read": 0, "subject": "hi", "from": "grace", "date": "2024-01-01", "fromColor": 16711680, "fromTourneyWinner": 0 },
    { "mid": 3002, "read": 1, "subject": "re: hi", "from": "heidi", "date": "2024-01-02", "fromColor": 0, "fromTourneyWinner": 1 }
  ],
  "tournaments": [
    { "name": "Spring Open", "eventId": 4001, "numRounds": 5, "gameName": "Pente", "status": 2, "date": "2024-03-01" }
  ],
  "onlinePlayers": ["bob", "carol"]
}
```

- [ ] **Step 2: Add the fixture to the test target's resources**

Add `PenteEngineTests/Fixtures/dashboard_sample.json` to the `PenteEngineTests` target's
**Copy Bundle Resources** phase (via `Scripts/add_swift_file.rb` if it supports resources,
else the `xcodeproj` gem: `target.add_resources([group.new_file('Fixtures/dashboard_sample.json')])`).
Verify with: `git diff penteLive.xcodeproj/project.pbxproj | grep -i dashboard_sample`.

- [ ] **Step 3: Commit**

```bash
git add PenteEngineTests/Fixtures/dashboard_sample.json penteLive.xcodeproj/project.pbxproj
git commit -m "test(dashboard): golden fixture exercising all sections + coercions"
```

---

### Task 3: Wire structs + `FlexibleString` decoding

**Files:**
- Create: `test1/Dashboard/DashboardWire.swift`
- Test: `PenteEngineTests/DashboardDecodingTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// PenteEngineTests/DashboardDecodingTests.swift
import XCTest
@testable import penteLive

final class DashboardDecodingTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = Bundle(for: type(of: self)).url(forResource: "dashboard_sample", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    func testDecodesTopLevelSections() throws {
        let wire = try JSONDecoder().decode(WireDashboard.self, from: fixtureData())
        XCTAssertEqual(wire.player?.name, "alice")
        XCTAssertEqual(wire.player?.color, 1122867)
        XCTAssertEqual(wire.kingOfTheHill?.count, 3)
        XCTAssertEqual(wire.ratingStats?.count, 2)
        XCTAssertEqual(wire.invitationsReceived?.count, 1)
        XCTAssertEqual(wire.messages?.count, 2)
        XCTAssertEqual(wire.onlinePlayers, ["bob", "carol"])
    }

    func testFlexibleStringCoercesNumberAndString() throws {
        let wire = try JSONDecoder().decode(WireDashboard.self, from: fixtureData())
        // setId came in as a number 9001 -> "9001"
        XCTAssertEqual(wire.invitationsSent?.first?.setId?.value, "9001")
        // opponentRating number -> string
        XCTAssertEqual(wire.invitationsReceived?.first?.opponentRating?.value, "1450")
        // livePlayers number -> string
        XCTAssertEqual(wire.player?.livePlayers?.value, "5")
    }

    func testMissingInvitationsReceivedIsNil() throws {
        let json = Data("{\"player\":{\"name\":\"x\"}}".utf8)
        let wire = try JSONDecoder().decode(WireDashboard.self, from: json)
        XCTAssertNil(wire.invitationsReceived)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: canonical test command. Expected: FAIL — `Cannot find 'WireDashboard' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// test1/Dashboard/DashboardWire.swift
import Foundation

/// Decodes a JSON value that may arrive as String, Int, Double, or Bool into a String,
/// reproducing the legacy `[x stringValue]` coercions.
struct FlexibleString: Decodable {
    let value: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let i = try? c.decode(Int.self) { value = String(i) }
        else if let d = try? c.decode(Double.self) { value = String(d) }
        else if let b = try? c.decode(Bool.self) { value = b ? "1" : "0" }
        else { value = "" }
    }
}

struct WirePlayer: Decodable {
    let color: Int?
    let showAds: Bool?
    let name: String?
    let subscriber: Bool?
    let dbAccess: Bool?
    let emailMe: Bool?
    let livePlayers: FlexibleString?
    let onlineFollowing: FlexibleString?
}

struct WireHill: Decodable {
    let gameId: Int?
    let numPlayers: FlexibleString?
    let amIMember: Bool?
    let iAmKing: Bool?
    let kingName: String?
    let canChallenge: Bool?
}

struct WireRatingStat: Decodable {
    let rating: FlexibleString?
    let totalGames: FlexibleString?
    let lastGameDate: FlexibleString?
    let tourneyWinner: Int?
    let gameId: Int?
}

/// Covers invitations (sent/received), active games (both), and open invitations.
/// Different sections populate different subsets of these keys.
struct WireGame: Decodable {
    let setId: FlexibleString?
    let gid: FlexibleString?
    let gameName: String?
    let opponentName: String?
    let opponentRating: FlexibleString?
    let inviterName: String?
    let inviterRating: FlexibleString?
    let color: String?
    let daysPerMove: FlexibleString?
    let timeLeft: String?
    let rated: FlexibleString?
    let opponentColor: Int?
    let inviterColor: Int?
    let opponentTourneyWinner: Int?
    let inviterTourneyWinner: Int?
}

struct WireMessage: Decodable {
    let mid: FlexibleString?
    let read: Int?
    let subject: String?
    let from: String?
    let date: String?
    let fromColor: Int?
    let fromTourneyWinner: Int?
}

struct WireTournament: Decodable {
    let name: String?
    let eventId: FlexibleString?
    let numRounds: FlexibleString?
    let gameName: String?
    let status: FlexibleString?
    let date: String?
}

struct WireDashboard: Decodable {
    let player: WirePlayer?
    let kingOfTheHill: [WireHill]?
    let ratingStats: [WireRatingStat]?
    let invitationsSent: [WireGame]?
    let invitationsReceived: [WireGame]?
    let activeGamesMyTurn: [WireGame]?
    let activeGamesOpponentTurn: [WireGame]?
    let openInvitationGames: [WireGame]?
    let messages: [WireMessage]?
    let tournaments: [WireTournament]?
    let onlinePlayers: [String]?
}
```

- [ ] **Step 4: Add file to app target & run**

```bash
ruby Scripts/add_swift_file.rb Dashboard/DashboardWire.swift penteLive
ruby Scripts/add_swift_file.rb ../PenteEngineTests/DashboardDecodingTests.swift PenteEngineTests
```
Run: canonical test command. Expected: PASS (3 new tests).

- [ ] **Step 5: Commit**

```bash
git add test1/Dashboard/DashboardWire.swift PenteEngineTests/DashboardDecodingTests.swift penteLive.xcodeproj/project.pbxproj
git commit -m "feat(dashboard): Codable wire structs with FlexibleString coercion"
```

---

### Task 4: Mapping wire → ObjC models (the core)

**Files:**
- Create: `test1/Dashboard/DashboardMapping.swift`
- Test: `PenteEngineTests/DashboardMappingTests.swift`

Reproduces `parseDashboard`'s field reads exactly. `LegacyPenteGame.getGameName` provides
game names (it is `@objc`/`+ (NSString *)getGameName:(int)`); confirm the Swift call shape
at implementation time (`LegacyPenteGame.getGameName(Int32(g))`), adjust the cast if the
importer shows a different signature.

- [ ] **Step 1: Write the failing test**

```swift
// PenteEngineTests/DashboardMappingTests.swift
import XCTest
import UIKit
@testable import penteLive

final class DashboardMappingTests: XCTestCase {
    private func loadDashboard() throws -> Dashboard {
        let url = Bundle(for: type(of: self)).url(forResource: "dashboard_sample", withExtension: "json")
        let wire = try JSONDecoder().decode(WireDashboard.self, from: try Data(contentsOf: XCTUnwrap(url)))
        return DashboardMapping.map(wire)
    }

    func testFlags() throws {
        let f = try loadDashboard().flags
        XCTAssertEqual(f.myColorRGB, 1122867)
        XCTAssertEqual(f.playerName, "alice")
        XCTAssertTrue(f.showAds)
        XCTAssertFalse(f.subscriber)
        XCTAssertTrue(f.dbAccess)
        XCTAssertTrue(f.emailMe)
        XCTAssertEqual(f.livePlayers, "5")
        XCTAssertEqual(f.onlineFollowing, "3")
        XCTAssertEqual(f.tbHills, 1)   // only gameId 53 > 50
        XCTAssertEqual(f.tbRatings, 1) // only gameId 52 > 50
    }

    func testActiveGameMapping() throws {
        let g = try XCTUnwrap(loadDashboard().activeGames.first)
        XCTAssertEqual(g.gameID, "5001")
        XCTAssertEqual(g.gameType, "Pente")
        XCTAssertEqual(g.opponentName, "dave")
        XCTAssertEqual(g.opponentRating, "1480")
        XCTAssertEqual(g.myColor, "white")          // parseStoneColor("white_to_move")
        XCTAssertEqual(g.remainingTime, "2 days")
        XCTAssertEqual(g.ratedNot, "rated")
        XCTAssertEqual(g.crown, 0)
    }

    func testReceivedInvitationUsesRawColorAndDaysPerMove() throws {
        let g = try XCTUnwrap(loadDashboard().invitations.first)
        XCTAssertEqual(g.gameID, "9002")
        XCTAssertEqual(g.myColor, "black")          // raw color, NOT parseStoneColor
        XCTAssertEqual(g.remainingTime, "7 days per move")
        XCTAssertEqual(g.crown, 1)
    }

    func testOpenInvitationUsesInviterFields() throws {
        let g = try XCTUnwrap(loadDashboard().publicInvitations.first)
        XCTAssertEqual(g.gameID, "7001")
        XCTAssertEqual(g.opponentName, "frank")     // inviterName
        XCTAssertEqual(g.opponentRating, "1300")    // inviterRating
        XCTAssertEqual(g.remainingTime, "2 days per move")
    }

    func testMessageReadUnread() throws {
        let msgs = try loadDashboard().messages
        XCTAssertEqual(msgs.count, 2)
        XCTAssertEqual(msgs[0].messageID, "3001")
        XCTAssertEqual(msgs[0].unread, "unread")    // read == 0
        XCTAssertEqual(msgs[0].author, "grace")
        XCTAssertEqual(msgs[1].unread, "read")      // read == 1
    }

    func testHillNamingAndFlags() throws {
        let hills = try loadDashboard().hills
        XCTAssertEqual(hills.count, 3)
        XCTAssertTrue(hills[1].game.hasPrefix("Speed "))     // gameId 2, even
        XCTAssertTrue(hills[2].game.hasPrefix("tb-"))        // gameId 53 > 50
        XCTAssertTrue(hills[0].member)
        XCTAssertTrue(hills[2].king)
        XCTAssertEqual(hills[0].numPlayers, "4")
    }

    func testRatingStatNaming() throws {
        let rs = try loadDashboard().ratingStats
        XCTAssertEqual(rs.count, 2)
        XCTAssertEqual(rs[0].rating, "1500")
        XCTAssertEqual(rs[0].totalGames, "42")
        XCTAssertEqual(rs[0].crown, 1)
        XCTAssertTrue(rs[1].game.hasPrefix("tb-"))           // gameId 52 > 50
    }

    func testTournamentMapping() throws {
        let t = try XCTUnwrap(loadDashboard().tournaments.first)
        XCTAssertEqual(t.name, "Spring Open")
        XCTAssertEqual(t.tournamentID, "4001")
        XCTAssertEqual(t.round, "5")
        XCTAssertEqual(t.tournamentState, "2")
        XCTAssertEqual(t.date, "2024-03-01")
    }

    func testOnlinePlayersAndAvatars() throws {
        let d = try loadDashboard()
        XCTAssertEqual(d.onlinePlayers["bob"], "")
        XCTAssertEqual(d.onlinePlayers["carol"], "")
        // carol's invitation has opponentColor 0 (black) -> excluded from avatars;
        // bob (sent, opponentColor 16711680) included.
        XCTAssertTrue(d.avatarUsernames.contains("bob"))
        XCTAssertFalse(d.avatarUsernames.contains("carol"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: canonical test command. Expected: FAIL — `Cannot find 'DashboardMapping' in scope`.

- [ ] **Step 3: Write minimal implementation**

```swift
// test1/Dashboard/DashboardMapping.swift
import UIKit

enum DashboardMapping {

    static func uiColor(fromRGB rgb: Int) -> UIColor {
        UIColor(red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(rgb & 0x0000FF) / 255.0, alpha: 1.0)
    }

    static func parseStoneColor(_ s: String?) -> String {
        guard let s = s else { return "" }
        if s.hasPrefix("white") { return "white" }
        if s.hasPrefix("black") { return "black" }
        return ""
    }

    /// Reproduces the `tb-` / `Speed ` / plain decoration from parseDashboard.
    static func decoratedGameName(gameId: Int) -> String {
        var g = gameId
        if g > 50 { g -= 50 }
        let name = LegacyPenteGame.getGameName(Int32(g)) ?? ""
        if gameId > 50 { return "tb-" + name }
        if gameId % 2 == 0 { return "Speed " + name }
        return name
    }

    private static let black = uiColor(fromRGB: 0)

    static func map(_ wire: WireDashboard) -> Dashboard {
        var avatars: [String] = []

        func mapInvitationGame(_ w: WireGame) -> Game {
            let g = Game()
            g.gameID = w.setId?.value ?? ""
            g.gameType = w.gameName
            g.opponentName = w.opponentName
            g.opponentRating = w.opponentRating?.value ?? ""
            g.myColor = w.color                                   // raw, no parseStoneColor
            g.remainingTime = "\(w.daysPerMove?.value ?? "") days per move"
            g.ratedNot = w.rated?.value
            g.nameColor = uiColor(fromRGB: w.opponentColor ?? 0)
            g.crown = Int32(w.opponentTourneyWinner ?? 0)
            if g.nameColor != black, let n = g.opponentName { avatars.append(n) }
            return g
        }

        func mapActiveGame(_ w: WireGame) -> Game {
            let g = Game()
            g.gameID = w.gid?.value ?? ""
            g.gameType = w.gameName
            g.opponentName = w.opponentName
            g.opponentRating = w.opponentRating?.value ?? ""
            g.myColor = parseStoneColor(w.color)
            g.remainingTime = w.timeLeft
            g.ratedNot = w.rated?.value
            g.nameColor = uiColor(fromRGB: w.opponentColor ?? 0)
            g.crown = Int32(w.opponentTourneyWinner ?? 0)
            if g.nameColor != black, let n = g.opponentName { avatars.append(n) }
            return g
        }

        func mapOpenInvitation(_ w: WireGame) -> Game {
            let g = Game()
            g.gameID = w.setId?.value ?? ""
            g.gameType = w.gameName
            g.opponentName = w.inviterName
            g.opponentRating = w.inviterRating?.value ?? ""
            g.myColor = parseStoneColor(w.color)
            g.remainingTime = "\(w.daysPerMove?.value ?? "") days per move"
            g.ratedNot = w.rated?.value
            g.nameColor = uiColor(fromRGB: w.inviterColor ?? 0)
            g.crown = Int32(w.inviterTourneyWinner ?? 0)
            if g.nameColor != black, let n = g.opponentName { avatars.append(n) }
            return g
        }

        let sent = (wire.invitationsSent ?? []).map(mapInvitationGame)
        let received = (wire.invitationsReceived ?? []).map(mapInvitationGame)
        let activeMine = (wire.activeGamesMyTurn ?? []).map(mapActiveGame)
        let activeOpp = (wire.activeGamesOpponentTurn ?? []).map(mapActiveGame)
        let open = (wire.openInvitationGames ?? []).map(mapOpenInvitation)

        let messages: [Message] = (wire.messages ?? []).map { w in
            let m = Message()
            m.messageID = w.mid?.value ?? ""
            m.unread = (w.read ?? 0) == 0 ? "unread" : "read"
            m.subject = w.subject
            m.author = w.from
            m.timeStamp = w.date
            m.nameColor = uiColor(fromRGB: w.fromColor ?? 0)
            m.crown = Int32(w.fromTourneyWinner ?? 0)
            if m.nameColor != black, let n = m.author { avatars.append(n) }
            return m
        }

        var tbHills = 0
        let hills: [KingOfTheHill] = (wire.kingOfTheHill ?? []).map { w in
            let h = KingOfTheHill()
            h.gameId = Int32(w.gameId ?? 0)
            h.numPlayers = w.numPlayers?.value
            h.member = w.amIMember ?? false
            h.king = w.iAmKing ?? false
            h.currentKing = w.kingName
            h.canSendOpen = w.canChallenge ?? false
            if Int(h.gameId) > 50 { tbHills += 1 }
            h.game = decoratedGameName(gameId: Int(h.gameId))
            return h
        }

        var tbRatings = 0
        let ratings: [RatingStat] = (wire.ratingStats ?? []).map { w in
            let r = RatingStat()
            r.rating = w.rating?.value
            r.totalGames = w.totalGames?.value
            r.lastPlayed = w.lastGameDate?.value
            r.crown = Int32(w.tourneyWinner ?? 0)
            r.gameId = Int32(w.gameId ?? 0)
            if Int(r.gameId) > 50 { tbRatings += 1 }
            r.game = decoratedGameName(gameId: Int(r.gameId))
            return r
        }

        let tournaments: [Tournament] = (wire.tournaments ?? []).map { w in
            let t = Tournament()
            t.name = w.name
            t.tournamentID = w.eventId?.value
            t.round = w.numRounds?.value
            t.game = w.gameName
            t.tournamentState = w.status?.value
            t.date = w.date
            return t
        }

        var online: [String: String] = [:]
        for n in (wire.onlinePlayers ?? []) { online[n] = "" }

        let p = wire.player
        let flags = DashboardFlags(
            myColorRGB: p?.color ?? 0,
            playerName: p?.name ?? "",
            showAds: p?.showAds ?? false,
            subscriber: p?.subscriber ?? false,
            dbAccess: p?.dbAccess ?? false,
            emailMe: p?.emailMe ?? false,
            tbHills: tbHills,
            tbRatings: tbRatings,
            livePlayers: p?.livePlayers?.value ?? "0",
            onlineFollowing: p?.onlineFollowing?.value ?? "0")

        return Dashboard(sentInvitations: sent, invitations: received,
                         activeGames: activeMine, nonActiveGames: activeOpp,
                         publicInvitations: open, messages: messages,
                         tournaments: tournaments, hills: hills, ratingStats: ratings,
                         onlinePlayers: online, avatarUsernames: avatars, flags: flags)
    }
}
```

Note on `Game`/`Message` setters: the ObjC properties are `nonatomic, retain NSString *`,
so they accept `String?` from Swift. `crown`/`gameId` are `int` → set with `Int32(...)`.
`nameColor` is `UIColor`. If any setter name differs from the property (e.g. a custom
getter), check `PentePlayer.h` and adjust.

- [ ] **Step 4: Add file & run**

```bash
ruby Scripts/add_swift_file.rb Dashboard/DashboardMapping.swift penteLive
ruby Scripts/add_swift_file.rb ../PenteEngineTests/DashboardMappingTests.swift PenteEngineTests
```
Run: canonical test command. Expected: PASS (all mapping tests).

- [ ] **Step 5: Commit**

```bash
git add test1/Dashboard/DashboardMapping.swift PenteEngineTests/DashboardMappingTests.swift penteLive.xcodeproj/project.pbxproj
git commit -m "feat(dashboard): wire->ObjC model mapping with golden-fixture tests"
```

---

### Task 5: `DashboardEndpoint`

**Files:**
- Create: `test1/Dashboard/DashboardEndpoint.swift`
- Test: `PenteEngineTests/DashboardEndpointTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// PenteEngineTests/DashboardEndpointTests.swift
import XCTest
@testable import penteLive

final class DashboardEndpointTests: XCTestCase {
    func testProdRequestShape() {
        let req = DashboardEndpoint().dashboardRequest(username: "al ice", password: "p&w", useLocalhost: false)
        let s = req.url!.absoluteString
        XCTAssertTrue(s.hasPrefix("https://www.pente.org/gameServer/mobile/json/index.jsp?"))
        XCTAssertTrue(s.contains("name=al%20ice") || s.contains("name=al+ice"))
        XCTAssertTrue(s.contains("password=p%26w"))
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.timeoutInterval, 7.0, accuracy: 0.001)
    }

    func testLocalhostHost() {
        let req = DashboardEndpoint().dashboardRequest(username: "a", password: "b", useLocalhost: true)
        XCTAssertTrue(req.url!.absoluteString.hasPrefix("https://localhost/gameServer/mobile/json/index.jsp?"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: canonical test command. Expected: FAIL — `Cannot find 'DashboardEndpoint'`.

- [ ] **Step 3: Write minimal implementation**

```swift
// test1/Dashboard/DashboardEndpoint.swift
import Foundation

struct DashboardEndpoint {
    /// `useLocalhost` defaults to the app's dev flag (`developmentEnabled()`), matching the
    /// legacy `if (development)` URL swap. Tests pass it explicitly.
    func dashboardRequest(username: String, password: String,
                          useLocalhost: Bool = developmentEnabled()) -> URLRequest {
        let host = useLocalhost ? "https://localhost" : "https://www.pente.org"
        var comps = URLComponents(string: "\(host)/gameServer/mobile/json/index.jsp")!
        comps.queryItems = [URLQueryItem(name: "name", value: username),
                            URLQueryItem(name: "password", value: password)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        req.timeoutInterval = 7.0
        return req
    }
}
```

Note: `URLComponents` percent-encodes the query, which the legacy raw `stringWithFormat`
did not. This is a correctness improvement (special chars in name/password now encode). If
byte-identical URLs are required, build the string manually instead — but encoding is the
right default. Flag this in the on-device check.

- [ ] **Step 4: Add file & run**

```bash
ruby Scripts/add_swift_file.rb Dashboard/DashboardEndpoint.swift penteLive
ruby Scripts/add_swift_file.rb ../PenteEngineTests/DashboardEndpointTests.swift PenteEngineTests
```
Run: canonical test command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test1/Dashboard/DashboardEndpoint.swift PenteEngineTests/DashboardEndpointTests.swift penteLive.xcodeproj/project.pbxproj
git commit -m "feat(dashboard): DashboardEndpoint request builder"
```

---

### Task 6: `Transport` protocol + `PenteHTTPClientTransport`

**Files:**
- Create: `test1/Dashboard/DashboardTransport.swift`

No unit test in this task (the real transport hits the network); it is exercised via a stub
in Task 7. This task just compiles the protocol + default impl.

- [ ] **Step 1: Write implementation**

```swift
// test1/Dashboard/DashboardTransport.swift
import Foundation

protocol Transport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Default transport wrapping the existing AFNetworking-backed PenteHTTPClient,
/// preserving its session/SSL behavior. Completion fires on the main queue.
struct PenteHTTPClientTransport: Transport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            PenteHTTPClient.sendRequest(request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: DashboardError.make(.network, error.localizedDescription))
                    return
                }
                guard let data = data, let response = response else {
                    continuation.resume(throwing: DashboardError.make(.network, "Empty response"))
                    return
                }
                continuation.resume(returning: (data, response))
            }
        }
    }
}
```

Note: confirm the imported Swift name of `+ sendRequest:completion:` — expected
`PenteHTTPClient.sendRequest(_:completion:)`, callable with trailing closure as above. If
the importer names it differently, adjust. Ensure `#import "PenteHTTPClient.h"` is in the
bridging header (add it if missing).

- [ ] **Step 2: Add file & build**

```bash
ruby Scripts/add_swift_file.rb Dashboard/DashboardTransport.swift penteLive
```
Run: the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**

```bash
git add test1/Dashboard/DashboardTransport.swift penteLive.xcodeproj/project.pbxproj test1/penteLive-Bridging-Header.h
git commit -m "feat(dashboard): Transport protocol + PenteHTTPClient-backed default"
```

---

### Task 7: `DashboardService`

**Files:**
- Create: `test1/Dashboard/DashboardService.swift`
- Test: `PenteEngineTests/DashboardServiceTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// PenteEngineTests/DashboardServiceTests.swift
import XCTest
@testable import penteLive

private struct StubTransport: Transport {
    let data: Data
    let status: Int
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let resp = HTTPURLResponse(url: request.url!, statusCode: status,
                                   httpVersion: nil, headerFields: nil)!
        return (data, resp)
    }
}

final class DashboardServiceTests: XCTestCase {
    private func fixture() throws -> Data {
        let url = Bundle(for: type(of: self)).url(forResource: "dashboard_sample", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    func testLoadsAndMaps() async throws {
        let service = DashboardService(transport: StubTransport(data: try fixture(), status: 200))
        let dash = try await service.loadDashboard(username: "a", password: "b")
        XCTAssertEqual(dash.flags.playerName, "alice")
        XCTAssertEqual(dash.activeGames.first?.gameID, "5001")
    }

    func testNon200ThrowsHttp() async throws {
        let service = DashboardService(transport: StubTransport(data: Data("{}".utf8), status: 503))
        do { _ = try await service.loadDashboard(username: "a", password: "b"); XCTFail("expected throw") }
        catch { XCTAssertEqual((error as NSError).code, DashboardErrorCode.http.rawValue) }
    }

    func testMissingInvitationsReceivedThrowsInvalidCredentials() async throws {
        let service = DashboardService(transport: StubTransport(data: Data("{\"player\":{}}".utf8), status: 200))
        do { _ = try await service.loadDashboard(username: "a", password: "b"); XCTFail("expected throw") }
        catch { XCTAssertEqual((error as NSError).code, DashboardErrorCode.invalidCredentials.rawValue) }
    }

    func testMalformedJsonThrowsDecoding() async throws {
        let service = DashboardService(transport: StubTransport(data: Data("not json".utf8), status: 200))
        do { _ = try await service.loadDashboard(username: "a", password: "b"); XCTFail("expected throw") }
        catch { XCTAssertEqual((error as NSError).code, DashboardErrorCode.decoding.rawValue) }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: canonical test command. Expected: FAIL — `Cannot find 'DashboardService'`.

- [ ] **Step 3: Write minimal implementation**

```swift
// test1/Dashboard/DashboardService.swift
import Foundation

@objc final class DashboardService: NSObject {
    private let transport: Transport
    private let endpoint: DashboardEndpoint

    init(transport: Transport = PenteHTTPClientTransport(),
         endpoint: DashboardEndpoint = DashboardEndpoint()) {
        self.transport = transport
        self.endpoint = endpoint
    }

    /// ObjC sees `loadDashboardWithUsername:password:completionHandler:`.
    @objc func loadDashboard(username: String, password: String) async throws -> Dashboard {
        let request = endpoint.dashboardRequest(username: username, password: password)
        let (data, response) = try await transport.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw DashboardError.make(.http, "HTTP \(http.statusCode)")
        }

        let wire: WireDashboard
        do {
            wire = try JSONDecoder().decode(WireDashboard.self, from: data)
        } catch {
            throw DashboardError.make(.decoding, error.localizedDescription)
        }

        guard wire.invitationsReceived != nil else {
            throw DashboardError.make(.invalidCredentials, "Not registered")
        }
        return DashboardMapping.map(wire)
    }
}
```

- [ ] **Step 4: Add file & run**

```bash
ruby Scripts/add_swift_file.rb Dashboard/DashboardService.swift penteLive
ruby Scripts/add_swift_file.rb ../PenteEngineTests/DashboardServiceTests.swift PenteEngineTests
```
Run: canonical test command. Expected: PASS (4 new tests). **Phase 1 complete: full intake is now headlessly tested.**

- [ ] **Step 5: Commit**

```bash
git add test1/Dashboard/DashboardService.swift PenteEngineTests/DashboardServiceTests.swift penteLive.xcodeproj/project.pbxproj
git commit -m "feat(dashboard): DashboardService async load with stub-transport tests"
```

---

## Phase 2 — Cutover

### Task 8: Add `refreshDashboard` + `applyDashboard:` to the VC (parallel to the old path)

**Files:**
- Modify: `test1/GamesTableViewController.m` (add two methods; do NOT yet remove `parseDashboard`)
- Modify: `test1/GamesTableViewController.h` (declare `- (void)refreshDashboard;`)

The new `applyDashboard:` contains the **UI half** of the old `parseDashboard`, sourced from
the typed `Dashboard` instead of raw JSON. It reuses the existing `updateSection:...` helper
and the KOTH/rating row-diffing logic (currently at `:3578-3647` and `:3649-3678`). Keep that
diffing logic verbatim, but read counts/items from `dashboard.hills` / `dashboard.ratingStats`
and `dashboard.flags.tbHills` / `.tbRatings` instead of building them inline.

- [ ] **Step 1: Declare the entry point**

In `GamesTableViewController.h`, add to the `@interface`:
```objc
- (void)refreshDashboard;
```

- [ ] **Step 2: Implement `refreshDashboard` + `applyDashboard:`**

Add near the existing `parseDashboard` in `GamesTableViewController.m`:

```objc
- (void)refreshDashboard {
    [self performSelector:@selector(scrollViewDidScroll:)
               withObject:self.tableView
               afterDelay:0.05];
    self.tableView.layer.borderWidth = 1.5;

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *user = [defaults objectForKey:usernameKey];
    NSString *pass = [defaults objectForKey:passwordKey];
    self.username = user;
    self.password = pass;

    BOOL wantsToSeeAvatars = [defaults boolForKey:@"wantToSeeAvatars"];
    if (!wantsToSeeAvatars) {
        [self.player.avatars removeAllObjects];
        [self.player.pendingAvatarChecks removeAllObjects];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.pullToReloadHeaderView setStatusString:@"Loading Games..." animated:YES];
        [self.pullToReloadHeaderView layoutSubviews];
    });

    DashboardService *service = [[DashboardService alloc] init];
    __weak typeof(self) weakSelf = self;
    [service loadDashboardWithUsername:user
                             password:pass
                    completionHandler:^(Dashboard *dashboard, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;
            if (error) {
                if (error.code == 4 /* DashboardErrorCode.invalidCredentials */) {
                    // legacy silent reset (missing invitationsReceived key)
                    strongSelf.tableView.layer.borderWidth = 0.0;
                    [strongSelf performSelector:@selector(scrollViewDidScroll:)
                                     withObject:strongSelf.tableView afterDelay:0.01];
                    [strongSelf performSelector:@selector(pullDownToReloadActionFinished) withObject:nil];
                    [strongSelf.tableView setUserInteractionEnabled:YES];
                } else {
                    [strongSelf showErrorAlertWithMessage:error.localizedDescription];
                }
                return;
            }
            [strongSelf applyDashboard:dashboard wantsAvatars:wantsToSeeAvatars];
        });
    }];
}

- (void)applyDashboard:(Dashboard *)dashboard wantsAvatars:(BOOL)wantsToSeeAvatars {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:@"registrationSuccess"];

    DashboardFlags *flags = dashboard.flags;
    [self.player setMyColor:UIColorFromRGB(flags.myColorRGB)];
    [self.player setShowAds:flags.showAds];
    [self.player setPlayerName:flags.playerName];
    [self.player setSubscriber:flags.subscriber];
    [self.player setDbAccess:flags.dbAccess];
    [self.player setEmailMe:flags.emailMe];
    [defaults setBool:self.player.emailMe forKey:@"emailMe"];
    [defaults setBool:self.player.personalizeAds forKey:PERSONALIZEADSKEY];
    if ([self.player subscriber]) {
        [defaults setBool:NO forKey:@"shouldSendReceipt"];
    }

    livePlayers = flags.livePlayers;
    onlineFollowing = flags.onlineFollowing;
    // --- badge updates: copy verbatim from parseDashboard :3504-3542, using
    //     livePlayers / onlineFollowing (already set above). ---

    if (wantsToSeeAvatars) {
        for (NSString *name in dashboard.avatarUsernames) {
            [self.player addUser:name];
        }
    }

    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        self.tableView.layer.borderWidth = 0.0;
        [self performSelector:@selector(scrollViewDidScroll:) withObject:self.tableView afterDelay:0.01];
        [self performSelector:@selector(pullDownToReloadActionFinished) withObject:nil];
        [self parseMessages];
    }];
    [self.tableView beginUpdates];
    [self.tableView setUserInteractionEnabled:NO];

    // --- KOTH section: reuse the existing diffing from parseDashboard :3578-3647,
    //     but with `NSArray *sectionItems = dashboard.hills;` and
    //     `int tbHills = dashboard.flags.tbHills;` instead of building them. ---
    [self updateKothSectionWithItems:dashboard.hills tbHills:dashboard.flags.tbHills];

    // --- rating stats: reuse :3649-3678 with dashboard.ratingStats and flags.tbRatings ---
    [[self.player ratingStats] setArray:dashboard.ratingStats];
    [self.player setTbRatings:dashboard.flags.tbRatings];

    [self updateSection:SENTINVITATIONSSECTION newItems:[dashboard.sentInvitations mutableCopy]
               oldItems:[self.player sentInvitations] collapsed:sentInvitationsCollapsed
                 setter:^(NSMutableArray *items) { [self.player setSentInvitations:items]; }];
    [self updateSection:INVITATIONSSECTION newItems:[dashboard.invitations mutableCopy]
               oldItems:[self.player invitations] collapsed:invitationsReceivedCollapsed
                 setter:^(NSMutableArray *items) { [self.player setInvitations:items]; }];
    [self updateSection:ACTIVEGAMESSECTION newItems:[dashboard.activeGames mutableCopy]
               oldItems:[self.player activeGames] collapsed:activeGamesCollapsed
                 setter:^(NSMutableArray *items) { [self.player setActiveGames:items]; }];
    [self updateSection:NONACTIVEGAMESSECTION newItems:[dashboard.nonActiveGames mutableCopy]
               oldItems:[self.player nonActiveGames] collapsed:nonActiveGamesCollapsed
                 setter:^(NSMutableArray *items) { [self.player setNonActiveGames:items]; }];
    [self updateSection:PUBLICINVITATIONSSECTION newItems:[dashboard.publicInvitations mutableCopy]
               oldItems:[self.player publicInvitations] collapsed:publicInvitationsCollapsed
                 setter:^(NSMutableArray *items) { [self.player setPublicInvitations:items]; }];
    [self updateSection:MESSAGESSECTION newItems:[dashboard.messages mutableCopy]
               oldItems:[self.player messages] collapsed:messagesCollapsed
                 setter:^(NSMutableArray *items) { [self.player setMessages:items]; }];
    [self updateSection:TOURNAMENTSSECTION newItems:[dashboard.tournaments mutableCopy]
               oldItems:[self.player tournaments] collapsed:tournamentsCollapsed
                 setter:^(NSMutableArray *items) { [self.player setTournaments:items]; }];

    [self.player setOnlinePlayers:dashboard.onlinePlayers];

    [self.tableView endUpdates];
    [CATransaction commit];
    [self.tableView setUserInteractionEnabled:YES];
}
```

Extract the KOTH diffing into `- (void)updateKothSectionWithItems:(NSArray *)items tbHills:(int)tbHills`
by moving the body of `parseDashboard :3578-3647` verbatim (it already references
`sectionItems`/`tbHills`/`kothCollapsed`/`KOTHSECTION`); rename its `sectionItems` param to
`items` and its local `tbHills` to the parameter. This keeps the bespoke animation behavior
byte-identical.

> **Implementer:** read `parseDashboard` (`:3389-3930`) in full before writing this. The
> badge block (`:3504-3542`) and KOTH diff (`:3578-3647`) must be copied verbatim — they are
> the parts NOT covered by unit tests, so faithfulness matters most here.

- [ ] **Step 3: Build (no behavior change yet — old path still active)**

Run: the build-only command. Expected: BUILD SUCCEEDED.
(`refreshDashboard` exists but nothing calls it yet, so runtime behavior is unchanged.)

- [ ] **Step 4: Commit**

```bash
git add test1/GamesTableViewController.m test1/GamesTableViewController.h
git commit -m "feat(dashboard): add refreshDashboard + applyDashboard (not yet wired)"
```

---

### Task 9: Repoint callers to `refreshDashboard`

**Files:**
- Modify: `test1/GamesTableViewController.m` (the ~12 `[self dashboardParse]`/`[weakSelf dashboardParse]` call sites)
- Modify: `test1/AppDelegate.m:250-253` and `:331-332`

- [ ] **Step 1: Repoint the VC's own callers**

Replace every `[self dashboardParse]`, `[weakSelf dashboardParse]`, `[weakSelf2 dashboardParse]`,
`[weakSelf3 dashboardParse]`, `[strongSelf dashboardParse]`, and the
`performSelectorOnMainThread:@selector(dashboardParse)` (`:771`) with the `refreshDashboard`
equivalent. Find them:
```bash
grep -n "dashboardParse" test1/GamesTableViewController.m
```
For the `performSelectorOnMainThread:@selector(dashboardParse)` site, use
`@selector(refreshDashboard)`.

- [ ] **Step 2: Repoint AppDelegate**

In `AppDelegate.m`, change the two `respondsToSelector:@selector(dashboardParse)` blocks
(`:250-253`, `:331-332`) to call `refreshDashboard`:
```objc
if ([navController.visibleViewController respondsToSelector:@selector(refreshDashboard)]) {
    [((GamesTableViewController *)(navController.visibleViewController)) refreshDashboard];
}
```
(Keep the existing surrounding structure; only the selector/name changes.)

- [ ] **Step 3: Build**

Run: the build-only command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run the test suite (unchanged, must stay green)**

Run: canonical test command. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add test1/GamesTableViewController.m test1/AppDelegate.m
git commit -m "feat(dashboard): route all dashboard refreshes through the service"
```

---

### Task 10: On-device verification checkpoint (owner)

- [ ] **Step 1: Owner runs the app on a real device/simulator and verifies:**
  - Initial dashboard load after login (all sections populate).
  - Pull-to-reload refreshes correctly.
  - Foreground refresh from background (AppDelegate path).
  - Messages list; tapping a push notification deep-links (parseMessages path intact).
  - Launch the board from an active-game cell.
  - Tournaments and King-of-the-Hill lists render with correct `tb-`/`Speed ` names.
  - Invitations: sent, received, open — accept/decline still work.
  - Avatars load when enabled; none load when disabled.
  - Live-players / online-following badges show correct counts.
  - Special characters in username/password still authenticate (URL encoding change).

- [ ] **Step 2: If a regression is found**, capture it and fix before proceeding to Phase 3.
  Do NOT delete the old code (Task 11) until this passes.

---

## Phase 3 — Delete dead code

### Task 11: Remove the old parse path

**Files:**
- Modify: `test1/GamesTableViewController.m` (delete `parseDashboard` `:3389-3930` and `dashboardParse` `:3327-3336`)

- [ ] **Step 1: Delete**

Remove `- (void)dashboardParse` and `- (void)parseDashboard` entirely. Keep `parseMessages`,
`messagesParse`, `showErrorAlertWithMessage:`, `updateSection:...`, `parseStoneColor`, and the
new `updateKothSectionWithItems:tbHills:`. Confirm nothing else references the deleted methods:
```bash
grep -n "dashboardParse\|parseDashboard" test1/GamesTableViewController.m test1/AppDelegate.m
```
Expected: no matches.

- [ ] **Step 2: Build + test**

Run: the build-only command, then the canonical test command. Expected: BUILD SUCCEEDED, tests PASS.

- [ ] **Step 3: Commit**

```bash
git add test1/GamesTableViewController.m
git commit -m "refactor(dashboard): delete legacy parseDashboard/dashboardParse"
```

- [ ] **Step 4 (optional): line-count sanity**

```bash
wc -l test1/GamesTableViewController.m
```
Expected: ~400+ fewer lines than the 5,006 baseline.

---

## Self-review notes (author)

- **Spec coverage:** Service (T1,3-7) ✓; endpoint+dev toggle (T5) ✓; transport wrapping PenteHTTPClient (T6) ✓; typed Dashboard returning ObjC objects (T1,4) ✓; flags + avatar list + NSUserDefaults handled by VC (T8) ✓; error type + invalidCredentials silent path (T1,7,8) ✓; AppDelegate entry point (T9) ✓; parseMessages untouched ✓; tests reuse PenteEngineTests + golden fixture (T2-7) ✓; phasing service→cutover→delete ✓; on-device verification (T10) ✓.
- **Type consistency:** `DashboardErrorCode` raw values (network=1, http=2, decoding=3, invalidCredentials=4) used consistently in T1/T7/T8. `DashboardMapping.map` / `DashboardService.loadDashboard(username:password:)` / `Transport.data(for:)` signatures match across tasks. `updateKothSectionWithItems:tbHills:` defined in T8, referenced in T8/T11.
- **Known faithfulness risks called out inline:** URL percent-encoding change (T5), verbatim badge + KOTH diff copy (T8), `LegacyPenteGame.getGameName` cast (T4), ObjC importer names for `sendRequest:completion:` and the async completion selector (T6/T8).
