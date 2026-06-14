# Dashboard Intake Module — Design

**Date:** 2026-06-14
**Status:** Approved (design); pending implementation plan
**Source:** Candidate 2 ("A Dashboard intake module") from the 2026-06-13 architecture review.
**Predecessor:** Candidate 1 (single Pente engine) — completed in PR #9. Same execution model (subagent-driven development + manual on-device verification) applies here.

## Problem

`GamesTableViewController.m` is ~5,006 lines. It does table-view UI **and** builds the
dashboard HTTP request **and** decodes the response JSON **and** maps it to model objects
**and** mutates the shared `PentePlayer.*` arrays **and** owns the failure alerts — all in
one ~540-line method (`parseDashboard`, `GamesTableViewController.m:3389-3930`). To change
the wire format you must also understand table-view diffing, `NSUserDefaults` keys, badge
updates, and `CATransaction`. None of the parsing is unit-testable — it needs a live
`UITableViewController`.

### Verified facts about the current code

- **One intake fetch.** `parseDashboard` issues a single GET to
  `mobile/json/index.jsp?name=&password=` via `PenteHTTPClient sendRequest:completion:`
  (AFNetworking-backed, completion on the main queue) and decodes it with
  `NSJSONSerialization`. That one response carries **everything**: the `player` block,
  king-of-the-hill, rating stats, sent/received invitations, active/non-active games,
  open invitations, messages, tournaments, and online players.
- **`parseMessages` is NOT a fetch.** Despite the name it does push-notification
  deep-link navigation (`receivedNotification` → segue to a game/invitation/message). It
  stays in the view controller, unchanged. Messages themselves are parsed *inside*
  `parseDashboard` from `jsonResponse[@"messages"]`.
- **Parsing is interleaved with UI.** Per section the method calls a helper
  `updateSection:newItems:oldItems:collapsed:setter:` (`:3362`) that performs incremental
  `insertRows`/`deleteRows`, wrapped in `CATransaction`, plus badge updates and bespoke
  KOTH/rating row diffing. The *parse → model* work is cleanly separable from this *UI
  update* work.
- The `tb/replyInvitation` and other action URLs are **write actions**, not intake.

## Goals

- A Swift `DashboardService` that owns request construction, the wire format, and decoding,
  returning a typed `Dashboard`. Headlessly unit-testable.
- The view controller calls one async method and applies the result: it keeps the
  `updateSection` diffing, badges, `NSUserDefaults`, `player.*` assignment, and alerts.
- `AppDelegate`'s foreground-refresh path calls one `@objc` entry point instead of
  downcasting the visible view controller.

## Non-goals

- The model classes (`Game`/`Message`/`Tournament`/`RatingStat`/`KingOfTheHill`) are **not**
  migrated. They stay ObjC in `PentePlayer.h/.m`, including their ~250 lines of date/emoji/
  attributed-string display logic, which is unrelated to the intake seam. The Swift service
  constructs these existing ObjC objects directly.
- The ~18 write/action HTTP calls (invitation replies, ads-preference, tournament actions,
  logout) stay in the view controller.
- Receipt/StoreKit logic stays in the VC/AppDelegate. The service only surfaces the
  relevant flag.
- No redesign of the games table UI, the section-diffing, or the badge logic.

## Decisions (from brainstorming)

| Decision | Choice |
|----------|--------|
| Scope | The single dashboard JSON intake (everything is in one response) |
| Language | Swift |
| Model boundary | **Hybrid** — service builds the existing ObjC `Game`/`Message`/etc objects; no model migration |
| Networking | `async`/`await`, wrapping the existing `PenteHTTPClient` behind a `Transport` protocol |
| Errors & effects | Pure service: throws typed `DashboardError`, returns flags + avatar-usernames in the result; VC owns alerts + `NSUserDefaults` + `player.*` + UI diffing |
| Test target | Reuse `PenteEngineTests` |

### Why hybrid (not a model migration)

`Game` is read in ~18 mostly-ObjC files, and `Game`/`Message` carry ~250 lines of display
logic (`localizedTimeString`, `attributedName`, `ratingString`, `replaceSmileys`).
Migrating them to Swift is large churn that serves none of the intake goal. Because ObjC
classes are fully usable from Swift, the service can `Game()` / `Message()` and set their
properties directly — the entire testable-parse win with zero consumer changes and zero
display-logic porting. The only thing that moves to Swift is the parse/mapping, which lives
in `parseDashboard`, not in the model classes.

