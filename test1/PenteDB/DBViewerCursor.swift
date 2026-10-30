import Foundation

extension DBStepPolicy {
    /// Stones one forward step adds from `index`. With Connect6 turn-stepping
    /// on, a step lands on the next turn boundary (0, 1, 3, 5, ...).
    static func stonesForward(game: Int, from index: Int) -> Int {
        guard connect6StepsPerTurn, DBGameCatalog.baseGame(game) == 13, index >= 1 else { return 1 }
        return index % 2 == 1 ? 2 : 1
    }
}

/// Position inside a finished game's move list (the game viewer).
struct DBViewerCursor {
    let moves: [Int]
    let game: Int
    private(set) var index: Int

    init(moves: [Int], game: Int) {
        self.moves = moves
        self.game = game
        index = moves.count
    }

    var visibleMoves: [Int] { Array(moves.prefix(index)) }

    @discardableResult
    mutating func forward() -> Bool {
        let room = moves.count - index
        guard room > 0 else { return false }
        index += min(DBStepPolicy.stonesForward(game: game, from: index), room)
        return true
    }

    @discardableResult
    mutating func back() -> Bool {
        guard index > 0 else { return false }
        index -= min(DBStepPolicy.stonesPerStep(game: game, count: index), index)
        return true
    }

    mutating func jump(to target: Int) {
        index = min(max(target, 0), moves.count)
    }
}
