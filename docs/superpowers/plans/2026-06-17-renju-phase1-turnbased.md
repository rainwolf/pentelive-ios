# Renju (Taraguchi-10) — Phase 1: Turn-Based iOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the Taraguchi-10 Renju opening + play into the iOS **turn-based (correspondence)** path — the Objective-C `BoardViewController` stack — driven by the server-shipped `renjuPhase`, plus the **shared Swift engine foundation** both transports need.

**Architecture:** Phase 1 = §11 of `docs/renju-handoff.md` (turn-based) + the shared engine work that §11 depends on. The TB board renders by replaying `moves` through the shared Swift `PenteGame` engine (`[engine replay:]` at `BoardViewController.m:2542` → `loadEngineIntoAbstractBoard` at `:2473`), so **black-first colour and 15×15 sizing live in the engine** (`RuleSet`/`PenteGame`) and are required here, not deferred to the live phase. The server is authoritative for all Renju legality (central squares, forbidden points, offer symmetry); the client **reads** `renjuPhase` and **submits** `&renjuAction=` — no client-side phase derivation on this path. Phase 2 (live / §9) reuses this same engine foundation.

**Tech Stack:** Swift + Objective-C interop (`penteLive-Swift.h` for ObjC→Swift; bridging header for Swift→ObjC), XCTest (`PenteEngineTests` target), `xcodebuild`, CocoaPods workspace (`penteLive.xcworkspace`, app scheme `test1`, product/module name `penteLive`).

---

## Build / Test Commands (memorize — used in every task)

**Run engine tests** (fast, headless — use for every Swift foundation task):
```bash
xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO -only-testing:PenteEngineTests
```
Run a single class/method: append `-only-testing:PenteEngineTests/<Class>/<method>`.

**Compile the whole app** (use after every ObjC task — ObjC UI is not unit-tested):
```bash
xcodebuild build -workspace penteLive.xcworkspace -scheme test1 \
  -destination 'platform=iOS Simulator,name=iPhone 17' SWIFT_ENABLE_EXPLICIT_MODULES=NO
```

**Gotchas (from prior plans, confirmed):**
- Always append `SWIFT_ENABLE_EXPLICIT_MODULES=NO` (else `module 'CocoaAsyncSocket' not found`).
- Only `iPhone 17` simulator is installed (no iPhone 16).
- SourceKit in-editor "No such module 'XCTest'/'UIKit'" / "Cannot find type" are FALSE ALARMS — they resolve at `xcodebuild` time. Trust the build, not the editor.
- Adding `case renju = 11` to `PenteVariant` breaks compilation at two exhaustive `switch`es with no `default` (`ruleSet(for:)`, `backgroundColor(for:boatPente:)`). Task 1 adds the enum case AND both arms together so the tree stays buildable.

## File Map (Phase 1)

| File | Responsibility | Tasks |
|---|---|---|
| `test1/PenteEngine/PenteVariant.swift` | add `case renju = 11` | 1 |
| `test1/PenteEngine/RuleSet.swift` | `boardSize` on protocol, `Cadence.blackFirst`, `RenjuRules`, `ruleSet` arm | 1 |
| `test1/PenteEngine/PenteGame.swift` | black-first cadence, board-size-aware indexing | 2 |
| `test1/BoardVariantMapping.swift` | `.renju` → `#D98880`; `variantForGameType` Renju branch | 1, 4 |
| `PenteEngineTests/PenteVariantTests.swift` / `RuleSetTests.swift` / `PenteGameEngineTests.swift` / `BoardVariantMappingTests.swift` | foundation tests | 1, 2 |
| `test1/PenteEngine/RenjuOfferSymmetry.swift` (NEW) | D4 dedup pure helper | 3 |
| `PenteEngineTests/RenjuOfferSymmetryTests.swift` (NEW) | dedup tests | 3 |
| `test1/SocialViewController.swift` | register ids 31/32/81 (name + picker) | 5 |
| `test1/BoardViewController.m/.h` | gridSize=15, coord math, JSON parse, submit `renjuAction`, opening UI | 6, 7, 8, 9 |
| `test1/BoardView.m` | 15×15 star points | 6 |

---

## Task 1: Shared engine foundation — `.renju` variant, RuleSet, colour (keeps build green)

**Files:**
- Modify: `test1/PenteEngine/PenteVariant.swift:6-18`
- Modify: `test1/PenteEngine/RuleSet.swift` (protocol `:14-23`, add struct, `ruleSet(for:)` `:114-128`)
- Modify: `test1/BoardVariantMapping.swift:33-61`
- Test: `PenteEngineTests/PenteVariantTests.swift`, `PenteEngineTests/RuleSetTests.swift`, `PenteEngineTests/BoardVariantMappingTests.swift`

- [ ] **Step 1: Write the failing tests**

In `PenteEngineTests/PenteVariantTests.swift`, add inside the class:
```swift
    func testRenjuRawValueIsEleven() {
        XCTAssertEqual(PenteVariant.renju.rawValue, 11)
    }
```

In `PenteEngineTests/RuleSetTests.swift`, add:
```swift
    func testRenju() {
        let r = ruleSet(for: .renju)
        XCTAssertNil(r.capture)          // Gomoku-like: no captures
        XCTAssertEqual(r.poof, .none)
        XCTAssertEqual(r.winLength, 5)
        XCTAssertEqual(r.opening, .none)  // opening squares enforced server-side / UI, not engine mask
        XCTAssertEqual(r.cadence, .blackFirst)
        XCTAssertEqual(r.boardSize, 15)
    }

    func testNonRenjuBoardSizeDefaultsTo19() {
        XCTAssertEqual(ruleSet(for: .pente).boardSize, 19)
        XCTAssertEqual(ruleSet(for: .gomoku).boardSize, 19)
    }
```

In `PenteEngineTests/BoardVariantMappingTests.swift`, add:
```swift
    func testRenjuBackgroundColorIsDustyRose() {
        let c = BoardVariantMapping.backgroundColor(for: .renju, boatPente: false)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Double(r), 0.851, accuracy: 0.001)   // #D98880
        XCTAssertEqual(Double(g), 0.533, accuracy: 0.001)
        XCTAssertEqual(Double(b), 0.502, accuracy: 0.001)
        XCTAssertEqual(Double(a), 1.0, accuracy: 0.001)
    }
```

- [ ] **Step 2: Run tests to verify they fail to compile**

Run the engine test command. Expected: COMPILE FAILURE — `type 'PenteVariant' has no member 'renju'`. (This is the red state.)

- [ ] **Step 3: Add the enum case**

