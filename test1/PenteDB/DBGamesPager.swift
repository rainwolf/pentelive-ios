import Foundation

/// Accumulated pages of a games search (spec §4.0 paging).
struct DBGamesPager {
    static let pageSize = 25

    private(set) var games: [DBGameHeader] = []
    private(set) var total: Int = 0

    var nextOffset: Int { games.count }
    var hasMore: Bool { games.count < total }

    mutating func reset() {
        games = []
        total = 0
    }

    /// Offset 0 replaces the list. Any other page appends only when it
    /// continues exactly where the list ends; a mismatched page is dropped.
    mutating func apply(_ r: DBGameSearchResult, offset: Int) {
        if offset == 0 {
            games = r.games
        } else if offset == games.count {
            games += r.games
        } else {
            return
        }
        total = r.total
    }
}
