import Foundation
import UIKit

/// Buys, restores and reports App Store purchases to pente.org (spec 5.1).
///
/// Every transaction is posted as its StoreKit 2 `jwsRepresentation` to
/// /gameServer/appStorePurchase and finished only after the server answered
/// (spec 4). All POSTs go through one serial queue; a transaction already in
/// flight is never posted a second time concurrently, and a caller asking for
/// it joins the running POST. Nothing is bought or posted without a logged-in
/// pente.org session.
@MainActor
@objc final class StoreService: NSObject {
    /// Posted (object: the service) whenever state the Store screen shows changed.
    @objc static let didChangeNotification = Notification.Name("StoreServiceDidChange")
    /// Posted by the real host after a `success*` or a revocation; the games
    /// list refreshes the dashboard.
    @objc static let entitlementsChangedNotification = Notification.Name("StoreServiceEntitlementsChanged")
    /// Posted by the real host on HTTP 401; the games list logs in again.
    @objc static let sessionLostNotification = Notification.Name("StoreServiceSessionLost")

    static let retryDelays: [TimeInterval] = [30, 120, 600]
    static let migratedAccountsKey = "storeMigrationSweepAccounts"
    static let legacyFlagsClearedKey = "storeLegacyReceiptFlagsCleared"
    static let manageSubscriptionsURL =
        URL(string: "https://buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/manageSubscriptions")!
    /// At most one re-login per 5 min (minutes) after HTTP 401: the servlet
    /// also answers 401 when it cannot load the player (a database error), and
    /// a re-login that keeps getting 401 must not loop.
    static let sessionLostQuietPeriod: TimeInterval = 300

    let server: StoreServerClient
    let source: TransactionSource
    let clock: StoreClock
    let messages: StoreMessageSink
    let host: StoreHost
    let defaults: UserDefaults
    /// Opens the Manage subscription fallback URL; tests replace it.
    var openURL: (URL) -> Void = { UIApplication.shared.open($0, options: [:], completionHandler: nil) }

    private(set) var infoFailed = false
    private(set) var products: [StoreProductInfo] = []
    private(set) var productsLoaded = false
    private(set) var isBusy = false

    private var storedInfo: StoreInfo?
    private var started = false
    private var storeVisible = false
    private var sweepPending = false
    private var resyncRunning = false
    private var resyncRequested = false
    private var retryStep = 0
    private var retryScheduled = false
    private var queueTail: Task<Void, Never>?
    private var inFlight: [UInt64: Task<StoreReply, Never>] = [:]
    private var lastSessionLostAt: Date?

    init(server: StoreServerClient, source: TransactionSource, clock: StoreClock,
         messages: StoreMessageSink, host: StoreHost, defaults: UserDefaults) {
        self.server = server
        self.source = source
        self.clock = clock
        self.messages = messages
        self.host = host
        self.defaults = defaults
        super.init()
    }

    // MARK: - State the Store screen reads

    /// Store info of the logged-in account; never another account's.
    var info: StoreInfo? {
        guard let info = storedInfo, info.username == host.username else { return nil }
        return info
    }

    var isLoggedIn: Bool { host.username != nil }

    var canMakePayments: Bool { source.canMakePayments }

    func screenModel(calendar: Calendar = .current) -> StoreScreenModel {
        StoreScreenModel.make(loggedIn: isLoggedIn, info: info, infoFailed: infoFailed,
                              productsLoaded: productsLoaded, products: products,
                              canMakePayments: canMakePayments, busy: isBusy, now: clock.now(),
                              calendar: calendar)
    }

    // MARK: - Launch and session

