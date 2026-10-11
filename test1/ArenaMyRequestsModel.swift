//
//  ArenaMyRequestsModel.swift
//  penteLive
//
//  Requester-side arena lobby state (spec C3): which tables carry the "Requested"
//  mark, and which taps wait for the server's dsgArenaMyRequestsEvent answer.
//  Main-thread only.
//

import Foundation

struct ArenaMyRequestsModel {
    enum TapAction: Equatable {
        case ignore // an answer for this table is still outstanding
        case request // send dsgArenaRequestJoinTableEvent
        case confirmWithdraw // ask before sending dsgArenaWithdrawJoinRequestEvent
    }

    /// Tables in the latest dsgArenaMyRequestsEvent.
    private(set) var requested = Set<Int>()
    /// Tables tapped since that event; further taps on them are ignored.
    private(set) var awaiting = Set<Int>()

    func isRequested(_ table: Int) -> Bool {
        return requested.contains(table)
    }

    func isAwaiting(_ table: Int) -> Bool {
        return awaiting.contains(table)
    }

    /// The server's full set. R11 answers every request and withdraw with one.
    mutating func apply(tables: [Int]) {
        requested = Set(tables)
        awaiting.removeAll()
    }

    mutating func tap(table: Int) -> TapAction {
        if awaiting.contains(table) {
            return .ignore
        }
        if requested.contains(table) {
            return .confirmWithdraw
        }
        awaiting.insert(table)
        return .request
    }

    /// Called when the withdraw confirm is accepted. Returns false, and the caller
    /// sends nothing, when an answer for this table is already outstanding.
    mutating func beginWithdraw(table: Int) -> Bool {
        guard !awaiting.contains(table) else { return false }
        awaiting.insert(table)
        return true
    }
}