## Architecture

```
DashboardService  (Swift, @objc, no UIKit view code; UIColor only)
  func loadDashboard() async throws -> Dashboard
    (ObjC sees the auto-bridged loadDashboardWithCompletionHandler:)

  ├─ DashboardEndpoint   builds the request URL; prod vs localhost via developmentEnabled()
  ├─ Transport (protocol) async data(for:); default impl wraps PenteHTTPClient; stub in tests
  ├─ DashboardWire (Codable, internal)  ──JSON decode──┐
  └─ DashboardMapping  map wire -> ObjC Game/Message/… ►  Dashboard (typed result)
        or throws DashboardError

GamesTableViewController (thinner)
  • refreshDashboard (@objc):  Task { let d = try await service.loadDashboard(); apply(d) }
                               catch -> map DashboardError to existing alert / silent reset
  • applyDashboard:  set flags + NSUserDefaults, badges, addUser for avatars,
                     updateSection diffing, KOTH/rating row animations, CATransaction
```

### Components

1. **`DashboardService`** (`@objc`) — the deep module. Public surface: `loadDashboard()
   async throws -> Dashboard`. Holds a `Transport` and a `DashboardEndpoint`. Everything
   else is its secret.
2. **`DashboardEndpoint`** — resolves prod vs `localhost` base URL via the existing
   `developmentEnabled()` bridge and builds the `name`/`password` GET. Replaces the
   duplicated `if (development)` URL pair.
3. **`Transport`** — `protocol Transport { func data(for: URLRequest) async throws ->
   (Data, URLResponse) }`. Default `PenteHTTPClientTransport` wraps
   `PenteHTTPClient.sendRequest:completion:` via `withCheckedThrowingContinuation`, keeping
   the AFNetworking session/SSL behavior. Tests inject a `StubTransport`.
4. **`DashboardWire`** (internal, `Codable`): `WireDashboard` + `WirePlayer`, `WireGame`,
   `WireMessage`, `WireTournament`, `WireRatingStat`, `WireHill`. All cross-key fields are
   **optional** — the legacy code treats missing keys as normal. Number-or-string fields use
   a small `FlexibleString` decoder to reproduce today's `stringValue` coercions
   (e.g. `mid`, `setId`, `opponentRating`).
5. **`DashboardMapping`** — the one place per-field reads/coercions live. Builds the ObjC
   model objects, faithfully reproducing: `parseStoneColor`, the `tb-`/`Speed ` game-name
   prefixing via `LegacyPenteGame.getGameName`, `UIColorFromRGB` (as a Swift helper),
   `"%@ days per move"` formatting, read/unread, crown/tourney-winner ints, and the
   `tbHills`/`tbRatings` counts.
