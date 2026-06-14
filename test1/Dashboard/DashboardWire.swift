import Foundation

/// Decodes a JSON value that may arrive as String, Int, Double, or Bool into a String,
/// reproducing the legacy `[x stringValue]` coercions.
struct FlexibleString: Decodable {
    let value: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let i = try? c.decode(Int.self) { value = String(i) }
        else if let d = try? c.decode(Double.self) { value = String(d) }
        else if let b = try? c.decode(Bool.self) { value = b ? "1" : "0" }
        // Unexpected shapes (nested object/array/null) collapse to "" — a lenient
        // wire layer mirroring legacy [x stringValue]. Downstream mapping must treat
        // an empty value as "absent", not a meaningful value.
        else { value = "" }
    }
}

struct WirePlayer: Decodable {
    let color: Int?
    let showAds: Bool?
    let name: String?
    let subscriber: Bool?
    let dbAccess: Bool?
    let emailMe: Bool?
    let livePlayers: FlexibleString?
    let onlineFollowing: FlexibleString?
}

struct WireHill: Decodable {
    let gameId: Int?
    let numPlayers: FlexibleString?
    let amIMember: Bool?
    let iAmKing: Bool?
    let kingName: String?
    let canChallenge: Bool?
}

struct WireRatingStat: Decodable {
    let rating: FlexibleString?
    let totalGames: FlexibleString?
    let lastGameDate: FlexibleString?
    let tourneyWinner: Int?
    let gameId: Int?
}

/// Covers invitations (sent/received), active games (both), and open invitations.
struct WireGame: Decodable {
    let setId: FlexibleString?
    let gid: FlexibleString?
    let gameName: String?
    let opponentName: String?
    let opponentRating: FlexibleString?
    let inviterName: String?
    let inviterRating: FlexibleString?
    let color: String?
    let daysPerMove: FlexibleString?
    let timeLeft: String?
    let rated: FlexibleString?
    let opponentColor: Int?
    let inviterColor: Int?
    let opponentTourneyWinner: Int?
    let inviterTourneyWinner: Int?
}

struct WireMessage: Decodable {
    let mid: FlexibleString?
    /// JSON boolean (server emits Gson(IndexResponse.MessageEntry.read), a Java `boolean`).
    /// true = already read. Must be Bool? — a JSON bool cannot decode into Int.
    let read: Bool?
    let subject: String?
    let from: String?
    let date: String?
    let fromColor: Int?
    let fromTourneyWinner: Int?
}

struct WireTournament: Decodable {
    let name: String?
    let eventId: FlexibleString?
    let numRounds: FlexibleString?
    let gameName: String?
    let status: FlexibleString?
    let date: String?
}

struct WireDashboard: Decodable {
    let player: WirePlayer?
    let kingOfTheHill: [WireHill]?
    let ratingStats: [WireRatingStat]?
    let invitationsSent: [WireGame]?
    let invitationsReceived: [WireGame]?
    let activeGamesMyTurn: [WireGame]?
    let activeGamesOpponentTurn: [WireGame]?
    let openInvitationGames: [WireGame]?
    let messages: [WireMessage]?
    let tournaments: [WireTournament]?
    let onlinePlayers: [String]?
}
