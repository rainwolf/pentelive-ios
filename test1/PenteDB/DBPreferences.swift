import Foundation

/// How the Moves list (and the board heat) is ordered; react_pentedb's
/// `explorerSort` ('winrate' | 'games').
enum DBMoveSort: String {
    case winRate = "winrate"
    case games
}

/// Device-local DB screen preferences.
@objc final class DBPreferences: NSObject {
    @objc static let shared = DBPreferences(defaults: .standard)

    let defaults: UserDefaults
    private static let heatKey = "DBHeatOnBoard"
    private static let shownKey = "DBMovesShown"
    private static let sortKey = "DBMoveSort"

    init(defaults: UserDefaults) {
        self.defaults = defaults
        super.init()
    }

    @objc var heatOnBoard: Bool {
        get { defaults.object(forKey: DBPreferences.heatKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: DBPreferences.heatKey) }
    }

    /// Number of moves shown; 0 means all.
    @objc var movesShown: Int {
        get { defaults.object(forKey: DBPreferences.shownKey) as? Int ?? 20 }
        set { defaults.set(newValue, forKey: DBPreferences.shownKey) }
    }

    /// Moves ordering; an unknown stored value reads as the win-rate default.
    var moveSort: DBMoveSort {
        get { defaults.string(forKey: DBPreferences.sortKey).flatMap(DBMoveSort.init(rawValue:)) ?? .winRate }
        set { defaults.set(newValue.rawValue, forKey: DBPreferences.sortKey) }
    }
}
