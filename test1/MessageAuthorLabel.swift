import Foundation

/// Sender label for a turn-based message entry, from the server's per-entry
/// author seat: "1"/"2", or "0" when the text already names its authors.
@objc final class MessageAuthorLabel: NSObject {
    /// " me: text", " <opponent>: text", " text" for named text,
    /// or nil for an unknown seat so the caller keeps its parity fallback.
    @objc(displayForSeat:iAmP1:opponentName:text:)
    static func display(forSeat seat: String?, iAmP1: Bool, opponentName: String, text: String) -> String? {
        switch seat {
        case "0": return " \(text)"
        case "1", "2": return isMine(forSeat: seat, iAmP1: iAmP1) ? " me: \(text)" : " \(opponentName): \(text)"
        default: return nil
        }
    }

    @objc(isMineForSeat:iAmP1:)
    static func isMine(forSeat seat: String?, iAmP1: Bool) -> Bool {
        return (seat == "1" && iAmP1) || (seat == "2" && !iAmP1)
    }
}
