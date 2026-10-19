import Foundation

/// One row of the account's ignore list (GET /gameServer/ignored).
struct IgnoreEntry: Decodable, Equatable {
    let ignorePid: Int64
    let name: String
    let ignoreInvite: Bool
    let ignoreChat: Bool
}

/// Which kind of block a list or an unblock acts on.
enum BlockFilter: Int, CaseIterable {
    case messages, invitations, both

    var title: String {
        switch self {
        case .messages: return NSLocalizedString("Messages", comment: "Blocked players filter")
        case .invitations: return NSLocalizedString("Invitations", comment: "Blocked players filter")
        case .both: return NSLocalizedString("Both", comment: "Blocked players filter")
        }
    }
}

/// Pure logic for the blocked-players feature.
enum BlockedPlayers {
    private struct Reply: Decodable {
        let success: Bool?
        let error: String?
        let ignores: [IgnoreEntry]?
    }

    private static func reply(_ data: Data?) -> Reply? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode(Reply.self, from: data)
    }

    /// The ignore list, or nil for no data, a non-JSON body (the login page
    /// an expired session returns with HTTP 200) or `success:false`.
    static func parse(_ data: Data?) -> [IgnoreEntry]? {
        guard let r = reply(data), r.success == true else { return nil }
        return r.ignores ?? []
    }

    /// The server's `error` string of a reply, if it has one.
    static func parseError(_ data: Data?) -> String? {
        guard let e = reply(data)?.error, !e.isEmpty else { return nil }
        return e
    }

    static func filter(_ entries: [IgnoreEntry], by: BlockFilter) -> [IgnoreEntry] {
        switch by {
        case .messages: return entries.filter { $0.ignoreChat }
        case .invitations: return entries.filter { $0.ignoreInvite }
        case .both: return entries
        }
    }

    /// The flags left on an entry after unblocking the given kind.
    static func remainingFlags(_ e: IgnoreEntry, unblocking: BlockFilter) -> (invite: Bool, chat: Bool) {
        switch unblocking {
        case .messages: return (e.ignoreInvite, false)
        case .invitations: return (false, e.ignoreChat)
        case .both: return (false, false)
        }
    }

    /// `messages`, `invitations` or `messages and invitations`.
    static func kindText(invite: Bool, chat: Bool) -> String {
        if invite && chat {
            return NSLocalizedString("messages and invitations", comment: "Kind of block")
        }
        return invite
            ? NSLocalizedString("invitations", comment: "Kind of block")
            : NSLocalizedString("messages", comment: "Kind of block")
    }

    static func isChatBlocked(_ name: String, in entries: [IgnoreEntry]) -> Bool {
        entries.contains { $0.ignoreChat && $0.name.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// `k=v&k=v`, everything but RFC 3986 unreserved characters percent-encoded.
    static func formEncode(_ params: [(String, String)]) -> String {
        let unreserved = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        func enc(_ s: String) -> String { s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? "" }
        return params.map { "\(enc($0.0))=\(enc($0.1))" }.joined(separator: "&")
    }
}
