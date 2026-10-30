import Foundation
import StoreKit
import UIKit

// MARK: - pente.org

/// The URL of /gameServer/appStorePurchase (spec 4). `useLocalhost` defaults
/// to the app's dev flag, like `DashboardEndpoint`, so the local stack can be
/// tested; tests pass it explicitly.
struct StoreEndpoint {
    let useLocalhost: Bool

    init(useLocalhost: Bool = developmentEnabled()) {
        self.useLocalhost = useLocalhost
    }

    var url: URL {
        URL(string: (useLocalhost ? "https://localhost" : "https://www.pente.org") + "/gameServer/appStorePurchase")!
    }

    /// The store info of the logged-in account (session cookie).
    func infoRequest() -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    /// `signedTransaction=<jwsRepresentation>`, form-encoded.
    func postRequest(signedTransaction: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(("signedTransaction=" + Self.formEncode(signedTransaction)).utf8)
        return request
    }

    /// Percent-encodes everything but the RFC 3986 unreserved characters.
    static func formEncode(_ value: String) -> String {
        let unreserved = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        return value.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }
}

/// One HTTP exchange: the status code (nil without a response) and the body.
typealias StoreTransport = (URLRequest) async -> (statusCode: Int?, body: Data?)

/// `StoreServerClient` over `PenteHTTPClient`, whose shared session carries
/// the login cookie. It follows redirects, so an expired session arrives as
/// the login page with HTTP 200: only the exact JSON or reply strings count.
@MainActor
final class PenteStoreServer: StoreServerClient {
    private let endpoint: StoreEndpoint
    private let transport: StoreTransport

    init(endpoint: StoreEndpoint = StoreEndpoint(),
         transport: @escaping StoreTransport = PenteStoreServer.penteHTTPClient) {
        self.endpoint = endpoint
        self.transport = transport
    }

    func fetchInfo(username: String) async -> StoreInfoResult {
        let answer = await transport(endpoint.infoRequest())
        return Self.infoResult(statusCode: answer.statusCode, body: answer.body, username: username)
    }

    func post(signedTransaction: String) async -> StoreReply {
        let answer = await transport(endpoint.postRequest(signedTransaction: signedTransaction))
        return StoreReply.parse(statusCode: answer.statusCode, body: answer.body)
    }

    /// HTTP 401: the session is gone. HTTP 200 with a body `StoreInfo` can
    /// parse: info. Anything else (the login page included): failed.
    nonisolated static func infoResult(statusCode: Int?, body: Data?, username: String) -> StoreInfoResult {
        if statusCode == 401 { return .sessionLost }
        guard statusCode == 200, let body = body,
              let info = StoreInfo.parse(body, username: username) else { return .failed }
        return .info(info)
    }

    nonisolated static func penteHTTPClient(_ request: URLRequest) async -> (statusCode: Int?, body: Data?) {
        await withCheckedContinuation { continuation in
            PenteHTTPClient.send(request) { data, response, _ in
                continuation.resume(returning: ((response as? HTTPURLResponse)?.statusCode, data))
            }
        }
    }
}

// MARK: - StoreKit 2

/// The thin StoreKit 2 adapter. It decides nothing: it buys with the token it
/// is given, reports every transaction (verified or not) with its
/// `jwsRepresentation`, and finishes only what `StoreService` tells it to.
/// Transactions seen on `Transaction.updates` or returned by a purchase are
/// kept until finished and reported by `unfinished()`, so a revocation of an
/// already finished transaction still reaches the resync (spec 5.1).
@MainActor
final class StoreKitTransactionSource: TransactionSource {
    private var productsByID: [String: Product] = [:]
    private var pending: [UInt64: VerificationResult<Transaction>] = [:]
    /// `finishedKey`s of the transactions this adapter finished.
    private var finished: Set<String> = []
    private var updatesTask: Task<Void, Never>?

    deinit {
        updatesTask?.cancel()
    }

    var canMakePayments: Bool { AppStore.canMakePayments }

    func products(for ids: [String]) async -> [StoreProductInfo] {
        do {
            let products = try await Product.products(for: ids)
            for product in products {
                productsByID[product.id] = product
            }
            return products.map { StoreProductInfo(id: $0.id, displayPrice: $0.displayPrice) }
        } catch {
            NSLog("StoreKitTransactionSource: product query failed: %@", error.localizedDescription)
            return []
        }
    }

