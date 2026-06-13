# penteLive iOS — Domain & Architecture Glossary

Shared vocabulary for the Pente game-logic layer. Use these terms exactly in code,
comments, and reviews. Domain terms name the rules of the game; seam terms name the
modules introduced by the **single game engine** consolidation (see
`docs/adr/` once recorded).

## Game variants

- **Pente** — base game. 2-stone custodial capture; win at 5-in-a-row or 10 captured stones.
- **Keryo-Pente** — adds a 3-stone capture; win threshold raised to 15 captures.
- **O-Pente** — Keryo capture **plus** the poof rule (both keryo-capture and keryo-poof apply).
- **Poof-Pente** — adds the poof rule on top of base Pente capture.
- **D-Pente / DK-Pente** — "drop" openings; D variants hide the capture-count UI.
- **G-Pente** — extended tournament opening mask (centre 5×5 plus four arms).
- **Swap2 / Swap2-Keryo** — Swap2 opening protocol over Pente / Keryo rules.
- **Gomoku** — 5-in-a-row, no captures.
- **Connect6** — 6-in-a-row, no captures, 4-move cadence (1,2,2,1,1,2,…).
- **Go** — a *different game* (groups, liberties, territory, dead stones), not a Pente
  variant. Lives in its own module — see **GoGame**.

## Domain rule terms

- **Capture** — a custodial capture: a run of opponent stones (2 for Pente, 3 for Keryo)
  flanked on both ends by the mover's colour is removed.
- **Poof** — the mover's just-placed stone is sandwiched between two opponent stones; the
  sandwich resolves in the mover's favour (Poof-Pente / O-Pente only).
- **Keryo-poof** — the 3-stone poof pattern. Historically bug-prone: both ends of the run
  must be checked (a both-ends check regression was fixed in commit `63986f7`).
- **Pente (the win line)** — five (or six, for Connect6) consecutive stones of one colour.
- **Capture threshold** — captures needed to win: 10 (Pente family), 15 (Keryo family),
  N/A (Gomoku, Connect6).
- **Opening restriction / tournament mask** — board cells temporarily forbidden during the
  opening (centre 5×5; G-Pente adds arms). Marked on the board as `-1`.

## Architecture seam terms (single-engine consolidation)

- **Game engine (`PenteGame`)** — the *stateful* deep module that owns board state, capture
  counters, opening masks, and move cadence. Callers drive it with `play(move)` / `replay`
  and read the result; they no longer own or mutate rule state. Written in **Swift**,
  exposed to Objective-C callers via `penteLive-Swift.h`.
- **RuleSet** — one class per variant (≈9), each a thin *recipe* selecting capture run-length,
  poof kind, win line + threshold, opening mask, and cadence. RuleSets hold **no** scan code.
- **Scan** — the rule-primitive layer: the 8-direction capture / poof / win-line scans exist
  **exactly once** here. RuleSets compose `Scan`; this is what makes the keryo-poof class of
  bug impossible to half-fix. The deletion test for the old forks resolves here.
- **MoveResult** — the value returned by `play`/`replay`: captured cells (position + colour),
  poof flag, winner, placed colour. The single source for capture **animation** in both the
  Swift `Table` UI and the ObjC `BoardViewController`. An `@objc` class for ObjC callers.
- **GoGame** — sibling module behind the same engine seam, implementing Go (groups,
  territory, dead stones). Replaces the Go logic currently inlined in `Table` /
  `BoardViewController`; `PenteGame`'s dead `goStoneGroup*` properties are removed.
- **Cross-check corpus** — a golden set of recorded games asserting `PenteGame.replay`
  reproduces the captures/winner the records show. Guards against engine regressions and,
  indirectly, MMAI rule drift. (A direct MMAI-vs-engine apply-move oracle is a documented
  later step; MMAI's C search loop is not on the shared code path for performance reasons.)
