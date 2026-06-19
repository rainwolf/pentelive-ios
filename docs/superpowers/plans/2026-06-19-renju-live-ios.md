# Live Renju (Taraguchi-10) iOS Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real-time (live) Renju with the Taraguchi-10 opening (game ids 31/32) to the penteLive iOS live-game stack, matching the server wire contract and the React live client.

**Architecture:** The position engine already exists (`PenteGame(variant: .renju)`, 15×15, black-first). This plan adds: (1) a pure opening model — a `RenjuTracking` record + classifiers/reducers ported verbatim from the React client and unit-tested against its truth tables; (2) live-model wiring (variant routing, 15×15 geometry, board colour, turn/colour derivation); (3) three socket events + senders + inbound handlers + a move-error arm; (4) the opening UI, presented with the existing **Swap2 action-sheet methodology** plus on-board placement/offer/selection. The server stays authoritative; the client derives the opening phase from the move count + accumulated decision echoes (the live socket carries no phase).

**Tech Stack:** Swift + Objective-C interop, XCTest target `PenteEngineTests` (`@testable import penteLive`), `xcodebuild`, CocoaPods workspace `penteLive.xcworkspace` (app scheme `test1`, product module `penteLive`), `GCDAsyncSocket` live transport.

**Spec:** `docs/superpowers/specs/2026-06-19-renju-live-ios-design.md`.
**Reference source of truth (port verbatim):** `react_live_game_room` PR #5 — `src/game/openingPhase.js`, `src/game/gameState.js`, `src/redux_reducers/utils.js`, `src/game/renjuSymmetry.js`, `src/Classes/GameClass.js` (`renjuBoxRadius`), and the test files `src/game/__tests__/openingPhase.test.js`, `src/redux_reducers/__tests__/renjuTracking.test.js`, `src/game/__tests__/renjuSymmetry.test.js`, `src/game/__tests__/gameState.test.js`.

## Global Constraints

- **Game ids in scope:** `31` (Renju) and `32` (Speed Renju). `81` (turn-based) is out of scope (separate ObjC stack). `GameEnum.renju = 31`, `GameEnum.speedRenju = 32` already exist (`HelperClasses.swift:82`).
- **Board:** 15×15. Centre = index `112` = `(7,7)`. Move index = `row*15 + col` = the server's `x + y*15` (equal **only** at gridSize 15). Server auto-places the centre (move 1) as an ordinary `dsgMoveTableEvent` — never place it client-side.
- **Stone colour:** already black-first in the engine (`RenjuRules.cadence = .blackFirst`, `PenteGame.colorForMove → 2-(index%2)`). Do **not** re-flip colour. Board values: `0` empty, `1` white, `2` black, `-1` masked.
- **Wire event keys (byte-for-byte; note the asymmetric `10`):** `dsgRenjuTaraguchiSwapTableEvent`, `dsgRenjuTaraguchiOffer10TableEvent`, `dsgRenjuTaraguchi10Select1TableEvent`. Every payload also carries `player`, `table`, `time`. **Outbound must include `"time": 0` literally.**
- **`-1` no-move sentinel:** `move: -1` on take-over (`swap:true`) and on the bare move-5 decline. Never send `0` (legal corner cell).
- **Decision echoes never carry stones.** Stones always ride `dsgMoveTableEvent`. Take-over is **not** a renju echo — it is a non-silent `dsgSwapSeatsTableEvent` (reuse the existing handler).
- **Rejoin signals arrive with `player == null`** (one current-decision-point signal before the bulk move list). Do not derive seat orientation from the silent-swap `swap` bit; seats come from `sendPlayingPlayers`.
- **Forbidden points / overline:** server-enforced only; iOS stays presentation-only (rely on `dsgMoveTableErrorEvent` / game-over).
- **Device matrix:** verify every UI change on iPhone **and** iPad (popover vs modal) per `penteLive-iOS/CLAUDE.md`.
- **Canonical test/build command** (substitute an installed simulator from `xcrun simctl list devices available` if `iPhone 17` is absent; record the substitution and reuse it; `SWIFT_ENABLE_EXPLICIT_MODULES=NO` is required on this machine):
  ```bash
  xcodebuild test -workspace penteLive.xcworkspace -scheme test1 \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    SWIFT_ENABLE_EXPLICIT_MODULES=NO \
    -only-testing:PenteEngineTests/<TestClass>/<testMethod> 2>&1 | tail -12
  ```
  For a full build (UI tasks): replace `test … -only-testing:…` with `build`.

---

## File Structure

**New files:**
- `test1/PenteEngine/RenjuTracking.swift` — the opening tracking record (value type).
- `test1/PenteEngine/RenjuOpeningPhase.swift` — pure classifiers (`renjuPhase`, `renjuOpeningPlayer`, `renjuBoxRadius`, choice predicates, `renjuModalButtons`).
- `test1/PenteEngine/RenjuLiveSymmetry.swift` — stabilizer-based D4 offer dedup (mirrors the server; the existing `RenjuOfferSymmetry` is full-D4 and too strict for the asymmetric opening — do not reuse it for live).
- `PenteEngineTests/RenjuTrackingTests.swift`, `PenteEngineTests/RenjuOpeningPhaseTests.swift`, `PenteEngineTests/RenjuLiveSymmetryTests.swift`, `PenteEngineTests/RenjuLiveModelTests.swift`.

**Modified files:**
- `test1/HelperClasses.swift` — `GameState.renju`; `Table` (`isRenju`, `game` didSet gridSize, `penteVariant(for:)`, `syncFromEngine`, `addMove`/`addMoves`, `currentPlayer`, `gameColor`, `reset`, `swapSeats`, the three `applyRenju*` mutators); `TablesAndPlayer` (three `renju*` forwarders).
- `test1/PenteLiveSocket.swift` — four new inbound arms in `processEvent`.
- `test1/RoomViewController.swift` — `renjuSwapTableEvent`, `renjuOffer10TableEvent`, `renjuSelect1TableEvent`, `moveErrorTableEvent`.
- `test1/TableViewController.swift` — three senders; the renju opening block in `stateChanged()`; board sub-modes + pending lock in `boardTouch`; offer counter.
- `test1/LiveBoard.swift` — 15×15 star points + translucent candidate rendering.

---

## Phase A — Pure opening model (unit-tested against the React truth tables)

### Task 1: `RenjuTracking` record + `GameState.renju`

**Files:**
- Create: `test1/PenteEngine/RenjuTracking.swift`
- Modify: `test1/HelperClasses.swift` (`GameState` class, ~652-684)
- Test: `PenteEngineTests/RenjuTrackingTests.swift`

**Interfaces:**
- Produces: `struct RenjuTracking { var complete, awaitingSwap, branchChosen, tenOffer: Bool; var offered: [Int]; var selected: Int?; var swapTaken: Bool }` with a zero-arg init defaulting every field; `GameState.renju: RenjuTracking`.

- [ ] **Step 1: Write the failing test**

Create `PenteEngineTests/RenjuTrackingTests.swift` (set Target Membership = `PenteEngineTests`):
```swift
import XCTest
@testable import penteLive

final class RenjuTrackingTests: XCTestCase {
    // Mirrors react gameState.test.js: freshRenjuTracking defaults.
    func testDefaults() {
        let t = RenjuTracking()
        XCTAssertFalse(t.complete)
        XCTAssertFalse(t.awaitingSwap)
        XCTAssertFalse(t.branchChosen)
        XCTAssertFalse(t.tenOffer)
        XCTAssertEqual(t.offered, [])
        XCTAssertNil(t.selected)
        XCTAssertFalse(t.swapTaken)
    }
    func testValueSemantics() {
        var a = RenjuTracking()
        a.offered.append(1)
        XCTAssertEqual(RenjuTracking().offered, []) // a fresh value is unaffected
    }
    func testGameStateHasFreshTracking() {
        XCTAssertEqual(GameState().renju.offered, [])
        XCTAssertFalse(GameState().renju.complete)
    }
}
```

