import XCTest
@testable import penteLive

final class MessageReplyInputTests: XCTestCase {
    private var vc: UIViewController!
    private var tv: UITextView!

    override func setUp() {
        super.setUp()
        let cls = NSClassFromString("MessagesViewController") as! UIViewController.Type
        vc = cls.init()
        vc.loadViewIfNeeded()
        tv = vc.value(forKey: "replyMessageView") as? UITextView
    }

    override func tearDown() {
        tv = nil
        vc = nil
        super.tearDown()
    }

    /// Calls the delegate, then applies UIKit's default edit when it returns YES.
    @discardableResult
    private func type(_ text: String, at range: NSRange, into initial: String) -> Bool {
        tv.text = initial
        tv.selectedRange = NSRange(location: range.location, length: range.length)
        let delegate = vc as! UITextViewDelegate
        let allow = delegate.textView?(tv, shouldChangeTextIn: range, replacementText: text) ?? true
        if allow {
            let ns = (tv.text ?? "") as NSString
            if NSMaxRange(range) <= ns.length {
                tv.text = ns.replacingCharacters(in: range, with: text)
            }
        }
        return allow
    }

    func testTypingNearStartAllowedAndInserted() {
        XCTAssertTrue(type("x", at: NSRange(location: 0, length: 0), into: "hello world"))
        XCTAssertEqual(tv.text, "xhello world")
        XCTAssertTrue(type("x", at: NSRange(location: 1, length: 0), into: "hello world"))
        XCTAssertEqual(tv.text, "hxello world")
    }

    func testThirdSpaceAtEndBecomesNewline() {
        XCTAssertFalse(type(" ", at: NSRange(location: 4, length: 0), into: "ab  "))
        XCTAssertEqual(tv.text, "ab\n")
        XCTAssertEqual(tv.selectedRange, NSRange(location: 3, length: 0))
    }

    func testThirdSpaceInMiddleBecomesNewline() {
        XCTAssertFalse(type(" ", at: NSRange(location: 4, length: 0), into: "ab  cd"))
        XCTAssertEqual(tv.text, "ab\ncd")
        XCTAssertEqual(tv.selectedRange, NSRange(location: 3, length: 0))
    }

    func testReplacingSelectionHonoursRangeLength() {
        XCTAssertTrue(type("XY", at: NSRange(location: 2, length: 3), into: "hello world"))
        XCTAssertEqual(tv.text, "heXY world")
        // selection replaced by a space completing three spaces with neighbours
        XCTAssertFalse(type(" ", at: NSRange(location: 4, length: 2), into: "ab  QQcd"))
        XCTAssertEqual(tv.text, "ab\ncd")
    }

    func testPasteWithTripleSpacesAtStartAndEnd() {
        XCTAssertFalse(type("   x   ", at: NSRange(location: 0, length: 0), into: ""))
        XCTAssertEqual(tv.text, "\nx\n")
        XCTAssertEqual(tv.selectedRange, NSRange(location: 3, length: 0))
    }

    func testPasteCompletingSpacesBeforeIt() {
        XCTAssertFalse(type("  c", at: NSRange(location: 3, length: 0), into: "ab "))
        XCTAssertEqual(tv.text, "ab\nc")
        XCTAssertEqual(tv.selectedRange, NSRange(location: 4, length: 0))
    }

    func testTripleSpaceAfterEmojiKeepsCursorAfterNewline() {
        // "😀" is two UTF-16 units
        XCTAssertFalse(type(" ", at: NSRange(location: 4, length: 0), into: "😀  "))
        XCTAssertEqual(tv.text, "😀\n")
        XCTAssertEqual(tv.selectedRange, NSRange(location: 3, length: 0))
    }

    func testDeletionJoiningSpacesIsNotRewritten() {
        XCTAssertTrue(type("", at: NSRange(location: 3, length: 1), into: "a  x  b"))
        XCTAssertEqual(tv.text, "a    b")
        XCTAssertTrue(type("", at: NSRange(location: 0, length: 1), into: "abc"))
        XCTAssertEqual(tv.text, "bc")
    }

    func testMarkedTextIsNotRewritten() throws {
        tv.text = "ab"
        tv.selectedRange = NSRange(location: 2, length: 0)
        tv.setMarkedText("  ", selectedRange: NSRange(location: 2, length: 0))
        try XCTSkipIf(tv.markedTextRange == nil, "marked text unavailable off-screen")
        let before = tv.text
        let delegate = vc as! UITextViewDelegate
        XCTAssertTrue(delegate.textView?(tv, shouldChangeTextIn: NSRange(location: 2, length: 2), replacementText: "   ") ?? false)
        XCTAssertEqual(tv.text, before)
    }

    func testOutOfBoundsRangeReturnsYes() {
        tv.text = "abc"
        let delegate = vc as! UITextViewDelegate
        XCTAssertTrue(delegate.textView?(tv, shouldChangeTextIn: NSRange(location: 10, length: 0), replacementText: "x") ?? false)
        XCTAssertTrue(delegate.textView?(tv, shouldChangeTextIn: NSRange(location: 1, length: 9), replacementText: "x") ?? false)
        XCTAssertEqual(tv.text, "abc")
    }

    func testReturnKeyReturnsNo() {
        tv.text = "abc"
        let delegate = vc as! UITextViewDelegate
        XCTAssertFalse(delegate.textView?(tv, shouldChangeTextIn: NSRange(location: 3, length: 0), replacementText: "\n") ?? true)
        XCTAssertEqual(tv.text, "abc")
        XCTAssertFalse(tv.isFirstResponder)
    }
}
