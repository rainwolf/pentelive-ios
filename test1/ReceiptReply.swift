import Foundation

/// What pente.org's iOSReceiptValidation reply means. Every valid-receipt
/// reply contains "success", so older clients keep treating it as one.
@objc enum ReceiptReplyKind: Int {
    /// "success": a new purchase, the server thanked the subscriber.
    case newPurchase
    /// "success:renewal": a renewal or extension was recorded.
    case renewal
    /// "success:known": this transaction was already recorded for this player.
    case known
    /// "success:shared": the transaction is recorded under another player.
    case shared
    /// "invalid receipt": no valid purchase in the receipt.
    case invalid
    /// No reply or an unrecognised one: the POST should be retried.
    case failed
}

@objc final class ReceiptReply: NSObject {
    @objc(kindForReply:)
    static func kind(forReply reply: String?) -> ReceiptReplyKind {
        guard let reply = reply else { return .failed }
        if reply.contains("success") {
            if reply.contains("success:renewal") { return .renewal }
            if reply.contains("success:shared") { return .shared }
            // "success:known", and any variant a newer server adds, is
            // already recorded: never thank the subscriber again.
            if reply.contains("success:") { return .known }
            return .newPurchase
        }
        if reply.contains("invalid receipt") { return .invalid }
        return .failed
    }
}