- [ ] **Step 2: Run to verify it fails**

Run the canonical command with `-only-testing:PenteEngineTests/RenjuTrackingTests`. Expected: FAIL — `cannot find 'RenjuTracking' in scope`.

- [ ] **Step 3: Implement**

Create `test1/PenteEngine/RenjuTracking.swift` (add to the `test1`/`penteLive` app target):
```swift
import Foundation

/// Client mirror of the server's Taraguchi-10 opening flags (openingComplete / awaitingSwap /
/// branchChosen / tenOffer / offeredFifth / selectedFifth) — see react gameState.js
/// `freshRenjuTracking`. A plain value type: it accumulates the opening decisions from the
/// socket echoes; `renjuPhase(_:_:)` classifies it. Places no stones.
struct RenjuTracking {
    var complete = false
    var awaitingSwap = false
    var branchChosen = false
    var tenOffer = false
    var offered: [Int] = []
    var selected: Int? = nil
    var swapTaken = false
}
```
In `HelperClasses.swift`, add to `GameState` (after `var goState = GoState.play`):
```swift
    var renju = RenjuTracking()
```

- [ ] **Step 4: Run to verify it passes** — Expected: 3 tests PASS.

- [ ] **Step 5: Commit**
```bash
git add test1/PenteEngine/RenjuTracking.swift test1/HelperClasses.swift PenteEngineTests/RenjuTrackingTests.swift
git commit -m "feat(renju-live): RenjuTracking opening record + GameState.renju"
```

---

### Task 2: Opening phase classifiers (`RenjuOpeningPhase.swift`)

**Files:**
- Create: `test1/PenteEngine/RenjuOpeningPhase.swift`
- Test: `PenteEngineTests/RenjuOpeningPhaseTests.swift`

**Interfaces:**
- Consumes: `RenjuTracking` (Task 1).
- Produces: `enum RenjuPhase { case swap, branch, selection, move, complete }`; `func renjuPhase(_ numMoves: Int, _ t: RenjuTracking) -> RenjuPhase`; `func renjuOpeningPlayer(_ numMoves: Int, _ t: RenjuTracking) -> Int?` (seat 1/2 or nil); `func renjuBoxRadius(_ numMoves: Int) -> Int`; `func isRenjuSwapChoice/_BranchChoice/_Selection(_:_:_:) -> Bool`; `struct RenjuModalButtons { let swap, declinePlace, offer10: Bool }`; `func renjuModalButtons(_:_:_:) -> RenjuModalButtons`.

- [ ] **Step 1: Write the failing test** (mirrors `openingPhase.test.js` truth tables)

Create `PenteEngineTests/RenjuOpeningPhaseTests.swift`:
```swift
import XCTest
@testable import penteLive

final class RenjuOpeningPhaseTests: XCTestCase {
    private func rs(_ f: (inout RenjuTracking) -> Void) -> RenjuTracking { var t = RenjuTracking(); f(&t); return t }

    func testWindows1to4OpenAreSwap() {
        for n in [1,2,3,4] { XCTAssertEqual(renjuPhase(n, rs { $0.awaitingSwap = true }), .swap) }
    }
    func testMove4ResolvedNoBranchIsBranch() {
        XCTAssertEqual(renjuPhase(4, rs { $0.awaitingSwap = false; $0.branchChosen = false }), .branch)
    }
    func testTenOffersNoneSelectedIsSelection() {
        XCTAssertEqual(renjuPhase(4, rs { $0.branchChosen = true; $0.tenOffer = true; $0.offered = Array(repeating: 0, count: 10); $0.selected = nil }), .selection)
    }
    func testBranchAMove5WindowOpenIsSwap() {
        XCTAssertEqual(renjuPhase(5, rs { $0.branchChosen = true; $0.tenOffer = false; $0.awaitingSwap = true }), .swap)
    }
    func testBranchAMove5ResolvedIsMove() {
        XCTAssertEqual(renjuPhase(5, rs { $0.branchChosen = true; $0.tenOffer = false; $0.awaitingSwap = false }), .move)
    }
    func testBranchBCompleteIsComplete() {
        XCTAssertEqual(renjuPhase(5, rs { $0.branchChosen = true; $0.tenOffer = true; $0.complete = true }), .complete)
    }
    func testPostTakeoverWindows1to3AreMove() {
        for n in [1,2,3] { XCTAssertEqual(renjuPhase(n, rs { $0.awaitingSwap = false }), .move) }
    }
    func testCompleteIsComplete() { XCTAssertEqual(renjuPhase(6, rs { $0.complete = true }), .complete) }

    // renjuOpeningPlayer (seat 1/2/nil)
    func testAwaitingSwapNotLastColorToMove() {
        XCTAssertEqual(renjuOpeningPlayer(1, rs { $0.awaitingSwap = true }), 2)
        XCTAssertEqual(renjuOpeningPlayer(4, rs { $0.awaitingSwap = true }), 1)
    }
    func testBranchChoiceIsBlack() {
        XCTAssertEqual(renjuOpeningPlayer(4, rs { $0.awaitingSwap = false; $0.branchChosen = false }), 1)
    }
    func testBranchBOfferingBlackSelectingWhite() {
        XCTAssertEqual(renjuOpeningPlayer(4, rs { $0.branchChosen = true; $0.tenOffer = true; $0.offered = [1,2] }), 1)
        XCTAssertEqual(renjuOpeningPlayer(4, rs { $0.branchChosen = true; $0.tenOffer = true; $0.offered = Array(repeating: 0, count: 10); $0.selected = nil }), 2)
    }
    func testCompleteIsNil() { XCTAssertNil(renjuOpeningPlayer(6, rs { $0.complete = true })) }
    func testBranchAWindow5AndMove6White() {
        XCTAssertEqual(renjuOpeningPlayer(5, rs { $0.branchChosen = true; $0.awaitingSwap = true }), 2)
        XCTAssertEqual(renjuOpeningPlayer(5, rs { $0.branchChosen = true; $0.awaitingSwap = false }), 2)
    }
    func testBranchBSelectedFallsThroughToParity() {
        XCTAssertEqual(renjuOpeningPlayer(4, rs { $0.branchChosen = true; $0.tenOffer = true; $0.offered = Array(repeating: 0, count: 10); $0.selected = 57 }), 1)
    }

    func testBoxRadius() {
        XCTAssertEqual(renjuBoxRadius(0), 0)
        XCTAssertEqual([1,2,3,4].map(renjuBoxRadius), [1,2,3,4])
        XCTAssertEqual(renjuBoxRadius(5), 0)
    }

    func testPredicatesGateOnStarted() {
        XCTAssertFalse(isRenjuSwapChoice(2, rs { $0.awaitingSwap = true }, false))
        XCTAssertTrue(isRenjuSwapChoice(2, rs { $0.awaitingSwap = true }, true))
        XCTAssertTrue(isRenjuBranchChoice(4, rs { $0.awaitingSwap = false; $0.branchChosen = false }, true))
        XCTAssertTrue(isRenjuSelection(4, rs { $0.branchChosen = true; $0.tenOffer = true; $0.offered = Array(repeating: 0, count: 10) }, true))
    }
    func testModalButtonsByPhase() {
        func eq(_ b: RenjuModalButtons, _ s: Bool, _ d: Bool, _ o: Bool) { XCTAssertEqual([b.swap,b.declinePlace,b.offer10], [s,d,o]) }
        eq(renjuModalButtons(2, rs { $0.awaitingSwap = true }, true), true, true, false)
        eq(renjuModalButtons(4, rs { $0.awaitingSwap = true }, true), true, true, true)
        eq(renjuModalButtons(4, rs { $0.awaitingSwap = false; $0.branchChosen = false }, true), false, true, true)
        eq(renjuModalButtons(5, rs { $0.branchChosen = true; $0.awaitingSwap = true }, true), true, true, false)
    }
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL — `cannot find 'renjuPhase' in scope`.

- [ ] **Step 3: Implement**

Create `test1/PenteEngine/RenjuOpeningPhase.swift` (verbatim port of react `openingPhase.js` + `GameClass.renjuBoxRadius`):
```swift
import Foundation

