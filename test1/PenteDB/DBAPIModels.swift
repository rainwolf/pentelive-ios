import Foundation

// MARK: - Filters

/// Server capability flags from `/ping` `features` (spec §4.1). Each one
/// gates its own filter control and wire key; missing means off.
struct DBServerFeatures: Equatable {
    var excludeTimeouts = false
    var liveOrTurnBased = false

    static let none = DBServerFeatures()

    init(excludeTimeouts: Bool = false, liveOrTurnBased: Bool = false) {
        self.excludeTimeouts = excludeTimeouts
        self.liveOrTurnBased = liveOrTurnBased
    }

    init(features: [String]) {
        excludeTimeouts = features.contains("excludeTimeouts")
        liveOrTurnBased = features.contains("liveOrTurnBased")
    }
}

/// Wire filters for /api/db. String keys are always encoded (null when unset),
/// int and bool keys always present. `excludeTimeouts` / `liveOrTurnBased` are
/// each written only when the server advertises that feature (`features`).
struct DBFilters: Encodable, Equatable {
    var player1Name: String?
    var player2Name: String?
    var site: String?
    var event: String?
    var round: String?
    var section: String?
    var afterDate: String?
    var beforeDate: String?
    var player1Seat: Int = 1
    var player2Seat: Int = 2
    var winner: Int = 0
    var player1RatingAbove: Int = 0
    var player2RatingAbove: Int = 0
    var excludeTimeouts: Bool = false
    var liveOrTurnBased: String = "all"
    /// Not encoded; what /ping advertised when the request was built.
    var features = DBServerFeatures.none

    private enum CodingKeys: String, CodingKey {
        case player1Name, player2Name, site, event, round, section, afterDate, beforeDate
        case player1Seat, player2Seat, winner, player1RatingAbove, player2RatingAbove
        case excludeTimeouts, liveOrTurnBased
    }

    var isDefault: Bool {
        var d = DBFilters()
        d.features = features
        if !features.excludeTimeouts { d.excludeTimeouts = excludeTimeouts }
        if !features.liveOrTurnBased { d.liveOrTurnBased = liveOrTurnBased }
        return self == d
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(player1Name, forKey: .player1Name)
        try c.encode(player2Name, forKey: .player2Name)
        try c.encode(site, forKey: .site)
        try c.encode(event, forKey: .event)
        try c.encode(round, forKey: .round)
        try c.encode(section, forKey: .section)
        try c.encode(afterDate, forKey: .afterDate)
        try c.encode(beforeDate, forKey: .beforeDate)
        try c.encode(player1Seat, forKey: .player1Seat)
        try c.encode(player2Seat, forKey: .player2Seat)
        try c.encode(winner, forKey: .winner)
        try c.encode(player1RatingAbove, forKey: .player1RatingAbove)
        try c.encode(player2RatingAbove, forKey: .player2RatingAbove)
        if features.excludeTimeouts {
            try c.encode(excludeTimeouts, forKey: .excludeTimeouts)
        }
        if features.liveOrTurnBased {
            try c.encode(liveOrTurnBased, forKey: .liveOrTurnBased)
        }
    }
}

// MARK: - Requests

struct DBPositionStatsRequest: Encodable {
    var game: Int
    var moves: [Int]
    var scope: String
    var filters: DBFilters?

    private enum CodingKeys: String, CodingKey { case game, moves, scope, filters }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(game, forKey: .game)
        try c.encode(moves, forKey: .moves)
        try c.encode(scope, forKey: .scope)
        if let f = filters, !f.isDefault { try c.encode(f, forKey: .filters) } else { try c.encodeNil(forKey: .filters) }
    }
}

struct DBGameSearchRequest: Encodable {
    var game: Int
    var moves: [Int]?
    var scope: String
    var filters: DBFilters?
    var offset: Int
    var limit: Int

    init(game: Int, moves: [Int]?, scope: String, filters: DBFilters?, offset: Int, limit: Int) {
        self.game = game
        self.moves = moves
        self.scope = scope
        self.filters = filters
        self.offset = offset
        self.limit = min(limit, 100)
    }

    private enum CodingKeys: String, CodingKey { case game, moves, scope, filters, offset, limit }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(game, forKey: .game)
        try c.encodeIfPresent(moves, forKey: .moves)
        try c.encode(scope, forKey: .scope)
        if let f = filters, !f.isDefault { try c.encode(f, forKey: .filters) } else { try c.encodeNil(forKey: .filters) }
        try c.encode(offset, forKey: .offset)
        try c.encode(min(limit, 100), forKey: .limit)
    }
}

// MARK: - Responses

struct DBNextMove: Decodable, Equatable {
    var move: Int
    var games: Int
    var wins: Int
    var winPct: Double

    init(move: Int, games: Int, wins: Int, winPct: Double) {
        self.move = move; self.games = games; self.wins = wins; self.winPct = winPct
    }

    private enum CodingKeys: String, CodingKey { case move, games, wins, winPct }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        move = try c.decodeIfPresent(Int.self, forKey: .move) ?? 0
        games = try c.decodeIfPresent(Int.self, forKey: .games) ?? 0
        wins = try c.decodeIfPresent(Int.self, forKey: .wins) ?? 0
        winPct = try c.decodeIfPresent(Double.self, forKey: .winPct) ?? 0
    }
}

