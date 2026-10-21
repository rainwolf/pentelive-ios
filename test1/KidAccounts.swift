import UIKit

/// A player on a kid's chat whitelist (names the kid may message).
struct KidPlayer: Decodable, Equatable {
    let pid: Int64
    let name: String
    /// Donor name color RGB int; 0 = no color.
    let nameColor: Int
    /// 0 none; 1/2/3 tournament crowns; > 3 KOTH crown (kothWins + 3).
    let tourneyWinner: Int

    init(pid: Int64, name: String, nameColor: Int = 0, tourneyWinner: Int = 0) {
        self.pid = pid
        self.name = name
        self.nameColor = nameColor
        self.tourneyWinner = tourneyWinner
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pid = try c.decode(Int64.self, forKey: .pid)
        name = try c.decode(String.self, forKey: .name)
        nameColor = try c.decodeIfPresent(Int.self, forKey: .nameColor) ?? 0
        tourneyWinner = try c.decodeIfPresent(Int.self, forKey: .tourneyWinner) ?? 0
    }

    private enum CodingKeys: String, CodingKey {
        case pid, name, nameColor, tourneyWinner
    }

    /// The name styled exactly like a dashboard message sender (color, weight, crown),
    /// by reusing `Message.attributedName` with the same mapping as `DashboardMapping`.
    var styledName: NSAttributedString {
        let m = Message()
        m.author = name
        m.nameColor = DashboardMapping.uiColor(fromRGB: nameColor)
        m.crown = Int32(tourneyWinner)
        return m.attributedName()
    }
}

/// One kid account owned by the signed-in parent.
struct KidAccount: Decodable, Equatable {
    let kidPid: Int64
    let name: String
    let copyMessages: Bool
    let copyLiveChat: Bool
    /// nil: the server predates turn-based message copies, so the UI hides the switch.
    let copyTbMessages: Bool?
    let whitelist: [KidPlayer]

    init(kidPid: Int64, name: String, copyMessages: Bool, copyLiveChat: Bool, copyTbMessages: Bool? = nil, whitelist: [KidPlayer]) {
        self.kidPid = kidPid
        self.name = name
        self.copyMessages = copyMessages
        self.copyLiveChat = copyLiveChat
        self.copyTbMessages = copyTbMessages
        self.whitelist = whitelist
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kidPid = try c.decode(Int64.self, forKey: .kidPid)
        name = try c.decode(String.self, forKey: .name)
        copyMessages = try c.decodeIfPresent(Bool.self, forKey: .copyMessages) ?? false
        copyLiveChat = try c.decodeIfPresent(Bool.self, forKey: .copyLiveChat) ?? false
        copyTbMessages = try c.decodeIfPresent(Bool.self, forKey: .copyTbMessages)
        let lossy = try c.decodeIfPresent([KidAccounts.Lossy<KidPlayer>].self, forKey: .whitelist) ?? []
        whitelist = lossy.compactMap { $0.value }
    }

    private enum CodingKeys: String, CodingKey {
        case kidPid, name, copyMessages, copyLiveChat, copyTbMessages, whitelist
    }
}

/// One active turn-based game of a kid, as listed to the parent.
struct KidActiveGame: Decodable, Equatable {
    let gid: Int64
    let game: Int
    let gameName: String
    let opponentPid: Int64
    let opponentName: String
    let kidsTurn: Bool
    /// Epoch milliseconds; 0 when unknown.
    let lastMoveDate: Int64
    let privateGame: Bool

    init(gid: Int64, game: Int, gameName: String, opponentPid: Int64, opponentName: String,
         kidsTurn: Bool, lastMoveDate: Int64, privateGame: Bool)
    {
        self.gid = gid
        self.game = game
        self.gameName = gameName
        self.opponentPid = opponentPid
        self.opponentName = opponentName
        self.kidsTurn = kidsTurn
        self.lastMoveDate = lastMoveDate
        self.privateGame = privateGame
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        gid = try c.decode(Int64.self, forKey: .gid)
        game = try c.decodeIfPresent(Int.self, forKey: .game) ?? 0
        gameName = try c.decode(String.self, forKey: .gameName)
        opponentPid = try c.decodeIfPresent(Int64.self, forKey: .opponentPid) ?? 0
        opponentName = try c.decode(String.self, forKey: .opponentName)
        kidsTurn = try c.decodeIfPresent(Bool.self, forKey: .kidsTurn) ?? false
        lastMoveDate = try c.decodeIfPresent(Int64.self, forKey: .lastMoveDate) ?? 0
        privateGame = try c.decodeIfPresent(Bool.self, forKey: .privateGame) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case gid, game, gameName, opponentPid, opponentName, kidsTurn, lastMoveDate, privateGame
    }

    var title: String {
        String(format: NSLocalizedString("%@ vs %@", comment: "Kid active game row title: game name, opponent"),
               gameName, opponentName)
    }