/// Pure client mirror of RenjuState.getOpeningPhase / getCurrentPlayer (server) — ported from
/// react src/game/openingPhase.js. Pure over (numMoves, RenjuTracking); the thresholds live here.
enum RenjuPhase { case swap, branch, selection, move, complete }

func renjuPhase(_ numMoves: Int, _ t: RenjuTracking) -> RenjuPhase {
    if t.complete { return .complete }
    if t.awaitingSwap { return .swap }
    if numMoves == 4 && !t.branchChosen { return .branch }
    if numMoves == 4 && t.branchChosen && t.tenOffer && t.offered.count == 10 && t.selected == nil {
        return .selection
    }
    return .move
}

/// Seat (1/2) to move during the opening, or nil once complete (caller falls back to alternation).
/// Seat-index space — NOT stone colour. Mirrors react renjuOpeningPlayer.
func renjuOpeningPlayer(_ numMoves: Int, _ t: RenjuTracking) -> Int? {
    if t.complete { return nil }
    let n = numMoves
    if t.awaitingSwap {
        let lastColor = ((n - 1) % 2) + 1
        return 3 - lastColor
    }
    if t.branchChosen && t.tenOffer && n == 4 {
        if t.offered.count < 10 { return 1 } // black offering
        if t.selected == nil { return 2 }    // white selecting
    }
    if n == 4 && !t.branchChosen { return 1 } // black chooses branch (and plays move 5)
    return (n % 2) + 1
}

/// Box radius about centre for placing the NEXT stone (moves 2-5 -> 1..4; else 0 = whole board).
func renjuBoxRadius(_ numMoves: Int) -> Int {
    return (numMoves >= 1 && numMoves <= 4) ? numMoves : 0
}

func isRenjuSwapChoice(_ n: Int, _ t: RenjuTracking, _ started: Bool) -> Bool { started && renjuPhase(n, t) == .swap }
func isRenjuBranchChoice(_ n: Int, _ t: RenjuTracking, _ started: Bool) -> Bool { started && renjuPhase(n, t) == .branch }
func isRenjuSelection(_ n: Int, _ t: RenjuTracking, _ started: Bool) -> Bool { started && renjuPhase(n, t) == .selection }

struct RenjuModalButtons { let swap: Bool; let declinePlace: Bool; let offer10: Bool }

func renjuModalButtons(_ n: Int, _ t: RenjuTracking, _ started: Bool) -> RenjuModalButtons {
    let swapChoice = isRenjuSwapChoice(n, t, started)
    let branchChoice = isRenjuBranchChoice(n, t, started)
    return RenjuModalButtons(swap: swapChoice,
                             declinePlace: swapChoice || branchChoice,
                             offer10: branchChoice || (swapChoice && n == 4))
}
```

- [ ] **Step 4: Run to verify it passes** — Expected: all PASS.

- [ ] **Step 5: Commit**
```bash
git add test1/PenteEngine/RenjuOpeningPhase.swift PenteEngineTests/RenjuOpeningPhaseTests.swift
git commit -m "feat(renju-live): opening phase + to-move classifiers (ported from react)"
```

---

### Task 3: Stabilizer-based offer-symmetry dedup (`RenjuLiveSymmetry.swift`)

**Files:**
- Create: `test1/PenteEngine/RenjuLiveSymmetry.swift`
- Test: `PenteEngineTests/RenjuLiveSymmetryTests.swift`

**Why new (not `RenjuOfferSymmetry`):** the existing `RenjuOfferSymmetry` rejects offers under the **full** D4 group unconditionally; the server (`RenjuState.isSymmetricDuplicate`) dedups under the **stabilizer of the current placed position**. For the asymmetric 4-stone opening the stabilizer is `{identity}`, so only exact-duplicate offers are illegal — the full-D4 helper over-rejects. Port the server-matching react `renjuSymmetry.js`.

**Interfaces:**
- Produces: `enum RenjuLiveSymmetry` with `static func rotate(_ move: Int, _ r: Int, size: Int = 15) -> Int`; `static func stabilizer(_ valueAt: (Int) -> Int, size: Int = 15) -> [Int]`; `static func isOfferDup(_ move: Int, offers: [Int], stab: [Int], size: Int = 15) -> Bool`; `static func isSymmetricDup(_ move: Int, offers: [Int], valueAt: (Int) -> Int, size: Int = 15) -> Bool`.

- [ ] **Step 1: Write the failing test** (mirrors `renjuSymmetry.test.js`)

Create `PenteEngineTests/RenjuLiveSymmetryTests.swift`:
```swift
import XCTest
@testable import penteLive

final class RenjuLiveSymmetryTests: XCTestCase {
    private func board(_ occ: [Int: Int]) -> (Int) -> Int { { occ[$0] ?? 0 } }

