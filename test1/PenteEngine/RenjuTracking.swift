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
