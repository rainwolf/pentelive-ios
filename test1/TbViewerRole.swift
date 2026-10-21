import Foundation

/// Who is looking at a turn-based game: one of its players, or a non-player
/// (a parent watching a kid's game). A non-player sees the board from
/// player 1's side and with both players named.
@objc final class TbViewerRole: NSObject {
    @objc let isPlayer: Bool
    @objc let seesAsPlayer1: Bool
    @objc let myLabel: String
    private let username: String

    private init(isPlayer: Bool, seesAsPlayer1: Bool, myLabel: String, username: String) {
        self.isPlayer = isPlayer
        self.seesAsPlayer1 = seesAsPlayer1
        self.myLabel = myLabel
        self.username = username
    }

    @objc(roleForUsername:player1:player2:)
    static func role(username: String?, player1: String?, player2: String?) -> TbViewerRole {
        let me = (username ?? "").lowercased()
        let isP1 = !me.isEmpty && player1?.lowercased() == me
        let isP2 = !me.isEmpty && player2?.lowercased() == me
        if isP1 || isP2 {
            return TbViewerRole(isPlayer: true, seesAsPlayer1: isP1, myLabel: "me", username: me)
        }
        return TbViewerRole(isPlayer: false, seesAsPlayer1: true, myLabel: player1 ?? "", username: me)
    }

    /// Only a player is asked to accept or decline a pending set cancellation,
    /// and not when they requested it themselves.
    @objc(promptsCancelReplyForRequester:)
    func promptsCancelReply(requester: String?) -> Bool {
        return isPlayer && requester?.lowercased() != username
    }
}
