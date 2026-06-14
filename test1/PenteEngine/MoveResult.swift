import Foundation

/// Result of a single `PenteGame.play(_:)`. Drives capture animation in both UIs.
@objc final class MoveResult: NSObject {
    /// Stones removed by this move (captures and/or poofs), in detection order.
    /// Each `Capture.color` is the colour of the *removed* stone.
    @objc let captured: [Capture]
    /// True when this move triggered at least one poof (self-capture).
    @objc let poofed: Bool
    /// 0 = no winner, 1 = white wins, 2 = black wins.
    @objc let winner: Int
    /// Colour just played (1 white, 2 black). 0 only for an empty replay.
    @objc let placed: Int

    @objc init(captured: [Capture], poofed: Bool, winner: Int, placed: Int) {
        self.captured = captured
        self.poofed = poofed
        self.winner = winner
        self.placed = placed
        super.init()
    }
}