struct DBPositionStats: Decodable, Equatable {
    var totalGames: Int
    var totalWinPct: Double
    var nextMoves: [DBNextMove]
    var blocked: Bool

    private enum CodingKeys: String, CodingKey { case totalGames, totalWinPct, nextMoves, blocked }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalGames = try c.decodeIfPresent(Int.self, forKey: .totalGames) ?? 0
        totalWinPct = try c.decodeIfPresent(Double.self, forKey: .totalWinPct) ?? 0
        nextMoves = try c.decodeIfPresent([DBNextMove].self, forKey: .nextMoves) ?? []
        blocked = try c.decodeIfPresent(Bool.self, forKey: .blocked) ?? false
    }
}

struct DBPlayer: Decodable, Equatable {
    var name: String
    var rating: Int
    var nameColor: Int
    var crown: Int

    private enum CodingKeys: String, CodingKey { case name, rating, nameColor, crown }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        rating = try c.decodeIfPresent(Int.self, forKey: .rating) ?? 0
        nameColor = try c.decodeIfPresent(Int.self, forKey: .nameColor) ?? 0
        crown = try c.decodeIfPresent(Int.self, forKey: .crown) ?? 0
    }
}

struct DBGameHeader: Decodable, Equatable {
    var gid: Int64
    /// "archive" or "mine" (spec §3.7). For "mine", `gid` is a wgid that
    /// loads from `GET /collection/{wgid}`. Missing means "archive".
    var source: String
    var game: Int
    var player1: DBPlayer?
    var player2: DBPlayer?
    var winner: Int
    var site: String?
    var event: String?
    var round: String?
    var section: String?
    var playDate: String?
    var moveCount: Int

    /// A missing gid decodes to 0, which is never a real game id: never open
    /// it by id or let it pass a stale-response gid check.
    var hasRealGid: Bool { gid > 0 }

    var isMine: Bool { source == "mine" }

    private enum CodingKeys: String, CodingKey {
        case gid, source, game, player1, player2, winner, site, event, round, section, playDate, moveCount
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gid = try c.decodeIfPresent(Int64.self, forKey: .gid) ?? 0
        source = try c.decodeIfPresent(String.self, forKey: .source) ?? "archive"
        game = try c.decodeIfPresent(Int.self, forKey: .game) ?? 0
        player1 = try c.decodeIfPresent(DBPlayer.self, forKey: .player1)
        player2 = try c.decodeIfPresent(DBPlayer.self, forKey: .player2)
        winner = try c.decodeIfPresent(Int.self, forKey: .winner) ?? 0
        site = try c.decodeIfPresent(String.self, forKey: .site)
        event = try c.decodeIfPresent(String.self, forKey: .event)
        round = try c.decodeIfPresent(String.self, forKey: .round)
        section = try c.decodeIfPresent(String.self, forKey: .section)
        playDate = try c.decodeIfPresent(String.self, forKey: .playDate)
        moveCount = try c.decodeIfPresent(Int.self, forKey: .moveCount) ?? 0
    }
}

struct DBGameSearchResult: Decodable, Equatable {
    var total: Int
    var games: [DBGameHeader]
    var blocked: Bool

    private enum CodingKeys: String, CodingKey { case total, games, blocked }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = try c.decodeIfPresent(Int.self, forKey: .total) ?? 0
        games = try c.decodeIfPresent([DBGameHeader].self, forKey: .games) ?? []
        blocked = try c.decodeIfPresent(Bool.self, forKey: .blocked) ?? false
    }
}

struct DBGameDetail: Decodable, Equatable {
    var header: DBGameHeader?
    var moves: [Int]
    var blocked: Bool

    private enum CodingKeys: String, CodingKey { case header, moves, blocked }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        header = try c.decodeIfPresent(DBGameHeader.self, forKey: .header)
        moves = try c.decodeIfPresent([Int].self, forKey: .moves) ?? []
        blocked = try c.decodeIfPresent(Bool.self, forKey: .blocked) ?? false
    }
}

struct DBPing: Decodable, Equatable {
    var auth: String?
    var dbAccess: Bool
    /// Server capability flags (spec §4.1), e.g. "excludeTimeouts",
    /// "liveOrTurnBased". Missing means none. Gates filter controls at runtime.
    var features: [String]

    private enum CodingKeys: String, CodingKey { case auth, dbAccess, features }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        auth = try c.decodeIfPresent(String.self, forKey: .auth)
        dbAccess = try c.decodeIfPresent(Bool.self, forKey: .dbAccess) ?? false
        features = try c.decodeIfPresent([String].self, forKey: .features) ?? []
    }
}

struct DBPlayersResult: Decodable, Equatable {
    var players: [String]

    private enum CodingKeys: String, CodingKey { case players }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        players = try c.decodeIfPresent([String].self, forKey: .players) ?? []
    }
}

struct DBErrorEnvelope: Decodable {
    struct Body: Decodable {
        var code: String?
        var message: String?
    }
    var error: Body
}