In `test1/PenteEngine/PenteVariant.swift`, after `case connect6 = 10`:
```swift
    case connect6 = 10
    /// Renju (Taraguchi-10). 15×15, black-first, no captures. Raw value 11 = next free.
    case renju = 11
```

- [ ] **Step 4: Add `boardSize` to the RuleSet protocol with a 19 default, the black-first cadence, and `RenjuRules`**

In `test1/PenteEngine/RuleSet.swift`:

Extend the `Cadence` enum (`:10`):
```swift
/// Move-colour cadence.
enum Cadence { case alternating, connect6, blackFirst }
```

Add `boardSize` to the protocol (`:14-23`), after `var cadence: Cadence { get }`:
```swift
    var cadence: Cadence { get }
    /// Board edge length. 19 for the Pente/Go family; 15 for Renju.
    var boardSize: Int { get }
}

/// Default board size: every legacy variant is 19×19. Only Renju overrides.
extension RuleSet { var boardSize: Int { 19 } }
```

Add the recipe after `GomokuRules` (`:103`):
```swift
struct RenjuRules: RuleSet {
    let capture: (run: Int, threshold: Int)? = nil   // Gomoku-like, no captures
    let poof: PoofKind = .none
    let winLength: Int = 5
    let opening: OpeningMask = .none   // central squares enforced server-side + in TB UI gate
    let cadence: Cadence = .blackFirst
    let boardSize: Int = 15
}
```

Add the arm to `ruleSet(for:)` (`:114-128`), before the closing brace:
```swift
    case .connect6:   return Connect6Rules()
    case .renju:      return RenjuRules()
    }
```

- [ ] **Step 5: Add the `.renju` colour case (the second exhaustive switch)**

In `test1/BoardVariantMapping.swift`, inside `backgroundColor(for:boatPente:)` (`:35-60`), before the closing `}` of the switch:
```swift
        case .connect6:
            return UIColor(red: 0.929, green: 0.639, blue: 0.992, alpha: 1)
        case .renju:
            // #D98880 dusty rose — canonical Renju board colour, distinct from gomoku.
            return UIColor(red: 0.851, green: 0.533, blue: 0.502, alpha: 1)
        }
```

- [ ] **Step 6: Run tests to verify they pass**

Run the engine test command. Expected: PASS, including `testRenjuRawValueIsEleven`, `testRenju`, `testNonRenjuBoardSizeDefaultsTo19`, `testRenjuBackgroundColorIsDustyRose`, and the full existing suite still green (the `Cadence` enum gained a case — confirm no other exhaustive `Cadence` switch broke; `colorForMove` is patched in Task 2, so a non-exhaustive-switch error there is expected and fixed next).

> NOTE: `colorForMove` in `PenteGame.swift` switches `Cadence` without a default. Adding `.blackFirst` makes it non-exhaustive → a compile error in Task 2's file. If Step 6 fails ONLY with "switch must be exhaustive" in `PenteGame.swift:colorForMove`, proceed to Task 2 (it fixes exactly that); the Task 1 tests are otherwise correct.

- [ ] **Step 7: Commit**
```bash
git add test1/PenteEngine/PenteVariant.swift test1/PenteEngine/RuleSet.swift test1/BoardVariantMapping.swift PenteEngineTests/PenteVariantTests.swift PenteEngineTests/RuleSetTests.swift PenteEngineTests/BoardVariantMappingTests.swift
git commit -m "feat(renju): add .renju variant, RenjuRules, board colour foundation"
```

---

## Task 2: Engine — black-first cadence + 15×15 board-size-aware indexing

**Files:**
- Modify: `test1/PenteEngine/PenteGame.swift` (`:13-45`, `:94-101`, `:104-108`)
- Test: `PenteEngineTests/PenteGameEngineTests.swift`

- [ ] **Step 1: Write the failing tests**

In `PenteEngineTests/PenteGameEngineTests.swift`, add:
```swift
    func testRenjuFirstStoneIsBlack() {
        let g = PenteGame(variant: .renju)
        _ = g.play(112)                       // server auto-centre
        XCTAssertEqual(g.stone(at: 112), 2)   // black-first: move 0 -> value 2
    }

    func testRenjuSecondStoneIsWhite() {
        let g = PenteGame(variant: .renju)
        _ = g.play(112)
        _ = g.play(113)
        XCTAssertEqual(g.stone(at: 113), 1)   // move 1 -> value 1 (white)
    }

    func testRenjuUses15x15Indexing() {
        let g = PenteGame(variant: .renju)
        _ = g.play(224)                       // last cell (col14,row14) on 15×15
        XCTAssertEqual(g.stone(at: 224), 2)
        XCTAssertEqual(g.stone(at: 225), 0)   // out of range on 15×15 -> treated empty
    }

    func testRenjuHasNoCaptures() {
        // Layout that WOULD capture in Pente: B(112) W(113) W(114) B(115) collinear (row 7).
        let g = PenteGame(variant: .renju)
        _ = g.play(112)   // B  (m0)
        _ = g.play(113)   // W  (m1)
        _ = g.play(200)   // B  (m2, off to the side)
        _ = g.play(114)   // W  (m3)
        _ = g.play(115)   // B  (m4) flanks the W pair
        XCTAssertEqual(g.stone(at: 113), 1)   // NOT captured
        XCTAssertEqual(g.stone(at: 114), 1)   // NOT captured
    }

    func testNonRenjuEngineUnchangedFirstStoneWhite() {
        let g = PenteGame(variant: .pente)
        _ = g.play(180)
        XCTAssertEqual(g.stone(at: 180), 1)   // legacy white-first preserved (19×19)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run the engine test command. Expected: COMPILE FAILURE (`switch must be exhaustive` in `colorForMove`) and/or the new renju assertions failing.

- [ ] **Step 3: Add a `boardSize` accessor and make indexing size-aware**

In `test1/PenteEngine/PenteGame.swift`, add a computed accessor after the stored properties (`:11`):
```swift
    @objc private(set) var blackCaptures: Int = 0

    /// Board edge length from the active recipe (15 for Renju, else 19).
    private var boardSize: Int { rules.boardSize }
```

In `init` (`:13-17`), size the board from the recipe:
```swift
    @objc init(variant: PenteVariant) {
        let recipe = ruleSet(for: variant)
        self.rules = recipe
        self.board = Array(repeating: Array(repeating: 0, count: recipe.boardSize),
                           count: recipe.boardSize)
        super.init()
    }
```

In `reset` (`:19-24`):
```swift
    @objc func reset() {
        board = Array(repeating: Array(repeating: 0, count: boardSize), count: boardSize)
        moveCount = 0
        whiteCaptures = 0
        blackCaptures = 0
    }
