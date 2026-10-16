import Foundation

/// One reply of pente.org's /gameServer/appStorePurchase POST (spec 5.3).
/// Only an HTTP 200 whose trimmed body equals one of the server's strings
/// exactly is a reply (the servlet appends a newline). HTTP 401 means the
/// session is gone. Anything else (no response, another status, an HTML
/// page, an unknown string) is `noReply`.
enum StoreReply: Equatable {
    case success
    case renewal
    case known
    case shared
    case invalidReceipt
    case inactive
    case retryLater
    case noReply
    case sessionLost

    static func parse(statusCode: Int?, body: Data?) -> StoreReply {
        guard let statusCode = statusCode else { return .noReply }
        if statusCode == 401 { return .sessionLost }
        guard statusCode == 200, let body = body,
              let text = String(data: body, encoding: .utf8) else { return .noReply }
        switch text.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "success": return .success
        case "success:renewal": return .renewal
        case "success:known": return .known
        case "success:shared": return .shared
        case "invalid receipt": return .invalidReceipt
        case "inactive": return .inactive
        case "retry later": return .retryLater
        default: return .noReply
        }
    }

    /// The StoreKit transaction is finished on every server answer except
    /// `retry later`, and never without an answer (spec 4).
    var finishesTransaction: Bool {
        switch self {
        case .success, .renewal, .known, .shared, .invalidReceipt, .inactive: return true
        case .retryLater, .noReply, .sessionLost: return false
        }
    }

    var isSuccess: Bool {
        switch self {
        case .success, .renewal, .known, .shared: return true
        case .invalidReceipt, .inactive, .retryLater, .noReply, .sessionLost: return false
        }
    }

    /// Retried by the foreground backoff (spec 5.1). A lost session is not:
    /// the post-login resync sends it.
    var isRetryable: Bool { self == .retryLater || self == .noReply }

    /// The message for the reply to the explicit buy POST of a transaction
    /// (spec 5.3 table). Automatic resyncs show nothing.
    var buyMessage: StoreMessage {
        switch self {
        case .success, .renewal, .known: return .thankYou
        case .shared: return .shared
        case .invalidReceipt: return .purchaseFailed
        case .inactive: return .inactive
        case .retryLater, .noReply, .sessionLost: return .saved
        }
    }

    /// The one message a restore shows (spec 5.1, 5.3). `syncFailed` is an
    /// `AppStore.sync()` failure other than a cancelled Apple ID prompt.
    static func restoreMessage(for replies: [StoreReply], syncFailed: Bool) -> StoreMessage {
        if replies.isEmpty { return syncFailed ? .restoreFailed : .noPurchasesToRestore }
        if replies.contains(.shared) { return .shared }
        if replies.contains(where: { $0.isSuccess }) { return .upToDate }
        if replies.contains(where: { !$0.finishesTransaction }) { return .restoreFailed }
        return .noPurchasesToRestore
    }
}

/// Every message the Store shows, its text copied from the spec.
enum StoreMessage: Equatable {
    case thankYou
    case shared
    case purchaseFailed
    case inactive
    case saved
    case pending
    case couldNotReach
    case noPurchasesToRestore
    case upToDate
    case restoreFailed

    var text: String {
        switch self {
        case .thankYou:
            return NSLocalizedString("Thank you for your purchase!", comment: "")
        case .shared:
            return NSLocalizedString("This purchase is linked to another pente.org account.", comment: "")
        case .purchaseFailed:
            return NSLocalizedString("The purchase could not be completed. Please try again later.", comment: "")
        case .inactive:
            return NSLocalizedString("This subscription is no longer active.", comment: "")
        case .saved:
            return NSLocalizedString("Your purchase is saved and will be registered with pente.org shortly.", comment: "")
        case .pending:
            return NSLocalizedString("Your purchase is waiting for approval", comment: "")
        case .couldNotReach:
            return NSLocalizedString("Could not reach pente.org. Check your connection and try again.", comment: "")
        case .noPurchasesToRestore:
            return NSLocalizedString("No purchases to restore.", comment: "")
        case .upToDate:
            return NSLocalizedString("Your purchases are up to date.", comment: "")
        case .restoreFailed:
            return NSLocalizedString("Restore failed, please try again later.", comment: "")
        }
    }
}
