# Renju (Taraguchi-10) — iOS implementation handoff

Extracted from `pente.org/docs/renju-integration-guide.md` (§9 live + §11 turn-based) on branch `feat/renju`. TWO parts: the **live** opening UI and the **turn-based (correspondence)** handoff — both must be wired (the app plays both transports).

- Cross-refs like `§2.4`/`§2.6`/`§7`/`§8` point to that integration guide; `§8` is the React reference implementation.
- Reference client: `rainwolf/react_live_game_room#5`. Live+TB server: `rainwolf/pente.org#8`.
- Canonical Renju board colour: **#D98880** (distinct from gomoku #A3FDEB).
- Anchors were grounded but **line numbers drift — grep the symbol** before editing. Resolve "(verify)" items during planning.
- LIVE path **derives** the phase from echoes; TURN-BASED **reads** the server-shipped `renjuPhase` and submits via the `renjuAction` contract (§2.4 — three actions: `swap` (take-over, no stone) · `move` (1 or 10 stones; branch inferred by count; windows-1–3 decline is a `move`) · `select` (atomic 2-stone: move 5 + move 6)).
- Suggested flow: treat each part as a spec → `writing-plans` → `subagent-driven-development`; build + test natively.

---

## 9. Sub-project 4 — iOS (`penteLive-iOS`) Taraguchi-10 handoff

Zero-context handoff for a fresh agent wiring the live Renju opening UI into the
`penteLive-iOS` submodule (a **separate repo** — do not edit it from this one). Every anchor
below was grep-verified against the submodule on this branch; line numbers are as-of-now and
drift, so grep the symbol.

> **CORRECTION (see §11).** iOS plays **BOTH** transports. This section (§9) covers the **live**
> path only (the Swift `PenteLiveSocket`/`TableViewController` stack). The original "LIVE ONLY /
> read-only viewer" verdict was **wrong**: the Objective-C `BoardViewController` is iOS's
> **interactive turn-based board** (`boardTap:`/`submitMove:`/`submitMoveToServer` building
> `command=move`), and it *does* read `game.jsp` JSON. The turn-based Renju handoff is **§11** —
> not deferred. (Unlike the live path, the TB path reads the **server-shipped** `renjuPhase`.)

**TRANSPORT VERDICT (live path): derive the phase, like §8.2 (React).** On the live socket the iOS
app is a raw-TCP / WebSocket client: `PenteLiveSocket.swift` opens a `GCDAsyncSocket` and reads
255-delimited JSON frames (`separator = Data([255])`, `PenteLiveSocket.swift:25`), dispatching by
top-level key in `processEvent` (`:105-174`); moves are **sent** as a hand-built
`dsgMoveTableEvent` dict via `socket.sendEvent(...)` (`TableViewController.sendMove:547`). The
**live Swift stack** has no `renjuPhase`/`GameResponse` consumer, so the live client gets **NO
`renjuPhase` on the wire** and must **derive** the Taraguchi-10 phase from tracked decision-echo
state (§9.2), identical in spirit to the React port. (The turn-based ObjC `BoardViewController`
path — which reads the server-shipped `renjuPhase` and submits `command=move&…&renjuAction=…` — is
documented separately in **§11**.)

**iOS and Android have no Renju support whatsoever today.** Game ids 31/32/81 are absent from
every enum and map; see §9.1 for the silent-degradation fall-through.

**How iOS genuinely differs from the React reference (§8) — read before forcing the React shape:**
- **Two languages.** The live-play stack is **Swift** (`PenteLiveSocket`, `TableViewController`,
  `RoomViewController`, `HelperClasses`, `LiveBoard`, `PenteEngine/*`). The read-only replay /
  turn-based viewer is **legacy Objective-C** (`BoardViewController.m/.h`, `BoardView.m/.h`,
  179 KB of ObjC). All Renju live work lands in the Swift files; the ObjC viewer is optional.
- **A client-side rules-engine *copy*.** `PenteEngine/PenteGame.swift` + `RuleSet.swift` +
  `PenteVariant.swift` are a structured Swift port of the move engine (capture rules, a
  `cadence` enum for move→color, and an `OpeningMask` enum for opening legality). React replays
  inline in `GameClass.js`; iOS routes color through `rules.cadence` and opening through
  `OpeningMask`, so Renju needs a **new variant + RuleSet + cadence + opening-mask kind** — more
  structured work than React’s inline `2-(i%2)` flip.
- **No event-wrapper classes, no Protocol module.** iOS parses each frame into a bare
  `[String: Any]` (`convertJSONStringToDictionary:177`) and dispatches via a literal if-else chain;
  outbound frames are **hand-built dicts** (`sendMove:548`). There is no `MESSAGES`/`Commands`
  registry (React) and no typed event package (Android). Adding the three Renju events = three new
  if-else arms + three hand-built send methods. Simpler plumbing, but **no schema validation** and
  **no `time:0` auto-stamp** — the sender must include `"time": 0` literally (as `sendMove` does).
- **No `openingPhase.js` analogue.** React centralizes phase logic in pure classifiers; iOS
  scatters it across `HelperClasses` (`isSwap2ChoiceWithPassOption:150`, `currentPlayer:466`) and
  carries only `swap2State`/`dPenteState` enums — there is **no `renjuState`**. You add the
  tracking slice and a `renjuPhase(...)` derivation from scratch.
- **Board size hardcoded `19` more pervasively.** Beyond the Swift engine’s literal `/19`/`%19`,
  there is a C array `abstractBoard[19][19]` in `BoardViewController.h:36`. React already had
  `gridSizeForGame` (only missing the 31/32/81 case); iOS needs a broader sizing pass.
- **No multi-select opening-UI precedent** (same gap as React, but worse): the swap2/dPente UI is
  a yes/no/pass `UIAlertController` action-sheet (`stateChanged:593/611/632`), not board
  interaction. There is no 10-pick picker, no translucent-candidate array, no central-box
  highlight, no “select 1 of 10” screen.

### 9.0 Board basics (restated for this client)
- Board **15×15**, game ids **31 (Renju) / 32 (Speed Renju) / 81 (TB Renju)**. Move encoding
  `x + y·15`; **center = 112** (`7 + 7·15`). The **server auto-places** the center as move 1 —
  it arrives as an ordinary `dsgMoveTableEvent`, so the client only needs the board sized to 15
  to render it correctly (no client-side auto-center).
- **Board background colour = `#D98880` (dusty rose)** — the canonical Renju board colour,
  **distinct from gomoku's `#A3FDEB`**. Matches the web (`renjuColor`, `gameScript.js:14`) and
  `react_live_game_room` (`.renju` in `TableClass.js`). This is the exact value the `.renju`
  `backgroundColor` case (§9.3 step 2a) must return.
- **Black plays first.** iOS color conventions to reconcile:
  - `abstractBoard` cell values: **0 = empty, 1 = WHITE, 2 = BLACK, −1 = masked** (the rendering
    convention; `BoardView.h:13-15` separately `#define WHITE 0 / BLACK 1 / RED 2` is a distinct
    legacy palette enum, **not** the board-value convention — do not conflate them).
  - The engine’s move→color is `PenteGame.colorForMove(_:)` `:94`: for the `.alternating` cadence
    it returns `(index % 2) + 1`, i.e. **move 0 → value 1 = WHITE first** — this is the **opposite**
    of Renju. The same white-first parity is echoed in `HelperClasses.currentPlayer():466`
    (`1 + moves.count % 2`).
  - So **“black first” ⇒ the first stone (move 0/center) must carry board value 2**. Because color
    flows through `rules.cadence`, the fix is a **new black-first cadence** (e.g.
    `colorForMove → 2 - (index % 2)`, giving move 0 → value 2), **not** an inline flip.

### 9.1 Confirmed anchors (file : symbol)
All grep-verified in the submodule on this branch; treat as fact unless marked **(verify)**.
“**WRONG today**” = the code path Renju ids 31/32/81 hit right now, which is incorrect for Renju.

