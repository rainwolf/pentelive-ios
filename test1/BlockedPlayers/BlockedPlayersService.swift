import Foundation
import UIKit

/// Network access and shared UI helpers for blocked players. Completions run
/// on the main queue (PenteHTTPClient guarantees it).
@objc final class BlockedPlayersService: NSObject {
    private static let timeout: TimeInterval = 7.0

    private static var url: URL {
        URL(string: (developmentEnabled() ? "https://localhost" : "https://www.pente.org") + "/gameServer/ignored")!
    }

    private static func credentials() -> [(String, String)] {
        let defaults = UserDefaults.standard
        return [("name2", defaults.string(forKey: "username") ?? ""),
                ("password2", defaults.string(forKey: "password") ?? "")]
    }

    private static func yn(_ b: Bool) -> String { b ? "Y" : "N" }

    private static func get() -> URLRequest {
        var request = URLRequest(url: URL(string: url.absoluteString + "?" + BlockedPlayers.formEncode(credentials()))!)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    private static func post(_ params: [(String, String)]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(BlockedPlayers.formEncode(params + credentials()).utf8)
        return request
    }

    private static func send(_ request: URLRequest, _ completion: @escaping (Data?) -> Void) {
        PenteHTTPClient.send(request) { data, _, _ in completion(data) }
    }

    private static func failureText(_ data: Data?) -> String {
        BlockedPlayers.parseError(data) ?? NSLocalizedString("Please try again.", comment: "Blocked players error")
    }

    private static func listResult(_ data: Data?, _ completion: ([IgnoreEntry]?, String?) -> Void) {
        if let entries = BlockedPlayers.parse(data) {
            completion(entries, nil)
        } else {
            completion(nil, failureText(data))
        }
    }

    static func load(_ completion: @escaping ([IgnoreEntry]?, String?) -> Void) {
        send(get()) { listResult($0, completion) }
    }

    @objc static func block(name: String, invite: Bool, chat: Bool,
                            completion: @escaping (Bool, String?) -> Void) {
        let params = [("action", "add"), ("ignoreName", name),
                      ("ignoreInvite", yn(invite)), ("ignoreChat", yn(chat))]
        send(post(params)) { data in
            if BlockedPlayers.parse(data) != nil {
                completion(true, nil)
            } else {
                completion(false, failureText(data))
            }
        }
    }

    /// Sets the flags of an entry (both false removes it); replies with the new list.
    static func update(pid: Int64, invite: Bool, chat: Bool,
                       _ completion: @escaping ([IgnoreEntry]?, String?) -> Void) {
        let params = [("action", "update"), ("ignorePid", String(pid)),
                      ("ignoreInvite", yn(invite)), ("ignoreChat", yn(chat))]
        send(post(params)) { listResult($0, completion) }
    }

    /// Whether `name` is blocked for messages; false when the list cannot be loaded.
    @objc static func isChatBlocked(name: String, completion: @escaping (Bool) -> Void) {
        load { entries, _ in
            completion(entries.map { BlockedPlayers.isChatBlocked(name, in: $0) } ?? false)
        }
    }

    /// Red disc with a white horizontal bar.
    @objc static func blockIcon() -> UIImage {
        let config = UIImage.SymbolConfiguration(paletteColors: [.white, .systemRed])
        return (UIImage(systemName: "minus.circle.fill", withConfiguration: config) ?? UIImage())
            .withRenderingMode(.alwaysOriginal)
    }

    @objc static func confirmBlock(name: String, forInvitation: Bool, onConfirm: @escaping () -> Void) {
        let title = String(format: NSLocalizedString("Block %@?", comment: "Block dialog title"), name)
        let message = forInvitation
            ? String(format: NSLocalizedString(
                "This declines the invitation and you will no longer receive invitations from %@.\nYou can unblock players in Settings.",
                comment: "Block invitation dialog message"), name)
            : String(format: NSLocalizedString(
                "You will no longer receive messages from %@.\nYou can unblock players in Settings.",
                comment: "Block message dialog message"), name)
        PenteAlert.show(withTitle: title, message: message,
                        cancelButtonTitle: NSLocalizedString("Cancel", comment: ""),
                        otherButtonTitles: [NSLocalizedString("Block", comment: "Block dialog button")]) { index in
            if index == 1 { onConfirm() }
        }
    }

    @objc static func showError(blocking: Bool, name: String, message: String?) {
        let format = blocking
            ? NSLocalizedString("Couldn't block %@", comment: "Block error title")
            : NSLocalizedString("Couldn't unblock %@", comment: "Unblock error title")
        let text = (message?.isEmpty == false) ? message!
            : NSLocalizedString("Please try again.", comment: "Blocked players error")
        PenteAlert.show(withTitle: String(format: format, name), message: text,
                        cancelButtonTitle: NSLocalizedString("OK", comment: ""))
    }
}
