import UIKit

enum DashboardMapping {

    static func uiColor(fromRGB rgb: Int) -> UIColor {
        UIColor(red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
                green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
                blue: CGFloat(rgb & 0x0000FF) / 255.0, alpha: 1.0)
    }

    static func parseStoneColor(_ s: String?) -> String {
        guard let s = s else { return "" }
        if s.hasPrefix("white") { return "white" }
        if s.hasPrefix("black") { return "black" }
        return ""
    }

    /// Reproduces the `tb-` / `Speed ` / plain decoration from parseDashboard.
    static func decoratedGameName(gameId: Int) -> String {
        var g = gameId
        if g > 50 { g -= 50 }
        let name = LegacyPenteGame.getName(Int32(g)) ?? ""
        if gameId > 50 { return "tb-" + name }
        if gameId % 2 == 0 { return "Speed " + name }
        return name
    }

    private static let black = uiColor(fromRGB: 0)

    static func map(_ wire: WireDashboard) -> Dashboard {
        var avatars: [String] = []

        func mapInvitationGame(_ w: WireGame) -> Game {
            let g = Game()
            g.gameID = w.setId?.value ?? ""
            g.gameType = w.gameName
            g.opponentName = w.opponentName
            g.opponentRating = w.opponentRating?.value ?? ""
            g.myColor = w.color
            g.remainingTime = "\(w.daysPerMove?.value ?? "") days per move"
            g.ratedNot = w.rated?.value
            g.nameColor = uiColor(fromRGB: w.opponentColor ?? 0)
            g.crown = Int32(w.opponentTourneyWinner ?? 0)
            if g.nameColor != black, let n = g.opponentName { avatars.append(n) }
            return g
        }

        func mapActiveGame(_ w: WireGame) -> Game {
            let g = Game()
            g.gameID = w.gid?.value ?? ""
            g.gameType = w.gameName
            g.opponentName = w.opponentName
            g.opponentRating = w.opponentRating?.value ?? ""
            g.myColor = parseStoneColor(w.color)
            g.remainingTime = w.timeLeft
            g.ratedNot = w.rated?.value
            g.nameColor = uiColor(fromRGB: w.opponentColor ?? 0)
            g.crown = Int32(w.opponentTourneyWinner ?? 0)
            if g.nameColor != black, let n = g.opponentName { avatars.append(n) }
            return g
        }

        func mapOpenInvitation(_ w: WireGame) -> Game {
            let g = Game()
            g.gameID = w.setId?.value ?? ""
            g.gameType = w.gameName
            g.opponentName = w.inviterName
            g.opponentRating = w.inviterRating?.value ?? ""
            g.myColor = parseStoneColor(w.color)
            g.remainingTime = "\(w.daysPerMove?.value ?? "") days per move"
            g.ratedNot = w.rated?.value
            g.nameColor = uiColor(fromRGB: w.inviterColor ?? 0)
            g.crown = Int32(w.inviterTourneyWinner ?? 0)
            if g.nameColor != black, let n = g.opponentName { avatars.append(n) }
            return g
        }

        let sent = (wire.invitationsSent ?? []).map(mapInvitationGame)
        let received = (wire.invitationsReceived ?? []).map(mapInvitationGame)
        let activeMine = (wire.activeGamesMyTurn ?? []).map(mapActiveGame)
        let activeOpp = (wire.activeGamesOpponentTurn ?? []).map(mapActiveGame)
        let open = (wire.openInvitationGames ?? []).map(mapOpenInvitation)

        let messages: [Message] = (wire.messages ?? []).map { w in
            let m = Message()
            m.messageID = w.mid?.value ?? ""
            m.unread = (w.read ?? false) ? "read" : "unread"
            m.subject = w.subject
            m.author = w.from
            m.timeStamp = w.date
            m.nameColor = uiColor(fromRGB: w.fromColor ?? 0)
            m.crown = Int32(w.fromTourneyWinner ?? 0)
            if m.nameColor != black, let n = m.author { avatars.append(n) }
            return m
        }

        var tbHills = 0
        let hills: [KingOfTheHill] = (wire.kingOfTheHill ?? []).map { w in
            let h = KingOfTheHill()
            h.gameId = Int32(w.gameId ?? 0)
            h.numPlayers = w.numPlayers?.value
            h.member = w.amIMember ?? false
            h.king = w.iAmKing ?? false
            h.currentKing = w.kingName
            h.canSendOpen = w.canChallenge ?? false
            if Int(h.gameId) > 50 { tbHills += 1 }
            h.game = decoratedGameName(gameId: Int(h.gameId))
            return h
        }

        var tbRatings = 0
        let ratings: [RatingStat] = (wire.ratingStats ?? []).map { w in
            let r = RatingStat()
            r.rating = w.rating?.value
            r.totalGames = w.totalGames?.value
            r.lastPlayed = w.lastGameDate?.value
            r.crown = Int32(w.tourneyWinner ?? 0)
            r.gameId = Int32(w.gameId ?? 0)
            if Int(r.gameId) > 50 { tbRatings += 1 }
            r.game = decoratedGameName(gameId: Int(r.gameId))
            return r
        }

        let tournaments: [Tournament] = (wire.tournaments ?? []).map { w in
            let t = Tournament()
            t.name = w.name
            t.tournamentID = w.eventId?.value
            t.round = w.numRounds?.value
            t.game = w.gameName
            t.tournamentState = w.status?.value
            t.date = w.date
            return t
        }

        var online: [String: String] = [:]
        for n in (wire.onlinePlayers ?? []) { online[n] = "" }

        let p = wire.player
        let flags = DashboardFlags(
            myColorRGB: p?.color ?? 0,
            playerName: p?.name ?? "",
            showAds: p?.showAds ?? false,
            subscriber: p?.subscriber ?? false,
            dbAccess: p?.dbAccess ?? false,
            emailMe: p?.emailMe ?? false,
            tbHills: tbHills,
            tbRatings: tbRatings,
            livePlayers: p?.livePlayers?.value ?? "0",
            onlineFollowing: p?.onlineFollowing?.value ?? "0")

        return Dashboard(sentInvitations: sent, invitations: received,
                         activeGames: activeMine, nonActiveGames: activeOpp,
                         publicInvitations: open, messages: messages,
                         tournaments: tournaments, hills: hills, ratingStats: ratings,
                         onlinePlayers: online, avatarUsernames: avatars, flags: flags)
    }
}