    /// Called once at launch: starts the Transaction.updates listener (before
    /// login the updates stay unfinished and the post-login resync sends
    /// them), resyncs on every return to the foreground, and clears the old
    /// receipt-retry flags once.
    @objc func start() {
        guard !started else { return }
        started = true
        Self.clearLegacyReceiptFlags(in: defaults)
        source.startListening { [weak self] in
            self?.resync(explicit: false)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground),
                                               name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    /// `shouldSendReceipt` / `shouldRefreshReceipt` drove the StoreKit 1
    /// receipt retry; removed on the first launch of this version only.
    static func clearLegacyReceiptFlags(in defaults: UserDefaults) {
        guard !defaults.bool(forKey: legacyFlagsClearedKey) else { return }
        defaults.removeObject(forKey: "shouldSendReceipt")
        defaults.removeObject(forKey: "shouldRefreshReceipt")
        defaults.set(true, forKey: legacyFlagsClearedKey)
    }

    @objc private func applicationWillEnterForeground() {
        resync(explicit: false)
    }

    /// Called by PenteNavigationViewController whenever `loggedIn` changes.
    /// Clears the store info on login and on logout; after a login runs the
    /// post-login resync, with the migration sweep when this account has not
    /// had a `success*` reply on this device yet.
    @objc func sessionDidChange(loggedIn: Bool) {
        storedInfo = nil
        infoFailed = false
        retryStep = 0
        sweepPending = false
        if loggedIn, let user = host.username {
            sweepPending = !hasMigrated(user)
        }
        notifyChange()
        guard loggedIn else { return }
        resync(explicit: false)
        if storeVisible {
            Task { await self.loadInfo() }
        }
    }

    // MARK: - Store screen

    /// The Store screen appeared (true) or went away (false). Opening it
    /// loads info and products and resyncs (spec 5.1).
    func storeVisibilityChanged(_ visible: Bool) {
        let opened = visible && !storeVisible
        storeVisible = visible
        guard opened else { return }
        Task { await self.loadInfo() }
        Task { await self.loadProducts() }
        resync(explicit: false)
    }

    func loadInfo() async {
        guard let user = host.username else {
            notifyChange()
            return
        }
        let result = await server.fetchInfo(username: user)
        guard host.username == user else { return }
        switch result {
        case .info(let fresh):
            storedInfo = fresh
            infoFailed = false
        case .failed:
            infoFailed = true
        case .sessionLost:
            infoFailed = true
            _ = reportSessionLost()
        }
        notifyChange()
    }

    func loadProducts() async {
        products = await source.products(for: StoreProducts.all)
        productsLoaded = true
        notifyChange()
    }

    // MARK: - Buy

    /// Always GETs first, so the token belongs to the account logged in at
    /// this moment; no purchase without that GET.
    func buy(productID: String, scene: UIWindowScene?) async {
        guard !isBusy, let user = host.username else { return }
        isBusy = true
        notifyChange()
        defer {
            isBusy = false
            notifyChange()
        }

        let result = await server.fetchInfo(username: user)
        guard host.username == user else { return }
        guard case .info(let fresh) = result else {
            if result == .sessionLost { _ = reportSessionLost() }
            messages.show(.couldNotReach)
            return
        }
        storedInfo = fresh
        infoFailed = false
        notifyChange()

        switch await source.purchase(productID: productID, token: fresh.appAccountToken, scene: scene) {
        case .transaction(let transaction):
            let reply = await send(transaction)
            messages.show(reply.buyMessage)
            await handle([reply], for: [transaction], user: user)
        case .cancelled:
            break
        case .pending:
            messages.show(.pending) // arrives later on Transaction.updates
        case .failed:
            messages.show(.purchaseFailed)
        }
    }

    // MARK: - Resync and restore

    /// Posts what StoreKit holds. Automatic (`explicit: false`): only
    /// `Transaction.unfinished`, plus the once-per-account migration sweep of
    /// current entitlements after a login; silent; requests during a run
    /// coalesce into one follow-up run. Explicit: unfinished plus current
    /// entitlements (restore).
    @objc(resyncExplicit:) func resync(explicit: Bool) {
        Task { await self.performResync(explicit: explicit) }
    }

    func performResync(explicit: Bool) async {
        if explicit {
            _ = await runResync(explicit: true)
            return
        }
        if resyncRunning {
            resyncRequested = true
            return
        }
        resyncRunning = true
        repeat {
            resyncRequested = false
            _ = await runResync(explicit: false)
        } while resyncRequested
        resyncRunning = false
    }

    func restore() async {
        guard !isBusy, host.username != nil else { return }
        isBusy = true
        notifyChange()
        defer {
            isBusy = false
            notifyChange()
        }
        var syncFailed = false
        do {
            try await source.sync()
        } catch StoreSyncError.cancelled {
            return
        } catch {
            syncFailed = true
        }
        let replies = await runResync(explicit: true)
        messages.show(StoreReply.restoreMessage(for: replies, syncFailed: syncFailed))
    }

    private func runResync(explicit: Bool) async -> [StoreReply] {
        guard let user = host.username else { return [] }
        var transactions = await source.unfinished()
        let sweep = !explicit && sweepPending
        if sweep { sweepPending = false }
        if explicit || sweep {
            for entitlement in await source.latestEntitlements()
            where !transactions.contains(where: { $0.id == entitlement.id }) {
                transactions.append(entitlement)
            }
        }
        var replies: [StoreReply] = []
        for transaction in transactions {
            guard host.username == user else { break }
            replies.append(await send(transaction))
        }
        // An outage must not cost an old subscriber the sweep: try again on
        // the next resync of this session.
        if sweep, host.username == user, replies.contains(where: { $0.isRetryable }) {
            sweepPending = true
        }
        await handle(replies, for: Array(transactions.prefix(replies.count)), user: user)
        return replies
    }

    // MARK: - Serial POST queue

    /// Posts one transaction through the serial queue. A transaction already
    /// in flight is not posted again: the caller gets that POST's reply.
    func send(_ transaction: StoreTransaction) async -> StoreReply {
        if let running = inFlight[transaction.id] {
            return await running.value
        }
        let previous = queueTail
        let task = Task { @MainActor () -> StoreReply in
            _ = await previous?.value
            return await self.post(transaction)
        }
        inFlight[transaction.id] = task
        queueTail = Task { @MainActor in _ = await task.value }
        let reply = await task.value
        if inFlight[transaction.id] == task {
            inFlight[transaction.id] = nil
        }
        return reply
    }

    private func post(_ transaction: StoreTransaction) async -> StoreReply {
        // Session lost between the purchase sheet and the POST: leave it
        // unfinished for the post-login resync.
        guard host.username != nil else { return .sessionLost }
        let reply = await server.post(signedTransaction: transaction.jws)
        if reply.finishesTransaction {
            await source.finish(transaction.id)
        }
        // A second 401 soon after a re-login is not a lost session: back off
        // as for no reply instead of logging in again.
        if reply == .sessionLost, !reportSessionLost() {
            return .noReply
        }
        return reply
    }

    /// HTTP 401: the host logs in again, at most once per
    /// `sessionLostQuietPeriod`. False when this 401 was not reported.
    private func reportSessionLost() -> Bool {
        let now = clock.now()
        if let last = lastSessionLostAt, now.timeIntervalSince(last) < Self.sessionLostQuietPeriod {
            return false
        }
        lastSessionLostAt = now
        host.sessionLost()
        return true
    }

    private func handle(_ replies: [StoreReply], for transactions: [StoreTransaction], user: String) async {
        let succeeded = replies.contains { $0.isSuccess }
        let revoked = zip(transactions, replies).contains { pair in
            pair.0.isRevoked && pair.1.finishesTransaction
        }
        if succeeded {
            markMigrated(user)
        }
        if replies.contains(where: { $0.isRetryable }) {
            scheduleRetry()
        } else if !replies.contains(.sessionLost) {
            retryStep = 0
        }
        if succeeded || revoked {
            host.entitlementsChanged()
            await loadInfo()
        }
    }

    // MARK: - Foreground retry

    /// 30 s, 2 min, 10 min after a `retry later`, a network error or an
    /// unrecognised reply, while the app is in the foreground; after that the
    /// login, foreground, Store-open and update triggers take over.
    private func scheduleRetry() {
        guard !retryScheduled, retryStep < Self.retryDelays.count else { return }
        retryScheduled = true
        let delay = Self.retryDelays[retryStep]
        retryStep += 1
        clock.schedule(after: delay) { [weak self] in
            guard let self = self else { return }
            self.retryScheduled = false
            guard self.host.isInForeground else { return }
            self.resync(explicit: false)
        }
    }

    // MARK: - Manage subscription

    func manageSubscriptions(in scene: UIWindowScene?) async {
        if let scene = scene, await source.showManageSubscriptions(in: scene) {
            return
        }
        openURL(Self.manageSubscriptionsURL)
    }

    // MARK: - Helpers

    private func hasMigrated(_ user: String) -> Bool {
        (defaults.stringArray(forKey: Self.migratedAccountsKey) ?? []).contains(user)
    }

    private func markMigrated(_ user: String) {
        var accounts = defaults.stringArray(forKey: Self.migratedAccountsKey) ?? []
        guard !accounts.contains(user) else { return }
        accounts.append(user)
        defaults.set(accounts, forKey: Self.migratedAccountsKey)
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
