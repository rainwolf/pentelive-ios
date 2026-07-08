//
//  Scan.swift
//  penteLive  (PenteEngine)
//
//  Pure directional rule primitives ported verbatim from the legacy
//  Objective-C engine (test1/PenteGame.m). No state, no board mutation:
//  every function takes a plain [[Int]] (board[row][col]) by value and
//  returns its result. Coordinates use rowCol = row * n + col, where n = board.count (the board edge length).
//
//  Cell values: 0 empty, 1 white, 2 black, -1 masked (a masked cell never
//  equals a colour, so it is inert in every scan).
//
//  The `color` parameter is always the colour of the stone JUST PLAYED
//  (the mover / "myColor" in the legacy code).
//

import Foundation

enum Scan {

    /// 8 neighbour directions, in the exact order the legacy engine scans them.
    private static let neighbours: [(Int, Int)] = [
        (-1, 0), (-1, -1), (0, -1), (1, -1),
        (1, 0), (1, 1), (0, 1), (-1, 1),
    ]

    private static func inBounds(_ i: Int, _ j: Int, n: Int) -> Bool {
        i >= 0 && i < n && j >= 0 && j < n
    }

    // MARK: - Custodial capture (run = 2 Pente, run = 3 Keryo)
    //
    // Ports detectCaptureOfOpponent:atPosition: (run = 2) and
    // detectKeryoCaptureOfOpponent:atPosition: (run = 3). For each of the 8
    // directions: if the far flanker (distance run+1) is the mover's colour and
    // the `run` stones between it and the placed stone are all the opponent's,
    // those stones are captured. The far flanker check matches the legacy
    // `abstractBoard[...] == myColor`; captured stones carry the opponent colour.
    static func captures(on board: [[Int]], at move: Int, color: Int, run: Int) -> [Capture] {
        var b = board
        let n = board.count
        let i = move / n, j = move % n
        let opponent = (color == 1) ? 2 : 1
        let far = run + 1
        var result: [Capture] = []
        for (di, dj) in neighbours {
            let fi = i + far * di, fj = j + far * dj
            guard inBounds(fi, fj, n: n), b[fi][fj] == color else { continue }
            var custodial = true
            for k in 1...run {
                if b[i + k * di][j + k * dj] != opponent {
                    custodial = false
                    break
                }
            }
            guard custodial else { continue }
            for k in 1...run {
                let ci = i + k * di, cj = j + k * dj
                b[ci][cj] = 0
                result.append(Capture(position: ci * n + cj, color: opponent))
            }
        }
        return result
    }