6. **`Dashboard`** (`@objc` result class) — typed aggregate the ObjC VC consumes:
   `sentInvitations`, `invitations`, `activeGames`, `nonActiveGames`, `publicInvitations`,
   `messages`, `tournaments`, `hills` (arrays of the ObjC model objects), `ratingStats`,
   `onlinePlayers`, plus a `DashboardFlags` value and `avatarUsernames` (names the VC should
   `addUser:` when avatars are enabled and the name color isn't black).
7. **`DashboardFlags`** (`@objc`) — `myColorRGB`, `playerName`, `showAds`, `subscriber`,
   `dbAccess`, `emailMe`, `personalizeAds`, `tbHills`, `tbRatings`, `livePlayers`,
   `onlineFollowing`. The VC applies these to `player` and `NSUserDefaults`.
8. **`DashboardError`** (`@objc`-compatible `enum`/`NSError`) — see Error handling.

## Data flow

1. A trigger (foreground, pull-to-refresh, post-action) calls `[self refreshDashboard]`.
2. `refreshDashboard` runs a `Task`; `await service.loadDashboard()`.
3. Service builds the endpoint, awaits `Transport.data(for:)`, checks HTTP status, decodes
   `WireDashboard`, and maps to a `Dashboard` of ObjC model objects + flags + avatar list.
   Returns it, or throws `DashboardError`.
4. On the main actor the VC `applyDashboard:` — flags, `NSUserDefaults`, badges, `addUser`,
   the `updateSection` diffing per section, KOTH/rating row animations, `CATransaction`,
   `reloadData`.
5. On `throws`, the VC maps `DashboardError` to the existing alert, or — for
   `.invalidCredentials` (the legacy "missing `invitationsReceived` key") — to the current
   silent border-reset.

## Error handling

```swift
enum DashboardError: Error {
    case network(Error)            // transport failure  (legacy: showErrorAlertWithMessage)
    case http(status: Int)         // non-200
    case decoding(Error)           // malformed JSON     (legacy: showErrorAlertWithMessage)
    case invalidCredentials        // missing invitationsReceived key (legacy: silent reset)
}
```

The service never presents UI. Receipt/StoreKit handling stays in the VC/AppDelegate.

## Threading

`async`/`await` replaces the `dashboardParse` detached `NSThread` wrapper. `Transport` runs
off-main (the continuation resumes from `PenteHTTPClient`'s main-queue completion, which is
fine — decoding/mapping are cheap). All UI mutation happens on the main actor in
`applyDashboard:`.

## Integration points

- The ~12 `[self dashboardParse]` calls become `[self refreshDashboard]`.
- `AppDelegate.m:250-253` and `:331-332`: call `[vc refreshDashboard]` (keep the existing
  `respondsToSelector:` guard) instead of `dashboardParse`. No behavior change.
- `parseMessages` (notification navigation) is untouched.
- `developmentEnabled()` selects prod vs `localhost` inside `DashboardEndpoint`.

## Testing

Reuse the `PenteEngineTests` target.

- **Golden fixture:** capture a real `json/index.jsp` response as a checked-in JSON file.
  A characterization test asserts the Swift mapping reproduces the field values the legacy
  ObjC parse produced (same corpus discipline that de-risked the engine migration).
- **Network-free layered tests:** fixture string → decode → map → assert the `Dashboard`
  (game ids, colors, ratings, `tb-`/`Speed ` names, read/unread, tbHills/tbRatings, flags).
  Edge cases: missing optional keys, number-as-string coercions, empty arrays, malformed
  JSON → `DashboardError.decoding`, missing `invitationsReceived` → `.invalidCredentials`.
- **Service-level:** inject a `StubTransport` to drive `loadDashboard()` end-to-end
  headlessly, including the non-200 → `DashboardError.http` path. (`UIColor` is fine in
  unit tests; the service has no view code.)

## Phasing

Each phase ends on a green build + green tests.

1. **Service + tests** — add `Dashboard`/`DashboardFlags`/`DashboardError`,
   `DashboardEndpoint`, `Transport` + `PenteHTTPClientTransport`, `DashboardWire`,
   `DashboardMapping`, `DashboardService`, and the fixture-driven tests. Not yet wired in.
2. **Cutover** — replace `parseDashboard`'s body with `refreshDashboard` (calls the
   service) + `applyDashboard:` (keeps the existing UI diffing). Repoint the ~12 callers
   and the two AppDelegate sites. On-device verify.
3. **Delete** — remove the dead parse code (the old request-building + JSON loops) and the
   `dashboardParse` detached-thread wrapper once `refreshDashboard` fully replaces it.

## Risks & verification

- The mapping must be byte-faithful to the legacy field reads; the golden fixture test is
  the guard.
- The UI diffing stays in the VC, so the table-animation behavior is unchanged by
  construction.
- On-device verification after cutover (manual, by owner): live dashboard refresh,
  pull-to-reload, foreground refresh from background, messages list, launching the board
  from a game cell, tournaments and king-of-the-hill lists, invitations (sent/received/
  open), avatar loading, the badge counts.

## Build facts (carried from the engine migration)

- Every `xcodebuild` must append `SWIFT_ENABLE_EXPLICIT_MODULES=NO` (else
  `module 'CocoaAsyncSocket' not found`).
- Use `-destination 'platform=iOS Simulator,name=iPhone 17'` (no iPhone 16 installed).
- Canonical test command:
  `xcodebuild test -workspace penteLive.xcworkspace -scheme test1 -destination
  'platform=iOS Simulator,name=iPhone 17' SWIFT_ENABLE_EXPLICIT_MODULES=NO
  -only-testing:PenteEngineTests`
- Adding files to Xcode targets is headless via the `xcodeproj` gem (group-relative refs)
  or `Scripts/add_swift_file.rb`.