| Area | File | Symbol / fact |
|---|---|---|
| inbound dispatch | `test1/PenteLiveSocket.swift` | `processEvent(eventString:)` **:105-174** — if-else chain keyed on the top-level JSON key. Present: `dsgMoveTableEvent` (:146), `dsgSystemMessageTableEvent` (:148), `dsgSwapSeatsTableEvent` (:150), `dsgSwap2PassTableEvent` (:170). **No** `dsgRenjuTaraguchiSwapTableEvent` / `…Offer10…` / `…Select1…` → the three echoes are **silently dropped** (no else-arm). **WRONG today.** |
| frame decode | `test1/PenteLiveSocket.swift` | `socket(didRead:withTag:)` **:89-96** reads to `separator = Data([255])` (:25), UTF-8 → `convertJSONStringToDictionary` (:177) → `[String: Any]`; **no schema validation**. |
| outbound send | `test1/PenteLiveSocket.swift` | `sendEvent(eventDictionary:)` → `sendEvent(eventData:)` **:225-243** — `JSONSerialization` → append `separator` → `socket.write`. Generic; senders hand-build the dict. **No `time` auto-stamp.** |
| move send | `test1/TableViewController.swift` | `sendMove(move:)` **:547-548** builds `["dsgMoveTableEvent": ["move": move, "moves": [move], "player": me, "table": table.table, "time": 0]]`. The dict-shape template for the new Renju senders. |
| dPente swap UI | `test1/TableViewController.swift` | `stateChanged()` **:593-607** — `UIAlertController(.actionSheet)` “Continue play as” with **Player 1 (white)** / **Player 2 (black)**; sends `dsgSwapSeatsTableEvent`. |
| swap2 swap UI | `test1/TableViewController.swift` | `stateChanged()` **:611-631** (with pass: P1/P2/**Pass Decision**) and **:632+** (without pass); sends `dsgSwapSeatsTableEvent` or `dsgSwap2PassTableEvent`. The opening-UI dispatch precedent to mirror — **yes/no/pass only, no board interaction.** |
| swap2 detection | `test1/HelperClasses.swift` | `isSwap2ChoiceWithPassOption()` **:150-152** = `isSwap2() && moves.count==3 && state.swap2State == .noChoice`; `isSwap2ChoiceWithoutPassOption()` **:154-156** (`moves.count==5`). The count+state derivation pattern to copy for Renju. |
| opening-state enums | `test1/HelperClasses.swift` | `class GameState` **:651-683** with `enum DPenteState` (:659) + `enum Swap2State` (:665); fields `dPenteState`/`swap2State` (:679-680). **No `renjuState` / `RenjuState` enum.** **WRONG today.** |
| swap reducers | `test1/HelperClasses.swift` | `swapSeats(swap:silent:)` **:414-434** sets `dPenteState`/`swap2State` → `.swapped`/`.notSwapped`; `swap2Pass(silent:)` **:436-438** sets `.swap2Pass`. Table-level wrappers `swapSeats(tableId:swap:silent:)` (:777) / `swap2Pass(tableId:silent:)` (:785). |
| color parity (table) | `test1/HelperClasses.swift` | `currentPlayer()` **:466-485** — non-Go/non-Connect6 returns `1 + (moves.count % 2)`. This turn-order parity is **CORRECT for Renju normal play** (alternation is unchanged); the black-first concern is a stone-**COLOUR** fix via the cadence (`colorForMove → 2 - (index % 2)`, §9.0), **NOT** a `currentPlayer` change. **WRONG today only in the OPENING** — needs a `renjuOpeningPlayer` arm (§9.2) for the swap/branch/selection decision points. |
| color parity (engine) | `test1/PenteEngine/PenteGame.swift` | `colorForMove(_:)` **:94-101** — `.alternating` cadence → `(index % 2) + 1` (move 0 = value 1 = white); `.connect6` cadence is special. Keyed on `rules.cadence`. **WRONG today** for Renju. |
| board-value palette | `test1/BoardView.h` | **:13-15** `#define WHITE 0 / BLACK 1 / RED 2` (legacy palette, distinct from the `abstractBoard` 0/1/2/−1 convention). `abstractBoard` ivar at :29. |
| board size (Table) | `test1/HelperClasses.swift` | `abstractBoard` **:103** = `Array(repeating: Array(repeating: 0, count: 19), count: 19)` (also re-inited :211, :374, :445); `var gridSize = 19` **:328** (dynamic only for Go ids). **WRONG today** (Renju needs 15). |
| board size (engine) | `test1/PenteEngine/PenteGame.swift` | board init `count: 19` (**:15, :20**); `stone(at:)` **:27-31** `board[rowCol/19][rowCol%19]`; `play(_:)` **:34-45** `board[move/19][move%19]`; `apply(removed)` **:106** `cap.position/19`. Literal `19` divisor throughout. **WRONG today.** |
| board size (ObjC) | `test1/BoardViewController.h` | C array `abstractBoard[19][19]` **:36** (+ `replayGame` `gridSize` default 19, `BoardViewController.m:1383`). Read-only viewer; **WRONG today** if used for Renju. |
| opening mask | `test1/PenteEngine/PenteGame.swift` | `applyOpeningMask()` **:127-130** dispatches on `OpeningMask`; `maskTournamentOpening()` **:145-148** = `for i in 7..<12, j in 7..<12` (center 5×5 of 19×19, masks idx 7-11); `maskGPenteOpening()` :153-159; `.swap2` case is **unhandled** (`break`). **No radius-by-move-number mask** for Renju’s 3×3/5×5/7×7/9×9. **WRONG today.** |
| opening-mask enum | `test1/PenteEngine/RuleSet.swift` | `enum OpeningMask { none, tournament, gpente, swap2 }` **:7** — no Renju/radius mask. **WRONG today.** |
| variant→ruleset | `test1/PenteEngine/RuleSet.swift` | `ruleSet(for:)` **:114-126** — switch over **11** `PenteVariant` cases, **no `.renju`**. **WRONG today.** |
| variant enum | `test1/PenteEngine/PenteVariant.swift` | `enum PenteVariant: Int` **:6-17** — 11 cases `pente=0 … connect6=10`; **no `renju`**. Raw values frozen to legacy ObjC enum → **next free raw value is 11**. **WRONG today.** |
| id→variant | `test1/HelperClasses.swift` | `penteVariant(for:)` **:266-280** — switch on `GameEnum`; `default: return .pente` (:278). Ids 31/32/81 hit default → **`.pente`** (Pente capture rules, not Gomoku). **WRONG today.** |
| game-id enum | `test1/HelperClasses.swift` | `enum GameEnum: Int` **:81** — cases 1…30 (`speedSwap2Keryo=30`). `GameEnum(rawValue: 31)` ⇒ **nil**. **WRONG today.** |
| game names | `test1/HelperClasses.swift` | `static let gameNames` **:115-121** — keys 1…30 only; **31/32/81 absent** (UI shows no name). **WRONG today.** |
| string→variant | `test1/BoardVariantMapping.swift` | `variant(forGameType:)` **:8-28** — maps game-type strings to `PenteVariant`; fallback `return .pente` (:28). **No Renju gameType.** **WRONG today.** |
| star points + sizing | `test1/LiveBoard.swift` | `var gridSize = 19` **:23**; `draw(_:)` **:80-151** draws 5 special circles via `c = floor(gridSize/2)` and a 19-specific point set (with a `gridSize == 9` special-case). **No central-box concept.** Needs 15×15 star points {3,7,11} → indices `[48,52,56,108,112,116,168,172,176]`. **WRONG today.** |
| translucent stones | `test1/LiveBoard.swift` | `init` **:30-35** — `whiteStone`/`blackStone` created with `alpha = 0.7; isOpaque = false; fill = true`. **Reusable translucent primitive** for offer candidates. |
| move-apply path | `test1/RoomViewController.swift` | `moveTableEvent(event:)` **:871** — on `dsgMoveTableEvent` reads `event["move"] as! Int` (**:877**) and `event["moves"] as! [Int]` (**:878**), then calls `table.addMove`/`addMoves` and `tableViewController.stateChanged()`. **Confirmed: a coordinate is a single `Int` board index (`x + y·15`), inbound (`:877-878`) and outbound (`sendMove:548`).** |
| move replay | `test1/HelperClasses.swift` | `addMoves(moves:)` (≈**:209-232**) → `engine.replay(...)` then `syncFromEngine()` (:296-309, hardcoded `0..<19` loop). Engine is authority for Pente-family. |
| swap2 handler pattern | `test1/RoomViewController.swift` | `swapSeatsTableEvent(event:)` **:745**; `swap2PassTableEvent(event:)` (≈**:760-769**) extracts fields on main queue → `playersAndTables.swap2Pass(tableId:silent:)` → `stateChanged()`. **The direct reference for the three new Renju handlers.** |
| system-message handler | `test1/PenteLiveSocket.swift` / `RoomViewController.swift` | dispatch at `PenteLiveSocket:148` → `systemMessageTableEvent(event:)` (≈`RoomViewController:894-905`) extracts `message` and shows it via `tableViewController.addText`. **Display-only** today; reusable (with a non-dismissible variant) as the Branch-B selector prompt. |
| dPente choice precedent (ObjC) | `test1/BoardViewController.m` | `dPenteChoiceLabel` (`:52, :340, :1824-1870`) — “Play as” server-driven opening-UI precedent in the legacy viewer; `boardTap:` (`:644`) tracks `swap2Move1/2/3`, `dPenteMove1-4`. **(verify — legacy ObjC, read-only path)** |

### 9.2 Live phase derivation (mirror `swap2Phase` / §8.2)
iOS plays Renju **live**, so — exactly as React — there is **no `renjuPhase` on the socket**; the
client must derive it. iOS has **no `openingPhase.js`** and **no `renjuState`** (only
`swap2State`/`dPenteState`, `HelperClasses.swift:679-680`), so add both:

(1) a tracking slice on the `Table`/`GameState`, accumulated **from the three echo events** (§9.4):

```swift
enum RenjuBranch { case a, b }
struct RenjuTracking {
    var swapWindowOpen: Bool = true   // is the CURRENT swap window still undecided?
    var branch: RenjuBranch? = nil    // set by the move-4 decision echoes
    var offers: [Int]? = nil          // the 10 Branch-B candidates (offer10 echo)
    var selection: Int? = nil         // white's pick (select1 echo)
}
// NOTE: no net-swap / orientation field here. Who-owns-black comes from `table.seats`
// (the visual seat swap on a live swap=true, and sendPlayingPlayers on rejoin) — NEVER
// from the silent rejoin swap event (its swap bit is the current window's decision, §7).
```

(2) a pure `renjuPhase(movesCount, tracking)` classifier (mirror `isSwap2ChoiceWithPassOption`),
where `movesCount = table.moves.count` (stones on board, incl. the auto-center = move 1):

| movesCount | tracked state | phase | to-move acts |
|---|---|---|---|
| 1 | swapWindowOpen | `SWAP` (window 1) | Swap, **or** decline + place move 2 ∈ 3×3 |
| 2 | swapWindowOpen | `SWAP` (window 2) | Swap, **or** decline + place move 3 ∈ 5×5 |
| 3 | swapWindowOpen | `SWAP` (window 3) | Swap, **or** decline + place move 4 ∈ 7×7 |
| **4** | **swapWindowOpen** | **`SWAP`** (window 4) | THREE actions: `swap=true` take-over → **`BRANCH`** (no stone) · `swap=false` **bundled with move 5 ∈ 9×9** → **Branch A** (constrained **`MOVE`** placement) · `Offer10` → **Branch B** (**`OFFERS`**) |
| **4** | swap=true taken, `branch==nil` | **`BRANCH`** | black chooses → place move 5 ∈ 9×9 (**`MOVE`**, Branch A) **or** offer 10 (**`OFFERS`**, Branch B) |
| **4** | `branch==.a` (after take-over) | **`MOVE`** | place move 5 inside the 9×9 — constrained opening placement |
| **4** | `branch==.b`, offering | **`OFFERS`** | black offers ten 5th-move candidates (anywhere on board, §9.5) |
| **4** | `branch==.b`, `offers` present | **`SELECTION`** | white picks 1 of the 10 → becomes move 5 |
| **5** | `branch==.a`, swap-5 undecided | **`SWAP`** (window 5) | Swap, **or** decline → then move 6 |
| **5** | `branch==.a`, swap-5 decided | **`COMPLETE`** (move 6 anywhere) | place move 6 — free alternating play |
| **5** | `branch==.b` (selection done) | **`COMPLETE`** (move 6 anywhere) | place move 6 — **no swap-5 window in Branch B** |
| ≥6 | — | **`COMPLETE`** | plain alternation; black forbidden-points **server-enforced** |

**Move-4 model (live path), identical to §8.2.** At the move-4 window the to-move player has
**three** wire actions: (a) `swap=true` take-over → standalone **`BRANCH`** (no stone);
(b) `swap=false` **bundled with move 5 in the 9×9** = **Branch A** (there is **no** stoneless
move-4 decline); (c) `Offer10` = **Branch B**. The standalone `BRANCH` state therefore arises
**only** after a take-over. Branch-A move 5 itself arrives as a **swap event** (`swap=false`, with
the move) per the §7 decision-echo notes, not as a branch event. Grounds (server side, §7):
`ServerTable.handleRenjuSwap` (bundled decline + `chooseBranch(false)`),
`RenjuState.wouldAcceptDeclinedOpeningMove`.

**Reuse the swap2 derivation shape.** `currentPlayer()` (`:466`) and the `isSwap2Choice*`
predicates already derive “whose move / which choice” from `(moves.count, swap2State)`. Add a
`renjuOpeningPlayer(movesCount, tracking)` and an `isRenjuSwapChoice`/`isRenjuBranchChoice`/
`isRenjuSelection` set in the same style, then gate the UI (§9.6) off them — **(verify the exact
`currentPlayer()` arm is needed for correct `isMyTurn` during the opening; the safe move is to add
it, mirroring the swap2 arm).**

**Rejoin / spectate.** Honour the §7 current-decision-point contract: the server sends
authoritative seats (`sendPlayingPlayers`) **plus exactly one** signal keyed by `numMoves` —
*nothing* (window open / complete), a **silent** `dsgSwapSeatsTableEvent` (window resolved →
`MOVE`/`BRANCH`), an **offer10** frame (Branch-B selection pending), or a replayed **select1**
(Branch-B move 5 chosen). Reconstruct via the §7 `RenjuRejoin.decode(numMoves, signal)` rules. In
the **silent** `swapSeats` branch (`swapSeats(swap:silent:)` :414) for Renju, **advance the
tracked phase for the current window only** — do **not** double-swap seats (seats are already
current) and do **not** derive who-owns-black from the swap bit (seats come from
`sendPlayingPlayers`). This is exactly the dPente silent-swap contract.

**Alternative considered:** port `RenjuState`’s server-side Taraguchi-10 state machine into Swift.
**Not recommended** — it duplicates a non-trivial engine plus the forbidden-point finder it leans
on. Track only the four decision variables above; the server stays authoritative.

### 9.3 iOS file-by-file map
1. **`test1/HelperClasses.swift`** — Renju ids resolve WRONG today (§9.1). 
   - `GameEnum` (:81): add `case renju = 31`, `speedRenju = 32`, `tbRenju = 81`.
   - `gameNames` (:115): add `31: "Renju", 32: "Speed Renju", 81: "TB Renju"`.
   - `penteVariant(for:)` (:266-280): add `case .renju, .speedRenju, .tbRenju: return .renju` **before** the `.pente` default (requires the new `PenteVariant.renju`, step 4).
   - `var gridSize` (:328): add a Renju branch returning **15** (alongside the Go 9/13/19 cases).
   - `abstractBoard` (:103, and the re-inits at :211/:374/:445): size from `gridSize` (15 for Renju) instead of the literal `19`.
   - `currentPlayer()` (:466-485): add a `#isRenju` arm. Outside the opening, Renju is plain move-parity; during the opening, return `renjuOpeningPlayer(moves.count, renjuTracking)` (mirror the swap2 arm). **(verify need.)**
   - `GameState` (:651-683): add a `renjuTracking` slice (the §9.2 struct/enum) next to `dPenteState`/`swap2State`; initialise it in `reset()` (next to :380-381 / :451).
   - `swapSeats(swap:silent:)` (:414-434): add a Renju branch — in the **silent** branch advance `renjuTracking` for the current window only (rejoin phase marker, §7); do **not** set `.swapped`/`.notSwapped` and do **not** re-animate. The non-silent branch keeps the visual `table.swap()` (who-owns-black).
   - Add mutators `renjuSwap(swap:move:silent:)`, `renjuOffer10(moves:)`, `renjuSelect1(move:)` (mirror `swap2Pass:436`) that **update `renjuTracking` only and place NO stones** (stones arrive via the `addMove` path). At `moves.count == 4`, **any** `swap=false` echo carrying a valid stone ⇒ `branch = .a` (whether the window was open — a bundled decline — or already closed by a prior take-over). `renjuOffer10`: `branch = .b`, `offers = data["moves"]`. `renjuSelect1`: `selection = data["move"]`.
   - `addMoves`/`syncFromEngine` (:209-232 / :296-309): drive the loop from `gridSize`, not `0..<19`; the engine replay must run the Renju variant.
2. **`test1/PenteEngine/PenteVariant.swift`** (:6-17): add `case renju = 11` (next frozen raw value). **⚠ Bumping this enum breaks the build at every *exhaustive* `switch` over `PenteVariant` that has no `default` — audit and patch each one, INCLUDING the test targets (`PenteVariantTests` / `RuleSetTests`).** Known non-default switch: `BoardVariantMapping.backgroundColor(for:boatPente:)` (step 2a). (`hidesCaptureLabels(for:opening:)` at `BoardVariantMapping.swift:66` is **safe** — it has a `default`.)
2a. **`test1/BoardVariantMapping.swift`** — `backgroundColor(for:boatPente:)` (**:35-60**) is an exhaustive `switch` over all `PenteVariant` cases with **no `default`**, so adding `.renju` won't compile until you add a case. Add `case .renju: return UIColor(red: 0.851, green: 0.533, blue: 0.502, alpha: 1)` — the canonical Renju board colour **#D98880** (§9.0), distinct from the `.gomoku` case. (`variant(forGameType:)` at :8-28 has a `.pente` fallback so it won't break the build; add a Renju gameType branch there only if the server emits a Renju game-type string.)
3. **`test1/PenteEngine/RuleSet.swift`**
   - `OpeningMask` (:7): add a Renju kind (e.g. `case renju` or a parametric radius mask) for the 3×3/5×5/7×7/9×9 central squares by move number.
   - Add a `RenjuRules` struct: **Gomoku-like** (no captures), win = black-exact-5 / white-5+ (display only — server is authority), **black-first cadence**, `opening = .renju`. Add `case .renju: return RenjuRules()` to `ruleSet(for:)` (:114-126).
   - Cadence: add a black-first cadence consumed by `colorForMove` (step 4) so move 0 → value 2.
4. **`test1/PenteEngine/PenteGame.swift`**
   - Replace the literal `19` divisor with a `boardSize` (15 for Renju) in `stone(at:)` (:31), `play(_:)` (:45), `apply(removed)` (:106), and board init (:15/:20).
   - `colorForMove(_:)` (:94): handle the new black-first cadence → `2 - (index % 2)` (move 0 = value 2 = black).
   - Add a `maskRenjuOpening(moveNumber:)` (analogous to `maskTournamentOpening:145`) that masks everything **outside** the N×N central square about center index 112 for the current opening move (radii 1/2/3/4 → 3×3/5×5/7×7/9×9), and wire it into `applyOpeningMask()` (:127). (The center stone is server-auto-placed; the client only renders it.)
5. **`test1/LiveBoard.swift`**
   - `gridSize` (:23) + `draw(_:)` star points (:80-151): for Renju use `gridSize = 15` and the 9 star points at {3,7,11} → indices `[48,52,56,108,112,116,168,172,176]` (index `= col + row·15`, center 112); do **not** reuse the 19-specific 5-point set.
   - Add a **central-box highlight** overlay (new rect/dashed layer) for the legal N×N region during `MOVE` and the decline-and-place action (§9.6).
   - Reuse the `alpha = 0.7` `whiteStone`/`blackStone` (:30-35) to render up to 10 translucent candidates.
6. **`test1/PenteLiveSocket.swift`** — `processEvent` (:105-174): add three else-arms mirroring the `dsgSwap2PassTableEvent` arm (:170):
   ```swift
   } else if let content = event?["dsgRenjuTaraguchiSwapTableEvent"] {
       room.renjuSwapTableEvent(event: content as! [String: Any])
   } else if let content = event?["dsgRenjuTaraguchiOffer10TableEvent"] {
       room.renjuOffer10TableEvent(event: content as! [String: Any])
   } else if let content = event?["dsgRenjuTaraguchi10Select1TableEvent"] {
       room.renjuSelect1TableEvent(event: content as! [String: Any])
   }
   ```
   (Outbound `sendEvent(eventDictionary:)` at :225 is generic — no change.)
7. **`test1/RoomViewController.swift`** — add `renjuSwapTableEvent` / `renjuOffer10TableEvent` / `renjuSelect1TableEvent` (mirror `swap2PassTableEvent:760` / `swapSeatsTableEvent:745`): on the main queue extract `table`/fields, call the `playersAndTables` Renju mutators (step 1), then `stateChanged()`. Consider a **non-dismissible** variant of `systemMessageTableEvent` (:894) for the Branch-B selector prompt.
8. **`test1/TableViewController.swift`**
   - Add send methods mirroring `sendMove(move:)` (:547): `sendRenjuSwap(swap:move:)`, `sendRenjuOffer10(_:)`, `sendRenjuSelect1(move:)` — hand-build the dicts (§9.4) and call `socket.sendEvent(eventDictionary:)`. Include `"time": 0` explicitly (no auto-stamp).
   - `stateChanged()` (:552): add a Renju block gated off the derived phase (§9.2), mirroring the dPente/swap2 action-sheet blocks (:593/:611/:632) — but routing to the **new board-interaction UI** (§9.6), not a yes/no sheet: swap windows → “Swap (take over)” / “Don’t swap (place next stone)”; move-4 → “Swap” or branch-by-stone-count; selection → pick.
9. **New Swift files** under `test1/` — the Renju opening UI (§9.6): central-box overlay, 10-pick multi-select, translucent-candidate rendering, and the white selection screen. No existing component is more than a yes/no sheet, so these are new.
10. **(Deferred, read-only viewer)** `test1/BoardViewController.m/.h`, `BoardView.m/.h`: size `abstractBoard[19][19]` (`BoardViewController.h:36`) and the `drawRect:` index decode (`BoardView.m:219-220`) to the game’s grid; and to render the historic opening, read `renjuPhase`/`renjuOffers`/`renjuSwaps` from `game.jsp` (the §2.6/§4 fields the parser at :1453-1503 ignores today). Only needed if historic Renju replay must show the opening — **not required for live play**.

### 9.4 Wire examples (verified keys + fields)
Outbound is a hand-built `[String: Any]` (no `Commands` facade, no `time` auto-stamp — include
`"time": 0` yourself, as `sendMove` does), serialized by `socket.sendEvent(eventDictionary:)`.
Inbound is the same single-key shape parsed into `[String: Any]`, with a **server-stamped
non-zero `time`** (epoch ms). Keys verified against the backend wrapper (`DSGEventWrapper` →
`dsgRenjuTaraguchiSwapTableEvent` / `…Offer10…` / `…Select1…`; inherited `player`/`table`/`time`).
One literal per event (table 5, center 112, 15×15):

**Swap event** — take-over, decline+place, or Branch-A move 5 (all three use this event):
```swift
// outbound: decline window-1 swap + place move 2 at col8,row7 (=113, in 3×3)
let e1: [String: Any] = ["dsgRenjuTaraguchiSwapTableEvent":
    ["swap": false, "move": 113, "player": me, "table": table.table, "time": 0]]
socket.sendEvent(eventDictionary: e1)

// outbound: take over the side (no stone). Send move -1 — the no-move sentinel; the server ignores
// `move` on swap=true (handleRenjuSwap reads getMove() but never uses it), and -1 (not 0 = corner cell) is unambiguous.
["dsgRenjuTaraguchiSwapTableEvent": ["swap": true, "move": -1, "player": me, "table": table.table, "time": 0]]
```
```json
// inbound echo (server time stamped); the stone, if any, arrives separately as dsgMoveTableEvent
{ "dsgRenjuTaraguchiSwapTableEvent": { "swap": false, "move": 113, "player": "alice", "table": 5, "time": 1718400000123 } }
```
**Offer 10** (Branch B — black offers ten 5th-move candidates). The ten must have no two
D4-symmetric duplicates (§9.5); this example uses offsets `(1,0)(2,0)(3,0)(4,0)(1,1)(2,1)(3,1)(4,1)(2,2)(3,2)`
about centre 112 → **10 distinct {|dx|,|dy|} orbits**, all in-bounds, none = centre:
```swift
["dsgRenjuTaraguchiOffer10TableEvent":
    ["moves": [113, 114, 115, 116, 128, 129, 130, 131, 144, 145], "player": me, "table": table.table, "time": 0]]
```
**Select 1** (white picks one of the ten → becomes move 5; placed via a following `dsgMoveTableEvent`):
```swift
["dsgRenjuTaraguchi10Select1TableEvent": ["move": 130, "player": me, "table": table.table, "time": 0]]
```
**Contract reminders (from §7), enforced in the reducers (step 1):** never place stones from these
three echoes — stones ride `dsgMoveTableEvent` (the `addMove`/`moveTableEvent` path). On (re)join,
the server sends authoritative seats (`sendPlayingPlayers`) plus **exactly one**
current-decision-point signal (§7 / §9.2): *nothing*, a **silent** `dsgSwapSeatsTableEvent`
(window resolved; its `swap` bit is the **current window’s** decision, **not** net orientation —
seats are **not** re-applied), an **offer10** frame (Branch-B selection pending), or a replayed
**select1** frame (Branch-B move 5 chosen). Reconstruct via `RenjuRejoin.decode(numMoves, signal)`.

### 9.5 Offer symmetry dedup (client-side, UX nicety)
The ten Branch-B offers must contain no two D4-symmetric duplicates. The server already rejects
violations via `RenjuState.offerFifthMoves` (→ `offerFifthMove`), so client-side checking is a
**UX nicety** (instant feedback vs a round-trip error) — recommended, not required. iOS has **no**
existing port (unlike the JSP `renjuRotate`/`renjuStabilizer`/`renjuIsSymmetricDup`), so port the
algorithm into Swift — or simply let the server reject and surface the error.

**The ten offers are NOT box-constrained.** Any in-bounds, empty, non-D4-symmetric point is legal
— corner offers included (confirmed by the 2026-06-15 round-trip). Only the **Branch-A** move 5 is
restricted to the 9×9 box. So the 10-pick multi-select must allow the **whole board** (minus
occupied + symmetric-duplicate cells), **not** a central square.

Algorithm for the 15×15 board (center `(7,7)`):
- For move `m`: `x = m % 15`, `y = m / 15`, `dx = x − 7`, `dy = y − 7`.
- The **8 D4 images** of `(dx,dy)`: rotations `(dx,dy)`,`(−dy,dx)`,`(−dx,−dy)`,`(dy,−dx)` and
  reflections `(−dx,dy)`,`(dx,−dy)`,`(dy,dx)`,`(−dy,−dx)`. Map each back: `m' = (tx+7) + (ty+7)·15`.
- Reject an offer if **any** of its 8 images equals an already-accepted offer. Maintain a running
  `Set<Int>` of all images of accepted offers and test membership.

Mirror the server logic exactly: the canonical reference is the JSP port (`renjuRotate` /
`renjuStabilizer` / `renjuIsSymmetricDup` in `gameServer/tb/mobileGame.jsp`), itself a JS port of
`SimpleGridState.rotateMove` + the position stabilizer (§3). Translate that to Swift verbatim so
the client agrees with `offerFifthMove`.

### 9.6 New UI primitives (no iOS precedent)
The swap2/dPente UI is a plain `UIAlertController` action-sheet (§9.1) — the Renju opening needs
board-level interaction with **no existing analogue** in this client (`KOTHTableViewController`
uses a `UIPickerView` for a single pick, which is **not** a multi-select):
- **Central-box highlight** — render a colored/dashed rectangle marking only the legal cells inside
  the N×N square about center 112 for the current opening move: **moves 2/3/4/5 → 3×3 / 5×5 / 7×7 /
  9×9** (radius 1/2/3/4). Applies during the `MOVE`/placement phase **and** the decline-and-place
  action of a `SWAP` window (the bundled stone is constrained to the same square). This box covers
  **only the single-stone placements (moves 2–5, incl. Branch-A move 5)** — the ten Branch-B offers
  are **not** box-constrained (§9.5), so do **not** draw a box for the offer-10 picker. No precedent
  in `LiveBoard.draw`’s star-points logic → likely a new overlay/`CALayer` or extra `draw` pass.
- **Translucent “dead-stone” candidates** — render the 10 Branch-B offers (and, during `SELECTION`,
  the non-picked nine) as translucent black, with an optional pick-order label (1–10). Reuse
  `LiveBoard`’s `alpha = 0.7` `blackStone` (:32-35) — the closest existing primitive; rendering
  **10 simultaneously and clearing on interaction is untested**. **(verify the array render/clear.)**
- **10-pick multi-select + submit** — tap to add a candidate, tap again to remove, with a
  `Pick n of 10` counter; **auto-send** on the 10th pick (emit `dsgRenjuTaraguchiOffer10TableEvent`
  without a separate Confirm button). Validation before send: exactly **1** stone inside the 9×9
  for Branch A, or exactly **10** distinct, non-D4-duplicate (§9.5) stones placed **anywhere on the
  board** for Branch B; alert otherwise. Branch is inferred from the count (1 = continue / 10 =
  offer), matching the `ServerTable`/`MoveServlet` contract.
- **White selection screen** — a full-screen or modal view for white to choose 1 of the 10 offered
  moves (like the swap prompt, but 10 board cells/buttons instead of 2–3). On pick, emit
  `dsgRenjuTaraguchi10Select1TableEvent` (§9.4). **(verify: separate `UIViewController` vs an
  in-`TableViewController` overlay.)**
- **Non-dismissible selection prompt** — the server prompts the selector via
  `dsgSystemMessageTableEvent` (today display-only via `addText`, §9.1). For Renju the prompt must
  be **action-forcing** (non-dismissible) until a selection is sent, not a passive text-log line.
  **(verify the server actually sends this for Renju selection.)**

Visual reference (different framework, do not copy code): `gameServer/tb/mobileGame.jsp` and its
board JS — `drawDeadStone`, the central-square hinting by move number, and the multi-pick picker.

**Could NOT confirm from code (carry forward; treat as "verify"):**
- Whether a per-variant `currentPlayer()` opening branch is strictly required for correct
  `isMyTurn` during the Renju opening (a `renjuOpeningPlayer` mirroring the swap2 arm is the safe
  move). **(verify)**
- Whether the iOS app supports **any** turn-based move POST (e.g. `renjuAction`/`MoveServlet`), or
  is strictly live-WS for sending; the `game.jsp` GET is read-only load. Assumed live-only.
  **(verify)**
- How the historic `game.jsp` endpoint behaves when handed a Renju id 31/32/81 — does it ship
  `renjuPhase`/`renjuOffers`/`renjuSwaps` (the parser ignores them) or a malformed response?
  **(verify)**
- How live games assign player 1 vs player 2 (is P1 always white, or rotation/negotiation?), and
  how iOS initiates/joins a Renju game (lobby/creation UI vs live room only). **(verify)**
- Whether coordinate axis labels (A–P, 1–15) are rendered anywhere beyond `LiveBoard`/`BoardView`
  (none found in their `draw` code). **(verify)**
- The `playersAndTables.swapSeats` / `swap2Pass` method bodies in the `TablesAndPlayer` class
  (≈`HelperClasses.swift:685`) — referenced by the room handlers but their definitions were not
  inspected; the new Renju mutators must follow the same internal pattern. **(verify)**
- Whether the central-box highlight is achievable in the current `LiveBoard.draw` architecture or
  needs a new overlay/view; the exact multi-select gesture (long-press / tap-count / explicit
  buttons); and efficient render/clear of 10 simultaneous translucent candidates. **(verify)**
- Client-side forbidden-point validation (overline / double-four / double-three) is **expected to
  be NONE** (server-enforced per the contract); do **not** port the finder. If marking is ever
  added, fetch `getForbiddenPoints` from the server. **(verify the server-only assumption.)**

*Resolved while grounding (no longer open):* the stone-color convention **is** confirmed from code
— `abstractBoard` values 1 = white / 2 = black (with `−1` masked), and engine
`colorForMove → (index % 2) + 1` is white-first; so Renju black-first ⇒ first stone value 2 via a
new black-first cadence (§9.0).

---

## 11. Sub-project 6 — iOS (`penteLive-iOS`) **turn-based** (correspondence) Taraguchi-10 handoff

This is the **turn-based (correspondence, days-per-move-over-HTTP) complement to the live iOS handoff in §9** — and it **corrects the §9 transport verdict**. §9 declared iOS "LIVE ONLY" and called the Objective-C `BoardViewController` a "read-only viewer." **That is wrong.** `BoardViewController` IS iOS's interactive turn-based board: its header declares **`boardTap:`** (`BoardViewController.h:77`, a `UILongPressGestureRecognizer` wired via `boardTapRecognizer:75`) and **`submitMove:`** (`:79`); the implementation has `submitMove:`/`submitMoveToServer` (`BoardViewController.m:1197`/`:1216`) which build a `game?command=move…&gid=…&moves=…&message=…` request inline (`:1275-1295`) and dispatch it via **GET** (`setHTTPMethod:@"GET"`, `:1302`) to `gameServer/tb/game`. The interactive-TB launcher is `GamesTableViewController.m`, which opens this board for play with `[boardController setActiveGame:YES]` (`:2166`, `:3658`). So iOS plays **BOTH** transports: **live** via the Swift `PenteLiveSocket`/`TableViewController` stack (§9), and **turn-based** via the ObjC `BoardViewController` (this section). The live and TB paths are different code in different languages and must be wired for Renju **separately** — §9 covers the Swift live stack; §11 covers the ObjC TB stack. Every anchor below was grep-verified against the `penteLive-iOS` submodule on this branch (a **separate repo** — do not edit it from this one); line numbers drift, so grep the symbol.

### 11.0 Board basics (restated for the TB board)
- Board **15×15**, game ids **31 (Renju) / 32 (Speed Renju) / 81 (TB Renju)**. The TB board most often shows **`TB_RENJU=81`** (turn-based games), but `BoardViewController` also replays finished live games, so all three ids must size correctly. Move encoding `x + y·15`; **center = 112** (`7 + 7·15`); the **server auto-places** the center as move 1 — it arrives inside the `game.jsp` `moves` array, so the client only needs the board sized to 15 (no client auto-center).
- **Board background colour = `#D98880` (dusty rose)** — the canonical Renju board colour, **distinct from gomoku's `#A3FDEB`** (iOS gomoku ≈ RGB `0.612,1,0.898`, `BoardVariantMapping.swift:56-57`). `#D98880` ≈ RGB `0.851,0.533,0.502`. This is the **same** value §9.3 step 2a adds to the shared `BoardVariantMapping.backgroundColor(for:.renju)` case — **(verify the ObjC TB board actually consumes that `@objc` bridge** — `@objc(backgroundColorForVariant:boatPente:)`, `BoardVariantMapping.swift:33` — **rather than a separate ObjC colour path).**
- **Black plays first.** Stone-value convention on the TB board: `abstractBoard` cell value **1 → light/white stone, 2+ → dark/black** (the value→fill test lives in `BoardView.m:193-196`) — **matches** the task's "board value 2 = black." (The `BoardView.h:13-15` `#define WHITE 0 / BLACK 1 / RED 2` is a **legacy palette enum, distinct** from the `abstractBoard` value convention — do **not** conflate them.) "Black first" ⇒ the first stone (the auto-center) must render as **value 2**. The TB board is **replay-driven** (it re-plays the `moves` array from `game.jsp`), so first-stone colour is set by the replay loop's parity, not a live cadence — ensure the Renju replay assigns value `2` to move 0 (black-first), the inverse of gomoku/Pente white-first.

### 11.1 Confirmed anchors (file : symbol)
All grep-verified in the submodule on this branch. **(WRONG today)** = the path Renju ids 31/32/81 hit now, incorrect for Renju; **(OK)** = correct / reusable as precedent; **(verify)** = not fully confirmed from code. Files are ObjC unless noted Swift.

| Area | File | Symbol / fact |
|---|---|---|
| interactive TB launcher | `test1/GamesTableViewController.m` | opens the board **for play**: `[boardController setActiveGame:YES]` (**:2166**, **:3658**) → `replayGame` → `[[boardController boardTapRecognizer] setEnabled:YES]`. This is the interactive-TB entry point. **(OK)** |
| read-only replay path | `test1/PenteWebViewController.swift` (Swift) | `webView(…decidePolicyFor…)` **:39/:47** detects `gameServer/tb/game?gid=` URLs, extracts the gid (**:47-52**), instantiates `BoardViewController` (**:69**), but sets `activeGame=false` (**:73**) and `boardTapRecognizer.isEnabled=false` (**:75**) **before** `replayGame()` (**:76**) — a **read-only** replay, not interactive play. **(OK)** |
| interactive TB board (the §9 correction) | `test1/BoardViewController.h` | **`boardTap:` IBAction :77** (`UILongPressGestureRecognizer *boardTapRecognizer :75`) + **`submitMove:` IBAction :79** → this IS the interactive TB board, not a read-only viewer. `int abstractBoard[19][19]` **:36** (sizing, see below). **(OK / sizing WRONG)** |
| game load (read) | `test1/BoardViewController.m` | `replayGame` **:1380** → `GET …/gameServer/mobile/json/game.jsp?gid=%@` **:1422** (prod) / **:1427** (localhost); `NSJSONSerialization` **:1453**. **(OK)** |
| JSON parse fields | `test1/BoardViewController.m` | `replayGame` parse block **:1465-1522** reads `canHide`/`canUnHide`(:1465-66), `player1`/`player2`(:1473-74), `currentPlayer`(:1475), `undoRequested`(:1476), `sid`(:1477), `moves`(:1478-81, a comma-separated `String` split via `componentsSeparatedByString:@","`), `rated`(:1485), `privateGame`(:1486), `gameName`(:1488), `messageNums`(:1509), `messages`(:1512), `cancel`(:1516). **Opening-state precedent: `dPenteState` IS parsed at :1767-1768.** **No `renjuPhase`/`renjuOffers`/`renjuSwaps`.** **(WRONG today)** |
| move submit (URL) | `test1/BoardViewController.m` | `submitMoveToServer` **:1216-1331**; builds the URL inline (**:1271-1299** — **:1275/:1281** no-message variant, **:1288/:1295** with-message) and dispatches it via **GET** (`setHTTPMethod:@"GET"` **:1302**) to `gameServer/tb/game`. (The `:2181/:2185` POST is `requestUndo`'s, not this submit.) **No `renjuAction` param.** **(WRONG today)** |
| move-string build | `test1/BoardViewController.m` | `submitMoveToServer` move-string construction **:1219-1253** (Connect6 / D-Pente / Swap2 via `finalMove`, `dPenteMove1-4`, `swap2Move1-3`). **No renju swap/branch/offer/select payload formats.** **(WRONG today)** |
| board tap (placement) | `test1/BoardViewController.m` | `boardTap:` impl **:644**; computes move index, checks the empty cell, stores `finalMove`, updates preview stone **:694-755**. Ordinary single-stone placement only; **no opening dialog** beyond dPente/swap2. Reusable; needs a central-box gate for Renju. **(OK)** |
| opening-UI precedent | `test1/BoardViewController.m` | `swap2Opening`/`swap2Choice` flags **:84-85**, `dPenteChoiceLabel` `@synthesize :52` / header `UILabel BoardViewController.h:59`, show/hide **:1824-1876**; D-Pente/Swap2 show `player1Button`/`player2Button`; Swap2 adds `passButton :1862`. **Yes/no/pass only — no board interaction, no Renju.** **(WRONG today for Renju)** |
| game registration | `test1/SocialViewController.swift` (Swift) | `gameNames` dict **:28-35** (TB ids `51…75`); `gameNamesArray` **:36-43** (the game-picker list). **`Renju`(31)/`Speed Renju`(32)/`Turn-based Renju`(81) absent** from both → no name, not pickable. **(WRONG today)** |
| global grid size | `test1/BoardViewController.m` | `int … gridSize = 19` **:103**; reset to 19 in `replayGame` **:1383**; adapted only for Go (`9`/`13`) at **:1888/:1891**. **No `15` for Renju.** **(WRONG today)** |
| board-array sizing | `test1/BoardViewController.h:36` / `.m:78` | `int abstractBoard[19][19]` / `int abstractGoBoard[19][19]`. **A 15×15 board fits inside the 19×19 array (15<19) — no realloc strictly required;** the breakage is the **decode math + iteration bounds**, not capacity. **(WRONG today — math)** |
| coordinate math | `test1/BoardViewController.m` | hardcoded `/19`, `%19` at **:564,:574,:590,:605,:620,:746,:831-833**; `char coordinateLetters[19]` (A–T skipping I) **:93-94**, accessed `coordinateLetters[move % 19]` / `19 - (move/19)` (**:831/:833**). Renju needs `% gridSize` and the **first 15 labels A–P skipping I**. **(WRONG today)** |
| TB board render | `test1/BoardView.m` | `gridSize` default 19 **:29/:63**; grid loop `for (i=0; i<gridSize; ++i)` **:86-95**; **`drawRect` decode `i = stoneInt/gridSize`, `j = stoneInt%gridSize` :219-220/:231-232/:270/:280 — already `gridSize`-aware (OK)**; **star points: 5 circles hardcoded for 19×19 :150-176 (WRONG for 15×15)**; stone fill value `1→light / 2+→dark` **:193-196 (OK, matches 2=black)**. |
| stone palette / fill | `test1/BoardView.h:13-15` (palette) + `StoneView` decl `BoardView.h:17-26` / impl `BoardView.m:292-359` | `#define WHITE 0/BLACK 1/RED 2` (legacy palette, **distinct** from `abstractBoard` 0/1/2 value convention); `abstractBoard` ivar `:29`. The value→fill test (1→light/white, 2+→dark) is in `BoardView.m:193-196`. (No `StoneView.m` exists — `StoneView` lives inside `BoardView.m`.) **(OK — don't conflate the two conventions)** |
| variant enum (shared w/ §9) | `test1/PenteEngine/PenteVariant.swift` (Swift) | `@objc enum PenteVariant: Int` **:6**, cases `pente=0 … connect6=10` (**:7-17**); **no `renju`**, next free raw value **11**. §9.3 step 4 adds `case renju = 11`. **(WRONG today)** |
| variant→colour map (shared w/ §9) | `test1/BoardVariantMapping.swift` (Swift) | `backgroundColor(for:boatPente:)` **:33-60** — exhaustive `switch` over all `PenteVariant` cases, **no `default`** (adding `.renju=11` won't compile until a case is added); `variant(forGameType:)` **:8-28** has a `.pente` fallback (**:11/:28**), no Renju gameType. §9.3 step 2/2a adds the `.renju` `#D98880` case + (if needed) a Renju gameType branch. **(WRONG today)** |
| ObjC consumption of the colour bridge | `test1/BoardViewController.*` / `BoardView.*` | **(verify)** whether the ObjC TB board reads its background from the `@objc(backgroundColorForVariant:boatPente:)` bridge (`BoardVariantMapping.swift:33`) — in which case §9.3 step 2a's `.renju` case covers it — **or from a separate ObjC colour path that also needs a Renju branch.** **(verify)** |

### 11.2 TB phase + transport — the server **ships** `renjuPhase` (read, don't derive)
**The defining difference from §9 (live).** On the **live** socket there is no `renjuPhase` on the wire and the client must **derive** the Taraguchi-10 phase from tracked decision echoes (§9.2 / §10.2a). On the **turn-based** path the server has **already derived and resolved the phase** (`TBGame.getRenjuPhase()`, §2.6) and **ships it in the JSON**. So the iOS TB board **READS** the phase directly — **there is NO client-side phase derivation here**, and no `openingPhase`-style classifier to port. This mirrors Android's TB read note (§10.2b).

**Read path.** `replayGame` (`BoardViewController.m:1380`) does `GET gameServer/mobile/json/game.jsp?gid=<id>` (`:1422`) → a Gson `GameResponse`. Add three fields to whatever model receives that JSON and parse them next to where the parser **already reads `dPenteState` (`:1767-1768`)** — the existing opening-state-field precedent. Field shapes (§2.6; types **confirmed** against the backend `GameResponse.java:45-47` per §10.3 step 8):
- **`renjuPhase`** — `String`, one of **`SWAP` | `BRANCH` | `OFFERS` | `SELECTION` | `MOVE` | `COMPLETE`**, else `null` (non-Renju).
- **`renjuOffers`** — `String`, **comma-separated** offered move indices, else `null`.
- **`renjuSwaps`** — `Integer` (packed opening word), else `null`.

The read phases map to the §11.5 UI as follows: `SWAP` → swap window (windows 1–4) — take over (`swap`) or place the next opening stone (a 1-stone `move`); `BRANCH` → Branch A (1-stone `move`) or Branch B (10-stone `move`); `OFFERS` → a read-only state the single-request client **never acts on** (Branch B + its ten offers are one `move`); `SELECTION` → white commits move 5 + move 6 in one atomic 2-stone `select`; `MOVE` → constrained central-square placement (moves 2–5, incl. Branch-A move 5); `COMPLETE` → ordinary alternating play (black forbidden-points server-enforced).

**Submit path — the §2.4 `MoveServlet` contract over the existing `submitMoveToServer` HTTP request.** Today `submitMoveToServer` (`:1216`) builds the URL inline (`:1271-1299`) — `gameServer/tb/game?command=move&mobile=&gid=<gid>&moves=<payload>&message=<msg>` — and dispatches it via **GET** (`setHTTPMethod:@"GET"`, `:1302`). For Renju the client **reads `renjuPhase`** (above) and **appends `&renjuAction=<action>` to that GET query string**, with a renju-shaped `moves` payload. The opening uses exactly **THREE** `renjuAction` values — `swap`, `move`, `select` — resolved by `RenjuTbContract.resolve` (verified against `RenjuTbContract.java` + `MoveServlet.java`):

| `renjuAction` | phase | `moves` payload | server behavior |
|---|---|---|---|
| `swap` | SWAP | none (`moves` ignored) | Take over the opponent's side at the open swap window — seats swap, **no stone** placed. The next decision (branch / next stone) arrives as a subsequent `move`. |
| `move` | SWAP / BRANCH / MOVE | `<m>` (1 stone) | Auto-declines a pending swap first, then places one stone — windows 1–3 → the next opening stone; **at the branch point** (move 4, branch unchosen; fresh-decline *or* post-take-over) → Branch A move 5 (restricted to the 9×9 centre); MOVE phase → a plain opening stone. |
| `move` | SWAP@4 / BRANCH | `<s1>,…,<s10>` (10 stones) | Auto-declines a pending swap, then Branch B: take the ten-offer branch and validate + persist the ten 5th-move offers **atomically**. Only valid at the branch point. |
| `select` | SELECTION | `<m5>,<m6>` (2 stones) | **Atomic**: commit one of the ten offered moves as **move 5 (black)** *and* place **move 6 (white)** → opening complete. Stores neither unless both are legal. |

Contract rules:
- **Branch A vs B is inferred from the `move` stone count alone** (1 = A, 10 = B) — there is **no** separate branch/offer request.
- `swap` is **always** a take-over (no stone; never a `0`). **Declining a swap is implicit in sending a `move`** — the windows-1–3 decline is a 1-stone `move`, **not** a standalone swap-decline payload.
- **MOVE / COMPLETE** placements go as a **plain `move` with NO `renjuAction`**.
- The read-only `renjuPhase` enum (above) is **unchanged**; under this single-request contract a TB client **never acts on a standalone `OFFERS` phase** — Branch B and its ten offers are one `move`.

The server validates everything authoritatively (central squares, forbidden points, offer symmetry/distinctness). A `renjuAction` that does **not** match the pending phase is rejected with **"Renju action does not match the pending decision."** (`:438`); other rejections carry **distinct, often phase-specific** messages (e.g. "Expected 10 offered moves.", "Selected move was not offered.", "Expected a move when declining to swap.") that the client should **surface verbatim**, distinct from a transport/DB error. Client-side checks are UX only.

### 11.3 iOS TB file-by-file map (the real work)
Renju ids 31/32/81 resolve **WRONG** today across the ObjC TB stack (§11.1). The work is: register the game, parse the new JSON fields, size the board to 15, send `renjuAction`, and build the opening UI from scratch.

1. **`test1/SocialViewController.swift`** *(registration)* — add to `gameNames` (**:28-35**): `"Renju": 31, "Speed Renju": 32, "Turn-based Renju": 81`, and add the corresponding entries to `gameNamesArray` (**:36-43**) so Renju is **pickable** in the game selector (the picker reads the array at **:282/:302/:306/:310**; the lookup `gameNames[gameString]` is at **:136/:228**). Without this, Renju games show no name and cannot be created from this screen.
2. **`test1/BoardViewController.m` — `replayGame` JSON parse** *(read the phase)* — extend the parse block (next to the existing `dPenteState` read at **:1767-1768**) to read `jsonResponse[@"renjuPhase"]` (`NSString`), `jsonResponse[@"renjuOffers"]` (comma-separated `NSString` → `int[]`), and `jsonResponse[@"renjuSwaps"]` (`NSNumber`/nullable). Store them on the `Game`/board model **(verify whether `Game.swift`/`Move.swift` need new fields, or an ObjC ivar suffices — not explored)**. This is a **read**, not a derivation (§11.2).
3. **`test1/BoardViewController.m` — board sizing** *(15×15)* — after the `replayGame` reset `gridSize = 19` (**:1383**) add a Renju branch setting **`gridSize = 15`** for ids 31/32/81 (parallel to the Go `9`/`13` branches at **:1888/:1891**). Then make every hardcoded `/19`,`%19` **`gridSize`-aware** (**:564,:574,:590,:605,:620,:746,:831-833**) — `BoardView.m` already decodes with `/gridSize`,`%gridSize` (**:219-280**), so the controller must match it or the two disagree. The `abstractBoard[19][19]` array (`.h:36`) **physically fits** a 15×15 board (15<19), so no reallocation is strictly required — but the index math and the iteration bounds (any `0..<19` / `< gridSize` loops, e.g. the sync loops) **must** use `gridSize`. (This is the survey's "most dangerous" item, framed precisely: it is the decode math, not the array capacity.)
4. **`test1/BoardViewController.m` — coordinate labels** — `coordinateLetters[19]` (A–T skipping I, **:93-94**) accessed via `% 19` / `19 - (move/19)` (**:831/:833**) must use the **first 15 labels A–P skipping I** and `% gridSize` / `gridSize - 1 - (move/gridSize)`.
5. **`test1/BoardView.m` — star points** — the 5 hardcoded 19×19 circles (`drawRect` **:150-176**) are wrong for 15×15. Use the Renju star points at cols/rows **{3,7,11}** → indices **`[48,52,56,108,112,116,168,172,176]`** (index `= col + row·15`, center 112), matching §4 / §8.3 / §9.3. (`drawRect`'s stone decode at **:219-280** is already `gridSize`-aware — leave it.) Renju forbids black stones on these points anyway, so they are purely visual.
6. **`test1/BoardViewController.m` — `submitMoveToServer`** *(send `renjuAction`)* — extend the move-string construction (**:1219-1253**, alongside the Connect6/D-Pente/Swap2 cases) with the three Renju payload formats (§11.2 table): `swap` (**no** `moves` payload — take-over only), `move` (`<m>` = 1 stone for a windows-1–3 decline / Branch A / a plain opening stone, **or** `<s1>,…,<s10>` = 10 stones for Branch B — branch inferred by count), and `select` (`<m5>,<m6>` = 2 stones: move 5 + move 6); then extend the URL builders (**:1275/:1281/:1288/:1295**) to append **`&renjuAction=<action>`** to the GET query string when the game is Renju (and send **no** `renjuAction` for plain `MOVE`/`COMPLETE` placements). Surface the server's rejection message **verbatim** (often phase-specific — §11.2), distinct from a transport error.
7. **Shared Swift variant/colour (cross-ref §9.3 steps 2/2a/4)** — `PenteVariant.swift` `case renju = 11` and `BoardVariantMapping.swift` `.renju` → `#D98880` are **shared** with the live stack and specified in §9; do not re-spec them. For the TB board, only **confirm** the ObjC board actually consumes the `@objc` colour bridge (§11.1 last row) and that the `gameName` string the TB endpoint emits for Renju maps to `.renju` in `variant(forGameType:)`.
8. **Opening UI** *(from scratch — §11.5)* — the existing TB opening UI (`dPenteChoiceLabel`/`swap2`, **:1824-1876**) is yes/no/pass buttons only. Renju needs board-level interaction (central-box highlight, 10-pick multi-select, translucent candidates, white selection), driven by the **read** `renjuPhase` and submitted via `renjuAction`. Reuse `boardTap:` (**:644**) for placement and picking; reuse the dPente/swap2 button block (**:1824-1876**) as the dispatch precedent.

### 11.4 Wire / URL examples
**Read (server→client) — `game.jsp` `GameResponse` JSON** for an in-progress TB Renju game awaiting the white selection (Branch B), table-free (TB has no table id). The Renju fields ride alongside the existing ones the parser already reads (`:1465-1522`):
```json
{
  "gameName": "Turn-based Renju",
  "moves": "112,113,114,115",
  "currentPlayer": "bob",
  "rated": true,
  "privateGame": false,
  "renjuPhase": "SELECTION",
  "renjuOffers": "113,114,115,116,128,129,130,131,144,145",
  "renjuSwaps": 13
}
```
- `moves` is itself a **comma-separated `String`**, not a JSON array — iOS splits it with `componentsSeparatedByString:@","` (`BoardViewController.m:1478-1481`). `renjuPhase` is read **as-is** (no derivation). `renjuOffers` is the **same comma-separated `String`** shape — split to `int[]` (here the ten Branch-B candidates). `renjuSwaps` is the packed opening word (Integer; treat as opaque for UI — the phase already tells you what to show). For a non-Renju game all three are `null` (Gson tolerates missing fields).

**Submit (client→server)** — the existing `submitMoveToServer` **GET** with `&renjuAction=` appended to the query string (base `gameServer/tb/game?command=move&mobile=&gid=<gid>&moves=<payload>&message=<msg>`, built `:1271-1299`, dispatched `setHTTPMethod:@"GET"` `:1302`). Concrete (gid `4242`, center 112, 15×15) — **three actions; branch inferred by stone count**:
```
# SWAP (windows 1–3): decline + place the next opening stone at col8,row7 (=113, inside the 3×3)
#   the decline is IMPLICIT in the 1-stone `move`; there is no separate swap-decline payload
…/gameServer/tb/game?command=move&mobile=&gid=4242&moves=113&message=&renjuAction=move

# SWAP: take over opponent's side — NO `moves` payload (never a `0`)
…/gameServer/tb/game?command=move&mobile=&gid=4242&moves=&message=&renjuAction=swap

# Branch point (a fresh move-4 decline, or after a take-over): Branch A = a 1-stone `move`
#   places move 5 at 130 (must be inside the 9×9)
…/gameServer/tb/game?command=move&mobile=&gid=4242&moves=130&message=&renjuAction=move

# Branch point: Branch B = a 10-stone `move` carrying the ten 5th-move offers (no two D4-symmetric)
#   one atomic request; there is no separate branch/offer step
…/gameServer/tb/game?command=move&mobile=&gid=4242&moves=113,114,115,116,128,129,130,131,144,145&message=&renjuAction=move

# SELECTION: white commits move 5 (one of the ten) + move 6 in one atomic 2-stone `select`
…/gameServer/tb/game?command=move&mobile=&gid=4242&moves=130,131&message=&renjuAction=select

# MOVE (a constrained opening stone) / COMPLETE: a plain move — NO renjuAction
…/gameServer/tb/game?command=move&mobile=&gid=4242&moves=130&message=
```
Notes (from §2.4 / `RenjuTbContract.java` + `MoveServlet.java`): **Branch A vs B is inferred from the `move` stone count alone** — 1 stone = Branch A (the 9×9-constrained move 5), 10 stones = Branch B offers — so there is **no** separate `branch`/`offer` request. **Declining a swap is implicit in sending a `move`**: the windows-1–3 decline is the 1-stone `move` above, and at the move-4 branch point a fresh decline is likewise just the Branch-A (1-stone) or Branch-B (10-stone) `move`. `swap` is **always** a take-over carrying **no** stone. A `select` is **atomic** — it commits move 5 (one of the ten offered) **and** move 6 together; the server stores neither unless both are legal. The ten Branch-B offers are **not** box-constrained (anywhere on the board, minus occupied + D4-symmetric duplicates, §11.5); only the **Branch-A** move 5 is restricted to the 9×9.

### 11.5 Opening UI on the TB board (driven by the read `renjuPhase`)
The TB board has **no opening UI today** other than the dPente/swap2 yes/no/pass buttons (`:1824-1876`); the Renju opening is a **from-scratch build** on the existing TB board (reusing `boardTap:` for placement/picking and the dPente/swap2 button block as the dispatch precedent). Unlike §9.6 (live, phase **derived**), here every control is gated by the **server-provided `renjuPhase`** (§11.2) and submitted via `renjuAction` (§11.4). No state machine to track — just `switch(renjuPhase)`:
- **`SWAP` (swap windows) — swap prompt.** Show two controls (mirror the `player1Button`/`player2Button` block): **"Swap (take over)"** → `renjuAction=swap` with **no `moves` payload** (seats swap, no stone); **"Don't swap (place next stone)"** → place the next opening stone inside its central square and send it as a **1-stone `move`** (`renjuAction=move`, `moves=<move>`) — the decline is **implicit** in the `move`; there is no separate swap-decline payload (**windows 1–3**). At the **move-4 swap window**, declining is the **branch choice itself** (next-but-one bullet): a **1-stone `move`** (Branch A) or a **10-stone `move`** (Branch B) — there is **no** stoneless move-4 decline. The decline-and-place stone is **central-box constrained** (see below).
- **Central-box placement (`MOVE`, and the decline-stone of a `SWAP` window).** Constrain `boardTap:` to the legal N×N square about center 112 for the current opening move: **moves 2/3/4/5 → 3×3 / 5×5 / 7×7 / 9×9** (radius 1/2/3/4). Highlight that square (a new overlay/`CALayer` or extra `drawRect` pass — the TB board has no zone-highlight precedent). This box covers **only** single-stone placements (moves 2–5, incl. Branch-A move 5) — **not** the Branch-B 10-pick. Both a `MOVE`-phase placement and a windows-1–3 decline submit as a **1-stone `move`** — the `MOVE`-phase placement plain (no `renjuAction`), the windows-1–3 decline with `renjuAction=move`.
- **`BRANCH` (the branch point — after a take-over, or a fresh move-4 decline).** The branch is chosen by a **single `move`, inferred by stone count** — there is **no** separate branch/offer step: **Branch A** = a **1-stone `move`** placing move 5 in the 9×9; **Branch B** = a **10-stone `move`** carrying the ten 5th-move offers at once. (After a take-over the server ships `renjuPhase=BRANCH`; after a fresh move-4 decline the player goes straight to the same count-inferred `move`.)
- **Branch-B 10-pick multi-select (part of the Branch-B `move`).** Under the single-request contract the client **never acts on a standalone `OFFERS` phase** — the ten offers ride the Branch-B `move` itself. Picker UI: tap to add a candidate, tap again to remove, with an `n/10` counter; render placed picks as **translucent black** (reuse the `BoardView` stone-fill at lower opacity / the Go dead-stone look). Picks are allowed **anywhere on the board** (in-bounds + empty, minus D4-symmetric duplicates — §11.5 dedup, a UX nicety; the server rejects violations via `offerFifthMove`). On the 10th pick, submit the whole branch as **`renjuAction=move`** with `moves=<s1>,…,<s10>` (**exactly ten** — Branch B is inferred from the count).
- **`SELECTION` — white commits move 5 + move 6 (atomic).** Present the ten `renjuOffers` candidates (parsed from the comma-separated JSON) as translucent black; white taps one to choose **move 5** → solid, the rest cleared, then places **move 6** anywhere legal. Submit both together as **`renjuAction=select`** with `moves=<m5>,<m6>` (move 5 must be one of the offered; the server stores neither unless both are legal). A non-dismissible prompt (vs the passive text-log line the existing message handler shows) is the right affordance.
- **`COMPLETE` — ordinary placement.** Plain `boardTap:` + a normal `command=move` (no `renjuAction`); black forbidden-points are server-enforced (rejected on submit with a **phase-specific message** the client surfaces verbatim).

Offer symmetry dedup (15×15, center `(7,7)`): for move `m`, `x=m%15`, `y=m/15`, `dx=x-7`, `dy=y-7`; the 8 D4 images are rotations `(dx,dy),(-dy,dx),(-dx,-dy),(dy,-dx)` + reflections `(-dx,dy),(dx,-dy),(dy,dx),(-dy,-dx)`, mapped back `m'=(tx+7)+(ty+7)·15`; reject an offer if any image is already accepted. Mirror the JSP `renjuRotate` (`mobileGame.jsp:998`) / `renjuStabilizer` (`:1008`) / `renjuIsSymmetricDup` (`:1027`) exactly so the client agrees with the server. Visual reference (different framework — do not copy code): `gameServer/tb/mobileGame.jsp` — central-square hinting by move number and the multi-pick picker; the translucent dead/candidate stone is drawn by `drawDeadStone` in **`gameServer/tb/gameScript.js:722`** (mobileGame.jsp only *calls* it, e.g. `:1045`/`:1059`).

### Could NOT confirm (carry into QA / verify before relying on)
- **Model fields for the new JSON.** Whether `Game.swift` / `Move.swift` (or the ObjC `Game`/board model) need explicit `renjuPhase`/`renjuOffers`/`renjuSwaps` fields, or an ObjC ivar suffices — the model structs were not opened. **(verify)**
- **ObjC consumption of the colour bridge.** Whether the ObjC TB board reads its background from the shared `@objc BoardVariantMapping.backgroundColorForVariant:boatPente:` (so §9.3 step 2a's `.renju #D98880` case covers it) or from a separate ObjC colour path needing its own Renju branch. **(verify)**
- **`gameName` string for Renju.** The exact `gameName` value the TB endpoint emits for ids 31/32/81 (`"Turn-based Renju"`? `"Renju"`?) and that it maps to `.renju` in `variant(forGameType:)` and to the right `gridSize` branch. **(verify)**
- **`renjuSwaps` packing.** It is an `Integer` packed opening word; the UI does not need to decode it (the phase suffices), but confirm no UI relies on its bits. **(verify backend packing if ever decoded.)**
- **Coordinate axis correctness after the `/gridSize` switch.** Contract is `x + y·15`; confirm the ObjC decode (post-fix at `:564…:833`) and `BoardView.m`'s `/gridSize` agree end-to-end on 15×15. **(verify)**
- **`canHide`/`canUnHide` (`:1465-66`)** — whether these are TB-only or also apply to replayed live games (affects whether the Renju TB flow must preserve them). **(verify)**
- **Forbidden-point validation is server-only (expected).** No client finder found; do **not** port it. If marking is ever added, fetch `getForbiddenPoints` from the server. **(verify the server-only assumption.)**
- **Rejection-message surfacing.** The server returns **distinct, often phase-specific** messages for a bad `renjuAction` (e.g. "Renju action does not match the pending decision." `:438`, "Expected 10 offered moves." `:474`, "Selected move was not offered." `:505`) rather than a generic "Invalid move". Confirm the iOS error-handling path in `submitMoveToServer` surfaces that message **verbatim**, distinct from a transport error. **(verify the iOS error-handling path.)**
- **Which `submitMoveToServer` URL variant Renju hits** (`&message=` at `:1275/:1281` vs `&message=%@` at `:1288/:1295`) and the cleanest place to append `&renjuAction=` across all four. **(verify.)**
- *Resolved while grounding (no longer open):* stone-value convention is confirmed (`abstractBoard` 1=white / 2=black, `BoardView.m:193-196`; there is **no** `StoneView.m` — `StoneView` lives in `BoardView.m:292-359`); the interactive-TB nature of `BoardViewController` is confirmed (`boardTap:`/`submitMove:` in the header, `submitMoveToServer` builds `command=move` and dispatches it via **GET** at `:1302`, launched interactively by `GamesTableViewController.m` `setActiveGame:YES` `:2166`/`:3658`; `PenteWebViewController.swift` is the **read-only** replay path); and the `GameResponse` field types are confirmed (String/String/Integer, §10.3 step 8).