    // MARK: - Self-capture "poof" (run = 2 poof, run = 3 keryo-poof)
    //
    // Ports detectPoof:atPosition: (run = 2) and detectKeryoPoof:atPosition:
    // (run = 3). The mover's own stones are removed ("poof") when a line of them,
    // including the just-placed stone, is flanked at BOTH ends by the opponent.
    // Poofed stones carry the mover's colour (Capture.color == color). The placed
    // stone is emitted first (the legacy code inserts it at the front of this
    // call's records), then the partner stones in detection order.
    static func poof(on board: [[Int]], at move: Int, color: Int, run: Int) -> [Capture] {
        var b = board
        let n = board.count
        let i = move / n, j = move % n
        let opponent = (color == 1) ? 2 : 1
        var directional: [Capture] = []
        var poofed = false

        if run == 2 {
            // A pair (placed stone + 1 partner) flanked at both ends.
            for (di, dj) in neighbours {
                let pi = i + di, pj = j + dj           // partner
                let fi = i + 2 * di, fj = j + 2 * dj   // far end, beyond the partner
                let oi = i - di, oj = j - dj           // opposite end, beyond the placed stone
                guard inBounds(fi, fj, n: n), inBounds(oi, oj, n: n) else { continue }
                if b[pi][pj] == color, b[fi][fj] == opponent, b[oi][oj] == opponent {
                    poofed = true
                    b[pi][pj] = 0
                    b[i][j] = 0
                    directional.append(Capture(position: pi * n + pj, color: color))
                }
            }
        } else {
            // run == 3 keryo-poof.
            // (a) Three mover stones starting at the placed stone, flanked both ends.
            for (di, dj) in neighbours {
                let p1i = i + di, p1j = j + dj           // near partner
                let p2i = i + 2 * di, p2j = j + 2 * dj   // far partner
                let fi = i + 3 * di, fj = j + 3 * dj      // far end
                let oi = i - di, oj = j - dj              // opposite end
                guard inBounds(fi, fj, n: n), inBounds(oi, oj, n: n) else { continue }
                if b[p1i][p1j] == color, b[p2i][p2j] == color,
                   b[fi][fj] == opponent, b[oi][oj] == opponent {
                    poofed = true
                    b[p2i][p2j] = 0
                    b[p1i][p1j] = 0
                    b[i][j] = 0
                    directional.append(Capture(position: p2i * n + p2j, color: color))
                    directional.append(Capture(position: p1i * n + p1j, color: color))
                }
            }
            // (b) Placed stone centred in three mover stones, flanked both ends.
            // BOTH partners (pa at +dir, pb at -dir) must be the mover's colour.
            // The bug fixed in 63986f7 checked one partner twice instead of both.
            let axes: [(Int, Int)] = [(1, 0), (1, 1), (0, 1), (1, -1)]
            for (di, dj) in axes {
                let pai = i + di, paj = j + dj            // partner +dir
                let pbi = i - di, pbj = j - dj            // partner -dir
                let eai = i + 2 * di, eaj = j + 2 * dj    // end +2dir
                let ebi = i - 2 * di, ebj = j - 2 * dj    // end -2dir
                guard inBounds(eai, eaj, n: n), inBounds(ebi, ebj, n: n) else { continue }
                if b[pai][paj] == color, b[pbi][pbj] == color,
                   b[eai][eaj] == opponent, b[ebi][ebj] == opponent {
                    poofed = true
                    b[pai][paj] = 0
                    b[pbi][pbj] = 0
                    b[i][j] = 0
                    directional.append(Capture(position: pai * n + paj, color: color))
                    directional.append(Capture(position: pbi * n + pbj, color: color))
                }
            }
        }

        guard poofed else { return [] }
        // Placed stone first, then the partner records in detection order.
        var result: [Capture] = [Capture(position: i * n + j, color: color)]
        result.append(contentsOf: directional)
        return result
    }

    // MARK: - Win line (length = 5 Pente, length = 6 Connect6)
    //
    // Ports detectPenteOf:atPosition:. Along each of the 4 axes, count starts at 1
    // (the placed stone) and accumulates over BOTH directions of that axis before
    // resetting for the next axis; a win is reported as soon as the run reaches
    // `length` (legacy `penteCounter > 4` generalised to `count > length - 1`).
    // Bounds are `>= 0` / `< 19`: an INTENTIONAL deviation from legacy detectPenteOf,
    // whose `> 0` low bound never scanned row 0 or column 0 and so missed 5-in-a-row
    // wins along the top edge / left edge. Indices are 0..18, so `>= 0 && < 19` is the
    // correct in-bounds range (like the existing Connect6 winLength correction).
    static func winLine(on board: [[Int]], at move: Int, color: Int, length: Int) -> Bool {
        let n = board.count
        let row = move / n, col = move % n
        let axes: [((Int, Int), (Int, Int))] = [
            ((-1, 0), (1, 0)),    // vertical
            ((0, -1), (0, 1)),    // horizontal
            ((-1, -1), (1, 1)),   // main diagonal
            ((-1, 1), (1, -1)),   // anti-diagonal
        ]
        for (d1, d2) in axes {
            var count = 1
            for (di, dj) in [d1, d2] {
                var i = row + di
                var j = col + dj
                while i >= 0, i < n, j >= 0, j < n {
                    if board[i][j] == color {
                        count += 1
                        if count > length - 1 { return true }
                    } else {
                        break
                    }
                    i += di
                    j += dj
                }
            }
        }
        return false
    }

