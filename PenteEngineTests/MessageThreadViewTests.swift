import XCTest
@testable import penteLive

final class MessageThreadViewTests: XCTestCase {
    private let json = """
    {"success":true,"message":{"mid":20,"replyToMid":10,"from":"bob","to":"alice","subject":"Re: hi","body":"line1\\nline2 <b>x</b> &amp;","date":1700000100000,"read":false},"replyTo":{"mid":10,"replyToMid":0,"from":"alice","to":"bob","subject":"hi","body":"hello","date":1700000000000}}
    """

    private func thread() -> MessageThread {
        return MessageThread.parse(json.data(using: .utf8))!
    }

    private func fixedFormatter() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }

    func testOrderHeadersAndSeparator() {
        let t = thread()
        let f = fixedFormatter()
        let text = MessageThreadRenderer.attributedText(for: t, dateFormatter: f).string
        let expected = "bob \u{00B7} 2023-11-14 22:15\nline1\nline2 <b>x</b> &amp;\n\nalice \u{00B7} 2023-11-14 22:13\nhello"
        XCTAssertEqual(text, expected)
        XCTAssertFalse(text.contains("Re: hi"))
    }

    func testReceivedUsesLabelColorNoIndent() {
        let s = MessageThreadRenderer.attributedText(for: thread(), dateFormatter: fixedFormatter())
        let attrs = s.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual(attrs[.foregroundColor] as? UIColor, UIColor.label)
        XCTAssertNil(attrs[.paragraphStyle])
        XCTAssertNil(attrs[MessageThreadRenderer.quoteBarKey])
    }

    func testReplyUsesSecondaryColorIndentAndBar() {
        let s = MessageThreadRenderer.attributedText(for: thread(), dateFormatter: fixedFormatter())
        let idx = (s.string as NSString).range(of: "hello").location
        let attrs = s.attributes(at: idx, effectiveRange: nil)
        XCTAssertEqual(attrs[.foregroundColor] as? UIColor, UIColor.secondaryLabel)
        let p = attrs[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(p?.headIndent, 16)
        XCTAssertEqual(p?.firstLineHeadIndent, 16)
        XCTAssertNotNil(attrs[MessageThreadRenderer.quoteBarKey])
        // Bar covers the reply header too.
        let hdr = (s.string as NSString).range(of: "alice \u{00B7}").location
        XCTAssertNotNil(s.attribute(MessageThreadRenderer.quoteBarKey, at: hdr, effectiveRange: nil))
    }

    func testHeaderIsBold() {
        let s = MessageThreadRenderer.attributedText(for: thread(), dateFormatter: fixedFormatter())
        let font = s.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertTrue(font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? false)
    }

    func testBodyNotHTMLInterpreted() {
        let s = MessageThreadRenderer.attributedText(for: thread(), dateFormatter: fixedFormatter())
        XCTAssertTrue(s.string.contains("<b>x</b> &amp;"))
    }

    func testSingleMessageHasNoReplyOrSeparator() {
        let single = "{\"success\":true,\"message\":{\"mid\":1,\"replyToMid\":0,\"from\":\"a\",\"to\":\"b\",\"subject\":\"s\",\"body\":\"x\",\"date\":1700000000000,\"read\":true}}"
        let t = MessageThread.parse(single.data(using: .utf8))!
        let s = MessageThreadRenderer.attributedText(for: t, dateFormatter: fixedFormatter())
        XCTAssertEqual(s.string, "a \u{00B7} 2023-11-14 22:13\nx")
    }

    func testViewShowsThreadAndKeepsLinks() {
        let v = MessageThreadView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), textContainer: nil)
        v.show(thread())
        v.layoutIfNeeded()
        XCTAssertFalse(v.isEditable)
        XCTAssertTrue(v.isSelectable)
        XCTAssertTrue(v.dataDetectorTypes.contains(.link))
        XCTAssertTrue(v.text.contains("hello"))
    }

    func testViewDrawsOneBarBesideReplyOnly() {
        let v = MessageThreadView(frame: CGRect(x: 0, y: 0, width: 320, height: 480), textContainer: nil)
        v.show(thread())
        v.layoutIfNeeded()
        XCTAssertEqual(v.quoteBarRects.count, 1)
        guard let bar = v.quoteBarRects.first else { return }
        // Bar sits in the indent gutter, below the received entry.
        let gutterStart = v.textContainerInset.left + v.textContainer.lineFragmentPadding
        XCTAssertGreaterThanOrEqual(bar.minX, gutterStart)
        XCTAssertLessThan(bar.maxX, gutterStart + MessageThreadRenderer.replyIndent)
        XCTAssertGreaterThan(bar.minY, v.textContainerInset.top + UIFontMetrics(forTextStyle: .body).scaledFont(for: UIFont.systemFont(ofSize: 18)).lineHeight)
        XCTAssertGreaterThan(bar.height, 0)

        let single = "{\"success\":true,\"message\":{\"mid\":1,\"replyToMid\":0,\"from\":\"a\",\"to\":\"b\",\"subject\":\"s\",\"body\":\"x\",\"date\":1,\"read\":true},\"replyTo\":null}"
        v.show(MessageThread.parse(single.data(using: .utf8))!)
        v.layoutIfNeeded()
        XCTAssertTrue(v.quoteBarRects.isEmpty)
    }
}