```

In `stone(at:)` (`:27-32`):
```swift
    @objc func stone(at rowCol: Int) -> Int {
        let cells = boardSize * boardSize
        guard rowCol >= 0 && rowCol < cells else { return 0 }
        return board[rowCol / boardSize][rowCol % boardSize]
    }
```

In `play(_:)` guard + placement (`:37-45`):
```swift
        let cells = boardSize * boardSize
        guard move >= 0 && move < cells else {
            return MoveResult(captured: [], poofed: false, winner: 0, placed: 0)
        }
        let placedColor = colorForMove(moveCount)
        clearOpeningMask()
        board[move / boardSize][move % boardSize] = placedColor
```

In `apply(_:)` (`:104-108`):
```swift
    private func apply(_ removed: [Capture]) {
        for cap in removed {
            board[cap.position / boardSize][cap.position % boardSize] = 0
            if cap.color == 1 { whiteCaptures += 1 } else { blackCaptures += 1 }
        }
    }
```

(Leave `clearOpeningMask`/`maskTournamentOpening`/`maskGPenteOpening` as-is with literal `19` — they run ONLY for `.tournament`/`.gpente` openings, which are 19×19 variants; Renju's `.none` opening never enters them.)

- [ ] **Step 4: Add the black-first cadence to `colorForMove`**

In `colorForMove(_:)` (`:94-101`):
```swift
    private func colorForMove(_ index: Int) -> Int {
        switch rules.cadence {
        case .alternating:
            return (index % 2) + 1
        case .connect6:
            return (((index % 4) == 0) || ((index % 4) == 3)) ? 1 : 2
        case .blackFirst:
            return 2 - (index % 2)   // move 0 -> 2 (black), move 1 -> 1 (white)
        }
    }
```

- [ ] **Step 5: Run tests to verify they pass**

Run the engine test command. Expected: PASS for all new renju tests AND the full existing suite (corpus, scan, etc.) still green.

- [ ] **Step 6: Commit**
```bash
git add test1/PenteEngine/PenteGame.swift PenteEngineTests/PenteGameEngineTests.swift
git commit -m "feat(renju): black-first cadence + 15x15 board-size-aware engine indexing"
```

---

## Task 3: D4 offer-symmetry dedup — pure Swift helper (UX nicety, server is authority)

**Files:**
- Create: `test1/PenteEngine/RenjuOfferSymmetry.swift`
- Test: `PenteEngineTests/RenjuOfferSymmetryTests.swift`
- After creating, **add both files to the Xcode targets** (see Step 5).

Mirrors the server's `renjuRotate`/`renjuStabilizer`/`renjuIsSymmetricDup` (§9.5/§11.5). 15×15, centre `(7,7)`.

- [ ] **Step 1: Write the failing tests**

Create `PenteEngineTests/RenjuOfferSymmetryTests.swift`:
```swift
import XCTest
@testable import penteLive

final class RenjuOfferSymmetryTests: XCTestCase {
    // centre = 112 = (7,7). 113 = (8,7) -> dx=1,dy=0.
    func testEightImagesOfAnAxisPoint() {
        // (1,0) orbit under D4 = {(±1,0),(0,±1)} -> 4 distinct cells.
        let images = RenjuOfferSymmetry.d4Images(of: 113)
        let expected: Set<Int> = [113,            // (1,0)
                                  111,            // (-1,0)
                                  112 + 15,       // (0,1) = 127
                                  112 - 15]       // (0,-1) = 97
        XCTAssertEqual(images, expected)
    }

    func testAddingSymmetricDuplicateIsRejected() {
        var accepted = Set<Int>()
        XCTAssertTrue(RenjuOfferSymmetry.tryAccept(113, into: &accepted))   // (1,0)
        XCTAssertFalse(RenjuOfferSymmetry.tryAccept(111, into: &accepted))  // (-1,0) is a D4 image -> reject
        XCTAssertFalse(RenjuOfferSymmetry.tryAccept(127, into: &accepted))  // (0,1) image -> reject
        XCTAssertTrue(RenjuOfferSymmetry.tryAccept(114, into: &accepted))   // (2,0) different orbit -> ok
    }

    func testDiagonalOrbitHasFourImages() {
        // 128 = (8,8) -> dx=1,dy=1. D4 orbit = {(±1,±1)} -> 4 cells.
        XCTAssertEqual(RenjuOfferSymmetry.d4Images(of: 128).count, 4)
    }

    func testGenericOrbitHasEightImages() {
        // 130 = (10,8) -> dx=3,dy=1. Generic orbit -> 8 distinct cells.
        XCTAssertEqual(RenjuOfferSymmetry.d4Images(of: 130).count, 8)
    }