    /// "<name>'s turn", plus ", last move <date>" when the last move time is known.
    func subtitle(kidName: String, formatDate: (Date) -> String) -> String {
        let turn = String(format: NSLocalizedString("%@'s turn", comment: "Kid active game row: whose turn it is"),
                          kidsTurn ? kidName : opponentName)
        guard lastMoveDate > 0 else { return turn }
        let date = formatDate(Date(timeIntervalSince1970: Double(lastMoveDate) / 1000))
        return turn + String(format: NSLocalizedString(", last move %@", comment: "Kid active game row: last move date"), date)
    }
}

/// Everything `/gameServer/kids` reports for the signed-in account.
struct KidAccountsState: Equatable {
    let isKid: Bool
    let emailVerified: Bool
    let parentName: String?
    let whitelist: [KidPlayer]
    let kids: [KidAccount]
    let message: String?
}

/// A change request to `/gameServer/kids`.
enum KidAction: Equatable {
    case create(name: String, password: String)
    case convert(name: String)
    case password(kidPid: Int64, password: String)
    case whitelistAdd(kidPid: Int64, playerName: String)
    case whitelistRemove(kidPid: Int64, playerPid: Int64)
    case settings(kidPid: Int64, copyMessages: Bool?, copyLiveChat: Bool?, copyTbMessages: Bool? = nil)
    case release(kidPid: Int64)

    /// Form parameters; the first pair is always the action name.
    var params: [(String, String)] {
        func yn(_ b: Bool) -> String {
            b ? "Y" : "N"
        }
        switch self {
        case let .create(name, password):
            return [("action", "create"), ("kidName", name), ("kidPassword", password)]
        case let .convert(name):
            return [("action", "convert"), ("kidName", name)]
        case let .password(kidPid, password):
            return [("action", "password"), ("kidPid", String(kidPid)), ("kidPassword", password)]
        case let .whitelistAdd(kidPid, playerName):
            return [("action", "whitelistAdd"), ("kidPid", String(kidPid)), ("playerName", playerName)]
        case let .whitelistRemove(kidPid, playerPid):
            return [("action", "whitelistRemove"), ("kidPid", String(kidPid)), ("playerPid", String(playerPid))]
        case let .settings(kidPid, copyMessages, copyLiveChat, copyTbMessages):
            var p = [("action", "settings"), ("kidPid", String(kidPid))]
            if let m = copyMessages {
                p.append(("copyMessages", yn(m)))
            }
            if let l = copyLiveChat {
                p.append(("copyLiveChat", yn(l)))
            }
            if let t = copyTbMessages {
                p.append(("copyTbMessages", yn(t)))
            }
            return p
        case let .release(kidPid):
            return [("action", "release"), ("kidPid", String(kidPid))]
        }
    }
}

/// Pure logic for the kid accounts feature.
enum KidAccounts {
    /// Decodes an element or yields nil instead of failing the whole array.
    struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws {
            value = try? T(from: decoder)
        }
    }

    private struct Reply: Decodable {
        let success: Bool?
        let isKid: Bool?
        let emailVerified: Bool?
        let parentName: String?
        let whitelist: [Lossy<KidPlayer>]?
        let kids: [Lossy<KidAccount>]?
        let message: String?
        let error: String?
    }

    private struct ActiveGamesReply: Decodable {
        let success: Bool?
        let games: [Lossy<KidActiveGame>]?
    }

    private static func reply(_ data: Data?) -> Reply? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode(Reply.self, from: data)
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let s = s, !s.isEmpty else { return nil }
        return s
    }

    /// The account's kid state, nil on no data, a non-JSON body (the login page an
    /// expired session returns with HTTP 200) or `success:false`.
    static func parse(_ data: Data?) -> KidAccountsState? {
        guard let r = reply(data), r.success == true else { return nil }
        return KidAccountsState(
            isKid: r.isKid ?? false,
            emailVerified: r.emailVerified ?? false,
            parentName: nonEmpty(r.parentName),
            whitelist: (r.whitelist ?? []).compactMap { $0.value },
            kids: (r.kids ?? []).compactMap { $0.value },
            message: nonEmpty(r.message)
        )
    }

    /// A kid's active games in server order. nil on no data, a non-JSON body or
    /// `success != true`; a missing `games` is `[]`; malformed entries are skipped.
    static func parseActiveGames(_ data: Data?) -> [KidActiveGame]? {
        guard let data = data,
              let r = try? JSONDecoder().decode(ActiveGamesReply.self, from: data),
              r.success == true else { return nil }
        return (r.games ?? []).compactMap { $0.value }
    }

    /// The server's `error` text, nil when absent or the body is not JSON.
    static func parseError(_ data: Data?) -> String? {
        nonEmpty(reply(data)?.error)
    }

    static func kid(_ pid: Int64, in state: KidAccountsState) -> KidAccount? {
        state.kids.first { $0.kidPid == pid }
    }

    /// Names a kid may message: the whitelist plus the parent. Empty unless the account is a kid.
    static func allowedRecipients(_ state: KidAccountsState) -> [String] {
        guard state.isKid else { return [] }
        var seen = Set<String>()
        var names: [String] = []
        for n in state.whitelist.map({ $0.name }) + [state.parentName].compactMap({ $0 }) {
            if seen.insert(n.lowercased()).inserted {
                names.append(n)
            }
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}