    // MARK: - Boat-Pente "unbreakable five"
    //
    // Ports CAi::boatRunProof (Ai.cpp:2252). Boat-Pente treats a 5-in-a-row as a
    // WIN only if some >=5 run through the placed stone is "unbreakable": no stone
    // in that run can be undone by an opponent custodial capture. Boat is a
    // Pente-flavour variant (capture run = 2), so only the pair form is tested
    // (Keryo/O-Pente triple breaks do not apply). A run stone S is breakable when,
    // in some direction, S has an own-colour partner at S+k whose flanks S+2k and
    // S-k are one enemy and one empty — the opponent plays the empty flank to
    // custodially capture the (S, partner) pair. Empty is `<= 0` (covers 0 and the
    // -1 mask), matching the legacy oracle.
    //
    // These two functions mirror server BoatPenteState.isGameOver, which re-scans
    // the WHOLE board every call (not just the last move): `hasRun` answers "does
    // this colour hold any >=length run right now" (used for the current player's
    // promoted win, awarded with no capture check), and `boatHasUnbreakableRun`
    // answers "does this colour hold a >=length run with no pair-capturable stone"
    // (used for the mover's fresh win). See PenteGame.computeWinner for how the two
    // combine. Overlines count (server allowOverlines(true)).

    // The 4 axes as forward step directions; runs are enumerated from their start
    // cell (the one whose backward neighbour is not `color`) so each run is seen once.
    private static let axisSteps: [(Int, Int)] = [(0, 1), (1, 0), (1, 1), (1, -1)]

    /// True iff `color` holds any run of at least `length` (overlines included).
    static func hasRun(on board: [[Int]], color: Int, length: Int) -> Bool {
        let n = board.count
        for i in 0..<n {
            for j in 0..<n where board[i][j] == color {
                for (di, dj) in axisSteps {
                    let bi = i - di, bj = j - dj
                    if bi >= 0, bi < n, bj >= 0, bj < n, board[bi][bj] == color { continue }
                    var cnt = 0, x = i, y = j
                    while x >= 0, x < n, y >= 0, y < n, board[x][y] == color {
                        cnt += 1; x += di; y += dj
                    }
                    if cnt >= length { return true }
                }
            }
        }
        return false
    }

    /// True iff `color` holds a run of at least `length` in which no stone can be
    /// undone by an opponent custodial capture (the Boat-Pente "unbreakable five").
    ///
    /// `withTriples` selects the capture forms tested. Boat-Pente (capture run 2)
    /// passes false: only the pair form. O-Pente (capture run 3) passes true: the
    /// pair form PLUS the two triple forms (run stone at an end / in the middle of
    /// an own triple), mirroring VariantReferee.boatRowWinner(withTriples=true) and
    /// OPenteState. The default is false so Boat callers stay pair-only.
    static func boatHasUnbreakableRun(on board: [[Int]], color: Int, length: Int,
                                      withTriples: Bool = false) -> Bool {
        let n = board.count
        for i in 0..<n {
            for j in 0..<n where board[i][j] == color {
                for (di, dj) in axisSteps {
                    let bi = i - di, bj = j - dj
                    if bi >= 0, bi < n, bj >= 0, bj < n, board[bi][bj] == color { continue }
                    var run: [(Int, Int)] = []
                    var x = i, y = j
                    while x >= 0, x < n, y >= 0, y < n, board[x][y] == color {
                        run.append((x, y)); x += di; y += dj
                    }
                    if run.count >= length,
                       !runBreakable(on: board, run: run, color: color, n: n,
                                     withTriples: withTriples) {
                        return true
                    }
                }
            }
        }
        return false
    }

