import Foundation

/// Device-local DB screen preferences.
@objc final class DBPreferences: NSObject {
    @objc static let shared = DBPreferences(defaults: .standard)

    let defaults: UserDefaults
    private static let heatKey = "DBHeatOnBoard"
    private static let shownKey = "DBMovesShown"

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
}
