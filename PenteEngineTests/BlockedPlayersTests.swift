import XCTest
@testable import penteLive

final class BlockedPlayersTests: XCTestCase {
    private func entry(_ pid: Int64, _ name: String, invite: Bool, chat: Bool) -> IgnoreEntry {
        IgnoreEntry(ignorePid: pid, name: name, ignoreInvite: invite, ignoreChat: chat)
    }

    func testParseValid() {
        let json = #"{"success":true,"ignores":[{"ignorePid":5,"name":"graviton","ignoreInvite":true,"ignoreChat":false}]}"#
        let entries = BlockedPlayers.parse(Data(json.utf8))
        XCTAssertEqual(entries?.count, 1)
        XCTAssertEqual(entries?.first?.ignorePid, 5)
    }

    func testParseNameColorAndCrown() {
        let json = #"{"success":true,"ignores":[{"ignorePid":5,"name":"graviton","ignoreInvite":true,"ignoreChat":false,"nameColor":16711680,"tourneyWinner":2}]}"#
        let e = BlockedPlayers.parse(Data(json.utf8))?.first
        XCTAssertEqual(e?.nameColor, 16711680)
        XCTAssertEqual(e?.tourneyWinner, 2)
    }

    func testParseWithoutStyleFieldsDefaultsZero() {
        let json = #"{"success":true,"ignores":[{"ignorePid":5,"name":"graviton","ignoreInvite":true,"ignoreChat":false}]}"#
        let e = BlockedPlayers.parse(Data(json.utf8))?.first
        XCTAssertEqual(e?.nameColor, 0)
        XCTAssertEqual(e?.tourneyWinner, 0)
    }

    func testStyledNameMatchesDashboardMessageSender() {
        for (color, crown) in [(0, 0), (16711680, 2), ((255 << 24) + 1, 5), (0, 1)] {
            let e = IgnoreEntry(ignorePid: 1, name: "graviton", ignoreInvite: true, ignoreChat: true,
                                nameColor: color, tourneyWinner: crown)
            let m = Message()
            m.author = "graviton"
            m.nameColor = DashboardMapping.uiColor(fromRGB: color)
            m.crown = Int32(crown)
            let got = e.styledName, want: NSAttributedString = m.attributedName()
            let ctx = "color \(color) crown \(crown)"
            XCTAssertEqual(got.string, want.string, ctx)
            XCTAssertEqual(got.length, want.length, ctx)
            // Name run: same font and color attributes (attachments are fresh objects, so compare separately).
            let nameRange = NSRange(location: 0, length: "graviton".count)
            let a = got.attributes(at: 0, effectiveRange: nil), b = want.attributes(at: 0, effectiveRange: nil)
            XCTAssertEqual(a[.font] as? UIFont, b[.font] as? UIFont, ctx)
            XCTAssertEqual(a[.foregroundColor] as? UIColor, b[.foregroundColor] as? UIColor, ctx)
            XCTAssertEqual(got.attributedSubstring(from: nameRange).string, "graviton")
            if want.length > "graviton ".count {
                let ga = got.attribute(.attachment, at: want.length - 1, effectiveRange: nil) as? NSTextAttachment
                let wa = want.attribute(.attachment, at: want.length - 1, effectiveRange: nil) as? NSTextAttachment
                XCTAssertNotNil(wa?.image, ctx)
                XCTAssertEqual(ga?.image, wa?.image, ctx)
            }
        }
    }

    func testParseHtmlLoginPageIsNil() {
        XCTAssertNil(BlockedPlayers.parse(Data("<html>login</html>".utf8)))
        XCTAssertNil(BlockedPlayers.parse(nil))
    }

    func testParseFailureIsNil() {
        let data = Data(#"{"success":false,"error":"Login required"}"#.utf8)
        XCTAssertNil(BlockedPlayers.parse(data))
        XCTAssertEqual(BlockedPlayers.parseError(data), "Login required")
    }

    func testFilter() {
        let a = entry(1, "A", invite: true, chat: false)
        let b = entry(2, "B", invite: false, chat: true)
        let c = entry(3, "C", invite: true, chat: true)
        let all = [a, b, c]
        XCTAssertEqual(BlockedPlayers.filter(all, by: .messages), [b, c])
        XCTAssertEqual(BlockedPlayers.filter(all, by: .invitations), [a, c])
        XCTAssertEqual(BlockedPlayers.filter(all, by: .both), [a, b, c])
    }

    func testRemainingFlags() {
        let c = entry(3, "C", invite: true, chat: true)
        let m = BlockedPlayers.remainingFlags(c, unblocking: .messages)
        XCTAssertTrue(m.invite); XCTAssertFalse(m.chat)
        let b = BlockedPlayers.remainingFlags(c, unblocking: .both)
        XCTAssertFalse(b.invite); XCTAssertFalse(b.chat)
    }

    func testKindText() {
        XCTAssertEqual(BlockedPlayers.kindText(invite: false, chat: true), "messages")
        XCTAssertEqual(BlockedPlayers.kindText(invite: true, chat: false), "invitations")
        XCTAssertEqual(BlockedPlayers.kindText(invite: true, chat: true), "messages and invitations")
    }

    func testIsChatBlockedCaseInsensitive() {
        XCTAssertTrue(BlockedPlayers.isChatBlocked("Graviton", in: [entry(1, "graviton", invite: false, chat: true)]))
        XCTAssertFalse(BlockedPlayers.isChatBlocked("Graviton", in: [entry(1, "graviton", invite: true, chat: false)]))
    }

    func testFormEncodeSpecialChars() {
        XCTAssertEqual(BlockedPlayers.formEncode([("ignoreName", "a b+c&d")]), "ignoreName=a%20b%2Bc%26d")
    }

    func testBlockButtonTitles() {
        XCTAssertEqual(BlockedPlayersService.blockButtonTitles(forInvitation: false),
                       ["Block messages", "Block messages and invitations"])
        XCTAssertEqual(BlockedPlayersService.blockButtonTitles(forInvitation: true),
                       ["Block invitations", "Block messages and invitations"])
    }
}
