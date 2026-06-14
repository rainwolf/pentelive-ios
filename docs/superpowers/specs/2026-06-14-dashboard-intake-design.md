# Dashboard Intake Module — Design

**Date:** 2026-06-14
**Status:** Approved (design); pending implementation plan
**Source:** Candidate 2 ("A Dashboard intake module") from the 2026-06-13 architecture review.
**Predecessor:** Candidate 1 (single Pente engine) — completed in PR #9. Same execution model (subagent-driven development + manual on-device verification) applies here.

## Problem

`GamesTableViewController.m` is ~5,006 lines. It does table-view UI **and** builds HTTP
requests **and** decodes the dashboard JSON **and** mutates the shared `PentePlayer.*`
arrays **and** owns the failure alerts. To change one feature you must hold table-view
protocols, the wire format, `NSUserDefaults` keys, and the data model in your head at
once. None of the parsing is unit-testable — it needs a live `UITableViewController`.

Concretely:
- `parseDashboard` (`GamesTableViewController.m:3389-3940`) runs on a detached `NSThread`,
  builds a GET to `mobile/json/index.jsp?name=&password=`, decodes it with
  `NSJSONSerialization`, reads ~30 keys, constructs `Game`/`Message`/`Tournament`/
  `RatingStat`/`KingOfTheHill` objects, mutates `self.player.*`, sets flags
  (`subscriber`, `showAds`, `emailMe`, `personalizeAds`, `tbHills`), writes
  `NSUserDefaults` (e.g. `showOnlyTB`), and finally `reloadData` on the main queue.
- `parseMessages` (`:3941+`) is a thin second intake path.
- ~12 `[self dashboardParse]` call sites trigger this.
- `AppDelegate.m:250-253` and `:331-332` downcast the visible view controller to
  `GamesTableViewController` just to poke `dashboardParse` — a view-hierarchy reach-around.

### Scope clarification (verified against the code)

The architecture report framed this as "30 HTTP requests + string-matching dispatch."
In reality the **read-intake** is essentially a single JSON fetch: `parseDashboard`
decodes active/non-active games, invitations, public invitations, tournaments,
rating stats, and king-of-the-hill from **one** `json/index.jsp` response, plus the
secondary `parseMessages` fetch. The `tb/replyInvitation` URLs are **write actions**
(accept/decline), not intake, and are out of scope. Only ~8 `rangeOfString:` calls
exist, used for status/error checks, not as the main parse mechanism (which is JSON).

## Goals

- A `DashboardService` that owns request construction, the wire format, and decoding,
  returning a typed result. UIKit-free and fully unit-testable headlessly.
- The view controller calls one method and renders the result; it owns alerts, flag
  application, `NSUserDefaults`, and `player.*` assignment.
- `AppDelegate`'s foreground-refresh path calls a single `@objc` entry point instead of
  spelunking the view hierarchy.

## Non-goals

- The ~18 write/action HTTP calls (invitation replies, ads-preference, tournament
  actions, logout) stay in the view controller for now.
- Receipt/StoreKit/purchase logic stays in the VC/AppDelegate. The service only surfaces
  the `shouldSendReceipt` flag; it does not validate receipts.
- No unrelated UI redesign of the games table.

## Decisions (from brainstorming)

| Decision | Choice |
|----------|--------|
| Scope | All read-intake — which collapses to the single dashboard JSON fetch + messages fetch |
| Language | Swift |
| Model migration | **Migrate everything** — `Game`/`Message`/`Tournament`/`RatingStat`/`KingOfTheHill` become Swift, app-wide |
| Networking | `async`/`await` (URLSession) |
| Errors & effects | Pure service: throws typed `DashboardError`, returns flags in the model; VC owns alerts + `NSUserDefaults` + `player.*` |
| Test target | Reuse `PenteEngineTests` |

### Why `@objc` Swift classes, not pure structs, for the migrated models

`Game` is read in **18 files**, most of them ObjC (`.m`): `BoardViewController`,
`AISetupView`, `ArenaTableSetupView`, `DBSetupView`, `DatabaseViewController`,
`MessagesViewController`, `InvitationsViewController`, `MMAIViewController`, etc. Pure
Swift structs are invisible to ObjC. To migrate the models app-wide *without* also
rewriting all 18 consumers into Swift, the migrated types are **`@objc` Swift classes**
(NSObject subclasses) with the **same property names/getters** as today's `@interface`
declarations, so ObjC call sites compile unchanged. Pure `Codable` value structs are
used **inside** the service for parsing and are mapped to these `@objc` classes.

## Architecture

```
DashboardService  (Swift, UIKit-free, async/await)
  func loadDashboard() async throws -> Dashboard
  func loadMessages()  async throws -> [Message]

  ├─ DashboardEndpoint    builds request URLs; prod vs localhost via developmentEnabled()
  ├─ Transport (protocol) wraps URLSession; stubbable in tests
  ├─ Wire<…> Codable structs (internal)  ──JSON decode──┐
  └─ map(WireX -> X)  ───────────────────────────────────►  @objc model classes
        returns Dashboard { games, invitations, publicInvitations,
                            tournaments, ratingStats, hills, flags, livePlayers, … }
        or throws DashboardError

GamesTableViewController (thinner)
  • refresh():  Task { let d = try await service.loadDashboard(); apply(d) }
  • apply(_:):  flags + NSUserDefaults, assign player.* arrays, reloadData on main
  • owns ALL UIAlerts  (DashboardError -> alert)
  • @objc refreshDashboard  — single entry AppDelegate calls
```

