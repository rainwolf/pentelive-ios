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
}
