import Foundation

/// One message in a thread, as returned by GET /gameServer/messageJson.
@objc final class MessageThreadEntry: NSObject, Decodable {
    @objc let mid: Int
    @objc let replyToMid: Int
    @objc let from: String
    @objc let to: String
    @objc let subject: String
    @objc let body: String
    let dateMillis: Int64
    /// Absent on the replyTo entry.
    let read: Bool?

    @objc var date: Date { Date(timeIntervalSince1970: TimeInterval(dateMillis) / 1000.0) }

    private enum CodingKeys: String, CodingKey {
        case mid, replyToMid, from, to, subject, body, read
        case dateMillis = "date"
    }
}

private struct MessageThreadResponse: Decodable {
    let success: Bool
    let error: String?
    let message: MessageThreadEntry?
    let replyTo: MessageThreadEntry?
}

/// Received message plus the viewer's own earlier message it answers (if any).
@objc final class MessageThread: NSObject {
    @objc let message: MessageThreadEntry
    @objc let replyTo: MessageThreadEntry?

    private init(message: MessageThreadEntry, replyTo: MessageThreadEntry?) {
        self.message = message
        self.replyTo = replyTo
    }

    /// Newest first: [message, replyTo?].
    @objc var entries: [MessageThreadEntry] {
        return replyTo.map { [message, $0] } ?? [message]
    }

    /// nil for nil/empty data, non-JSON (e.g. HTML login page), success:false or missing message.
    @objc static func parse(_ data: Data?) -> MessageThread? {
        guard let data = data, !data.isEmpty,
              let r = try? JSONDecoder().decode(MessageThreadResponse.self, from: data),
              r.success, let m = r.message else { return nil }
        return MessageThread(message: m, replyTo: r.replyTo)
    }
}
