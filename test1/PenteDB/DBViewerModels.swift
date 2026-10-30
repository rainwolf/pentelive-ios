import UIKit

struct DBViewerHeader {
    var p1Name: NSAttributedString
    var p1Rating: NSAttributedString
    var score: String
    var captures: NSAttributedString
    var date: String
    var p2Name: NSAttributedString
    var p2Rating: NSAttributedString

    static func make(header: DBGameHeader, moves: [Int], cursor: DBViewerCursor, now: Date) -> DBViewerHeader {
        let nameFont = UIFont.systemFont(ofSize: 15, weight: .semibold)
        let ratingFont = UIFont.systemFont(ofSize: 13)
        let capFont = UIFont.systemFont(ofSize: 13)
        let summary = DBCaptureReplay.summary(game: header.game, moves: Array(moves.prefix(cursor.index)))
        let captures = summary.showsIcons
            ? DBSubtitleFormatter.captureIcons(summary, font: capFont)
            : NSAttributedString(string: "")
        return DBViewerHeader(
            p1Name: DBRatingStyle.nameString(header.player1, font: nameFont, alignRight: false),
            p1Rating: DBRatingStyle.ratingString(header.player1, font: ratingFont),
            score: DBGameRowFormatter.score(winner: header.winner),
            captures: captures,
            date: DBGameRowFormatter.date(iso: header.playDate, now: now),
            p2Name: DBRatingStyle.nameString(header.player2, font: nameFont, alignRight: true),
            p2Rating: DBRatingStyle.ratingString(header.player2, font: ratingFont))
    }
}

enum DBMoveCellState: Equatable { case past, current, future }

struct DBMoveCell: Equatable {
    var index: Int
    var number: String?
    var label: String
    var state: DBMoveCellState

    static let futureHex: UInt32 = 0x8A8F99

    /// Numbering mirrors DatabaseViewController's move list: pairs per turn;
    /// Connect6 numbers move 0, then every 4th move from index 3.
    static func grid(moves: [Int], game: Int, cursorIndex: Int) -> [DBMoveCell] {
        let size = DBGameCatalog.gridSize(forGame: game)
        let isC6 = DBGameCatalog.baseGame(game) == 13
        return moves.enumerated().map { i, m in
            var number: String?
            if isC6 {
                if i == 0 { number = "1" } else if (i - 3) % 4 == 0 && i >= 3 { number = "\((i >> 2) + 2)" }
            } else if i % 2 == 0 {
                number = "\((i >> 1) + 1)"
            }
            let state: DBMoveCellState = i >= cursorIndex ? .future : (i == cursorIndex - 1 ? .current : .past)
            return DBMoveCell(index: i, number: number, label: DBMoveRanking.label(cell: m, gridSize: size), state: state)
        }
    }
}
