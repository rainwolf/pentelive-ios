import Foundation

/// How many stones one back/forward step moves.
enum DBStepPolicy {
    /// Connect6 turn-steps. Off: Connect6 steps one stone at a time.
    static var connect6StepsPerTurn = false

    static func stonesPerStep(game: Int, count: Int) -> Int {
        guard connect6StepsPerTurn,
              DBGameCatalog.baseGame(game) == 13,
              count >= 2 else { return 1 }
        return (count - 1) % 2 == 0 ? 2 : 1
    }

    /// D-Pente, DK-Pente, Swap2-* and Go (empty start) may start off-centre;
    /// others, Renju included, keep the fixed centre stone.
    static func minimumCount(game: Int) -> Int {
        switch DBGameCatalog.baseGame(game) {
        case 7, 17, 19, 21, 23, 27, 29: return 0
        default: return 1
        }
    }
}

/// The board line shown on the PenteDB screen, with a redo stack.
@objc final class DBLine: NSObject {
    @objc var game: Int
    @objc private(set) var moves: [NSNumber]
    private var redo: [[NSNumber]] = []

    @objc init(game: Int, moves: [NSNumber]) {
        self.game = game
        self.moves = moves
        super.init()
    }

    var cells: [Int] { moves.map { $0.intValue } }

    @objc var redoCount: Int { redo.reduce(0) { $0 + $1.count } }

    @objc func play(_ cell: Int) {
        moves.append(NSNumber(value: cell))
        redo.removeAll()
    }

    @objc func back() -> Bool {
        let room = moves.count - DBStepPolicy.minimumCount(game: game)
        guard room > 0 else { return false }
        let n = min(DBStepPolicy.stonesPerStep(game: game, count: moves.count), room)
        redo.append(Array(moves.suffix(n)))
        moves.removeLast(n)
        return true
    }

    @objc func forward() -> Bool {
        guard let group = redo.popLast() else { return false }
        moves.append(contentsOf: group)
        return true
    }

    @objc func reset(moves: [NSNumber]) {
        self.moves = moves
        redo.removeAll()
    }
}
