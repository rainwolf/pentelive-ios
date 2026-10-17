import XCTest
@testable import penteLive

final class MessageThreadTests: XCTestCase {

    private let withReplyTo = """
    {"success":true,
     "message":{"mid":20,"replyToMid":10,"from":"bob","to":"alice","subject":"Re: hi","body":"line1\\nline2 <b>x</b>","date":1700000100000,"read":false},
     "replyTo":{"mid":10,"replyToMid":0,"from":"alice","to":"bob","subject":"hi","body":"hello","date":1700000000000}}
    """

    private func parse(_ s: String?) -> MessageThread? {
        return MessageThread.parse(s?.data(using: .utf8))
    }

    func testSuccessWithReplyToParsesAndOrdersNewestFirst() {
        let t = parse(withReplyTo)
        XCTAssertNotNil(t)
        guard let t = t else { return }
        XCTAssertEqual(t.message.mid, 20)
        XCTAssertEqual(t.message.replyToMid, 10)
        XCTAssertEqual(t.message.from, "bob")
        XCTAssertEqual(t.message.body, "line1\nline2 <b>x</b>")
        XCTAssertEqual(t.message.dateMillis, 1700000100000)
        XCTAssertEqual(t.entries.count, 2)
        XCTAssertEqual(t.entries[0].mid, 20)
        XCTAssertEqual(t.entries[1].mid, 10)
        XCTAssertEqual(t.replyTo?.mid, 10)
    }

    func testSuccessWithNullReplyToHasSingleEntry() {
        let t = parse("""
        {"success":true,"message":{"mid":5,"replyToMid":0,"from":"bob","to":"alice","subject":"s","body":"b","date":1,"read":true},"replyTo":null}
        """)
        XCTAssertNotNil(t)
        XCTAssertNil(t?.replyTo)
        XCTAssertEqual(t?.entries.count, 1)
        XCTAssertEqual(t?.entries[0].mid, 5)
    }

    func testSuccessFalseIsFailure() {
        XCTAssertNil(parse(#"{"success":false,"error":"Message not found"}"#))
    }

    func testHtmlLoginPageIsFailure() {
        XCTAssertNil(parse(#"<html><body><form action="/gameServer/login">Login</form></body></html>"#))
    }

    func testEmptyOrSuccessWithoutMessageIsFailure() {
        XCTAssertNil(parse(""))
        XCTAssertNil(MessageThread.parse(nil))
        XCTAssertNil(parse(#"{"success":true}"#))
    }

    func testReadMissingOnReplyTo() {
        let t = parse(withReplyTo)
        XCTAssertEqual(t?.message.read, false)
        XCTAssertNil(t?.replyTo?.read)
    }

    func testMillisecondsConvertToDate() {
        let t = parse(withReplyTo)
        XCTAssertEqual(t?.message.date.timeIntervalSince1970 ?? 0, 1700000100.0, accuracy: 0.0001)
        XCTAssertEqual(t?.replyTo?.date.timeIntervalSince1970 ?? 0, 1700000000.0, accuracy: 0.0001)
    }
}