    func testTenValidOffersAllAccepted() {
        // The §9.4 example set: offsets (1,0)(2,0)(3,0)(4,0)(1,1)(2,1)(3,1)(4,1)(2,2)(3,2).
        let offers = [113,114,115,116, 128,129,130,131, 144,145]
        var accepted = Set<Int>()
        for m in offers { XCTAssertTrue(RenjuOfferSymmetry.tryAccept(m, into: &accepted), "\(m)") }
        XCTAssertEqual(accepted.count >= offers.count, true)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run the engine test command. Expected: COMPILE FAILURE — `cannot find 'RenjuOfferSymmetry' in scope`.

- [ ] **Step 3: Implement the helper**

Create `test1/PenteEngine/RenjuOfferSymmetry.swift`:
```swift
import Foundation

/// Client-side D4 symmetry dedup for Branch-B 5th-move offers (15×15, centre (7,7)).
/// Mirrors the server's renjuRotate/renjuStabilizer/renjuIsSymmetricDup so the client
/// agrees with `offerFifthMove`. UX nicety only — the server rejects violations anyway.
@objc final class RenjuOfferSymmetry: NSObject {
    static let size = 15
    static let centre = 7   // (7,7) on a 15×15 board

    /// The set of D4 images (rotations + reflections) of `move`, INCLUDING `move` itself.
    /// Off-board images are dropped (cannot occur for in-bounds offers, but safe).
    static func d4Images(of move: Int) -> Set<Int> {
        let x = move % size, y = move / size
        let dx = x - centre, dy = y - centre
        let orbits: [(Int, Int)] = [
            ( dx,  dy), (-dy,  dx), (-dx, -dy), ( dy, -dx),   // rotations
            (-dx,  dy), ( dx, -dy), ( dy,  dx), (-dy, -dx),   // reflections
        ]
        var out = Set<Int>()
        for (tx, ty) in orbits {
            let cx = tx + centre, cy = ty + centre
            guard cx >= 0, cx < size, cy >= 0, cy < size else { continue }
            out.insert(cy * size + cx)
        }
        return out
    }

    /// True if `move` shares no D4 image with any already-accepted offer; on success it
    /// records `move`'s images into `accepted` and returns true.
    static func tryAccept(_ move: Int, into accepted: inout Set<Int>) -> Bool {
        let images = d4Images(of: move)
        if !accepted.isDisjoint(with: images) { return false }
        accepted.formUnion(images)
        return true
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run the engine test command. Expected: PASS for all `RenjuOfferSymmetryTests`.

- [ ] **Step 5: Add the new files to the Xcode targets, then commit**

The two new files must be added to `project.pbxproj`: `RenjuOfferSymmetry.swift` → the **app target** (`test1`/`penteLive`), and `RenjuOfferSymmetryTests.swift` → the **`PenteEngineTests`** target. Open `penteLive.xcworkspace` in Xcode and drag them into the matching groups (PenteEngine group + PenteEngineTests group) with the correct target membership, OR edit `project.pbxproj` to add `PBXBuildFile`/`PBXFileReference` entries mirroring an existing sibling (e.g. `Capture.swift` for the app target, `MoveResultTests.swift` for the test target). Re-run the engine test command to confirm both compile and the tests run (a file not added to a target silently won't compile).
```bash
git add test1/PenteEngine/RenjuOfferSymmetry.swift PenteEngineTests/RenjuOfferSymmetryTests.swift penteLive.xcodeproj/project.pbxproj
git commit -m "feat(renju): D4 offer-symmetry dedup helper + tests"
```

---

## Task 4: Map Renju game-type strings → `.renju`

**Files:**
- Modify: `test1/BoardVariantMapping.swift:8-29`
- Test: `PenteEngineTests/BoardVariantMappingTests.swift`

- [ ] **Step 1: Write the failing test**

In `PenteEngineTests/BoardVariantMappingTests.swift`, add:
```swift
    func testRenjuGameTypesMapToRenjuVariant() {
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Renju"), .renju)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Speed Renju"), .renju)
        XCTAssertEqual(BoardVariantMapping.variant(forGameType: "Turn-based Renju"), .renju)
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run `-only-testing:PenteEngineTests/BoardVariantMappingTests/testRenjuGameTypesMapToRenjuVariant`. Expected: FAIL (returns `.pente` via the fallback).

- [ ] **Step 3: Add the Renju branch**

In `test1/BoardVariantMapping.swift`, inside `variant(forGameType:)`, BEFORE the `Gomoku` line (`:22`) so "Renju" can't be mis-caught (it won't, but keep it with the other explicit checks):
```swift
        if gameType.contains("Renju") { return .renju }
        if gameType.contains("Connect6") { return .connect6 }
        if gameType.contains("Gomoku") { return .gomoku }
```
(Insert the `Renju` line; leave the existing Connect6/Gomoku lines.)

- [ ] **Step 4: Run test to verify it passes**

Run the same `-only-testing` filter. Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add test1/BoardVariantMapping.swift PenteEngineTests/BoardVariantMappingTests.swift
git commit -m "feat(renju): map Renju game-type strings to .renju variant"
```

---

## Task 5: Register game ids 31/32/81 in the TB game picker

**Files:**
- Modify: `test1/SocialViewController.swift:28-43`

No unit test (UI registration); verify by build + that the picker shows the names.

- [ ] **Step 1: Add the three names to `gameNames`**

In `test1/SocialViewController.swift`, in the `gameNames` dictionary (`:28-35`), add three entries (place near the other base/speed/TB groupings; dictionary order is irrelevant):
```swift
                 "Renju": 31, "Speed Renju": 32, "Turn-based Renju": 81,
```

- [ ] **Step 2: Add them to `gameNamesArray` (the picker list)**

In `gameNamesArray` (`:36-43`), add `"Turn-based Renju"` into the turn-based block and `"Renju"` / `"Speed Renju"` into the base / speed blocks so all three are pickable:
```swift
                      // ...turn-based block...
                      "Turn-based Go", "Turn-based Go (9x9)", "Turn-based Go (13x13)", "Turn-based O-Pente", "Turn-based Renju",
                      // ...base block...
                      "Boat-Pente", "DK-Pente", "Go", "Go (9x9)", "Go (13x13)", "O-Pente", "Renju",
                      // ...speed block...
                      "Speed Go", "Speed Go (9x9)", "Speed Go (13x13)", "Speed O-Pente", "Speed Renju"]
```

- [ ] **Step 3: Build**

Run the app build command. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**
```bash
git add test1/SocialViewController.swift
git commit -m "feat(renju): register Renju/Speed/Turn-based ids in TB game picker"
```

---

## Task 6: Size the TB board to 15×15 (gridSize, coord math, labels, star points)

**Files:**
- Modify: `test1/BoardViewController.m` (`:103`, `:1383`, coord-math sites `:564,:574-595,:605,:620,:746,:831-863`, `:93-94`)
- Modify: `test1/BoardView.m` (star points `:150-176`)

No unit test (ObjC rendering); verify by build + on-simulator render of a Renju game.

- [ ] **Step 1: Set `gridSize = 15` for Renju in `replayGame`**

In `test1/BoardViewController.m`, just after the reset `gridSize = 19;` (`:1383`) and `isGoGame = NO;` (`:1384`), add a Renju branch keyed off the game type (the Go branch at `:1886-1891` is inside `if (isGoGame)` and does not cover Renju):
```objc
    gridSize = 19;
    isGoGame = NO;
    if ([self.game.gameType containsString:@"Renju"]) {
        gridSize = 15;
    }
```
> If `self.game.gameType` is not yet set at `:1383` (it is populated from the JSON later in `replayGame`), instead place this branch immediately AFTER the `gameName`/`gameType` is read from `jsonResponse` (near `:1488`) and before `loadEngineIntoAbstractBoard`/`:2542` runs. Grep `self.game.gameType` / `setGameType` to confirm the earliest point it is valid, and set `gridSize` there. The invariant: `gridSize == 15` must hold before the first `loadEngineIntoAbstractBoard` and first `drawRect`.

- [ ] **Step 2: Confirm the engine is (re)inited with the Renju variant before replay**

Grep for `initWithVariant` around the render/replay path (`:2510-2545`):
```bash
grep -n "initWithVariant\|engine = " test1/BoardViewController.m
```
Ensure that, on the render path where `variant = [BoardVariantMapping variantForGameType:...]` (`:2516`), the engine is created with that `variant` (e.g. `engine = [[SwiftPenteGame alloc] initWithVariant:variant];`) so a Renju game gets a 15×15, black-first engine. If the engine is only inited once at `:114` (PenteVariantPente), add a re-init from `variant` on this path. This makes `[engine stoneAt:rc]` and `loadEngineIntoAbstractBoard` (`:2473`, looping `rc < gridSize*gridSize`) agree with the 15×15 engine. Build after.

- [ ] **Step 3: Make coordinate math `gridSize`-aware**

Replace every hardcoded `/ 19` and `% 19` in `BoardViewController.m` at the sites `:564, :574, :575, :576, :580, :590, :595, :605, :620, :746, :831-863` with `/ gridSize` and `% gridSize`. Example (`:746`):
```objc
    abstractBoard[move / gridSize][move % gridSize] = 2;
