//
//  ArenaJoinRequestListModel.swift
//  penteLive
//
//  Owner-side arena request list state (spec C2). Applies server snapshots behind a
//  400 ms freeze and keeps the list interactive for at least 1000 ms after every
//  apply, so rows never move under a finger and a burst cannot lock the owner out.
//  Main-thread only. Time comes from the injected `schedule`, so tests use a fake clock.
//

import Foundation

final class ArenaJoinRequestListModel {
    typealias Schedule = (_ delay: TimeInterval, _ work: @escaping () -> Void) -> Void

    static let freezeDuration: TimeInterval = 0.4
    static let interactiveWindow: TimeInterval = 1.0
    static let mainQueueSchedule: Schedule = { delay, work in
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private enum Phase {
        case idle // interactive, no window running
        case frozen // spinner up, taps ignored; `held` is applied when the freeze ends
        case window // interactive; snapshots wait in `held` until the window ends
    }

    /// The rows on screen, in `seq` order. Empty means the list is hidden.
    private(set) var rows: [ArenaJoinRequest] = []
    /// The player whose accept or decline waits for the server's snapshot.
    private(set) var inFlightPlayer: String?
    /// Called after every change to `rows`, `isFrozen` or `inFlightPlayer`.
    var onChange: (() -> Void)?

    private var phase = Phase.idle
    private var held: [ArenaJoinRequest]?
    private var lastReceivedPlayers = Set<String>()
    private var timerToken = 0
    private let schedule: Schedule

    init(schedule: @escaping Schedule = ArenaJoinRequestListModel.mainQueueSchedule) {
        self.schedule = schedule
    }

    var isVisible: Bool {
        !rows.isEmpty
    }

    var isFrozen: Bool {
        phase == .frozen
    }

    var isInteractive: Bool {
        phase != .frozen && inFlightPlayer == nil
    }

    /// Takes the newest snapshot for this table, already in `seq` order (ArenaInbound sorts).
    /// Returns true when it names a player the previous snapshot did not (the new-request cue).
    @discardableResult
    func receive(_ snapshot: [ArenaJoinRequest]) -> Bool {
        let players = Set(snapshot.map { $0.player })
        let hasNewPlayer = !players.subtracting(lastReceivedPlayers).isEmpty
        lastReceivedPlayers = players
        switch phase {
        case .frozen:
            held = snapshot
        case .window:
            if isVisible {
                held = snapshot
            } else {
                open(with: snapshot)
            }
        case .idle:
            if isVisible {
                freeze(holding: snapshot)
            } else {
                open(with: snapshot)
            }
        }
        onChange?()
        return hasNewPlayer
    }

    /// Marks `player`'s row in flight before an accept or decline is sent. Returns false,
    /// and the caller sends nothing, while the list is not interactive or has no such row.
    func beginAction(on player: String) -> Bool {
        guard isInteractive, rows.contains(where: { $0.player == player }) else { return false }
        inFlightPlayer = player
        onChange?()
        return true
    }

    /// The popover is presenting. When presenting came after the opening freeze ended (it had to
    /// be retried), freeze again so no row can be tapped the instant it appears (controller ruling:
    /// present = freeze start). A freeze already running covers the appearance, so it is kept as is.
    /// An in-flight action already locks the list, and only the server's answer may end it.
    func freezeForPresenting() {
        guard isVisible, !isFrozen, inFlightPlayer == nil else { return }
        freeze(holding: held ?? rows)
        onChange?()
    }

    /// Clears everything and turns pending timers into no-ops (table left or filled).
    func reset() {
        timerToken += 1
        rows = []
        held = nil
        inFlightPlayer = nil
        lastReceivedPlayers = []
        phase = .idle
        onChange?()
    }

    /// A snapshot reaches a hidden list: its rows exist at once (the popover presents) but the
    /// list opens frozen, so no row can be tapped the instant it appears (controller ruling:
    /// present = freeze start). An empty snapshot just applies, there is nothing to show.
    private func open(with snapshot: [ArenaJoinRequest]) {
        guard !snapshot.isEmpty else {
            apply(snapshot)
            return
        }
        rows = snapshot
        inFlightPlayer = nil
        freeze(holding: snapshot)
    }

    private func freeze(holding snapshot: [ArenaJoinRequest]) {
        phase = .frozen
        held = snapshot
        startTimer(after: ArenaJoinRequestListModel.freezeDuration) { $0.endFreeze() }
    }

    /// Shows `snapshot`, ends any in-flight action (this is the server's answer) and opens the window.
    private func apply(_ snapshot: [ArenaJoinRequest]) {
        rows = snapshot
        held = nil
        inFlightPlayer = nil
        phase = .window
        startTimer(after: ArenaJoinRequestListModel.interactiveWindow) { $0.endWindow() }
    }

    private func endFreeze() {
        apply(held ?? rows)
        onChange?()
    }

    private func endWindow() {
        guard let next = held else {
            phase = .idle
            return
        }
        if isVisible {
            freeze(holding: next)
        } else {
            apply(next)
        }
        onChange?()
    }

    /// Only the most recently started timer may fire; reset() and newer timers cancel older ones.
    private func startTimer(after delay: TimeInterval, _ fire: @escaping (ArenaJoinRequestListModel) -> Void) {
        timerToken += 1
        let token = timerToken
        schedule(delay) { [weak self] in
            guard let self = self, self.timerToken == token else { return }
            fire(self)
        }
    }
}

/// What the table screen does with the request popover after a model change or appearance.
enum ArenaPopoverStep: Equatable {
    case nothing, present, dismiss, retryLater
}

extension ArenaJoinRequestListModel {
    /// The popover is up exactly while the list has rows (spec C2), and is never presented twice.
    /// - isPresented: our popover is up.
    /// - isOnScreen: the table screen is in a window; when it is not, viewDidAppear asks again.
    /// - isAnotherPresentationUp: something is presented on the table screen (another sheet,
    ///   or our own popover still animating out), so presenting must be retried shortly.
    static func popoverStep(hasRows: Bool, isPresented: Bool, isOnScreen: Bool, isAnotherPresentationUp: Bool) -> ArenaPopoverStep {
        guard hasRows else { return isPresented ? .dismiss : .nothing }
        if isPresented || !isOnScreen {
            return .nothing
        }
        return isAnotherPresentationUp ? .retryLater : .present
    }
}
