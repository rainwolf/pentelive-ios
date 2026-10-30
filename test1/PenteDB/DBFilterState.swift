import Foundation

/// User-editable filter state for the PenteDB screen (draft or applied).
struct DBFilterState: Codable, Equatable {
    var baseGame: Int = 1
    var speed = false
    var player1 = ""
    var player2 = ""
    var p1MinRating = 0
    var p2MinRating = 0
    var eitherSeat = false
    var excludeTimeouts = false
    var winner = 0
    static let liveOrTBAll = "all"
    static let liveOrTBLive = "live"
    static let liveOrTBTurnBased = "turnBased"
    var liveOrTurnBased = DBFilterState.liveOrTBAll
    var after: Date?
    var before: Date?
    var scope = "archive"

    /// Game id sent to the server: speed variant when the base has one.
    var gameId: Int {
        if speed && DBGameCatalog.supportsSpeed(base: baseGame) {
            return DBGameCatalog.speedVariant(ofBase: baseGame)
        }
        return baseGame
    }

    /// Ignores unsupported ids.
    mutating func setGame(id: Int) {
        guard DBGameCatalog.isSupported(id) else { return }
        baseGame = DBGameCatalog.baseGame(id)
        speed = DBGameCatalog.isSpeed(id)
    }

    /// Default with no server features: hidden extended values never count.
    var isDefault: Bool { isDefault(features: .none) }

    /// Extended values count only when `/ping` advertises their feature;
    /// a migrated legacy value is kept while hidden but never sent.
    func isDefault(features: DBServerFeatures) -> Bool {
        var d = DBFilterState()
        d.baseGame = baseGame
        d.speed = speed
        d.scope = scope
        if !hasPlayerFilter { d.eitherSeat = eitherSeat }
        if !features.excludeTimeouts { d.excludeTimeouts = excludeTimeouts }
        if !features.liveOrTurnBased { d.liveOrTurnBased = liveOrTurnBased }
        return self == d
    }

    private var hasPlayerFilter: Bool {
        Self.trimmed(player1) != nil || Self.trimmed(player2) != nil
            || p1MinRating > 0 || p2MinRating > 0
    }

    private static func trimmed(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }

    private static func dateString(_ d: Date, timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    func toWire(features: DBServerFeatures = .none, timeZone: TimeZone = .current) -> DBFilters? {
        var f = DBFilters()
        f.player1Name = Self.trimmed(player1)
        f.player2Name = Self.trimmed(player2)
        f.player1RatingAbove = max(0, p1MinRating)
        f.player2RatingAbove = max(0, p2MinRating)
        f.winner = winner
        f.afterDate = after.map { Self.dateString($0, timeZone: timeZone) }
        f.beforeDate = before.map { Self.dateString($0, timeZone: timeZone) }
        f.features = features
        if features.excludeTimeouts { f.excludeTimeouts = excludeTimeouts }
        if features.liveOrTurnBased { f.liveOrTurnBased = liveOrTurnBased }
        if eitherSeat && hasPlayerFilter {
            f.player1Seat = 0
            f.player2Seat = 0
        }
        return isDefault(features: features) ? nil : f
    }

    func chipSummary(features: DBServerFeatures = .none) -> String {
        var parts = [DBGameCatalog.name(forGame: gameId)]
        func player(_ name: String, _ rating: Int, _ label: String) {
            let n = Self.trimmed(name)
            let r = max(0, rating)
            if let n = n {
                parts.append(r > 0 ? "\(n) \(r)+" : n)
            } else if r > 0 {
                parts.append("\(label) \(r)+")
            }
        }
        player(player1, p1MinRating, "P1")
        player(player2, p2MinRating, "P2")
        if eitherSeat && hasPlayerFilter { parts.append("either seat") }
        if winner == 1 { parts.append("P1 wins") }
        if winner == 2 { parts.append("P2 wins") }
        if let a = after { parts.append("after " + Self.dateString(a, timeZone: .current)) }
        if let b = before { parts.append("before " + Self.dateString(b, timeZone: .current)) }
        if scope == "mine" { parts.append("Mine") }
        if scope == "both" { parts.append("Both") }
        if features.excludeTimeouts, excludeTimeouts { parts.append("no timeouts") }
        if features.liveOrTurnBased {
            if liveOrTurnBased == Self.liveOrTBLive { parts.append("live only") }
            if liveOrTurnBased == Self.liveOrTBTurnBased { parts.append("turn-based only") }
        }
        return parts.joined(separator: " · ")
    }
}

/// Persists `DBFilterState` as JSON; migrates the legacy NSUserDefaults keys
/// on first load.
struct DBFilterStore {
    static let key = "DBFiltersV1"
    static let ratingChoices: [Int] = [0] + Array(stride(from: 1000, through: 2700, by: 100))

    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    func load() -> DBFilterState {
        if let data = defaults.data(forKey: Self.key),
           let s = try? JSONDecoder().decode(DBFilterState.self, from: data) {
            return s
        }
        let s = migrateLegacy()
        save(s)
        return s
    }

    func save(_ state: DBFilterState) {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.key)
        }
    }

    private func migrateLegacy() -> DBFilterState {
        var s = DBFilterState()
        if let name = defaults.string(forKey: "DBGame") {
            s.setGame(id: DBGameCatalog.gameId(forName: name))
        }
        s.p1MinRating = Int(defaults.string(forKey: "DBP1Rating") ?? "") ?? 0
        s.p2MinRating = Int(defaults.string(forKey: "DBP2Rating") ?? "") ?? 0
        if let v = defaults.string(forKey: "DBBothOrEither") { s.eitherSeat = v != "both" }
        if let v = defaults.string(forKey: "DBExcludeTimeouts") { s.excludeTimeouts = v != "no" }
        if let v = defaults.string(forKey: "DBLiveOrTB"), !v.isEmpty {
            // Legacy stored the Type cell's display text, not the wire value.
            switch v {
            case "live only": s.liveOrTurnBased = DBFilterState.liveOrTBLive
            case "turn-based only": s.liveOrTurnBased = DBFilterState.liveOrTBTurnBased
            default: s.liveOrTurnBased = DBFilterState.liveOrTBAll
            }
        }
        return s
    }
}
