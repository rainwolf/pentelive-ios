import Foundation

enum DashboardErrorCode: Int {
    case network = 1
    case http = 2
    case decoding = 3
    case invalidCredentials = 4
}

enum DashboardError {
    static let domain = "org.pente.DashboardError"
    static func make(_ code: DashboardErrorCode, _ message: String) -> NSError {
        NSError(domain: domain, code: code.rawValue,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}

@objc final class DashboardFlags: NSObject {
    @objc let myColorRGB: Int
    @objc let playerName: String
    @objc let showAds: Bool
    @objc let subscriber: Bool
    @objc let dbAccess: Bool
    @objc let emailMe: Bool
    @objc let tbHills: Int
    @objc let tbRatings: Int
    @objc let livePlayers: String
    @objc let onlineFollowing: String

    @objc init(myColorRGB: Int, playerName: String, showAds: Bool, subscriber: Bool,
               dbAccess: Bool, emailMe: Bool, tbHills: Int, tbRatings: Int,
               livePlayers: String, onlineFollowing: String) {
        self.myColorRGB = myColorRGB; self.playerName = playerName
        self.showAds = showAds; self.subscriber = subscriber; self.dbAccess = dbAccess
        self.emailMe = emailMe; self.tbHills = tbHills; self.tbRatings = tbRatings
        self.livePlayers = livePlayers; self.onlineFollowing = onlineFollowing
    }
}

@objc final class Dashboard: NSObject {
    @objc let sentInvitations: [Game]
    @objc let invitations: [Game]
    @objc let activeGames: [Game]
    @objc let nonActiveGames: [Game]
    @objc let publicInvitations: [Game]
    @objc let messages: [Message]
    @objc let tournaments: [Tournament]
    @objc let hills: [KingOfTheHill]
    @objc let ratingStats: [RatingStat]
    @objc let onlinePlayers: [String: String]
    @objc let avatarUsernames: [String]
    @objc let flags: DashboardFlags

    @objc init(sentInvitations: [Game], invitations: [Game], activeGames: [Game],
               nonActiveGames: [Game], publicInvitations: [Game], messages: [Message],
               tournaments: [Tournament], hills: [KingOfTheHill], ratingStats: [RatingStat],
               onlinePlayers: [String: String], avatarUsernames: [String], flags: DashboardFlags) {
        self.sentInvitations = sentInvitations; self.invitations = invitations
        self.activeGames = activeGames; self.nonActiveGames = nonActiveGames
        self.publicInvitations = publicInvitations; self.messages = messages
        self.tournaments = tournaments; self.hills = hills; self.ratingStats = ratingStats
        self.onlinePlayers = onlinePlayers; self.avatarUsernames = avatarUsernames; self.flags = flags
    }
}
