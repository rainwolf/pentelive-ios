import Foundation

@objc final class KidMode: NSObject {
    @objc static let chatHint = "Only approved players see your messages"
    @objc static let composerHint = "Approved players only"
    @objc static let liveChatCopyNote = "Live chat copies are best effort: if the server's chat buffer is unavailable, that session isn't copied."
    static let broadcastRefusedText = "Kid accounts can't broadcast."

    private static let sendErrors = [
        "You can only send messages to players your parent approved.",
        "Player is ignoring your messages.",
    ]

    static func managedByParentText(_ parentName: String?) -> String {
        guard let parentName, !parentName.isEmpty else {
            return "Your account is managed by your parent."
        }
        return "Your account is managed by your parent, \(parentName)."
    }

    static func approvedCountText(_ count: Int) -> String {
        count == 1 ? "1 approved player" : "\(count) approved players"
    }

    static func isKid(loginEvent: [String: Any]) -> Bool {
        guard let me = loginEvent["me"] as? [String: Any] else { return false }
        let parentPid = me["parentPid"]
        if parentPid is NSNumber {
            return true
        }
        if let text = parentPid as? String {
            return !text.isEmpty
        }
        return false
    }

    @objc static func messageSendError(_ body: String?) -> String? {
        guard let body else { return nil }
        return sendErrors.first { body.contains($0) }
    }

    static func isBroadcastRefused(_ body: String) -> Bool {
        body.contains(broadcastRefusedText)
    }

    static func inviteAlertMessage(_ inviteText: String) -> String? {
        inviteText.isEmpty ? nil : "message: \(inviteText)"
    }

    @objc static func settingsHiddenKeys(loggedIn: Bool, subscriber: Bool, isKid: Bool) -> Set<String> {
        guard loggedIn else {
            return ["SubscribeButton", "StoreButton", "blockedPlayersButton", "kidAccountsButton"]
        }
        var keys: Set<String> = subscriber
            ? ["SubscribeButton", "SignUpButton", "SignUpLabel", "personalizeAds"]
            : ["SignUpButton", "SignUpLabel"]
        if isKid {
            keys.insert("kidAccountsButton")
        }
        return keys
    }
}
