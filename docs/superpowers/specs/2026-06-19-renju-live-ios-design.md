# Live Renju (Taraguchi-10) for penteLive iOS — Design

**Date:** 2026-06-19
**Branch:** `renju-live`
**Status:** Approved design; implementation pending.

## 1. Goal & scope

Implement **live** (real-time, socket-driven) Renju with the Taraguchi-10 opening in the
penteLive iOS app, matching the server contract on `pente.org` (PR #8, merged) and the
behaviour of the React live-room client (`react_live_game_room` PR #5, merged).

**In scope:** live game ids **31 (Renju)** and **32 (Speed Renju)** — identical board,
engine, and wire protocol; they differ only in clock (server-side).

**Out of scope:**
- Turn-based Renju (id **81**) — already shipped on the separate ObjC `BoardViewController`
  HTTP/JSON stack; untouched here.
- Client-side forbidden-point detection (overline / double-three / double-four). The server
  is authoritative; iOS stays presentation-only.
- Any new lobby / game-creation UI — `SocialViewController.swift:36` already lists Renju 31 /
  Speed Renju 32 / Turn-based Renju 81.

**Authority rule (from the owner):** where docs and code disagree, **the code wins**. The
server PR #8 Java handlers define the wire contract; the React PR #5 client is the reference
behaviour iOS must match.

## 2. Decisions

- **UI idiom = the live Swap2 methodology.** Binary/ternary opening choices are presented as
  `UIAlertController(.actionSheet)` built in `TableViewController.stateChanged()`, gated by a
  count/state-derived predicate on `Table` plus a seat check, each `UIAlertAction` sending a
  hand-built event dict via `socket.sendEvent`, with the iPad popover anchored to
  `navigationItem.rightBarButtonItems`. (Mirrors `TableViewController.swift` ~610–680.)
- **Central box = invisible gating.** Taps outside the legal box do nothing; no box is drawn.
  Consistent with Swap2 (no placement hints) and turn-based Renju (invisible `-1` mask).
- **Scope = 31 + 32** (free; share everything but the clock).
- **Stone colour is already correct.** `RenjuRules.cadence = .blackFirst` and
  `PenteGame.colorForMove` returns `2 - (index%2)` (move 0 = black). Do **not** re-flip colour;
  the doc note claiming a cadence fix is still required is stale.

## 3. Wire protocol (authoritative)

Transport unchanged: each event is one UTF-8 JSON object `{"<key>": {payload}}` framed by a
single `0xFF` (255) terminator over the TLS `GCDAsyncSocket` in `PenteLiveSocket.swift`. Decode
is **name-keyed** (`JSONSerialization` → `[String: Any]`); field order is non-load-bearing, but
the wrapper key and field names are exact. Every renju payload also carries inherited
`player:String`, `table:Int`, `time:Long`. **Outbound from iOS must include `"time": 0`
literally** (no auto-stamp; server restamps non-zero epoch-ms on echo).

### 3.1 The three events (copy key names byte-for-byte)

| Event key | Own fields | Meaning |
|---|---|---|
| `dsgRenjuTaraguchiSwapTableEvent` | `swap:Bool`, `move:Int` | swap-window decision |
| `dsgRenjuTaraguchiOffer10TableEvent` | `moves:[Int]` (exactly 10) | Branch B offer |
| `dsgRenjuTaraguchi10Select1TableEvent` | `move:Int` | white selects 1 of 10 |

Note the **asymmetric `10`**: it trails `Offer` (`…Offer10…`) but precedes `Select1`
(`…Taraguchi10Select1…`). Match the backend `DSGEventWrapper` exactly.

### 3.2 Outbound literals (templates to mirror `sendMove`)

```
take-over (window 1–4):   {"dsgRenjuTaraguchiSwapTableEvent": {"swap": true,  "move": -1,  "player": me, "table": t, "time": 0}}
decline + place (1–4):    {"dsgRenjuTaraguchiSwapTableEvent": {"swap": false, "move": idx, "player": me, "table": t, "time": 0}}
bare move-5 decline (A):  {"dsgRenjuTaraguchiSwapTableEvent": {"swap": false, "move": -1,  "player": me, "table": t, "time": 0}}
offer 10 (Branch B):      {"dsgRenjuTaraguchiOffer10TableEvent": {"moves": [..10..], "player": me, "table": t, "time": 0}}
select 1 (white):         {"dsgRenjuTaraguchi10Select1TableEvent": {"move": idx, "player": me, "table": t, "time": 0}}
```

- **`-1` is the no-move sentinel.** Never send `0` (a legal corner cell). The `move` field is
  always present; it is `-1` on `swap:true` and on the bare move-5 decline.

### 3.3 Inbound rules (CODE WINS — these correct stale prose)

1. **Decision echoes never carry stones.** Place no stone from any of the three renju events.
   Stones always ride the existing `dsgMoveTableEvent` path
   (`RoomViewController.moveTableEvent`). The renju echo is a marker that *precedes* the stone's
   own move event.
2. **Center auto-placed.** The server auto-plays move 1 (center, index 112) and it arrives as an
   ordinary `dsgMoveTableEvent`. The client must not place it itself — only size the board to 15.
3. **Take-over is NOT a renju echo.** On `swap:true` the server emits a non-silent
   `dsgSwapSeatsTableEvent` (+ timer broadcasts), no renju event. Reuse the existing
   `swapSeatsTableEvent` handler; do not also mutate seats locally (double-swap risk).
4. **Decline+place sequence:** `[dsgRenjuTaraguchiSwapTableEvent swap:false]` then
   `[dsgMoveTableEvent]`. The echo updates tracking; the move event places the stone.
5. **Offer-10 success (Branch B):** timer handoff → `dsgRenjuTaraguchiOffer10TableEvent` (10
   moves) to all → `dsgSystemMessageTableEvent` to **only** the selecting (white) player
   ("…pick one to play as move 5"). Reuse the existing `systemMessageTableEvent` handler as the
   gate for the selection UI.
6. **Select-1 success:** `dsgRenjuTaraguchi10Select1TableEvent` (chosen move) to all → a single
   `dsgMoveTableEvent` placing move 5.
7. **Error-to-sender:** `dsgMoveTableErrorEvent` to the sender only; table state untouched.
   Payload `move:Int` + `error:Int` (`NOT_IN_TABLE=2, NO_GAME=4, NOT_SITTING=6, NOT_TURN=12,
   INVALID_MOVE=13, UNKNOWN=99`). **Offer-10 batch rejection reports `move=-1`** (validate-all /
   commit-none). iOS currently has **no** arm for this event — add one to release the optimistic
   lock on a rejected decision and surface a brief message.
8. **Rejoin decision-point signal:** on join the server sends seats authoritatively
   (`sendPlayingPlayers`), then exactly one current-decision-point signal, then bulk
   `sendMoves`. The signal has **`player == null`**:
   - SILENT_SWAP → `dsgSwapSeatsTableEvent(player=null, silent=true, swap=resolvedDecision)`
   - OFFERS → `dsgRenjuTaraguchiOffer10TableEvent(player=null, the 10)`
   - SELECT1 → `dsgRenjuTaraguchi10Select1TableEvent(player=null, move)`
   - NONE → nothing (also suppressed at numMoves==0)

   Branch on `player == null` to distinguish a rejoin signal from a live echo. **Do not derive
   who-owns-black from the silent-swap `swap` bit** — `RenjuRejoin.decode` ignores it; seats come
   only from `sendPlayingPlayers`. The old `isNetSwapped()`/net-swap design was removed — do not
   implement it.
9. **Move encoding:** a coordinate is one `Int` index = `x + y*15` (`x=move%15` col, `y=move/15`
   row), center = 112. iOS live uses `row*gridSize+col`, which equals `x+y*15` **only when
   gridSize==15** — wiring 15 is mandatory.

## 4. Opening FSM (phase is derived, not transmitted)

The live socket carries **no `renjuPhase`** (that field is turn-based-JSON only). iOS derives the
phase from `numMoves` (= `table.moves.count`, including the auto-center) plus an accumulated
tracking record. The classifier logic is **ported verbatim** from the React `openingPhase.js`
(`renjuPhase`, `renjuOpeningPlayer`, `renjuBoxRadius`) and the `utils.js` reducers
(`advanceRenjuTrackingAfterMove`, `renjuSwap`, `renjuOffer10`, `renjuSelect1`) and
`gameState.js` `freshRenjuTracking`. The React PR #5 diff is the source of truth for the exact
expressions; the descriptions below are the contract those ports must satisfy.

### 4.1 Tracking record (port of `freshRenjuTracking`)

```swift
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
Mutated only by the reducers below; it places no stones. Stored on `GameState` alongside
`dPenteState` / `swap2State` / `goState` (`HelperClasses.swift` ~652–684).

### 4.2 Phase classifier (`renjuPhase(numMoves, t)`)

- `t.complete` → **COMPLETE**
- else `t.awaitingSwap` → **SWAP**
- else `numMoves==4 && !t.branchChosen` → **BRANCH**
- else `numMoves==4 && t.branchChosen && t.tenOffer && t.offered.count==10 && t.selected==nil`
  → **SELECTION**
- else → **MOVE**

(There is **no standalone OFFERS phase on the live path** — offer-10 advances straight to
SELECTION. OFFERS exists only in the turn-based string set.)

### 4.3 To-move classifier (`renjuOpeningPlayer(numMoves, t)` → seat 1/2/nil)

Returns a **seat index** (1/2), distinct from stone-colour space (black=2). Gates `isMyTurn`
during the opening; when it returns nil, `currentPlayer()` falls back to parity
`1 + moves.count%2`.

- `t.complete` → nil
- `t.awaitingSwap` → `3 - (((n-1)%2)+1)` (opponent of the last mover)
- `t.branchChosen && t.tenOffer && n==4` → `t.offered.count<10 ? 1` (black offering) `:
  (t.selected==nil ? 2` (white selecting) `: fallthrough)`
- `n==4 && !t.branchChosen` → 1 (black chooses branch / plays move 5)
- else → `(n%2)+1`

### 4.4 Window walk (n = stones incl. center)

- **n=1/2/3 (SWAP windows 1/2/3):** the opponent either **takes over** (`swap:true, move:-1` →
  seats swap) or **declines + places** move 2/3/4 inside the **3×3 / 5×5 / 7×7** box.
- **n=4 (SWAP window 4 = branch point):** three actions — (a) **take-over** (`swap:true`) →
  BRANCH; (b) **decline + place** one stone in the **9×9** box (`swap:false` with `move`) →
  Branch A move 5; (c) **Offer-10** → Branch B.
- **BRANCH** (reached only after a move-4 take-over): the new black seat chooses **Branch A**
  (place move 5 in 9×9, sent as `swap:false` with the stone) or **Branch B** (offer 10). A=1
  stone, B=10. Branch-A move 5 always arrives as a swap event (`swap:false` with move).
- **SELECTION** (n=4, `branchChosen && tenOffer && offered.count==10 && selected==nil`): white
  picks one → `select1` → server places it as move 5 → n=5 → COMPLETE.
- **Branch-A move-5 window** (n=5, `branchChosen && !tenOffer && awaitingSwap`): white takes
  over or bare-declines (`swap:false, move:-1`); move 6 follows as a whole-board move →
  COMPLETE. Branch B has no move-5 window.
- **COMPLETE** (n≥5, no window open): plain alternation; opening UI off.

### 4.5 Central-box radius

Single-stone placements only: move 2/3/4/5 → radius 1/2/3/4 about center (7,7), i.e.
`|x-7|<=r && |y-7|<=r` → 3×3/5×5/7×7/9×9. React: `radius = (n>=1 && n<=4) ? n : 0` with
`n=moves.length`. The 10 Branch-B offers and white's move 6 are **board-wide**.

### 4.6 Reducers (mutate tracking only; port verbatim)

- `renjuSwap(swap, move)` — mark the window decided; at n==4 a `swap:false` echo carrying a
  valid stone ⇒ `branchChosen=true` (Branch A). (React reducer ignores `move` and derives from
  the following move event / count.)
- `renjuOffer10(moves)` — `branchChosen=true; tenOffer=true; offered=moves`.
- `renjuSelect1(move)` — `selected=move`.
- `swapSeats` (renju arm) — `awaitingSwap=false; swapTaken=true`; does **not** touch
  `branchChosen`/`tenOffer`.
- `advanceAfterMove` (per appended stone) — recompute `awaitingSwap`/`complete`. Must produce
  identical state whether moves arrive incrementally or as a rejoin bulk replay.

## 5. Live-model wiring (the real gaps)

1. **`HelperClasses.swift` `penteVariant(for:)` (~267–281):** add
   `case .renju, .speedRenju: return .renju` before the `default: return .pente`. Today 31/32
   fall through to `.pente`, so the live engine plays Renju as 19×19 Pente with captures.
   (`GameEnum` already has `renju=31`/`speedRenju=32`; `ruleSet(for:.renju)` already exists.)
2. **`TableViewController.stateChanged()` geometry block (~556–562):** add a **15** case for
   31/32 (today only 9/13/19 → wrongly 19). Set `table.gridSize` / `board.gridSize` /
   `zoomedBoard.gridSize = 15`, recompute `cellSize`.
3. **`HelperClasses.swift` board sizing:** `abstractBoard` is hard-coded 19×19 (`:103`, mirrored
   in reset/`addMoves`/`syncFromEngine`). Generalise so renju mirrors a 15×15 engine board;
   ensure `Table.gridSize` default path (`~329–339`, today 9/13/19) gets a 15 path and
   `passMove = gridSize*gridSize` stays consistent.
4. **`HelperClasses.swift` `gameColor()` (~527):** add a renju branch returning
   `BoardVariantMapping.backgroundColor(for: .renju, boatPente: false)` (`#D98880`). Today 31/32
   render swap2-Keryo green.
5. **`LiveBoard.swift` `draw()` (~80–151):** 15×15 star points
   `{48,52,56,108,112,116,168,172,176}` and center 112; plus a translucent-candidate render path
   (reuse the α=0.7 `whiteStone`/`blackStone` primitive, mirroring the Go dead-stone path) for
   the ≤10 offers and the selection set.

## 6. UI design (Swap2 methodology)

Add an `if table.isRenju()` block in `TableViewController.stateChanged()` after the Swap2 block,
plus an `isRenju()` predicate (game==31||32) and choice predicates on `Table` mirroring
`isSwap2ChoiceWithPassOption()`.

- **Swap windows & branch fork → action sheets.** Gated by the choice predicate + seat check.
  Titles/actions:
  - windows 1–3 (decider seat): "Take over" / "Decline & place".
  - window 4 (decider seat): "Take over" / "Decline & place 5th move" / "Offer ten 5th moves".
  - BRANCH (new black after take-over): "Place 5th move" / "Offer ten 5th moves".
  - Branch-A move-5 window (white): "Take over" / "Decline".
  Each action either sends an echo immediately (take-over, bare decline, …) or **arms a board
  sub-mode** (place / offer). iPad popover anchored to the navbar bar button, exactly as Swap2.
- **Constrained placement.** After "Decline & place" / "Place 5th move", arm the board for one
  tap; `boardTouch` (`TableViewController.swift:165`) gated to the central box (radius from
  tracking) and to `renjuOpeningPlayer == my seat`. On a valid tap, send the `swap:false` echo
  with the tapped index (the server then echoes + sends the stone's move event).
- **Offer-10 multi-select.** "Offer ten" puts the board into collect mode: each tap adds/removes
  a candidate (board-wide, excluding occupied + D4-symmetric duplicates via the existing
  `RenjuOfferSymmetry`), with a counter N/10; auto-send `offer10` on the 10th. Candidates render
  translucent.
- **White selection.** Gated by the inbound `dsgSystemMessageTableEvent` (server delivers it only
  to the selector). The 10 candidates render translucent; tapping one sends `select1`.
- **Pending lock.** After sending any decision, lock further input until the corresponding echo
  (or `dsgMoveTableErrorEvent`) returns; the error arm releases the lock and shows a brief
  message (NOT_TURN / INVALID_MOVE).
- **Device matrix.** Verify central-box gating, the 10-pick multi-select + counter, translucent
  candidates, and the selection flow on **both iPhone and iPad** (popover vs modal per
  `penteLive-iOS/CLAUDE.md`).

## 7. Reuse map

**Reuse as-is:**
- Engine: `PenteGame(variant: .renju)` → 15×15, black-first, no capture (`RuleSet.swift` /
  `PenteGame.swift`).
- `RenjuOfferSymmetry.swift` (`@objc`) for D4 offer dedup (same logic TB uses).
- `BoardVariantMapping.backgroundColor(for: .renju)` → `#D98880`.
- `RoomViewController.swapSeatsTableEvent` for take-over + rejoin silent-swap.
- `dsgMoveTableEvent` pipeline (`moveTableEvent` → `Table.addMove`/`addMoves`) for all stone
  placement.
- `systemMessageTableEvent` handler as the selection gate.
- The Swap2 action-sheet idiom.

**New:**
- `RenjuTracking` value type + the pure classifiers/reducers (ported from React; unit-tested).
- Three inbound handlers (`renjuSwapTableEvent` / `renjuOffer10TableEvent` /
  `renjuSelect1TableEvent`) on `RoomViewController` + a `dsgMoveTableErrorEvent` arm.
- Three senders (`sendRenjuSwap` / `sendRenjuOffer10` / `sendRenjuSelect1`) on
  `TableViewController`.
- Three socket arms in `PenteLiveSocket.processEvent` (after the swap2Pass arm ~170) + the
  move-error arm.
- The renju opening block in `stateChanged()` and the board sub-modes in `boardTouch`.
- `LiveBoard` 15×15 layout + translucent-candidate rendering.

**Reference blueprint (translate, do not import):** the turn-based ObjC FSM in
`BoardViewController.m` (`renjuCentralBoxRadius`, `applyRenjuOpeningMaskIfNeeded`,
`renderRenjuOpeningUI`, `showRenjuOfferCounter`, `renjuActionForCurrentPhaseFillingMoves`).

## 8. Win / forbidden handling

Presentation-only. The shared engine treats overline as a win and has no forbidden-point logic;
black overline / double-three / double-four and exact-five-vs-overline are **server-enforced**.
Rely on `dsgMoveTableErrorEvent` (`INVALID_MOVE`) and the normal game-over signal. Do not port a
forbidden-point finder.

## 9. Testing strategy

**Unit** (standalone, via the project's clang one-liner convention — there is no Xcode test
target; see [[pentegame-engine-tests]]):
- `renjuPhase` / `renjuOpeningPlayer` / `renjuBoxRadius` against the React truth tables — every
  documented transition (windows 1–4, take-over → BRANCH, Branch A move-5 + its swap window,
  Branch B offer → SELECTION → complete, n≥6 alternation), including seat-vs-colour cases.
- `advanceAfterMove` + the three reducers — assert no stones placed and that bulk (rejoin)
  replay reconstructs `awaitingSwap`/`complete` identically to incremental application.
- D4 dedup via `RenjuOfferSymmetry` — lone-center rejects all 8 images; asymmetric placed
  position rejects only exact dups; single-axis symmetry rejects 2.
- Move-encoding round-trip at gridSize=15 — index 112 == (7,7); `x=move%15,y=move/15` matches
  `row*15+col`; central-box membership matches the radii.
- Codec — encode/decode each event as a single-key dict; name-keyed decode; `time:0` on send;
  `-1` sentinel always present on `swap:true` and the bare move-5 decline.

**Live vs localhost** (docker stack; accounts `iostest/app_tsetsoi` and `graviton/virginia`,
one per seat): drive each branch end-to-end and capture frames — (A) windows 1–3 decline+place
(`[swap echo]` then `[move event]`); (B) take-over (non-silent `dsgSwapSeatsTableEvent`, no renju
echo, seats swap once); (C) Branch A move-4 decline + move 5 in 9×9 + move-5 swap window + move
6; (D) Branch B offer-10 (offer to both, system message to selector only) + select1 + single
move 5 + move 6. **Rejoin:** disconnect/rejoin at each decision point (SILENT_SWAP / OFFERS /
SELECT1 / NONE); verify `player==null`, seats from `sendPlayingPlayers`, bulk replay, derived
phase matches the other client. **Errors:** out-of-box stone, symmetric/non-distinct offer set,
out-of-turn decision → `dsgMoveTableErrorEvent` to sender only (offer-10 → `move=-1`), lock
releases, recovery re-send succeeds. **Cross-client parity** against the React live client on the
same table.

## 10. Risks

- **Grid-size coupling.** `row*gridSize+col` equals the server's `x+y*15` only at gridSize==15.
  Change gridSize, `abstractBoard` sizing, `passMove`, and `boardTouch` math together or every
  off-center coordinate mis-maps.
- **Take-over double-swap.** Apply the seat swap only via the existing handler; do not also mutate
  seats locally.
- **Rejoin sequencing.** Branch on `player==null`; don't derive orientation from the swap bit;
  recompute tracking by replaying `advanceAfterMove` over the bulk moves.
- **Phase-derivation drift.** Port the React classifiers/reducers verbatim and unit-test against
  the React truth tables; do not hand-roll.
- **Seat-index vs stone-colour confusion.** Keep `renjuOpeningPlayer` (seat 1/2) separate from
  `currentColor = 2-(n%2)` (black=2).
- **Pending-lock release.** Without the new `dsgMoveTableErrorEvent` arm, a rejected
  decision/offer wedges the local UI.
- **Enum exhaustiveness.** `PenteVariant.renju=11` already exists; avoid regressing any
  non-default exhaustive switch (e.g. `BoardVariantMapping.backgroundColor`) including test
  targets.
- **New UI is the heavy part.** On-board central-box-gated tapping, the 10-pick multi-select with
  live counter + D4 dedup, translucent candidate rendering (10 at once is untested), and the
  selection flow are all new on the live path — verify on iPhone and iPad.

## 11. Out-of-scope / deferred

- Turn-based Renju (81) and its ObjC stack.
- Client-side forbidden-point marking/validation.
- Any new lobby/creation UI.
- Visible central-box overlay (chosen against; invisible gating).

## 12. References

- `pente.org/docs/renju-integration-guide.md` (§8 live client, §9 iOS handoff, §10/§11 context).
- Server: `pente.org` PR #8 — `ServerTable.handleRenjuSwap/Offer10/Select1`, `DSGEventWrapper`,
  `RenjuRejoin`, `RenjuState`.
- Client reference: `react_live_game_room` PR #5 — `openingPhase.js`, `gameState.js`,
  `utils.js`, `renjuSymmetry.js`, `RenjuChoiceModal`, `RenjuOfferPanel`.
- iOS engine + TB blueprint: `test1/PenteEngine/*`, `test1/BoardVariantMapping.swift`,
  `test1/RenjuOfferSymmetry.swift`, `test1/BoardViewController.m` (TB FSM).
