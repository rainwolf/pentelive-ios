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
