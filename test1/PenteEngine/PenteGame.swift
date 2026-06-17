import Foundation

/// Stateful game engine. Owns the board, capture counters, move index, and opening
/// mask. Drives the pure `Scan` primitives via the variant's `RuleSet` recipe.
/// `@objc`-exposed so ObjC callers reach it through the generated `penteLive-Swift.h`.
@objc(SwiftPenteGame) final class PenteGame: NSObject {
    private let rules: RuleSet
    private var board: [[Int]]
    private var moveCount: Int = 0
    @objc private(set) var whiteCaptures: Int = 0
    @objc private(set) var blackCaptures: Int = 0

    /// Board edge length from the active recipe (15 for Renju, else 19).
    private var boardSize: Int { rules.boardSize }

    @objc init(variant: PenteVariant) {
        let recipe = ruleSet(for: variant)
        self.rules = recipe
        self.board = Array(repeating: Array(repeating: 0, count: recipe.boardSize),
                           count: recipe.boardSize)
        super.init()
    }

    @objc func reset() {
        board = Array(repeating: Array(repeating: 0, count: boardSize), count: boardSize)
        moveCount = 0
        whiteCaptures = 0
        blackCaptures = 0
    }

    /// Read-only accessor for renderers. Returns 0 empty, 1 white, 2 black, -1 masked.
    @objc func stone(at rowCol: Int) -> Int {
        // @objc callers may pass an out-of-range index; treat it as empty rather
        // than trapping on the array access.
        let cells = boardSize * boardSize
        guard rowCol >= 0 && rowCol < cells else { return 0 }
        return board[rowCol / boardSize][rowCol % boardSize]
    }

    @objc func play(_ move: Int) -> MoveResult {
        // @objc callers may pass an out-of-range index; treat it as a no-op rather
        // than trapping on the array access.
        let cells = boardSize * boardSize
        guard move >= 0 && move < cells else {
            return MoveResult(captured: [], poofed: false, winner: 0, placed: 0)
        }
        let placedColor = colorForMove(moveCount)

        // Masks are a render-only overlay; clear any before placing so scans never
        // see -1 (legacy replayMoves operated on a mask-free board).
        clearOpeningMask()
        board[move / boardSize][move % boardSize] = placedColor

        var captured: [Capture] = []
        var poofed = false

        // Poofs first (ascending run), matching legacy PoofPente/OPente order.
        if rules.poof != .none {
            let poofRuns = (rules.poof == .keryo) ? [2, 3] : [2]
            for run in poofRuns {
                let removed = Scan.poof(on: board, at: move, color: placedColor, run: run)
                apply(removed)
                captured.append(contentsOf: removed)
                if !removed.isEmpty { poofed = true }
            }
        }

        // Captures: run 2 up to capture.run (Keryo/OPente also run 3).
        if let cap = rules.capture {
            var run = 2
            while run <= cap.run {
                let removed = Scan.captures(on: board, at: move, color: placedColor, run: run)
                apply(removed)
                captured.append(contentsOf: removed)
                run += 1
            }
        }

        moveCount += 1
        let winner = computeWinner(lastMove: move, color: placedColor)
        applyOpeningMask()  // overlay applied last, on the snapshot returned to renderers
        return MoveResult(captured: captured, poofed: poofed, winner: winner, placed: placedColor)
    }

    @objc func replay(_ moves: [Int], until: Int) -> MoveResult {
        reset()
        var last = MoveResult(captured: [], poofed: false, winner: 0, placed: 0)
        // `until` is an @objc entry point; callers (move sliders, move counts) may
        // pass values outside 0...moves.count. Clamp so we only replay valid moves.
        let bound = max(0, min(until, moves.count))
        var i = 0
        while i < bound {
            last = play(moves[i])
            i += 1
        }
        return last
    }

    // MARK: - Internals

    private func colorForMove(_ index: Int) -> Int {
        switch rules.cadence {
        case .alternating:
            return (index % 2) + 1
        case .connect6:
            return (((index % 4) == 0) || ((index % 4) == 3)) ? 1 : 2
        case .blackFirst:
            return 2 - (index % 2)   // move 0 -> 2 (black), move 1 -> 1 (white)
        }
    }

    /// Remove each captured/poofed stone and bump that colour's loss counter by one.
    private func apply(_ removed: [Capture]) {
        for cap in removed {
            board[cap.position / boardSize][cap.position % boardSize] = 0
            if cap.color == 1 { whiteCaptures += 1 } else { blackCaptures += 1 }
        }
    }

    private func computeWinner(lastMove: Int, color: Int) -> Int {
        if Scan.winLine(on: board, at: lastMove, color: color, length: rules.winLength) {
            return color
        }
        if let cap = rules.capture {
            // `>=` for BOTH families. In OPente/PoofPente a single move can remove
            // poof + capture stones together, so the counter may JUMP past the
            // threshold (e.g. 8 -> 12) and an `== threshold` test would miss the win.
            // Colour mapping preserved: whiteCaptures (white stones lost) -> black (2)
            // wins; blackCaptures -> white (1) wins.
            if whiteCaptures >= cap.threshold { return 2 }
            if blackCaptures >= cap.threshold { return 1 }
        }
        return 0
    }

    private func applyOpeningMask() {
        guard moveCount == 2 else { return }
        switch rules.opening {
        case .tournament: maskTournamentOpening()
        case .gpente:     maskGPenteOpening()
        case .none, .swap2: break
        }
    }

    private func clearOpeningMask() {
        guard rules.opening == .tournament || rules.opening == .gpente else { return }
        for r in 0..<19 {
            for c in 0..<19 where board[r][c] == -1 {
                board[r][c] = 0
            }
        }
    }

    private func maskTournamentOpening() {
        for i in 7..<12 {
            for j in 7..<12 where board[i][j] == 0 {
                board[i][j] = -1
            }
        }
    }

    private func maskGPenteOpening() {
        maskTournamentOpening()
        for i in 1..<3 {
            if board[9][11 + i] == 0 { board[9][11 + i] = -1 }
            if board[9][7 - i] == 0 { board[9][7 - i] = -1 }
            if board[11 + i][9] == 0 { board[11 + i][9] = -1 }
            if board[7 - i][9] == 0 { board[7 - i][9] = -1 }
        }
    }
}