```
And the label/row display pattern (`:831/:833`) becomes:
```objc
    coordinateLetters[move % gridSize]              // column letter
    gridSize - (move / gridSize)                    // row number (was 19 - (move/19))
```
Grep to confirm none remain:
```bash
grep -nE "/ ?19|% ?19" test1/BoardViewController.m
```
Expected after edit: no matches in coordinate-math context (the `abstractBoard[19][19]` declaration at `.h:36` stays — a 15×15 board fits inside it; only the index math changes).

- [ ] **Step 4: Coordinate letters — first 15 labels A–P (skip I)**

`coordinateLetters[19]` (`:93-94`) already lists `A B C D E F G H J K L M N O P Q R S T` (I skipped). For 15×15, the FIRST 15 entries are `A…P` (skipping I) — which is exactly `coordinateLetters[0..14]`. Since access is now `coordinateLetters[move % gridSize]` with `gridSize == 15`, indices stay in `0..14` and resolve to `A…P` automatically. **No array change needed** — just confirm Step 3's `% gridSize` is applied everywhere the array is indexed (grep `coordinateLetters[` and verify each uses `% gridSize`, not `% 19`).

- [ ] **Step 5: 15×15 star points in `BoardView.m`**

Replace the 5 hardcoded 19×19 circles (`:150-176`) with the 9 Renju star points at cols/rows `{3,7,11}` → indices `[48,52,56,108,112,116,168,172,176]` (index = col + row·15, centre 112) — but ONLY when `gridSize == 15`; keep the existing 5-point set for 19×19. Structure:
```objc
    if (gridSize == 15) {
        int starPoints[9] = {48, 52, 56, 108, 112, 116, 168, 172, 176};
        for (int s = 0; s < 9; ++s) {
            int col = starPoints[s] % gridSize;
            int row = starPoints[s] / gridSize;
            CGRect circle = CGRectMake(margin + col * margin - margin / 2,
                                       margin + row * margin - margin / 2,
                                       margin, margin);
            CGContextAddEllipseInRect(context, circle);
            CGContextStrokePath(context);
        }
    } else {
        // ...existing 19×19 five-circle block unchanged...
    }
```
> Verify `margin` here equals the per-cell pitch used by the grid loop at `:86-95` (`self.bounds.size.width / gridSize`). If the existing block uses a different `margin` derivation, match it so the dots land on intersections. Iterate in the simulator until the 9 dots sit on {3,7,11}².

- [ ] **Step 6: Build + visually verify**

Run the app build command (BUILD SUCCEEDED). Then run a TB Renju game (or a finished-game replay) in the simulator and confirm: 15×15 grid, dusty-rose background, 9 star points on the right intersections, the auto-centre stone renders **black**, and tapping maps to the right cell. Verify on **both iPhone and iPad** (per `penteLive-iOS/CLAUDE.md`).

- [ ] **Step 7: Commit**
```bash
git add test1/BoardViewController.m test1/BoardView.m
git commit -m "feat(renju): size TB board to 15x15 (gridSize, coord math, star points)"
```

---

## Task 7: Read the server-shipped `renjuPhase`/`renjuOffers`/`renjuSwaps`

**Files:**
- Modify: `test1/BoardViewController.h` (new ivars/properties)
- Modify: `test1/BoardViewController.m` `replayGame` parse block (next to the `dPenteState` read at `:1767-1768`)

State lives as **ObjC ivars** on `BoardViewController` (matches the existing `dPenteState`/`swap2Move` precedent; no Swift `Game`/`Move` model change — confirmed during grounding). No unit test; verify by build + logging.

- [ ] **Step 1: Declare the ivars**

In `test1/BoardViewController.h` (near the other opening-state ivars, e.g. by `int abstractBoard[19][19]` `:36`):
```objc
@property (nonatomic, copy) NSString *renjuPhase;   // SWAP|BRANCH|OFFERS|SELECTION|MOVE|COMPLETE, or nil
@property (nonatomic, strong) NSArray<NSNumber *> *renjuOffers;  // parsed offered move indices, or nil
@property (nonatomic, strong) NSNumber *renjuSwaps; // packed opening word (opaque), or nil
```

- [ ] **Step 2: Parse the three fields in `replayGame`**

In `replayGame`, next to the `dPenteState` read (`:1767-1768`), add (mirroring the existing nil-tolerant pattern):
```objc
    self.renjuPhase = jsonResponse[@"renjuPhase"] != [NSNull null]
                          ? jsonResponse[@"renjuPhase"] : nil;
    NSString *offersStr = jsonResponse[@"renjuOffers"] != [NSNull null]
                              ? jsonResponse[@"renjuOffers"] : nil;
    if (offersStr.length > 0) {
        NSMutableArray<NSNumber *> *parsed = [NSMutableArray array];
        for (NSString *tok in [offersStr componentsSeparatedByString:@","]) {
            [parsed addObject:@([tok intValue])];
        }
        self.renjuOffers = parsed;
    } else {
        self.renjuOffers = nil;
    }
    self.renjuSwaps = ([jsonResponse[@"renjuSwaps"] isKindOfClass:[NSNumber class]])
                          ? jsonResponse[@"renjuSwaps"] : nil;
```
> Note: `renjuOffers` rides the same comma-separated-`String` shape as `moves` (`:1478-1481`). For a non-Renju game all three are `null`/absent — Gson omits them; the `NSNull`/`isKindOfClass` guards keep them nil. `renjuSwaps` is opaque to the UI (the phase tells you what to show).

- [ ] **Step 3: Build + log to verify**

Build the app (BUILD SUCCEEDED). Temporarily `NSLog(@"renjuPhase=%@ offers=%@ swaps=%@", self.renjuPhase, self.renjuOffers, self.renjuSwaps);` after the parse, load a mid-opening TB Renju game, confirm the values match the server JSON, then remove the log.

- [ ] **Step 4: Commit**
```bash
git add test1/BoardViewController.h test1/BoardViewController.m
git commit -m "feat(renju): read server-shipped renjuPhase/renjuOffers/renjuSwaps on TB board"
```

---

## Task 8: Submit `&renjuAction=` + surface server rejection messages

**Files:**
- Modify: `test1/BoardViewController.m` `submitMoveToServer` (move-string build `:1219-1253`, URL builders `:1272-1299`, completion handler `:1310-1330`)

No unit test (network); verify by build + round-trip against the server. Wire contract from §11.2/§11.4.

- [ ] **Step 1: Add a helper to build the Renju `moves` payload + action for the current phase**

Add a method near `submitMoveToServer`. It returns the `renjuAction` string (or nil for plain MOVE/COMPLETE) and fills the `moves` payload by out-param. Pass in the user's chosen stone(s)/decision via existing ivars (set by the opening UI in Task 9):
```objc
// Returns the renjuAction for the pending phase, or nil for a plain command=move.
// `outMoves` receives the moves payload string for the URL.
- (NSString *)renjuActionForCurrentPhaseFillingMoves:(NSString **)outMoves {
    NSString *phase = self.renjuPhase;
    if ([phase isEqualToString:@"SWAP"]) {
        if (renjuTakeOver) {                 // user tapped "Swap (take over)"
            *outMoves = @"1";
        } else if (renjuMove4Decline) {      // declining the move-4 swap: NO bundled stone
            *outMoves = @"0";
        } else {                             // decline + place (windows 1-3)
            *outMoves = [NSString stringWithFormat:@"0,%d", finalMove];
        }
        return @"swap";
    }
    if ([phase isEqualToString:@"BRANCH"]) {
        *outMoves = renjuBranchB ? @"2" : @"1";   // user chose Branch A(1)/B(2)
        return @"branch";
    }
    if ([phase isEqualToString:@"OFFERS"]) {
        *outMoves = [self.renjuPickedOffers componentsJoinedByString:@","]; // exactly 10
        return @"offer";
    }
    if ([phase isEqualToString:@"SELECTION"]) {
        *outMoves = [NSString stringWithFormat:@"%d", finalMove]; // the picked offered move
        return @"select";
    }
    // MOVE / COMPLETE -> plain placement, no renjuAction
    *outMoves = [NSString stringWithFormat:@"%d", finalMove];
    return nil;
}
```
> `renjuTakeOver`, `renjuMove4Decline`, `renjuBranchB` are `BOOL` ivars and `renjuPickedOffers` is an `NSArray<NSString *> *` of the 10 picked indices — all set by the Task 9 opening UI. Declare them in `.h` alongside the Task 7 ivars.

- [ ] **Step 2: Wire the payload + `&renjuAction=` into `submitMoveToServer`**

In `submitMoveToServer`, where the move-string is built (`:1219-1253`), branch for Renju BEFORE the existing Connect6/dPente/Swap2 cases:
```objc
    NSString *renjuAction = nil;
    BOOL isRenju = [self.game.gameType containsString:@"Renju"];
    if (isRenju) {
        NSString *renjuMoves = nil;
        renjuAction = [self renjuActionForCurrentPhaseFillingMoves:&renjuMoves];
        moves = renjuMoves;   // reuse the existing `moves` string the URL builder consumes
    } else {
        // ...existing Connect6 / D-Pente / Swap2 / default move-string construction...
    }
```
Then, in each of the four URL builder variants (`:1275/:1281/:1288/:1295`), append the action when present. Append to the format string + args:
```objc
    NSString *renjuSuffix = (renjuAction != nil)
        ? [NSString stringWithFormat:@"&renjuAction=%@", renjuAction] : @"";
    // ...existing URL...stringWithFormat: append %@ with renjuSuffix at the end of the query...
```
The base URL is `gameServer/tb/game?command=move&mobile=&gid=%@&moves=%@&message=...`; append `renjuSuffix` after `message=`. For a plain `MOVE`/`COMPLETE` placement `renjuAction` is nil → `renjuSuffix` empty → an ordinary `command=move` (correct).

- [ ] **Step 3: Surface the server's rejection message verbatim (new — none today)**

Today the completion handler (`:1310-1330`) only checks transport `error` and calls `cleanUp` on success; the response BODY is never read. Renju rejections (e.g. "Renju action does not match the pending decision.", "Expected 10 offered moves.", "Selected move was not offered.") arrive in the body. Read it and surface it, distinct from a transport error:
```objc
        if (error) {
            // ...existing transport-error alert (keep as-is)...
            return;
        }
        NSString *body = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        NSString *trimmed = [body stringByTrimmingCharactersInSet:
                                 [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        // The TB endpoint returns a short error string on rejection; an accepted move
        // returns the normal success payload. Treat a non-empty, non-OK short body as a
        // rejection ONLY for Renju (avoid changing legacy behaviour for other games).
        BOOL isRenju = [self.game.gameType containsString:@"Renju"];
        if (isRenju && trimmed.length > 0 && [self looksLikeRenjuRejection:trimmed]) {
            UIAlertView *alert = [[UIAlertView alloc]
                initWithTitle:NSLocalizedString(@"Move rejected", nil)
                message:trimmed delegate:nil
                cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
            return;   // do NOT cleanUp — let the user retry the opening decision
        }
        [strongSelf cleanUp];
```
Add the predicate:
```objc
- (BOOL)looksLikeRenjuRejection:(NSString *)body {
    // The success payload is JSON/long; rejection messages are short human sentences,
    // often containing these phase-specific phrases. Grep the actual server responses
    // during the round-trip (Step 4) and tighten this if needed.
    if ([body hasPrefix:@"{"] || [body hasPrefix:@"["]) return NO;   // success JSON
    return ([body containsString:@"Renju"] || [body containsString:@"offered"] ||
            [body containsString:@"swap"]  || [body containsString:@"Expected"] ||
            [body containsString:@"decision"]);
}
```
> **(verify during Step 4)** the exact shape of an accepted-move success response vs a rejection body for the TB endpoint, and tighten `looksLikeRenjuRejection:` so a *successful* move is never mistaken for a rejection. If the server sets a non-200 HTTP status on rejection, prefer testing `((NSHTTPURLResponse *)response).statusCode` instead of sniffing the body — check this first.

- [ ] **Step 4: Build + round-trip verify**

Build (BUILD SUCCEEDED). Against a live/staging server, drive a TB Renju opening through each phase (swap / branch / offer / select / move) and confirm: each submit carries the right `moves` + `&renjuAction=`, accepted moves advance, and a deliberately-illegal action surfaces the server's verbatim message. Confirm the success path still `cleanUp`s normally.

- [ ] **Step 5: Commit**
```bash
git add test1/BoardViewController.h test1/BoardViewController.m
git commit -m "feat(renju): submit renjuAction per phase + surface server rejections (TB)"
```

---

## Task 9: TB opening UI — phase-driven board interaction

**Files:**
- Modify: `test1/BoardViewController.h` (UI ivars), `test1/BoardViewController.m` (`boardTap:` `:644`, the dPente/swap2 button block `:1824-1876`, a new `renderRenjuOpeningUI` dispatch)

The hardest task — no precedent beyond the yes/no/pass `dPente`/`swap2` buttons. Everything is gated by the **read** `renjuPhase` (Task 7) and submitted via `renjuAction` (Task 8). No state machine: `switch(renjuPhase)`. No unit test; verify on-simulator per phase + on iPhone AND iPad.

- [ ] **Step 1: Add the UI-state ivars**

In `BoardViewController.h` (with the Task 7/8 ivars):
```objc
@property (nonatomic, strong) NSMutableArray<NSNumber *> *renjuPickedOffers; // black's 10-pick (OFFERS)
// BOOL decision flags consumed by Task 8's payload builder:
//   renjuTakeOver, renjuMove4Decline, renjuBranchB  (declare as ivars)
@property (nonatomic, strong) CAShapeLayer *renjuBoxLayer;                   // central-box overlay
```

- [ ] **Step 2: Central-box overlay + boardTap gate (MOVE and SWAP-decline placement)**

Compute the legal N×N square about centre 112 by opening move number: moves 2/3/4/5 → 3×3/5×5/7×7/9×9 (radius 1/2/3/4). The opening move number = current stones on board (`moves.count`) when placing the next stone. Add:
```objc
// radius for the next single-stone opening placement; 0 = no box (offers/complete).
- (int)renjuCentralBoxRadius {
    NSString *phase = self.renjuPhase;
    int placed = (int)[self currentMovesCount];   // stones already on board (incl. auto-centre)
    if ([phase isEqualToString:@"MOVE"]) {
        // Branch-A move 5 -> 9×9 (radius 4). General MOVE placement: radius by move number.
        return MAX(1, MIN(4, placed));            // placing move (placed+1): 1..4
    }
    if ([phase isEqualToString:@"SWAP"] && !renjuTakeOver && !renjuMove4Decline) {
        // decline+place windows 1-3 -> placing move 2/3/4 -> radius 1/2/3
        return MAX(1, MIN(3, placed));
    }
    return 0;   // OFFERS (whole board), BRANCH/SELECTION/COMPLETE -> no box
}

- (void)updateRenjuBoxOverlay {
    [self.renjuBoxLayer removeFromSuperlayer];
    int r = [self renjuCentralBoxRadius];
    if (r == 0) { self.renjuBoxLayer = nil; return; }
    CGFloat cell = self.board.bounds.size.width / gridSize;
    int lo = 7 - r, hi = 7 + r;                   // centre (7,7), inclusive square [lo..hi]
    CGRect box = CGRectMake(lo * cell, lo * cell, (hi - lo + 1) * cell, (hi - lo + 1) * cell);
    CAShapeLayer *layer = [CAShapeLayer layer];
    layer.path = [UIBezierPath bezierPathWithRect:box].CGPath;
    layer.fillColor = [UIColor clearColor].CGColor;
    layer.strokeColor = [UIColor colorWithWhite:0 alpha:0.6].CGColor;
    layer.lineDashPattern = @[@6, @4];
    layer.lineWidth = 2;
    [self.board.layer addSublayer:layer];
    self.renjuBoxLayer = layer;
}
```
In `boardTap:` (`:644`), after computing `finalMove = gridSize * i + j;` (`:785`) and the empty-cell check, gate single-stone placement to the box when a radius is active:
```objc
    int boxR = [self renjuCentralBoxRadius];
    if (boxR > 0) {
        int col = finalMove % gridSize, row = finalMove / gridSize;
        if (abs(col - 7) > boxR || abs(row - 7) > boxR) {
            // outside the legal central square — ignore the tap (optionally flash the box)
            return;
        }
    }
```
> `currentMovesCount` = however the controller already knows the number of replayed stones (grep `moves count` / the parsed `moves` array length used by `replayGame`; reuse it). Iterate the dashed rect in-simulator until it frames the right cells.

- [ ] **Step 3: Phase dispatch — render the right controls**

Add `renderRenjuOpeningUI`, called wherever the dPente/swap2 buttons are shown/hidden (`:1824-1876`). Reuse `player1Button`/`player2Button` for the binary prompts and the existing `boardTap:` for placement/picking:
```objc
- (void)renderRenjuOpeningUI {
    [self hideAllOpeningButtons];        // reuse the dPente/swap2 show/hide helper
    [self updateRenjuBoxOverlay];
    NSString *phase = self.renjuPhase;
    if ([phase isEqualToString:@"SWAP"]) {
        // window 1-3: "Swap (take over)" | "Don't swap (place next stone)"
        // move-4 window: "Swap (take over)" | "Don't swap" (no bundled stone)
        [self showRenjuSwapButtons:[self isRenjuMove4Window]];
    } else if ([phase isEqualToString:@"BRANCH"]) {
        [self showRenjuBranchButtons];          // "Branch A (place move 5)" | "Branch B (offer 10)"
    } else if ([phase isEqualToString:@"OFFERS"]) {
        self.renjuPickedOffers = [NSMutableArray array];
        [self showRenjuOfferCounter];           // "Pick 0 of 10"; taps handled in boardTap:
    } else if ([phase isEqualToString:@"SELECTION"]) {
        [self showRenjuSelectionUI];            // render the 10 renjuOffers translucent; tap to pick
    }
    // MOVE / COMPLETE: plain boardTap placement (box overlay handles MOVE constraint)
}
```

- [ ] **Step 4: SWAP + BRANCH buttons (reuse player1/2 button targets)**

Wire the two reused buttons. On "Swap (take over)": set `renjuTakeOver = YES; renjuMove4Decline = NO;` then `[self submitMove:nil]` (Task 8 builds `moves=1`, `renjuAction=swap`). On "Don't swap": for windows 1-3 set `renjuTakeOver = NO; renjuMove4Decline = NO;` and require a central-box tap first (the placement supplies `finalMove`), then submit (`moves=0,<move>`). For the move-4 window "Don't swap" set `renjuMove4Decline = YES;` and submit immediately (`moves=0`, no stone) — the server then ships `BRANCH`. BRANCH buttons: "Branch A" → `renjuBranchB = NO`, submit (`moves=1`); "Branch B" → `renjuBranchB = YES`, submit (`moves=2`).

- [ ] **Step 5: OFFERS — 10-pick multi-select (whole board, D4-dedup) with auto-send**

In `boardTap:`, when `renjuPhase == "OFFERS"`, treat taps as add/remove of translucent candidates instead of a move (NO central box — offers are whole-board, §11.5):
```objc
    if ([self.renjuPhase isEqualToString:@"OFFERS"]) {
        NSNumber *cell = @(finalMove);
        if ([self.renjuPickedOffers containsObject:cell]) {
            [self.renjuPickedOffers removeObject:cell];        // tap again to remove
        } else {
            if (self.renjuPickedOffers.count >= 10) return;
            // UX dedup via the Swift helper (Task 3); server is authority either way.
            if ([self renjuOfferWouldDuplicate:finalMove]) {
                [self flashRenjuOfferRejected];                // brief feedback, do not add
                return;
            }
            [self.renjuPickedOffers addObject:cell];
        }
        [self renderRenjuOfferCandidatesTranslucent];          // alpha 0.7 black stones + n/10
        if (self.renjuPickedOffers.count == 10) {
            [self submitMove:nil];                              // auto-send: renjuAction=offer
        }
        return;
    }
```
Bridge to the Swift dedup (the running accepted-image set is rebuilt from the current picks):
```objc
- (BOOL)renjuOfferWouldDuplicate:(int)move {
    NSMutableSet<NSNumber *> *accepted = [NSMutableSet set];
    for (NSNumber *m in self.renjuPickedOffers) {
        for (NSNumber *img in [RenjuOfferSymmetry d4ImagesOf:m.intValue]) [accepted addObject:img];
    }
    for (NSNumber *img in [RenjuOfferSymmetry d4ImagesOf:move]) {
        if ([accepted containsObject:img]) return YES;
    }
    return NO;
}
```
> `RenjuOfferSymmetry.d4Images(of:)` returns a `Set<Int>`; for the ObjC bridge expose an `@objc static func d4ImagesOf(_ move: Int) -> [NSNumber]` wrapper on the helper (add it in Task 3's file). Render candidates by reusing the `StoneView`/`abstractBoard` dark fill at lower opacity (mirror the live `LiveBoard` `alpha = 0.7` look); show a `Pick n of 10` label.

- [ ] **Step 6: SELECTION — white picks 1 of 10**

Render the parsed `self.renjuOffers` (Task 7) as translucent black candidates. In `boardTap:`, when `renjuPhase == "SELECTION"`, accept a tap only if it hits one of `renjuOffers`; set `finalMove` to that index, clear the other nine, and submit (`renjuAction=select`, `moves=<move>`). Present the prompt as a **non-dismissible** affordance (vs the passive text-log message handler) until a selection is sent.

- [ ] **Step 7: COMPLETE — ordinary placement**

When `renjuPhase == "COMPLETE"` (or nil for a non-opening Renju position), `boardTap:` places normally and `submitMove:` sends a plain `command=move` (no `renjuAction`, Task 8 returns nil). Black forbidden-points are server-enforced — a rejected stone surfaces the server's phase-specific message (Task 8 Step 3).

- [ ] **Step 8: Build + full opening walk-through on iPhone AND iPad**

Build (BUILD SUCCEEDED). Drive a complete TB Renju opening end-to-end against the server: auto-centre → 4 swap windows (take-over and decline+place paths) → move-4 (Branch A constrained move 5 AND Branch B 10-offer) → white SELECTION → COMPLETE alternation. Verify the central box appears only for single-stone opening placements (moves 2-5), the 10-pick is whole-board with dedup + auto-send, selection is non-dismissible, and rejections show verbatim. Verify layout/popover behaviour on **both iPhone and iPad** (`penteLive-iOS/CLAUDE.md`).

- [ ] **Step 9: Commit**
```bash
git add test1/BoardViewController.h test1/BoardViewController.m test1/PenteEngine/RenjuOfferSymmetry.swift
git commit -m "feat(renju): turn-based opening UI (swap/branch/offers/selection) driven by renjuPhase"
```

---

## Self-Review (run before handing off)

**Spec coverage (§11):**
- §11.1 registration → Task 5. ✅
- §11.2 read `renjuPhase` (no derivation) → Task 7. ✅
- §11.2 submit `renjuAction` table → Task 8. ✅
- §11.3 step 1 (registration) → Task 5; step 2 (parse) → Task 7; step 3 (15×15 sizing) → Task 6; step 4 (coord labels) → Task 6; step 5 (star points) → Task 6; step 6 (submit) → Task 8; step 7 (shared variant/colour) → Tasks 1 & 4; step 8 (opening UI) → Task 9. ✅
- §11.5 opening UI per phase → Task 9. ✅
- §11.5 D4 dedup → Task 3 (helper) + Task 9 (wiring). ✅
- Shared engine foundation the TB render path depends on (black-first, 15×15) — §9.0/§9.3 steps 3-4, pulled forward because TB renders via `[engine replay:]` → Tasks 1 & 2. ✅
- `.renju` colour `#D98880` consumed by the ObjC board via the `@objc(backgroundColorForVariant:boatPente:)` bridge at `BoardViewController.m:2549` (grounding-confirmed) → Task 1. ✅

**Resolved (verify) items from grounding:**
- ObjC board reads bg from the shared `@objc` colour bridge (`:2549`) — no separate ObjC colour path. ✅
- New opening-state → ObjC ivars on `BoardViewController`, not Swift model. ✅
- Only TWO exhaustive `PenteVariant` switches break (`ruleSet`, `backgroundColor`); no test-file switch breaks. ✅
- Submit path reads NO response body today → Task 8 adds verbatim rejection surfacing (flagged for round-trip verify). ✅

**Still-open (carry into QA — flagged inline):** exact engine re-init line for the render path (Task 6 Step 2 grep); precise `margin`/pitch for star points (Task 6 Step 5); success-vs-rejection body shape / HTTP status (Task 8 Step 3); central-box overlay pixel fit + 10-translucent render/clear (Task 9). None block the plan; each has an explicit in-task verify step.

**Out of scope (Phase 2 — live / §9):** the Swift live stack (`PenteLiveSocket` echo arms, `RoomViewController` handlers, `HelperClasses` tracking + `renjuPhase` *derivation*, `TableViewController` send + live opening UI, `LiveBoard` overlays). The engine foundation (Tasks 1-3) is shared and will be reused unchanged.

---

## Execution Handoff

Plan complete. Two execution options:

1. **Subagent-Driven (recommended)** — fresh subagent per task, two-stage review between tasks, fast iteration. Best fit: Tasks 1-4 (Swift, TDD, self-verifying) parallelize/automate cleanly; Tasks 5-9 (ObjC UI) need build + simulator checkpoints.
2. **Inline Execution** — execute in this session with checkpoints.
