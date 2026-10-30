import Foundation

struct DBReplayResult: Equatable {
    var whiteCaptures: Int
    var blackCaptures: Int
    /// Go: the cell the side to move may not retake (ko), else -1.
    var koCell: Int
}

/// "Moves -> board" for every DB game. Go goes through GoGame (groups,
/// liberties, ko, dead stones after a double pass), Renju places black-first
/// stones without captures, every other game uses LegacyPenteGame.
///
/// The buffer is always 19x19 with row stride 19 (AbstractBoard); a smaller
/// board uses its top-left grid x grid corner, cell = y*grid + x. Values:
/// 1 white, 2 black, -1 ko (blocked: never drawn, never tappable).
@objc final class DBBoardReplayer: NSObject {
    static let stride = 19

    /// Clears all 361 values, then replays the first `until` moves. A pass
    /// (grid²) keeps the colour parity but is never placed; junk (< 0,
    /// > grid²) is dropped.
    @discardableResult
    static func replay(game: Int, moves: [Int], until: Int,
                       into cells: UnsafeMutablePointer<Int32>) -> DBReplayResult {
        for k in 0 ..< stride * stride { cells[k] = 0 }
        let grid = DBGameCatalog.gridSize(forGame: game)
        let pass = grid * grid
        let played = Array(moves.prefix(max(0, until)))
        if DBGameCatalog.isGo(game) {
            let go = GoGame(gridSize: grid)
            let valid = played.filter { $0 >= 0 && $0 <= pass }
            for m in valid { go.play(m) }
            for r in 0 ..< grid {
                for c in 0 ..< grid {
                    let v = go.stone(at: r * grid + c)
                    cells[r * stride + c] = (v == 1 || v == 2) ? Int32(v) : 0
                }
            }
            // A pass (or the stone-marking phase) lifts the ko.
            var ko = -1
            if go.phase == .play, let last = valid.last, last != pass,
               go.koMove >= 0, go.koMove < pass,
               cells[(go.koMove / grid) * stride + go.koMove % grid] == 0 {
                ko = go.koMove
                cells[(ko / grid) * stride + ko % grid] = -1
            }
            return DBReplayResult(whiteCaptures: go.whiteCaptures,
                                  blackCaptures: go.blackCaptures, koCell: ko)
        }
        if DBGameCatalog.isRenju(game) {
            var i = 0
            for m in played where m >= 0 && m <= pass {
                if m < pass {
                    cells[(m / grid) * stride + m % grid] = i % 2 == 0 ? 2 : 1
                }
                i += 1
            }
            return DBReplayResult(whiteCaptures: 0, blackCaptures: 0, koCell: -1)
        }
        // Pente family: 19x19; the pass sentinel and junk never reach the engine.
        let clean = played.filter { $0 >= 0 && $0 < pass }
        let g = LegacyPenteGame()
        g.abstractBoard = UnsafeMutableRawPointer(cells).assumingMemoryBound(to: AbstractBoard.self)
        let variant = PenteGameVariant(rawValue: DBGameCatalog.variant(forGame: game).rawValue) ?? .pente
        g.replayMoves(clean.map { NSNumber(value: $0) }, variant: variant, untilMove: clean.count)
        let result = DBReplayResult(whiteCaptures: Int(g.whiteCaptures),
                                    blackCaptures: Int(g.blackCaptures), koCell: -1)
        g.abstractBoard = nil
        return result
    }

    /// Objective-C entry (DatabaseViewController): `cells` is
    /// `&abstractBoard[0][0]`.
    @objc static func replay(game: Int, moves: [NSNumber], until: Int,
                             into cells: UnsafeMutablePointer<Int32>,
                             whiteCaptures: UnsafeMutablePointer<Int32>,
                             blackCaptures: UnsafeMutablePointer<Int32>) {
        let r = replay(game: game, moves: moves.map { $0.intValue }, until: until, into: cells)
        whiteCaptures.pointee = Int32(r.whiteCaptures)
        blackCaptures.pointee = Int32(r.blackCaptures)
    }
}
