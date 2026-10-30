import UIKit

struct DBCaptureSummary: Equatable {
    var whiteStonesCaptured: Int
    var blackStonesCaptured: Int
    var showsIcons: Bool
}

enum DBCaptureReplay {
    static func summary(game: Int, moves: [Int]) -> DBCaptureSummary {
        guard DBGameCatalog.hasCaptures(game: game), !moves.isEmpty else {
            return DBCaptureSummary(whiteStonesCaptured: 0, blackStonesCaptured: 0,
                                    showsIcons: DBGameCatalog.hasCaptures(game: game))
        }
        // Pass sentinel (gridSize^2) and junk must never be written into the board.
        let cells = DBGameCatalog.gridSize(forGame: game)
        let moves = moves.filter { $0 >= 0 && $0 < cells * cells }
        let board = UnsafeMutablePointer<AbstractBoard>.allocate(capacity: 19)
        defer { board.deallocate() }
        board.initialize(repeating: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), count: 19)
        let g = LegacyPenteGame()
        g.abstractBoard = board
        let variant = PenteGameVariant(rawValue: DBGameCatalog.variant(forGame: game).rawValue) ?? .pente
        g.replayMoves(moves.map { NSNumber(value: $0) }, variant: variant, untilMove: moves.count)
        let result = DBCaptureSummary(whiteStonesCaptured: Int(g.whiteCaptures),
                                      blackStonesCaptured: Int(g.blackCaptures), showsIcons: true)
        g.abstractBoard = nil
        return result
    }
}

@objc final class DBSubtitleFormatter: NSObject {
    @objc static func attributedSubtitle(game: Int, moves: [NSNumber], font: UIFont) -> NSAttributedString {
        let name = DBGameCatalog.name(forGame: game)
        let s = DBCaptureReplay.summary(game: game, moves: moves.map { $0.intValue })
        let out = NSMutableAttributedString(string: name, attributes: [.font: font])
        guard s.showsIcons else { return out }
        let ink = UIColor(dbHex: 0x16181D)
        out.append(NSAttributedString(string: "  ", attributes: [.font: font]))
        out.append(NSAttributedString(string: "●", attributes: [
            .font: font, .foregroundColor: UIColor.white,
            .strokeColor: ink, .strokeWidth: -2 as NSNumber]))
        out.append(NSAttributedString(string: " × \(s.whiteStonesCaptured)  ", attributes: [.font: font]))
        out.append(NSAttributedString(string: "●", attributes: [.font: font, .foregroundColor: ink]))
        out.append(NSAttributedString(string: " × \(s.blackStonesCaptured)", attributes: [.font: font]))
        return out
    }
}