    /// A run is breakable if any stone in it can be undone by an opponent custodial
    /// capture. Two families are tested per run stone S, mirroring the already-shipped
    /// Android VariantReferee.boatRowWinner breakability passes verbatim:
    ///
    /// - PAIR (8 dirs, always): S has an own partner at S+dir whose flanks S+2dir and
    ///   S-dir are one enemy and one empty — the opponent plays the empty flank to
    ///   custodially capture the (S, partner) pair. Mirrors BoatPenteState.isGameOver.
    ///
    /// When `withTriples` (O-Pente, capture run 3) and no pair broke S, two run-3 forms:
    /// - TRIPLE END (8 dirs): own stones at S+dir & S+2dir; the flanks S-dir / S+3dir
    ///   are one enemy and one empty — opponent captures the triple {S, S+dir, S+2dir}.
    /// - TRIPLE MIDDLE (4 axes): own stones at S+dir & S-dir; the flanks S+2dir / S-2dir
    ///   are one enemy and one empty — opponent captures the triple {S-dir, S, S+dir}.
    ///
    /// Empty is `<= 0` (covers 0 and the -1 mask); off-board flanks fail the inBounds
    /// guard and so are neither enemy nor empty — matching the pair form's edge handling
    /// (and Android's `-2` off-board sentinel that is skipped).
    private static func runBreakable(on board: [[Int]], run: [(Int, Int)], color: Int,
                                     n: Int, withTriples: Bool) -> Bool {
        for (sx, sy) in run {
            // PAIR form (8 dirs).
            var pairBreak = false
            for (di, dj) in neighbours {
                let px = sx + di, py = sy + dj          // partner
                let fx = sx + 2 * di, fy = sy + 2 * dj  // far flank (beyond partner)
                let bx = sx - di, by = sy - dj          // near flank (behind S)
                guard inBounds(px, py, n: n), inBounds(fx, fy, n: n),
                      inBounds(bx, by, n: n) else { continue }
                guard board[px][py] == color else { continue }  // need an own partner
                let fv = board[fx][fy], bv = board[bx][by]
                let fEnemy = fv > 0 && fv != color, fEmpty = fv <= 0
                let bEnemy = bv > 0 && bv != color, bEmpty = bv <= 0
                if (fEnemy && bEmpty) || (fEmpty && bEnemy) { pairBreak = true; break }
            }
            if pairBreak { return true }
            guard withTriples else { continue }

            // TRIPLE END form (8 dirs): own at S+dir & S+2dir; flanks S-dir / S+3dir.
            var tripleBreak = false
            for (di, dj) in neighbours {
                let a1x = sx + di, a1y = sy + dj            // S+dir
                let a2x = sx + 2 * di, a2y = sy + 2 * dj    // S+2dir
                let a3x = sx + 3 * di, a3y = sy + 3 * dj    // S+3dir (outer flank)
                let a4x = sx - di, a4y = sy - dj            // S-dir  (inner flank)
                guard inBounds(a1x, a1y, n: n), inBounds(a2x, a2y, n: n),
                      inBounds(a3x, a3y, n: n), inBounds(a4x, a4y, n: n) else { continue }
                guard board[a1x][a1y] == color, board[a2x][a2y] == color else { continue }
                let ov = board[a3x][a3y], iv = board[a4x][a4y]
                let oEnemy = ov > 0 && ov != color, oEmpty = ov <= 0
                let iEnemy = iv > 0 && iv != color, iEmpty = iv <= 0
                if (iEnemy && oEmpty) || (iEmpty && oEnemy) { tripleBreak = true; break }
            }
            if tripleBreak { return true }

            // TRIPLE MIDDLE form (4 axes): own at S+dir & S-dir; flanks S+2dir / S-2dir.
            for (di, dj) in neighbours.prefix(4) {
                let a1x = sx + di, a1y = sy + dj            // S+dir
                let a2x = sx - di, a2y = sy - dj            // S-dir
                let a3x = sx - 2 * di, a3y = sy - 2 * dj    // S-2dir (flank)
                let a4x = sx + 2 * di, a4y = sy + 2 * dj    // S+2dir (flank)
                guard inBounds(a1x, a1y, n: n), inBounds(a2x, a2y, n: n),
                      inBounds(a3x, a3y, n: n), inBounds(a4x, a4y, n: n) else { continue }
                guard board[a1x][a1y] == color, board[a2x][a2y] == color else { continue }
                let pv = board[a4x][a4y], mv = board[a3x][a3y]
                let pEnemy = pv > 0 && pv != color, pEmpty = pv <= 0
                let mEnemy = mv > 0 && mv != color, mEmpty = mv <= 0
                if (pEnemy && mEmpty) || (pEmpty && mEnemy) { return true }
            }
        }
        return false
    }
}
