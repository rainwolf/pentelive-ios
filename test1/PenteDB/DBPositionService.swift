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
    private var gamesTask: Task<Void, Never>?
    private var gamesLoading = false
    /// Position the games list was last requested for (page 2+ reuses it).
    private var gamesRequest: (game: Int, moves: [Int])?

    private let filterStore: DBFilterStore
    /// Applied filters, loaded from the store (same defaults as `preferences`).
    var filterState: DBFilterState
    /// Wire filters and scope are derived per request, so the
    /// `DBCapabilities.extendedFilters` gate is read at request time.
    var filters: DBFilters? { filterState.toWire() }
    @objc var scope: String { filterState.scope }
    @objc var filterGameId: Int { filterState.gameId }
    @objc var filterChipSummary: String { filterState.chipSummary() }
    private lazy var autocomplete = DBPlayerAutocomplete(client: client)
    @objc var onHeat: (([NSNumber: UIColor]) -> Void)?
    @objc var onStatsState: ((DBLoadState) -> Void)?
    @objc var onGamesChanged: (() -> Void)?
    @objc var onGamesState: ((DBLoadState) -> Void)?
    private(set) var pager = DBGamesPager()
    /// True while the state last reported through `onGamesState` belongs to a
    /// "Show more" page rather than the first page. Read it inside the callback.
    @objc private(set) var gamesStateIsLoadMore = false
    private(set) var lastStats: DBPositionStats?
    private(set) var occupied: Set<Int> = []
    /// Game id of the current position (labels need its grid size).
    @objc private(set) var game: Int = 0

    init(client: DBClient, preferences: DBPreferences = .shared) {
        self.client = client
        self.preferences = preferences
        filterStore = DBFilterStore(defaults: preferences.defaults)
        filterState = filterStore.load()
        super.init()
    }

    /// No credentials: the server accepts the cookies the app's login request
    /// stored in the shared HTTPCookieStorage (Task 5 spike).
    @objc static func makeDefault() -> DBPositionService {
        let endpoint = DBEndpoint(useLocalhost: developmentEnabled(), credentials: nil)
        return DBPositionService(client: DBClient(endpoint: endpoint))
    }

    /// The game viewer shares this service's client (and its cookie auth).
    @objc func makeGameViewer(gid: Int64) -> DBGameViewerViewController {
        DBGameViewerViewController(gid: gid, client: client)
    }

    /// "To DB" from a live game: a supported game becomes the saved filter
    /// game (legacy wrote `DBGame` in BoardViewController.toDB). Go, Renju
    /// and nil leave the filters alone.
    @objc func adoptInjectedGame(_ name: String?) {
        let id = DBGameCatalog.gameId(forName: name)
        guard DBGameCatalog.isSupported(id) else { return }
        filterState.setGame(id: id)
        filterStore.save(filterState)
    }

    /// Saves and adopts `state`. Returns true when the game id changed.
    @discardableResult
    func applyFilters(_ state: DBFilterState) -> Bool {
        let changed = state.gameId != filterState.gameId
        filterStore.save(state)
        filterState = state
        return changed
    }

    /// The filters sheet over the applied state. Apply saves through
    /// `applyFilters`, then tells the host whether the game changed.
    @objc func makeFiltersViewController(regularWidth: Bool,
                                         onApplied: @escaping (Bool) -> Void) -> UIViewController {
        let vc = DBFiltersViewController(applied: filterState, autocomplete: autocomplete)
        vc.onApply = { [weak self] state in
            guard let self = self else { return }
            onApplied(self.applyFilters(state))
        }
        vc.configurePresentation(regularWidth: regularWidth)
        return vc
    }

    @objc func positionDidChange(game: Int, moves: [NSNumber], occupied: [NSNumber]) {
        lastStats = nil
        self.game = game
        self.occupied = Set(occupied.map { $0.intValue })
        statsTask?.cancel()
        gamesTask?.cancel()
        onHeat?([:])
        pager.reset()
        gamesRequest = nil
        gamesLoading = false
        onGamesChanged?()
        guard DBGameCatalog.isSupported(game) else {
            _ = gate.next(.stats) // supersede anything in flight
            _ = gate.next(.games)
            onStatsState?(.unsupported)
            gamesStateIsLoadMore = false
            onGamesState?(.unsupported)
            return
        }
        onStatsState?(.loading)
        gamesRequest = (game, moves.map { $0.intValue })
        fetchGames(offset: 0)
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

    private func fetchGames(offset: Int) {
        guard let req = gamesRequest else { return }
        gamesTask?.cancel()
        let isLoadMore = offset > 0
        let id = gate.next(.games)
        gamesStateIsLoadMore = isLoadMore
        gamesLoading = true
        onGamesState?(.loading)
        let request = DBGameSearchRequest(game: req.game, moves: req.moves, scope: scope, filters: filters,
                                          offset: offset, limit: DBGamesPager.pageSize)
        gamesTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let result = try await self.client.searchGames(request)
                guard self.gate.isLatest(id, .games) else { return }
                self.gamesLoading = false
                self.gamesStateIsLoadMore = isLoadMore
                if result.blocked {
                    self.onGamesState?(.blocked)
                    return
                }
                self.pager.apply(result, offset: offset)
                self.onGamesChanged?()
                self.onGamesState?(self.pager.total == 0 ? .empty : .loaded)
            } catch is CancellationError {
                return
            } catch {
                guard self.gate.isLatest(id, .games) else { return }
                self.gamesLoading = false
                // A failed page keeps the rows already loaded.
                self.gamesStateIsLoadMore = isLoadMore
                self.onGamesState?(DBPositionService.state(for: error))
            }
        }
    }

    /// Fetches the next page ("Show more"). No-op while a fetch is in
    /// flight, when everything is loaded, or before any position is set.
    @objc func loadMoreGames() {
        guard gamesRequest != nil, pager.hasMore, !gamesLoading else { return }
        fetchGames(offset: pager.nextOffset)
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