    func testRotateCentreFixedAnd180() {
        XCTAssertEqual(RenjuLiveSymmetry.rotate(112, 0), 112)
        XCTAssertEqual(RenjuLiveSymmetry.rotate(112, 4), 112)
        XCTAssertEqual(RenjuLiveSymmetry.rotate(40, 4), 184)
        XCTAssertEqual(RenjuLiveSymmetry.rotate(184, 4), 40)
    }
    func testAsymmetricPositionIdentityStabilizer() {
        XCTAssertEqual(RenjuLiveSymmetry.stabilizer(board([112: 2, 129: 1])), [0])
    }
    func testAsymmetricOnlyExactDup() {
        let v = board([112: 2, 129: 1])
        XCTAssertFalse(RenjuLiveSymmetry.isSymmetricDup(184, offers: [40], valueAt: v))
        XCTAssertTrue(RenjuLiveSymmetry.isSymmetricDup(40, offers: [40], valueAt: v))
    }
    func testSymmetricPositionRejectsRotations() {
        let v = board([112: 2]) // lone centre -> full D4
        XCTAssertEqual(RenjuLiveSymmetry.stabilizer(v).count, 8)
        XCTAssertTrue(RenjuLiveSymmetry.isSymmetricDup(184, offers: [40], valueAt: v))
        XCTAssertFalse(RenjuLiveSymmetry.isSymmetricDup(56, offers: [40], valueAt: v))
    }
    func testSingleAxisSymmetryTwoElementStabilizer() {
        let v = board([112: 2, 127: 1]) // vertical-axis symmetry
        let stab = RenjuLiveSymmetry.stabilizer(v)
        XCTAssertEqual(stab.count, 2)
        XCTAssertTrue(RenjuLiveSymmetry.isOfferDup(94, offers: [100], stab: stab))
        XCTAssertFalse(RenjuLiveSymmetry.isOfferDup(158, offers: [100], stab: stab))
    }
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL — `cannot find 'RenjuLiveSymmetry'`.

- [ ] **Step 3: Implement** (verbatim port of `renjuSymmetry.js`; Swift integer division matches `Math.floor` for the non-negative indices used here)

Create `test1/PenteEngine/RenjuLiveSymmetry.swift`:
```swift
import Foundation

/// Stabilizer-based D4 offer dedup for Branch-B fifth-move offers — mirrors the server's
/// RenjuState.isSymmetricDuplicate (positionStabilizer + rotateMove) and react renjuSymmetry.js.
/// A candidate is a duplicate only if some symmetry that maps the PLACED stones onto themselves
/// also maps it onto an already-offered point. 15×15, centre index 112; index = x + y*size.
enum RenjuLiveSymmetry {
    static let size = 15
    private static let rotX = [1, 1, 1, 1, -1, -1, -1, -1]
    private static let rotY = [1, 1, -1, -1, -1, -1, 1, 1]
    private static let rotF = [0, 1, 0, 1, 0, 1, 0, 1]

    /// Image of `move` under D4 operation r (0..7), about the board centre.
    static func rotate(_ move: Int, _ r: Int, size: Int = size) -> Int {
        let off = size / 2
        let x = (move % size) - off
        let y = (move / size) - off
        var x1 = x * rotX[r]
        var y1 = y * rotY[r]
        if rotF[r] == 1 { Swift.swap(&x1, &y1) }
        return (x1 + off) + (y1 + off) * size
    }

    /// The operations (0..7) that map the current coloured position onto itself.
    static func stabilizer(_ valueAt: (Int) -> Int, size: Int = size) -> [Int] {
        var stab: [Int] = []
        for r in 0..<8 {
            var invariant = true
            var m = 0
            while m < size * size && invariant {
                let v = valueAt(m)
                if v > 0 && valueAt(rotate(m, r, size: size)) != v { invariant = false }
                m += 1
            }
            if invariant { stab.append(r) }
        }
        return stab
    }

    /// True if `move` maps onto an already-offered point under some op in `stab`.
    static func isOfferDup(_ move: Int, offers: [Int], stab: [Int], size: Int = size) -> Bool {
        let acc = Set(offers)
        return stab.contains { acc.contains(rotate(move, $0, size: size)) }
    }

    static func isSymmetricDup(_ move: Int, offers: [Int], valueAt: (Int) -> Int, size: Int = size) -> Bool {
        return isOfferDup(move, offers: offers, stab: stabilizer(valueAt, size: size), size: size)
    }
}
```

- [ ] **Step 4: Run to verify it passes** — Expected: all PASS.

- [ ] **Step 5: Commit**
```bash
git add test1/PenteEngine/RenjuLiveSymmetry.swift PenteEngineTests/RenjuLiveSymmetryTests.swift
git commit -m "feat(renju-live): stabilizer-based offer-symmetry dedup (matches server)"
```

---

## Phase B — Live-model wiring

### Task 4: Variant routing + 15×15 geometry + board colour

**Files:**
- Modify: `test1/HelperClasses.swift` — `Table.penteVariant(for:)` (~267), `game` didSet (~89), `syncFromEngine` (~297), `gameColor` (~527), add `isRenju()`.
- Test: `PenteEngineTests/RenjuLiveModelTests.swift`

**Interfaces:**
- Consumes: `PenteVariant.renju` (exists), `RenjuRules` (exists).
- Produces: `Table.isRenju() -> Bool`; renju routes to `.renju` engine; `Table.gridSize == 15` and `Table.passMove == 225` for 31/32; `Table.stone(at:)` correct on 15×15; `gameColor()` returns `#D98880` for renju.

- [ ] **Step 1: Write the failing test**

Create `PenteEngineTests/RenjuLiveModelTests.swift`:
```swift
import XCTest
@testable import penteLive

final class RenjuLiveModelTests: XCTestCase {
    private func renjuTable() -> Table {
        let t = Table(table: 5); t.game = 31; t.state.state = .started; return t
    }
    func testRenjuPredicateAndGeometry() {
        let t = renjuTable()
        XCTAssertTrue(t.isRenju())
        XCTAssertEqual(t.gridSize, 15)
        XCTAssertEqual(t.passMove, 225)
    }
    func testRenjuEngineIsBlackFirst15x15() {
        let t = renjuTable()
        t.addMove(move: 112)         // server auto-centre, index (7,7)
        XCTAssertEqual(t.stone(at: 112), 2) // black first
        t.addMove(move: 113)
        XCTAssertEqual(t.stone(at: 113), 1) // white second
    }
    func testRenjuColorIsDustyRose() {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        renjuTable().gameColor().getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertEqual(Double(r), 0.851, accuracy: 0.01)
        XCTAssertEqual(Double(g), 0.533, accuracy: 0.01)
        XCTAssertEqual(Double(b), 0.502, accuracy: 0.01)
    }
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (`isRenju` missing; gridSize 19; stone(at:112) wrong; colour green).

- [ ] **Step 3: Implement**

In `HelperClasses.swift`:

(a) `game` didSet — set gridSize/passMove for renju:
```swift
    var game = 1 {
        didSet {
            if game != oldValue {
                engine = PenteGame(variant: penteVariant(for: game))
                if game == GameEnum.renju.rawValue || game == GameEnum.speedRenju.rawValue {
                    gridSize = 15; passMove = 15 * 15
                }
            }
        }
    }
```

(b) Add `isRenju()` next to `isGo()` (~557):
```swift
    func isRenju() -> Bool {
        return game == GameEnum.renju.rawValue || game == GameEnum.speedRenju.rawValue
    }
```

(c) `penteVariant(for:)` — add before `default`:
```swift
        case .renju, .speedRenju: return .renju
```

(d) `syncFromEngine()` — index by the engine board dimension (15 for renju) so the 15×15 engine mirrors correctly:
```swift
    private func syncFromEngine() {
        let maskAllowed = rated || game == GameEnum.gPente.rawValue || game == GameEnum.speedGPente.rawValue
        let dim = isRenju() ? 15 : 19
        if isRenju() { abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19) }
        for r in 0 ..< dim {
            for c in 0 ..< dim {
                let value = engine.stone(at: r * dim + c)
                abstractBoard[r][c] = (value == -1 && !maskAllowed) ? 0 : value
            }
        }
        whiteCaptures = engine.whiteCaptures
        blackCaptures = engine.blackCaptures
    }
```

(e) `gameColor()` — insert a renju branch before the final `else` (renju ids 31/32 are above swap2Keryo 29/30, so they currently fall into the swap2Keryo green `else`):
```swift
        } else if game < GameEnum.renju.rawValue {
            return UIColor(red: 0.31, green: 0.78, blue: 0.47, alpha: 1.00)
        } else {
            return BoardVariantMapping.backgroundColor(for: .renju, boatPente: false)
        }
```
(Replaces the existing final `} else { return UIColor(red: 0.31, ...) }`.)

- [ ] **Step 4: Run to verify it passes** — Expected: all PASS. Then run the full existing suite once (`-only-testing:PenteEngineTests`) to confirm no regression in `BoardVariantMappingTests` / `TableEngineRoutingTests` / `RuleSetTests`.

- [ ] **Step 5: Commit**
```bash
git add test1/HelperClasses.swift PenteEngineTests/RenjuLiveModelTests.swift
git commit -m "feat(renju-live): route 31/32 to renju engine, 15x15 geometry, dusty-rose colour"
```

---

### Task 5: Tracking reducers on `Table` + advance-after-move + turn derivation

**Files:**
- Modify: `test1/HelperClasses.swift` — `Table.addMove` (~315), `addMoves` (~210), `reset` (~370), `swapSeats` (~415), `currentPlayer` (~467); add `applyRenjuSwap/Offer10/Select1` and `advanceRenjuTracking`.
- Test: extend `PenteEngineTests/RenjuTrackingTests.swift`

**Interfaces:**
- Consumes: `RenjuTracking`, `renjuOpeningPlayer` (Tasks 1-2).
- Produces: `Table.advanceRenjuTracking(isRejoin: Bool)`; `Table.applyRenjuSwap(swap: Bool, move: Int)`; `Table.applyRenjuOffer10(moves: [Int])`; `Table.applyRenjuSelect1(move: Int)`; renju arm in `swapSeats`; tracking reset in `reset`; `currentPlayer()` returns the opening seat / black-first parity for renju.

- [ ] **Step 1: Write the failing test** (mirrors `renjuTracking.test.js`; drives the real `Table` API)

Append to `RenjuTrackingTests.swift`:
```swift
extension RenjuTrackingTests {
    private func started() -> Table { let t = Table(table: 5); t.game = 31; t.state.state = .started; return t }
    private func phase(_ t: Table) -> RenjuPhase { renjuPhase(t.moves.count, t.state.renju) }

