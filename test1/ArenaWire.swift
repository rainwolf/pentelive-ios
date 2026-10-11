//
//  ArenaWire.swift
//  penteLive
//
//  Arena join-request wire protocol: the server events the client decodes and the
//  client events it sends (pente.org spec 2026-10-10-arena-persistent-join-requests).
//  Foundation only, so the hosted tests exercise it without UI.
//

import Foundation

/// One pending request in an owner snapshot. `seq` is server-assigned and increasing.
struct ArenaJoinRequest: Equatable {
    let player: String
    let seq: Int
}

/// Body of dsgArenaRequestEndedEvent. `player` is the requester, `owner` the table owner.
struct ArenaRequestEnded: Equatable {
    enum Reason: String, CaseIterable {
        case declined = "DECLINED"
        case tableFull = "TABLE_FULL"
        case tableClosed = "TABLE_CLOSED"
        case duplicate = "DUPLICATE"
        case blocked = "BLOCKED"
        case notAvailable = "NOT_AVAILABLE"
        case guestRated = "GUEST_RATED"
        case booted = "BOOTED"
        case noLongerAvailable = "NO_LONGER_AVAILABLE"
    }

    let table: Int
    let player: String
    let owner: String
    let reason: Reason

    /// The short notice shown for this ending (spec C4).
    var noticeText: String {
        switch reason {
        case .declined:
            return String(format: NSLocalizedString("%@ declined your request", comment: "arena notice; %@ is the table owner"), owner)
        case .tableFull:
            return String(format: NSLocalizedString("Table %ld is no longer available", comment: "arena notice"), table)
        case .tableClosed:
            return String(format: NSLocalizedString("Table %ld was closed", comment: "arena notice"), table)
        case .duplicate:
            return String(format: NSLocalizedString("You already sent a request to %@", comment: "arena notice; %@ is the table owner"), owner)
        case .booted:
            return String(format: NSLocalizedString("%@ removed you from table %ld, try again in a few minutes", comment: "arena notice; %@ is the table owner"), owner, table)
        case .blocked:
            return String(format: NSLocalizedString("You can't request table %ld again until its next game", comment: "arena notice"), table)
        case .notAvailable:
            return String(format: NSLocalizedString("You can't join table %ld right now", comment: "arena notice"), table)
        case .guestRated:
            return NSLocalizedString("Guests can't join rated tables", comment: "arena notice")
        case .noLongerAvailable:
            return String(format: NSLocalizedString("%@ is no longer available", comment: "arena notice to the owner; %@ is the requester"), player)
        }
    }
}

/// The arena events the server sends. Anything else (including the old S→C
/// dsgArenaRequestJoinTableEvent / dsgArenaRejectTableJoinEvent) is not an arena event.
enum ArenaInbound: Equatable {
    case joinRequests(table: Int, requests: [ArenaJoinRequest])
    case myRequests(tables: [Int])
    case requestEnded(ArenaRequestEnded)

    /// nil when `event` carries none of the three keys, or its payload is unusable.
    /// Bad list entries are skipped; the snapshot comes back in `seq` order, one row per player.
    init?(event: [String: Any]) {
        if let body = event["dsgArenaJoinRequestsEvent"] as? [String: Any] {
            guard let table = body["table"] as? Int else { return nil }
            var seen = Set<String>()
            let requests = (body["requests"] as? [Any] ?? [])
                .compactMap { entry -> ArenaJoinRequest? in
                    guard let fields = entry as? [String: Any],
                          let player = fields["player"] as? String,
                          let seq = fields["seq"] as? Int else { return nil }
                    return ArenaJoinRequest(player: player, seq: seq)
                }
                .sorted { $0.seq < $1.seq }
                .filter { seen.insert($0.player).inserted }
            self = .joinRequests(table: table, requests: requests)
        } else if let body = event["dsgArenaMyRequestsEvent"] as? [String: Any] {
            let tables = (body["tables"] as? [Any] ?? []).compactMap { $0 as? Int }
            self = .myRequests(tables: tables)
        } else if let body = event["dsgArenaRequestEndedEvent"] as? [String: Any] {
            guard let table = body["table"] as? Int,
                  let rawReason = body["reason"] as? String,
                  let reason = ArenaRequestEnded.Reason(rawValue: rawReason) else { return nil }
            self = .requestEnded(ArenaRequestEnded(table: table,
                                                   player: body["player"] as? String ?? "",
                                                   owner: body["owner"] as? String ?? "",
                                                   reason: reason))
        } else {
            return nil
        }
    }
}

/// The arena events the client sends. `player` is filled in by the server from the session.
enum ArenaOutbound {
    static func requestJoin(table: Int) -> [String: Any] {
        return ["dsgArenaRequestJoinTableEvent": ["table": table, "time": 0]]
    }

    static func withdraw(table: Int) -> [String: Any] {
        return ["dsgArenaWithdrawJoinRequestEvent": ["table": table, "time": 0]]
    }

    static func accept(table: Int, player: String) -> [String: Any] {
        return ["dsgArenaAcceptTableJoinEvent": ["table": table, "playerToAccept": player, "time": 0] as [String: Any]]
    }

    static func reject(table: Int, player: String) -> [String: Any] {
        return ["dsgArenaRejectTableJoinEvent": ["table": table, "playerToReject": player, "time": 0] as [String: Any]]
    }
}

enum ArenaText {
    /// The confirm shown before withdrawing (spec C3).
    static func withdrawConfirm(table: Int) -> String {
        return String(format: NSLocalizedString("Withdraw your request to table %ld? You won't be able to request it again until its next game.", comment: "arena withdraw confirm"), table)
    }
}