    func purchase(productID: String, token: UUID, scene: UIWindowScene?) async -> PurchaseOutcome {
        guard let product = await product(productID) else { return .failed }
        let options: Set<Product.PurchaseOption> = [.appAccountToken(token)]
        do {
            let result: Product.PurchaseResult
            if #available(iOS 17.0, *), let scene = scene {
                result = try await product.purchase(confirmIn: scene, options: options)
            } else {
                result = try await product.purchase(options: options)
            }
            switch result {
            case .success(let verification):
                pending[verification.unsafePayloadValue.id] = verification
                return .transaction(Self.storeTransaction(verification))
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed
            }
        } catch StoreKitError.userCancelled {
            return .cancelled
        } catch let error as SKError where error.code == .paymentCancelled {
            return .cancelled
        } catch {
            NSLog("StoreKitTransactionSource: purchase of %@ failed: %@", productID, error.localizedDescription)
            return .failed
        }
    }

    func unfinished() async -> [StoreTransaction] {
        var results = pending
        for await result in Transaction.unfinished {
            results[result.unsafePayloadValue.id] = result
        }
        return results.keys.sorted().compactMap { results[$0] }.map(Self.storeTransaction)
    }

    func latestEntitlements() async -> [StoreTransaction] {
        var transactions: [StoreTransaction] = []
        for await result in Transaction.currentEntitlements {
            transactions.append(Self.storeTransaction(result))
        }
        return transactions
    }

    func finish(_ transactionID: UInt64) async {
        if let result = pending.removeValue(forKey: transactionID) {
            finished.insert(Self.finishedKey(result.unsafePayloadValue))
            await result.unsafePayloadValue.finish()
        }
        for await result in Transaction.unfinished where result.unsafePayloadValue.id == transactionID {
            finished.insert(Self.finishedKey(result.unsafePayloadValue))
            await result.unsafePayloadValue.finish()
        }
    }

    func sync() async throws {
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            throw StoreSyncError.cancelled
        } catch {
            throw StoreSyncError.failed
        }
    }

    func startListening(_ onUpdate: @escaping @MainActor () -> Void) {
        guard updatesTask == nil else { return }
        updatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let source = self else { return }
                guard await source.record(result) else { continue }
                await onUpdate()
            }
        }
    }

    /// Ends the Transaction.updates listener (tests, so one test's listener
    /// never acts on the next test's transactions).
    func stopListening() {
        updatesTask?.cancel()
        updatesTask = nil
    }

    func showManageSubscriptions(in scene: UIWindowScene) async -> Bool {
        do {
            try await AppStore.showManageSubscriptions(in: scene)
            return true
        } catch {
            return false
        }
    }

    /// Keeps an update until it is finished. False, and nothing kept, for an
    /// unchanged copy of a transaction this adapter already finished: StoreKit
    /// can deliver a purchase on `Transaction.updates` after `purchase` returned
    /// it and it was posted and finished (StoreKit Testing, iOS 27.2 simulator).
    /// Kept, that copy would be posted a second time.
    private func record(_ result: VerificationResult<Transaction>) -> Bool {
        let transaction = result.unsafePayloadValue
        guard !finished.contains(Self.finishedKey(transaction)) else { return false }
        pending[transaction.id] = result
        return true
    }

    /// One state of a transaction: a revocation is a new state, so it is never
    /// mistaken for the copy finished before it. The purchase date is in the
    /// key because StoreKit Testing gives every transaction id 0.
    private nonisolated static func finishedKey(_ transaction: Transaction) -> String {
        "\(transaction.id)@\(transaction.purchaseDate.timeIntervalSince1970)"
            + "/\(transaction.revocationDate?.timeIntervalSince1970 ?? 0)"
    }

    private func product(_ id: String) async -> Product? {
        if let product = productsByID[id] { return product }
        _ = await products(for: [id])
        return productsByID[id]
    }

    /// Verified or not, the transaction is reported with its JWS: the server
    /// verifies it itself (a local failure can be a clock or chain problem).
    nonisolated static func storeTransaction(_ result: VerificationResult<Transaction>) -> StoreTransaction {
        let transaction = result.unsafePayloadValue
        let verified: Bool
        if case .verified = result {
            verified = true
        } else {
            verified = false
        }
        return StoreTransaction(id: transaction.id, productID: transaction.productID,
                                jws: result.jwsRepresentation, verified: verified,
                                isRevoked: transaction.revocationDate != nil)
    }
}

// MARK: - Clock, messages, host

@MainActor
final class SystemStoreClock: StoreClock {
    func now() -> Date { Date() }

    func schedule(after seconds: TimeInterval, _ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
            work()
        }
    }
}

/// The app's existing alert style (spec 5.3).
@MainActor
final class AlertStoreMessageSink: StoreMessageSink {
    func show(_ message: StoreMessage) {
        PenteAlert.show(withTitle: nil, message: message.text,
                        cancelButtonTitle: NSLocalizedString("OK", comment: ""))
    }
}

/// The app around the Store: the logged-in account is the username taken at
/// login (`loggedInUsername`, set by `setLoggedIn:`) while the root
/// navigation controller says `loggedIn` (spec 5.1 "Session"). Not the live
/// `username` default: Settings saves that field on every keystroke, before
/// Login is tapped.
@MainActor
final class AppStoreHost: StoreHost {
    private let navigation: () -> PenteNavigationViewController?
    private let notificationCenter: NotificationCenter

    init(navigation: @escaping () -> PenteNavigationViewController? = { AppDelegate.rootNavigationController() },
         notificationCenter: NotificationCenter = .default) {
        self.navigation = navigation
        self.notificationCenter = notificationCenter
    }

    var username: String? {
        guard let nav = navigation(), nav.loggedIn,
              let name = nav.loggedInUsername, !name.isEmpty else { return nil }
        return name.lowercased()
    }

    var isInForeground: Bool { UIApplication.shared.applicationState != .background }

    /// HTTP 401: logged out until the games list logs in again, which posts
    /// what is still unfinished (Task 9 wires the observer).
    func sessionLost() {
        navigation()?.loggedIn = false
        notificationCenter.post(name: StoreService.sessionLostNotification, object: nil)
    }

    /// The games list refreshes the dashboard, so `PentePlayer.subscriber`
    /// follows (Task 9 wires the observer).
    func entitlementsChanged() {
        notificationCenter.post(name: StoreService.entitlementsChangedNotification, object: nil)
    }
}

extension StoreService {
    /// The app's one service, over the real adapters.
    @objc static let shared = StoreService(server: PenteStoreServer(),
                                           source: StoreKitTransactionSource(),
                                           clock: SystemStoreClock(),
                                           messages: AlertStoreMessageSink(),
                                           host: AppStoreHost(),
                                           defaults: .standard)
}