    func testAddMoveOpensSwapWindow1to4() {
        let t = started(); t.addMove(move: 112)
        XCTAssertTrue(t.state.renju.awaitingSwap)
        XCTAssertFalse(t.state.renju.complete)
    }
    func testSwapFalseAtN4ChoosesBranchA() {
        let t = started(); [112,113,97,98].forEach { t.addMove(move: $0) }
        t.applyRenjuSwap(swap: false, move: 129)
        XCTAssertFalse(t.state.renju.awaitingSwap)
        XCTAssertTrue(t.state.renju.branchChosen)
        XCTAssertFalse(t.state.renju.tenOffer)
    }
    func testOffer10RecordsBranchB() {
        let t = started(); [112,113,97,98].forEach { t.addMove(move: $0) }
        let offers = [40,41,42,55,57,70,71,72,160,176]
        t.applyRenjuOffer10(moves: offers)
        XCTAssertTrue(t.state.renju.branchChosen)
        XCTAssertTrue(t.state.renju.tenOffer)
        XCTAssertEqual(t.state.renju.offered, offers)
        XCTAssertFalse(t.state.renju.awaitingSwap)
    }
    func testSelect1ThenMove5CompletesBranchB() {
        let t = started(); [112,113,97,98].forEach { t.addMove(move: $0) }
        t.applyRenjuOffer10(moves: [40,41,42,55,57,70,71,72,160,176])
        t.applyRenjuSelect1(move: 57)
        XCTAssertEqual(t.state.renju.selected, 57)
        t.addMove(move: 57)
        XCTAssertTrue(t.state.renju.complete)
    }
    func testBranchAMove5ThenWindow5ThenMove6Completes() {
        let t = started(); [112,113,97,98].forEach { t.addMove(move: $0) }
        t.applyRenjuSwap(swap: false, move: 129) // branch A
        t.addMove(move: 129)                     // move 5 -> window 5 opens
        XCTAssertTrue(t.state.renju.awaitingSwap)
        t.applyRenjuSwap(swap: false, move: -1)  // bare window-5 decline
        t.addMove(move: 200)                      // move 6
        XCTAssertTrue(t.state.renju.complete)
    }
    func testWindow1to3DeclineDoesNotChooseBranch() {
        let t = started(); [112,113].forEach { t.addMove(move: $0) }
        t.applyRenjuSwap(swap: false, move: 97)
        XCTAssertFalse(t.state.renju.branchChosen)
        XCTAssertFalse(t.state.renju.awaitingSwap)
    }
    func testLiveTakeoverAtN4GoesToBranch() {
        let t = started(); [112,113,97,98].forEach { t.addMove(move: $0) }
        t.swapSeats(swap: true, silent: false)
        XCTAssertFalse(t.state.renju.awaitingSwap)
        XCTAssertFalse(t.state.renju.branchChosen) // -> BRANCH
        t.addMove(move: 129)
        XCTAssertTrue(t.state.renju.awaitingSwap)   // window 5 opens
    }
    // rejoin: echo BEFORE the bulk move list must NOT reopen a resolved window
    func testRejoinOffer10ThenBulkIsSelection() {
        let t = started()
        t.applyRenjuOffer10(moves: [113,114,115,116,128,129,130,131,144,145])
        t.addMoves(moves: [112,113,97,98]) // bulk replay
        XCTAssertFalse(t.state.renju.awaitingSwap)
        XCTAssertEqual(phase(t), .selection)
    }
    func testRejoinSilentSwapThenBulkIsBranch() {
        let t = started()
        t.swapSeats(swap: false, silent: true) // rejoin take-over marker
        t.addMoves(moves: [112,113,97,98])
        XCTAssertFalse(t.state.renju.awaitingSwap)
        XCTAssertFalse(t.state.renju.branchChosen)
        XCTAssertEqual(phase(t), .branch)
    }
    func testRejoinNoEchoBulkIsSwap() {
        let t = started(); t.addMoves(moves: [112,113,97,98])
        XCTAssertTrue(t.state.renju.awaitingSwap)
        XCTAssertEqual(phase(t), .swap)
    }
    func testResetClearsTracking() {
        let t = started(); [112,113,97,98].forEach { t.addMove(move: $0) }
        t.applyRenjuOffer10(moves: [40,41,42,55,57,70,71,72,160,176])
        t.reset()
        XCTAssertEqual(t.state.renju.offered, [])
        XCTAssertFalse(t.state.renju.tenOffer)
    }
}
```

> Note on `swapSeats(swap:true, silent:false)`: the test does not pre-seat the table, and the existing `swapSeats` force-unwraps `seats[1]`/`seats[2]` only inside `if swap && !silent`. Seat the table in that test to avoid a nil-unwrap: add `t.seats[1] = LivePlayer(...)`/`t.seats[2] = ...` (use the project's `LivePlayer` initializer; check `HelperClasses.swift` for the exact init) before `swapSeats(swap: true, silent: false)`. For the silent-rejoin tests no seating is needed.

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (`applyRenjuSwap` etc. missing).

- [ ] **Step 3: Implement** (port react `utils.js` reducers; mutate `state.renju`)

In `Table.addMove(move:)`, after `syncFromEngine()` (before `lastMoveResult = result` is fine; place after the sync), add:
```swift
        advanceRenjuTracking(isRejoin: false)
```
In `Table.addMoves(moves:)`, after `syncFromEngine()` (the Pente-family branch, ~232) add:
```swift
        advanceRenjuTracking(isRejoin: true)
```
Add the reducers as `Table` methods:
```swift
    // Mirror react utils.js advanceRenjuTrackingAfterMove. isRejoin = bulk resetBoard+replay path
    // (the decision echoes arrived FIRST, so do not reopen a window they already resolved).
    func advanceRenjuTracking(isRejoin: Bool) {
        guard isRenju() else { return }
        let n = moves.count
        if !isRejoin { state.renju.swapTaken = false } // incremental move opens a fresh window
        let windowResolved = state.renju.swapTaken
            || (n == 4 && (state.renju.branchChosen || state.renju.tenOffer || state.renju.selected != nil))
        let windowOpens = !windowResolved && (n <= 4 || (n == 5 && !state.renju.tenOffer))
        state.renju.awaitingSwap = windowOpens
        state.renju.complete = !windowOpens && n >= 5
    }

    func applyRenjuSwap(swap: Bool, move: Int) {
        guard isRenju() else { return }
        state.renju.awaitingSwap = false
        // swap=false at the move-4 window continues Branch A; the stone rides the next move event.
        if swap == false && moves.count == 4 {
            state.renju.branchChosen = true
            state.renju.tenOffer = false
        }
    }

    func applyRenjuOffer10(moves offers: [Int]) {
        guard isRenju() else { return }
        state.renju.branchChosen = true
        state.renju.tenOffer = true
        state.renju.offered = offers
        state.renju.awaitingSwap = false
    }

    func applyRenjuSelect1(move: Int) {
        guard isRenju() else { return }
        state.renju.selected = move
    }
```
In `Table.swapSeats(swap:silent:)`, at the end of the method (after the existing if/else), add the renju arm (handles live take-over AND the silent rejoin marker):
```swift
        if isRenju() {
            state.renju.awaitingSwap = false
            state.renju.swapTaken = true
        }
```
In `Table.reset()`, after `state.swap2State = .noChoice`, add:
```swift
        state.renju = RenjuTracking()
