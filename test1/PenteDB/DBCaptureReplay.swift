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
        // DBBoardReplayer keeps pass sentinels (grid²) out of the board and
        // replays Go with Go rules.
        var cells = [Int32](repeating: 0, count: 361)
        let r = cells.withUnsafeMutableBufferPointer {
            DBBoardReplayer.replay(game: game, moves: moves, until: moves.count, into: $0.baseAddress!)
        }
        return DBCaptureSummary(whiteStonesCaptured: r.whiteCaptures,
                                blackStonesCaptured: r.blackCaptures, showsIcons: true)
    }
}

@objc final class DBSubtitleFormatter: NSObject {
    @objc static func attributedSubtitle(game: Int, moves: [NSNumber], font: UIFont) -> NSAttributedString {
        let name = DBGameCatalog.name(forGame: game)
        let s = DBCaptureReplay.summary(game: game, moves: moves.map { $0.intValue })
        let out = NSMutableAttributedString(string: name, attributes: [.font: font])
        guard s.showsIcons else { return out }
        out.append(NSAttributedString(string: "  ", attributes: [.font: font]))
        out.append(captureIcons(s, font: font))
        return out
    }

    /// Capture icons only (no game name), shared with the viewer header.
    static func captureIcons(_ s: DBCaptureSummary, font: UIFont) -> NSAttributedString {
        let out = NSMutableAttributedString()
        let ink = UIColor(dbHex: 0x16181D)
        out.append(NSAttributedString(string: "●", attributes: [
            .font: font, .foregroundColor: UIColor.white,
            .strokeColor: ink, .strokeWidth: -2 as NSNumber]))
        out.append(NSAttributedString(string: " × \(s.whiteStonesCaptured)  ", attributes: [.font: font]))
        out.append(NSAttributedString(string: "●", attributes: [.font: font, .foregroundColor: ink]))
        out.append(NSAttributedString(string: " × \(s.blackStonesCaptured)", attributes: [.font: font]))
        return out
    }
}