### Components

1. **`DashboardService`** — the deep module. Public surface is two async methods plus the
   `Dashboard` result and `DashboardError`. Everything else (endpoints, transport, wire
   structs, mapping) is its secret.
2. **`DashboardEndpoint`** — resolves prod vs `localhost` base URLs (replacing the
   duplicated `if (development)` URL pairs) via the existing `developmentEnabled()` bridge,
   and builds the `name`/`password` query.
3. **`Transport`** — a thin protocol over `URLSession` (`func data(for:) async throws ->
   (Data, URLResponse)`), so service tests inject a stub.
4. **Wire structs** (internal, `Codable`): `WireDashboard`, `WireGame`, `WireMessage`,
   `WireTournament`, `WireRatingStat`, `WireHill`, `WireFlags`. All cross-key fields
   **optional** — the legacy code treats missing keys (e.g. `invitationsReceived`) as
   normal, not an error.
5. **Mapping** (`map(WireX) -> X`) — the one place per-field reads and coercions live.
   Faithfully preserves today's quirks: JSON-number→string coercions (e.g. `mid` →
   `stringValue` for `messageID`), color/rated normalization, crown / tourney-winner
   flags, time formatting inputs.
6. **`Dashboard`** — typed aggregate: the model arrays plus a `DashboardFlags` value
   (`subscriber`, `showAds`, `emailMe`, `personalizeAds`, `tbHills`, `showOnlyTB`,
   `shouldSendReceipt`).
7. **Migrated `@objc` model classes** — `Game`, `Message`, `Tournament`, `RatingStat`,
   `KingOfTheHill` move out of `PentePlayer.h` into Swift, same property names.

## Data flow

1. A trigger (foreground, pull-to-refresh, post-action) calls VC `refresh()`.
2. `refresh()` runs a `Task`; `await service.loadDashboard()`.
3. Service builds the endpoint, awaits `Transport.data(for:)` off-main, checks the HTTP
   status, decodes `WireDashboard`, maps to the `@objc` models, returns `Dashboard`.
4. Back on the main actor the VC `apply(d)`: sets flags, writes `NSUserDefaults`, assigns
   `player.*` arrays, `reloadData()`.
5. On `throws`, the VC maps `DashboardError` to the existing alert for that condition.

## Error handling

```swift
enum DashboardError: Error {
    case network(URLError)        // transport failure
    case http(status: Int)        // non-200 (replaces rangeOfString:@"HTTP Error")
    case decoding(Error)          // malformed JSON
    case invalidCredentials       // server rejected name/password
    case serverMessage(String)    // server-supplied user-facing text
}
```

The service never presents UI. Each case maps to the alert the VC shows today.
StoreKit "invalid receipt" handling stays in the VC/AppDelegate; the service only
forwards the `shouldSendReceipt` flag.

## Threading

The detached-`NSThread` + synchronous request + `performSelectorOnMainThread` pattern is
replaced by `async`/`await`. URLSession runs off-main; UI mutation (`player.*`,
`reloadData`, alerts) happens on the main actor after the `await`.

## Integration points

- The ~12 `[self dashboardParse]` calls collapse to a single VC `refresh()`.
- `parseMessages` → `service.loadMessages()`, same shape.
- `AppDelegate.m:250-253` and `:331-332`: keep a thin `@objc` `-(void)refreshDashboard`
  on the VC; AppDelegate calls it directly instead of downcasting `visibleViewController`.
  No behavior change, no view-hierarchy reach-around.
- `developmentEnabled()` selects prod vs `localhost` inside `DashboardEndpoint`.

## Testing

Reuse the `PenteEngineTests` target.

- **Golden fixtures:** capture real `json/index.jsp` and messages responses as
  checked-in JSON. A characterization test asserts the Swift mapping reproduces the same
  field values the legacy ObjC parse produced — the corpus discipline that de-risked the
  engine migration.
- **Network-free layered tests:** feed a fixture string → decode → map → assert
  `Dashboard`. Edge cases: missing optional keys, JSON-number-as-string coercions, empty
  arrays, malformed JSON → `DashboardError.decoding`.
- **Service-level:** inject a stub `Transport` to drive `loadDashboard()` end-to-end
  headlessly, including the non-200 → `DashboardError.http` path.

## Phasing

Each phase ends on a green build.

1. **Models to Swift** — replace the ObjC `Game`/`Message`/`Tournament`/`RatingStat`/
   `KingOfTheHill` `@interface`s with `@objc` Swift classes (identical property names).
   Mechanical, app-wide (~18 files), highest churn — isolate it. Build-green checkpoint.
2. **Service + tests** — add `DashboardService`, `DashboardEndpoint`, `Transport`, wire
   structs, mapping, and fixtures. Not yet wired into the VC.
3. **Cutover** — route `dashboardParse`/`parseMessages` and the AppDelegate refresh
   through the service; VC applies flags/arrays/alerts; delete the old threading.
4. **Delete** — remove dead ObjC parsing and the old `@interface` declarations.

## Risks & verification

- Phase 1's blast radius is the **consumers** of `Game` (18 files), not the parse logic.
  A compile error in any consumer is the main failure mode; the `@objc`-same-property
  approach keeps call sites unchanged.
- On-device verification after cutover (manual, by owner): live dashboard refresh,
  messages, foreground refresh from background, database views, launching the board from
  a game cell, tournaments and king-of-the-hill lists, invitations.

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