```
In `Table.currentPlayer()`, add a renju arm. Insert after the `isGo()` block and before the `game != connect6` branch:
```swift
        } else if isRenju() {
            if let p = renjuOpeningPlayer(moves.count, state.renju) { return p }
            return 2 - (moves.count % 2) // black-first normal alternation
        } else if game != GameEnum.connect6.rawValue && game != GameEnum.speedConnect6.rawValue {
```
(Make it an `else if` chain off the existing `if isGo()`.)

- [ ] **Step 4: Run to verify it passes** — Expected: all RenjuTrackingTests PASS; rerun `RenjuOpeningPhaseTests` + `RenjuLiveModelTests` green.

- [ ] **Step 5: Commit**
```bash
git add test1/HelperClasses.swift PenteEngineTests/RenjuTrackingTests.swift
git commit -m "feat(renju-live): tracking reducers, advance-after-move, renju turn derivation"
```

---

## Phase C — Socket I/O

### Task 6: Outbound senders + codec test

**Files:**
- Modify: `test1/TableViewController.swift` (near `sendMove`, ~547)
- Test: `PenteEngineTests/RenjuLiveModelTests.swift` (codec round-trip — see note)

**Interfaces:**
- Produces: `TableViewController.sendRenjuSwap(swap: Bool, move: Int)`, `sendRenjuOffer10(moves: [Int])`, `sendRenjuSelect1(move: Int)` — each builds the single-key dict (with `"time": 0`) and calls `socket.sendEvent(eventDictionary:)`.

- [ ] **Step 1: Write the failing test**

The senders depend on `socket`/`me`/`table` (a live `TableViewController`), which is impractical to unit-test headlessly. Instead, unit-test a **pure dict builder** and have the senders call it, so the wire shape is covered. Add to `RenjuLiveModelTests.swift`:
```swift
extension RenjuLiveModelTests {
    func testRenjuEventDicts() {
        let swapDict = RenjuWire.swap(swap: true, move: -1, player: "alice", table: 5)
        let inner = swapDict["dsgRenjuTaraguchiSwapTableEvent"] as! [String: Any]
        XCTAssertEqual(inner["swap"] as! Bool, true)
        XCTAssertEqual(inner["move"] as! Int, -1)
        XCTAssertEqual(inner["player"] as! String, "alice")
        XCTAssertEqual(inner["table"] as! Int, 5)
        XCTAssertEqual(inner["time"] as! Int, 0)

        let offerDict = RenjuWire.offer10(moves: [1,2,3,4,5,6,7,8,9,10], player: "alice", table: 5)
        XCTAssertNotNil(offerDict["dsgRenjuTaraguchiOffer10TableEvent"])
        XCTAssertEqual((offerDict["dsgRenjuTaraguchiOffer10TableEvent"] as! [String: Any])["moves"] as! [Int], [1,2,3,4,5,6,7,8,9,10])

        let selDict = RenjuWire.select1(move: 130, player: "bob", table: 5)
        XCTAssertEqual((selDict["dsgRenjuTaraguchi10Select1TableEvent"] as! [String: Any])["move"] as! Int, 130)
    }
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (`RenjuWire` missing).

- [ ] **Step 3: Implement**

Create `test1/PenteEngine/RenjuWire.swift` (pure builders — keep the exact keys/fields here, one source of truth):
```swift
import Foundation

/// Builders for the three live Renju opening events. Keys are byte-for-byte the server contract
/// (note the asymmetric "10": Offer10 vs Taraguchi10Select1). Outbound always carries time:0.
enum RenjuWire {
    static func swap(swap: Bool, move: Int, player: String, table: Int) -> [String: Any] {
        ["dsgRenjuTaraguchiSwapTableEvent": ["swap": swap, "move": move, "player": player, "table": table, "time": 0] as [String: Any]]
    }
    static func offer10(moves: [Int], player: String, table: Int) -> [String: Any] {
        ["dsgRenjuTaraguchiOffer10TableEvent": ["moves": moves, "player": player, "table": table, "time": 0] as [String: Any]]
    }
    static func select1(move: Int, player: String, table: Int) -> [String: Any] {
        ["dsgRenjuTaraguchi10Select1TableEvent": ["move": move, "player": player, "table": table, "time": 0] as [String: Any]]
    }
}
```
In `TableViewController.swift`, after `sendMove(move:)`:
```swift
    func sendRenjuSwap(swap: Bool, move: Int) {
        socket.sendEvent(eventDictionary: RenjuWire.swap(swap: swap, move: move, player: me, table: table.table))
    }
    func sendRenjuOffer10(moves: [Int]) {
        socket.sendEvent(eventDictionary: RenjuWire.offer10(moves: moves, player: me, table: table.table))
    }
    func sendRenjuSelect1(move: Int) {
        socket.sendEvent(eventDictionary: RenjuWire.select1(move: move, player: me, table: table.table))
    }
```
Add `RenjuWire.swift` to the app target **and** `PenteEngineTests` Compile Sources (it's pure Foundation).

- [ ] **Step 4: Run to verify it passes** — Expected: PASS.

- [ ] **Step 5: Commit**
```bash
git add test1/PenteEngine/RenjuWire.swift test1/TableViewController.swift PenteEngineTests/RenjuLiveModelTests.swift
git commit -m "feat(renju-live): outbound renju event builders + senders"
```

---

### Task 7: Inbound handlers + socket arms + move-error arm

**Files:**
- Modify: `test1/HelperClasses.swift` — `TablesAndPlayer` forwarders (~778).
- Modify: `test1/RoomViewController.swift` — handlers (near `swapSeatsTableEvent` ~745, `moveTableEvent` ~871).
- Modify: `test1/PenteLiveSocket.swift` — `processEvent` arms (~170).

**Interfaces:**
- Consumes: `Table.applyRenjuSwap/Offer10/Select1` (Task 5).
- Produces: `TablesAndPlayer.renjuSwap(tableId:swap:move:)`, `renjuOffer10(tableId:moves:)`, `renjuSelect1(tableId:move:)`; `RoomViewController.renjuSwapTableEvent/renjuOffer10TableEvent/renjuSelect1TableEvent/moveErrorTableEvent(event:)`; four new `processEvent` arms.

- [ ] **Step 1: Write the failing test** (forwarder-level, the unit-testable seam)

Add to `RenjuLiveModelTests.swift`:
```swift
extension RenjuLiveModelTests {
    private func startedInPAT() -> (TablesAndPlayer, Table) {
        let pat = TablesAndPlayer(); let t = Table(table: 5); t.game = 31; t.state.state = .started
        pat.tables[5] = t; return (pat, t)
    }
    func testForwardersMutateTracking() {
        let (pat, t) = startedInPAT(); [112,113,97,98].forEach { t.addMove(move: $0) }
        pat.renjuOffer10(tableId: 5, moves: [40,41,42,55,57,70,71,72,160,176])
        XCTAssertTrue(t.state.renju.tenOffer)
        pat.renjuSelect1(tableId: 5, move: 57)
        XCTAssertEqual(t.state.renju.selected, 57)
    }
    func testSwapForwarderBranchA() {
        let (pat, t) = startedInPAT(); [112,113,97,98].forEach { t.addMove(move: $0) }
        pat.renjuSwap(tableId: 5, swap: false, move: 129)
        XCTAssertTrue(t.state.renju.branchChosen)
    }
}
```

- [ ] **Step 2: Run to verify it fails** — Expected: FAIL (forwarders missing).

- [ ] **Step 3: Implement**

In `TablesAndPlayer` (`HelperClasses.swift`, after `swap2Pass(tableId:silent:)` ~792):
```swift
    func renjuSwap(tableId: Int, swap: Bool, move: Int) {
        guard let table = tables[tableId] else { return }
        table.applyRenjuSwap(swap: swap, move: move)
    }
    func renjuOffer10(tableId: Int, moves: [Int]) {
        guard let table = tables[tableId] else { return }
        table.applyRenjuOffer10(moves: moves)
    }
    func renjuSelect1(tableId: Int, move: Int) {
        guard let table = tables[tableId] else { return }
        table.applyRenjuSelect1(move: move)
    }
```
In `RoomViewController.swift` (after `swap2PassTableEvent` ~769). **Branch on `player == nil`** for rejoin signals (still mutate tracking; the bulk move list follows). The three reducers are idempotent w.r.t. a following bulk replay because `advanceRenjuTracking(isRejoin:true)` respects the resolved window:
```swift
    func renjuSwapTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            let swap = event["swap"] as! Bool
            let move = event["move"] as! Int
            self.playersAndTables.renjuSwap(tableId: tableId, swap: swap, move: move)
            if tableId == self.tableViewController?.table.table { self.tableViewController?.stateChanged() }
        }
    }
    func renjuOffer10TableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            let moves = event["moves"] as! [Int]
            self.playersAndTables.renjuOffer10(tableId: tableId, moves: moves)
            if tableId == self.tableViewController?.table.table { self.tableViewController?.stateChanged() }
        }
    }
    func renjuSelect1TableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            let move = event["move"] as! Int
            self.playersAndTables.renjuSelect1(tableId: tableId, move: move)
            if tableId == self.tableViewController?.table.table { self.tableViewController?.stateChanged() }
        }
    }
    func moveErrorTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as? Int
            if tableId == self.tableViewController?.table.table {
                self.tableViewController?.renjuDecisionRejected(error: event["error"] as? Int ?? 99)
            }
        }
    }
```
> `tableViewController?.renjuDecisionRejected(error:)` is defined in Task 10 (it releases the pending lock + shows a message). If implementing handlers before the UI task, add a temporary no-op stub `func renjuDecisionRejected(error: Int) {}` in `TableViewController` and flesh it out in Task 10.

In `PenteLiveSocket.processEvent`, add after the `dsgSwap2PassTableEvent` arm (~171):
```swift
        } else if let content = event?["dsgRenjuTaraguchiSwapTableEvent"] {
            room.renjuSwapTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgRenjuTaraguchiOffer10TableEvent"] {
            room.renjuOffer10TableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgRenjuTaraguchi10Select1TableEvent"] {
            room.renjuSelect1TableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgMoveTableErrorEvent"] {
            room.moveErrorTableEvent(event: content as! [String: Any])
```

- [ ] **Step 4: Run to verify it passes** — Expected: forwarder tests PASS; build is clean (use the `build` variant of the canonical command to catch handler compile errors).

- [ ] **Step 5: Commit**
```bash
git add test1/HelperClasses.swift test1/RoomViewController.swift test1/PenteLiveSocket.swift PenteEngineTests/RenjuLiveModelTests.swift
git commit -m "feat(renju-live): inbound renju handlers, socket arms, move-error arm"
```

---

## Phase D — UI (Swap2 methodology + on-board interaction)

> UI tasks are not headless-unit-testable. Each ends with a clean `build` and is verified live in Task 11. Verify on iPhone and iPad.

### Task 8: LiveBoard 15×15 star points + translucent candidate rendering

**Files:**
- Modify: `test1/LiveBoard.swift` (`draw()` ~80-151, `gridSize` ~23)

- [ ] **Step 1: Implement star points + candidates**

In `LiveBoard.draw()`, add a `gridSize == 15` non-Go star-point layout drawing dots at indices `[48,52,56,108,112,116,168,172,176]` (the generic Pente 5-circle layout is 19×19-specific — gate it to `gridSize == 19`). Add a translucent-candidate pass: expose `var renjuCandidates: [Int] = []` and `var renjuCandidateColor: Int = 2` on `LiveBoard`; in `draw()`, after the stones, render each candidate index as a stone of `renjuCandidateColor` at `alpha = 0.5` (reuse the existing `whiteStone`/`blackStone` primitive used for translucent/dead stones). Set `setNeedsDisplay()` when `renjuCandidates` changes.

- [ ] **Step 2: Build clean** — run the canonical command with `build`. Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**
```bash
git add test1/LiveBoard.swift
git commit -m "feat(renju-live): 15x15 star points + translucent offer/selection candidates"
```

---

### Task 9: Opening action sheets in `stateChanged()` (Swap2 methodology)

**Files:**
- Modify: `test1/TableViewController.swift` (`stateChanged()` — after the `isSwap2()` block ~649)

- [ ] **Step 1: Implement the renju opening dispatch**

After the `if table.isSwap2() { … }` block, add an `if table.isRenju()` block that mirrors the Swap2 action-sheet idiom. Compute `let n = table.moves.count`, `let t = table.state.renju`, `let started = table.state.state == .started`, `let me = self.me`, and gate on `table.currentPlayerName() == me` (so only the to-move seat is prompted). Then:
- If `isRenjuSwapChoice(n, t, started)` **or** `isRenjuBranchChoice(n, t, started)`: build a `UIAlertController(title: "Continue play as"/"Renju opening", message: nil, preferredStyle: .actionSheet)`. Using `let buttons = renjuModalButtons(n, t, started)`, add actions:
  - if `buttons.swap`: "Take over" → `self.sendRenjuSwap(swap: true, move: -1); self.renjuPending = true`.
  - if `buttons.declinePlace`: title `n == 5 ? "Decline" : (isRenjuBranchChoice(...) || n == 4 ? "Place 5th move" : "Decline & place")`. For `n == 5` (bare window-5 decline) → `self.sendRenjuSwap(swap: false, move: -1); self.renjuPending = true`. Otherwise → arm placement: `self.renjuBoardMode = .placing`.
  - if `buttons.offer10`: "Offer ten 5th moves" → `self.renjuBoardMode = .offering; self.renjuPicks = []` and show the offer counter.
  - For iPad: `alertController.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?[isArenaTable ? 0 : 1]` (exactly as Swap2).
  - Present **only** if not already presenting and `renjuBoardMode == .idle` and `!renjuPending` (avoid re-popping on every `stateChanged`).
- If `isRenjuSelection(n, t, started)` and `table.currentPlayerName() == me`: set `self.renjuBoardMode = .selecting`, set `board.renjuCandidates = t.offered` / `zoomedBoard.renjuCandidates = t.offered` (candidate colour = `2 - (n % 2)`), and show a brief banner ("Pick one of the 10 offered moves"). The white-selector also receives a `dsgSystemMessageTableEvent` — that is informational; the selection UI is driven here off the derived phase.

Declare the UI state on `TableViewController`:
```swift
    enum RenjuBoardMode { case idle, placing, offering, selecting }
    var renjuBoardMode: RenjuBoardMode = .idle
    var renjuPicks: [Int] = []
    var renjuPending = false
```
Reset `renjuBoardMode = .idle; renjuPicks = []; renjuPending = false` whenever a new stone/echo advances the phase out of the current mode (recompute at the top of the renju block: if the derived phase no longer matches the active mode, reset it and clear `board.renjuCandidates`).

- [ ] **Step 2: Build clean.** Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**
```bash
git add test1/TableViewController.swift
git commit -m "feat(renju-live): opening action sheets (Swap2 methodology) + selection gating"
```

---

### Task 10: Board sub-modes in `boardTouch` (constrained placement / offer multi-select / selection) + pending lock

**Files:**
- Modify: `test1/TableViewController.swift` (`boardTouch` ~165, add `renjuDecisionRejected`, offer counter UI)

- [ ] **Step 1: Implement the touch routing**

At the top of `boardTouch`, before the existing `me != table.currentPlayerName()` early-return, handle renju sub-modes. Compute the tapped index `let idx = i * table.gridSize + j` (using the existing `i,j` computation from the zoom path — refactor so the index is available on `.ended`). On gesture `.ended` with a valid in-bounds empty cell:
- **`.placing`** (constrained single placement): require `withinRenjuBox(idx, radius: renjuBoxRadius(table.moves.count))` (centre (7,7)); if outside, ignore. On a valid tap: `sendRenjuSwap(swap: false, move: idx); renjuPending = true; renjuBoardMode = .idle`. (The server echoes the swap then the stone's own move event.)
- **`.offering`**: toggle `idx` in `renjuPicks` subject to dedup — accept only if `!RenjuLiveSymmetry.isOfferDup(idx, offers: renjuPicks, stab: stab)` where `stab = RenjuLiveSymmetry.stabilizer({ table.stone(at: $0) })` (recompute when picks change) and the cell is empty. Update `board.renjuCandidates = renjuPicks`; update the counter label "N/10". When `renjuPicks.count == 10`: `sendRenjuOffer10(moves: renjuPicks); renjuPending = true; renjuBoardMode = .idle; renjuPicks = []; board.renjuCandidates = []`.
- **`.selecting`**: if `idx` is in `table.state.renju.offered`: `sendRenjuSelect1(move: idx); renjuPending = true; renjuBoardMode = .idle; board.renjuCandidates = []`.
- Otherwise (`.idle`, opening complete or normal MOVE phase): fall through to the existing placement path. During the opening MOVE phase (e.g. the auto-centre is done and it is a plain placement window with no swap), the central-box constraint still applies for moves 2-5 — gate the normal `sendMove` by `withinRenjuBox` when `table.isRenju() && renjuBoxRadius(table.moves.count) > 0`.

Add helpers + the rejection handler + the ghost colour fix:
```swift
    private func withinRenjuBox(_ idx: Int, radius: Int) -> Bool {
        if radius == 0 { return true }
        let x = idx % table.gridSize, y = idx / table.gridSize
        return abs(x - 7) <= radius && abs(y - 7) <= radius
    }
    func renjuDecisionRejected(error: Int) {
        renjuPending = false
        renjuBoardMode = .idle
        renjuPicks = []
        board.renjuCandidates = []; zoomedBoard.renjuCandidates = []
        addText(text: "* Renju move rejected (\(error)) — try again")
        stateChanged()
    }
```
Ghost-stone colour during renju (the placed colour is black-first, decoupled from the seat): where `boardTouch` sets `zoomedStone.color = StoneColor(rawValue: table.currentPlayer())!`, special-case renju:
```swift
            if table.isRenju() {
                zoomedStone.color = StoneColor(rawValue: 2 - (table.moves.count % 2))!
            } else {
                zoomedStone.color = StoneColor(rawValue: table.currentPlayer())!
            }
```
Clear `renjuPending` when an inbound echo/move advances the state: at the end of the renju block in `stateChanged()`, set `renjuPending = false` once `table.moves.count` or the tracking has changed since the send (simplest: clear `renjuPending` at the top of each inbound renju handler's `stateChanged()` pass — i.e. reset it in `stateChanged()` whenever the derived phase/movecount differs from what was pending). Keep it minimal: clearing `renjuPending = false` at the start of the `isRenju()` block in `stateChanged()` is acceptable since every inbound echo calls `stateChanged()`.

Offer counter UI: add a small `UILabel` (and an implicit "tap the board" hint) shown while `renjuBoardMode == .offering` displaying `"\(renjuPicks.count)/10"`; hide it otherwise. Anchor it near the board; verify it does not overlap the seats/timer on iPhone or iPad.

- [ ] **Step 2: Build clean.** Expected: BUILD SUCCEEDED.

- [ ] **Step 3: Commit**
```bash
git add test1/TableViewController.swift
git commit -m "feat(renju-live): board sub-modes (place/offer/select), box gating, pending lock"
```

---

## Phase E — Live verification

### Task 11: End-to-end live verification vs localhost

**Files:** none (verification + any fixes uncovered).

**Accounts:** `iostest` / `app_tsetsoi` and `graviton` / `virginia` (one per seat). Backend: the running localhost stack. Run two app instances (two simulators, or app + the React live client) signed in as the two accounts and join the same Renju (id 31) table.

- [ ] **Step 1:** Create/join a Renju table; confirm the board renders **15×15**, dusty-rose `#D98880`, with the 9 star points, and that the **auto-centre** (move 1) appears as a black stone at (7,7) without the client placing it.
- [ ] **Step 2 — windows 1-3 decline+place:** as the window decider, choose "Decline & place" and tap inside the box (3×3/5×5/7×7); confirm the wire shows `[dsgRenjuTaraguchiSwapTableEvent swap:false]` **then** `[dsgMoveTableEvent]`, and the stone lands. Confirm an out-of-box tap is ignored.
- [ ] **Step 3 — take-over:** choose "Take over"; confirm a **non-silent `dsgSwapSeatsTableEvent`** (no renju echo), the seats swap exactly once, and the phase advances (n<4 → MOVE; n==4 → BRANCH).
- [ ] **Step 4 — Branch A:** at the move-4 window choose "Place 5th move" in the 9×9 box; then at the move-5 window the white player takes over or declines (bare, `move:-1`); confirm move 6 is whole-board and the opening completes.
- [ ] **Step 5 — Branch B:** at the move-4 window choose "Offer ten"; tap 10 board cells (confirm symmetric/occupied cells are refused and the counter reaches 10 → auto-send); confirm the **offer reaches both** clients, a `dsgSystemMessageTableEvent` reaches **only** the selector, the white selection screen shows the 10 translucent candidates, selecting sends `select1`, and a single `dsgMoveTableEvent` places move 5 → complete.
- [ ] **Step 6 — rejoin:** disconnect/rejoin one account at each decision point (SILENT_SWAP / OFFERS / SELECT1 / NONE); confirm the `player == null` signal arrives, seats come from `sendPlayingPlayers`, the bulk move list replays, and the derived phase matches the other client (no spurious swap modal in BRANCH/SELECTION).
- [ ] **Step 7 — errors:** send an out-of-box stone / a symmetric or non-distinct offer set / an out-of-turn decision; confirm `dsgMoveTableErrorEvent` reaches only the sender (offer-10 → `move=-1`), the pending lock releases, and a corrected re-send succeeds.
- [ ] **Step 8 — cross-client parity:** run the iOS app against the **same table** as the React live client; confirm identical board state and phase prompts both directions.
- [ ] **Step 9 — device matrix:** repeat the action-sheet, offer multi-select + counter, and selection flows on **iPhone and iPad** (popover vs modal).
- [ ] **Step 10 — full regression:** run `xcodebuild test … -only-testing:PenteEngineTests` and confirm the entire suite is green. Commit any fixes uncovered during verification with descriptive messages.

---

## Self-Review (filled in)

**Spec coverage:** §3 wire protocol → Tasks 6,7 (+ `RenjuWire`, the four arms, `-1` sentinel, `time:0`). §4 FSM/derivation → Tasks 1,2,3,5 (classifiers/reducers/advance, ported verbatim + truth-table tests). §5 live-model wiring → Task 4 (variant, 15×15, syncFromEngine, colour) + Task 5 (gridSize). §6 UI → Tasks 8,9,10 (Swap2 action sheets, board sub-modes, candidates, counter, selection). §7 reuse → engine/`RenjuLiveSymmetry`/`BoardVariantMapping`/`swapSeats`/move pipeline/system message used across tasks. §8 win/forbidden → presentation-only; Task 7 move-error arm + Task 11 step 7. §9 testing → unit tests per task + Task 11 live matrix.

**Placeholder scan:** UI Tasks 9/10 describe behaviour in prose with concrete code for the helpers/state; the action-sheet/touch-routing bodies are specified action-by-action with exact event calls — acceptable for UIKit glue that cannot be headlessly tested. `renjuDecisionRejected` stub dependency between Task 7 and Task 10 is called out explicitly.

**Type consistency:** `RenjuTracking` fields, `RenjuPhase` cases, `renjuPhase/renjuOpeningPlayer/renjuBoxRadius/renjuModalButtons` signatures, `RenjuLiveSymmetry` API, `RenjuWire` keys, `Table.applyRenju*`/`advanceRenjuTracking`/`isRenju`, `TablesAndPlayer.renju*`, and the `RoomViewController`/`PenteLiveSocket` arm names are used consistently across tasks.
