import UIKit

@objc enum DBLoadState: Int {
    case idle, loading, loaded, empty, blocked, unauthorized, subscriptionRequired, failed, unsupported
}

/// ObjC-facing facade over the position-stats endpoint. Main-actor only:
/// all state and callbacks live on the main thread, so the stale-request
/// gate needs no locking.
@MainActor
@objc final class DBPositionService: NSObject {
    private let client: DBClient
    @objc let preferences: DBPreferences
    private let gate = DBRequestGate()
    private var statsTask: Task<Void, Never>?

    @objc var scope: String = "archive"
    var filters: DBFilters?
    @objc var onHeat: (([NSNumber: UIColor]) -> Void)?
    @objc var onStatsState: ((DBLoadState) -> Void)?
    private(set) var lastStats: DBPositionStats?
    private(set) var occupied: Set<Int> = []
    /// Game id of the current position (labels need its grid size).
    @objc private(set) var game: Int = 0

    init(client: DBClient, preferences: DBPreferences = .shared) {
        self.client = client
        self.preferences = preferences
        super.init()
    }

    /// No credentials: the server accepts the cookies the app's login request
    /// stored in the shared HTTPCookieStorage (Task 5 spike).
    @objc static func makeDefault() -> DBPositionService {
        let endpoint = DBEndpoint(useLocalhost: developmentEnabled(), credentials: nil)
        return DBPositionService(client: DBClient(endpoint: endpoint))
    }

    @objc func setLegacyFilters(p1Name: String?, p2Name: String?, p1Rating: String?, p2Rating: String?,
                                eitherSeat: Bool, winner: Int, after: Date?, before: Date?) {
        filters = DBLegacyFilterAdapter.filters(p1Name: p1Name, p2Name: p2Name, p1Rating: p1Rating,
                                                p2Rating: p2Rating, eitherSeat: eitherSeat,
                                                winner: winner, after: after, before: before)
    }

    @objc func positionDidChange(game: Int, moves: [NSNumber], occupied: [NSNumber]) {
        lastStats = nil
        self.game = game
        self.occupied = Set(occupied.map { $0.intValue })
        statsTask?.cancel()
        onHeat?([:])
        guard DBGameCatalog.isSupported(game) else {
            _ = gate.next(.stats) // supersede anything in flight
            onStatsState?(.unsupported)
            return
        }
        onStatsState?(.loading)
        let id = gate.next(.stats)
        let request = DBPositionStatsRequest(game: game, moves: moves.map { $0.intValue },
                                             scope: scope, filters: filters)
        statsTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let stats = try await self.client.positionStats(request)
                guard self.gate.isLatest(id, .stats) else { return }
                self.lastStats = stats
                self.onHeat?(self.currentHeat)
                if stats.blocked {
                    self.onStatsState?(.blocked)
                } else if self.displayedMoves().isEmpty {
                    self.onStatsState?(.empty)
                } else {
                    self.onStatsState?(.loaded)
                }
            } catch is CancellationError {
                return
            } catch {
                guard self.gate.isLatest(id, .stats) else { return }
                self.onStatsState?(DBPositionService.state(for: error))
            }
        }
    }

    @objc func recomputeHeat() {
        onHeat?(currentHeat)
    }

    @objc var currentHeat: [NSNumber: UIColor] {
        guard lastStats != nil else { return [:] }
        var out: [NSNumber: UIColor] = [:]
        for (cell, color) in DBHeatScale.colors(for: displayedMoves()) {
            out[NSNumber(value: cell)] = color
        }
        return out
    }

    func displayedMoves() -> [DBNextMove] {
        guard let s = lastStats else { return [] }
        let n = preferences.movesShown
        return DBHeatScale.displayed(s.nextMoves, occupied: occupied, limit: n > 0 ? n : nil)
    }

    private static func state(for error: Error) -> DBLoadState {
        switch error as? DBError {
        case .unauthorized: return .unauthorized
        case .subscriptionRequired: return .subscriptionRequired
        case .blocked: return .blocked
        default: return .failed
        }
    }
}
