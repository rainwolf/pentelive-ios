//
//  Scan.swift
//  penteLive  (PenteEngine)
//
//  Pure directional rule primitives ported verbatim from the legacy
//  Objective-C engine (test1/PenteGame.m). No state, no board mutation:
//  every function takes a plain [[Int]] (board[row][col]) by value and
//  returns its result. Coordinates use rowCol = row * 19 + col.
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

    private static func inBounds(_ i: Int, _ j: Int) -> Bool {
        i >= 0 && i < 19 && j >= 0 && j < 19
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
        let i = move / 19, j = move % 19
        let opponent = (color == 1) ? 2 : 1
        let far = run + 1
        var result: [Capture] = []
        for (di, dj) in neighbours {
            let fi = i + far * di, fj = j + far * dj
            guard inBounds(fi, fj), b[fi][fj] == color else { continue }
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
                result.append(Capture(position: ci * 19 + cj, color: opponent))
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
        let i = move / 19, j = move % 19
        let opponent = (color == 1) ? 2 : 1
        var directional: [Capture] = []
        var poofed = false

        if run == 2 {
            // A pair (placed stone + 1 partner) flanked at both ends.
            for (di, dj) in neighbours {
                let pi = i + di, pj = j + dj           // partner
                let fi = i + 2 * di, fj = j + 2 * dj   // far end, beyond the partner
                let oi = i - di, oj = j - dj           // opposite end, beyond the placed stone
                guard inBounds(fi, fj), inBounds(oi, oj) else { continue }
                if b[pi][pj] == color, b[fi][fj] == opponent, b[oi][oj] == opponent {
                    poofed = true
                    b[pi][pj] = 0
                    b[i][j] = 0
                    directional.append(Capture(position: pi * 19 + pj, color: color))
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
                guard inBounds(fi, fj), inBounds(oi, oj) else { continue }
                if b[p1i][p1j] == color, b[p2i][p2j] == color,
                   b[fi][fj] == opponent, b[oi][oj] == opponent {
                    poofed = true
                    b[p2i][p2j] = 0
                    b[p1i][p1j] = 0
                    b[i][j] = 0
                    directional.append(Capture(position: p2i * 19 + p2j, color: color))
                    directional.append(Capture(position: p1i * 19 + p1j, color: color))
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
                guard inBounds(eai, eaj), inBounds(ebi, ebj) else { continue }
                if b[pai][paj] == color, b[pbi][pbj] == color,
                   b[eai][eaj] == opponent, b[ebi][ebj] == opponent {
                    poofed = true
                    b[pai][paj] = 0
                    b[pbi][pbj] = 0
                    b[i][j] = 0
                    directional.append(Capture(position: pai * 19 + paj, color: color))
                    directional.append(Capture(position: pbi * 19 + pbj, color: color))
                }
            }
        }

        guard poofed else { return [] }
        // Placed stone first, then the partner records in detection order.
        var result: [Capture] = [Capture(position: i * 19 + j, color: color)]
        result.append(contentsOf: directional)
        return result
    }

    // MARK: - Win line (length = 5 Pente, length = 6 Connect6)
    //
    // Ports detectPenteOf:atPosition:. Along each of the 4 axes, count starts at 1
    // (the placed stone) and accumulates over BOTH directions of that axis before
    // resetting for the next axis; a win is reported as soon as the run reaches
    // `length` (legacy `penteCounter > 4` generalised to `count > length - 1`).
    // The strict bounds `> 0` / `< 19` are preserved verbatim from the legacy code,
    // which intentionally never scans into row 0 or column 0.
    static func winLine(on board: [[Int]], at move: Int, color: Int, length: Int) -> Bool {
        let row = move / 19, col = move % 19
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
                while i > 0, i < 19, j > 0, j < 19 {
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
}
