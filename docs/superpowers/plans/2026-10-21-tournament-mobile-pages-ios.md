# Tournament Mobile Pages: iOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the in-app web view identify itself as the iOS app so the server serves the mobile layout for tournament and help pages.

**Architecture:** `PenteWebViewController` builds its `WKWebViewConfiguration` through one internal static factory that sets `applicationNameForUserAgent`. Everything else (layout, withdraw) is server-side.

**Tech Stack:** Swift, WebKit, XCTest (`PenteEngineTests` target, scheme `test1`, workspace `penteLive.xcworkspace`).

**Spec:** `pente.org/docs/superpowers/specs/2026-10-21-tournament-mobile-pages-design.md` (in the sibling `pente.org` repo). Server plan: `pente.org/docs/superpowers/plans/2026-10-21-tournament-mobile-pages-server.md`.

## Global Constraints

- User agent must contain the exact token `penteLive-iOS` (server check is a case-sensitive `contains`).
- `applicationNameForUserAgent` replaces WebKit's default suffix `Mobile/15E148`; keep it: value is exactly `Mobile/15E148 penteLive-iOS`.
- Only `PenteWebViewController` changes. The other plain `WKWebView`s (`BoardViewController.m:265`, `DatabaseViewController.m:199`, `MMAIViewController.m:159`) load local HTML and stay as they are.
- Must work on iPhone and iPad (see `penteLive-iOS/CLAUDE.md`).
- Commits signed (`git commit -S`), no co-author/generated-by lines, always `git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS`.
- Build/test scratch (derived data, screenshots) under `/private/tmp/claude-501/tourney-mobile/ios/`.
- The working tree on `main` holds an unrelated uncommitted change to `test1/GamesTableViewController.m` (tournament dot colour). Do not include it in this branch's commits; the controller settles it before execution starts.

## Review Focus

1. A pente.org link that opens a board replay (`?mobile&g=`, `gameServer/tb/game?gid=`) must still be intercepted after the configuration change → Task 2 Step 2 manual check.
2. iPad sends a desktop-mode user agent; the token must still be present there → Task 1 Step 6 runs the real-user-agent test on iPad. iPad (nav-bar controls) and iPhone (bottom toolbar) layouts unchanged → Task 2 runs both simulators.
3. Pages that did not opt in (profile, prefs) opened in this web view stay desktop → Task 2 Step 3.
4. Old app builds without the token keep getting the desktop pages (server's job; no iOS test).
5. None further found.

---

### Task 1: User agent token

**Files:**
- Modify: `test1/PenteWebViewController.swift:20` (`webView` stored property)
- Create: `PenteEngineTests/PenteWebViewConfigurationTests.swift` (add to the `PenteEngineTests` target, same way as `KidAccountsScreenTests.swift`)

**Interfaces:**
- Produces: `static func makeConfiguration() -> WKWebViewConfiguration` on `PenteWebViewController` (internal), used by the `webView` initializer.

- [ ] **Step 1: Branch** — `git -C … checkout -b tournament-mobile-pages` (leave the unrelated `GamesTableViewController.m` change unstaged).

- [ ] **Step 2: Write the failing test**

```swift
func testUserAgentCarriesAppToken() {
    let config = PenteWebViewController.makeConfiguration()
    XCTAssertEqual(config.applicationNameForUserAgent, "Mobile/15E148 penteLive-iOS")
}
```

- [ ] **Step 3: Run, expect FAIL**

`xcodebuild test -workspace /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS/penteLive.xcworkspace -scheme test1 -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath /private/tmp/claude-501/tourney-mobile/ios/dd SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests/PenteWebViewConfigurationTests 2>&1 | grep -E 'error:|Executed|TEST (SUCCEEDED|FAILED)'`
Expected: `error: type 'PenteWebViewController' has no member 'makeConfiguration'`. (If `iPhone 18 Pro` is not installed, use any available iPhone simulator and say which.)

- [ ] **Step 4: Implement** `makeConfiguration()` returning a fresh `WKWebViewConfiguration` with `applicationNameForUserAgent = "Mobile/15E148 penteLive-iOS"`; change the `webView` initializer to `WKWebView(frame: .zero, configuration: PenteWebViewController.makeConfiguration())` (explicit type name, keep `let`; `Self` is not allowed in a stored-property initializer).

- [ ] **Step 5: Run, expect PASS** — same command → `Executed 1 test, with 0 failures`, `TEST SUCCEEDED`.

- [ ] **Step 6: Add the real user-agent test.** iPadOS web views default to desktop browsing (Macintosh user agent), and it is unverified whether `applicationNameForUserAgent` is appended there. Add `testNavigatorUserAgentHasToken` to the same file: create a `WKWebView` with `makeConfiguration()`, `loadHTMLString("<html></html>", baseURL: nil)`, wait for navigation (XCTestExpectation via a small `WKNavigationDelegate`), `evaluateJavaScript("navigator.userAgent")`, assert the result contains `penteLive-iOS`. Run it on an iPhone simulator AND an iPad simulator (`-destination 'platform=iOS Simulator,name=<iPad model>'`). Expected: passes on both. If it fails on iPad, keep the token by setting `customUserAgent` on the web view to the default user agent plus ` penteLive-iOS` (read the default once via `evaluateJavaScript` before the first page load), update the tests to match, and report which path you took.

- [ ] **Step 7: Full suite** — run all `PenteEngineTests` (drop `-only-testing`) → `TEST SUCCEEDED`.

- [ ] **Step 8: Commit** (`project.pbxproj` needs a manual entry for the new test file; the project has no synced folders)

```bash
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS add docs/superpowers/plans/2026-10-21-tournament-mobile-pages-ios.md test1/PenteWebViewController.swift PenteEngineTests/PenteWebViewConfigurationTests.swift penteLive.xcodeproj/project.pbxproj
git -C /Users/waliedothman/mariposa/coding/pente.org-project/penteLive-iOS commit -S -m "Identify the in-app web view as penteLive-iOS"
```

---

### Task 2: Simulator E2E against the local backend

Requires the server plan's Tasks 2-4 deployed on the local stack.

**Files:** none committed. The app's `development` flag (points to `https://localhost`) is set locally only and reverted.

- [ ] **Step 1:** Run the app on an iPhone simulator with `development` on, logged in as `graviton` / `virginia`. Tap the registration-open tournament → page has no pente.org site header and fits the width.
- [ ] **Step 2:** Sign up → withdraw (confirm page → `Withdraw` → `You have withdrawn from …`) → sign up again. Tap the format rules link → mobile help page, no table of contents. Back button walks history back to the dashboard. A game link on a round page still opens the native board replay.
- [ ] **Step 3:** Tap the registration-closed (state 2, `status.jsp`) and started (state 3, `statusRound.jsp`) tournaments → mobile layout, no page-wide horizontal scroll. Open a profile from the dashboard → still the desktop layout (not opted in).
- [ ] **Step 4:** Repeat Step 1-2 on an iPad simulator.
- [ ] **Step 5:** Screenshots (`xcrun simctl io booted screenshot …`) to scratch; revert `development`; `git -C … status --porcelain` shows only the pre-existing `GamesTableViewController.m` change; delete `/private/tmp/claude-501/tourney-mobile/ios/dd`.
