@testable import penteLive
import XCTest

final class LinkPolicyTests: XCTestCase {
    private func adult(_ s: String?, dev: Bool = false) -> LinkPolicy.Action {
        LinkPolicy.classify(s, isKid: false, allowLocalhost: dev)
    }

    private func kid(_ s: String?, dev: Bool = false) -> LinkPolicy.Action {
        LinkPolicy.classify(s, isKid: true, allowLocalhost: dev)
    }

    func testPenteHostsStayInApp() {
        for url in ["https://pente.org", "https://www.pente.org/gameServer/profile?viewName=a",
                    "http://pente.org/x", "http://www.pente.org", "https://sub.deep.pente.org/",
                    "HTTPS://WWW.PENTE.ORG/Path", "https://Pente.Org", "https://pente.org:8443/x",
                    "https://www.pente.org:443/"] {
            XCTAssertEqual(adult(url), .inApp, url)
            XCTAssertEqual(kid(url), .inApp, url)
        }
    }

    func testLookalikeHostsAreExternalOrKidBlocked() {
        for url in ["https://evilpente.org", "https://pente.org.evil.com", "https://www.pente.org.evil.com/",
                    "https://notpente.org", "https://pente.org.", "https://pente-org.com",
                    "https://evil.com/pente.org", "https://evil.com/?u=https://pente.org",
                    "https://evil.com#pente.org", "https://m.facebook.com/pente.org", "http://example.com"] {
            XCTAssertEqual(adult(url), .external, url)
            XCTAssertEqual(kid(url), .blockedForKid, url)
        }
    }

    func testUserinfoAndParserDifferentialTricksAreBlocked() {
        for url in ["https://pente.org@evil.com", "https://pente.org:pw@evil.com/", "https://user@www.pente.org/",
                    "https://evil.com\\@pente.org", "https://pente.org\\.evil.com", "https://pente.org .evil.com",
                    "https://pente.org\t.evil.com", "https://\u{0}pente.org"] {
            XCTAssertEqual(adult(url), .blocked, url)
            XCTAssertEqual(kid(url), .blocked, url)
        }
    }

    func testLocalhostOnlyWhenDevFlagOn() {
        XCTAssertEqual(adult("https://localhost/gameServer/x", dev: true), .inApp)
        XCTAssertEqual(adult("https://LOCALHOST:8443/x", dev: true), .inApp)
        XCTAssertEqual(adult("https://localhost/gameServer/x", dev: false), .external)
        XCTAssertEqual(kid("https://localhost/gameServer/x", dev: false), .blockedForKid)
        XCTAssertEqual(adult("https://localhost.evil.com/", dev: true), .external)
        XCTAssertEqual(adult("https://notlocalhost/", dev: true), .external)
    }

    func testMailAndTelOnlyForNonKids() {
        for url in ["mailto:a@b.com", "tel:+3212345678", "MAILTO:a@b.com"] {
            XCTAssertEqual(adult(url), .external, url)
            XCTAssertEqual(kid(url), .blockedForKid, url)
        }
    }

    func testDangerousAndUnknownSchemesAreBlocked() {
        for url in ["javascript:alert(1)", "JavaScript:alert(1)", "file:///etc/passwd", "data:text/html,<b>x</b>",
                    "intent://x#Intent;scheme=http;end", "ftp://pente.org/x", "sms:123", "facetime:a@b.com",
                    "itms-apps://apps.apple.com/x", "penteLive://x", "blob:https://pente.org/abc", "about:blank",
                    "vbscript:x"] {
            XCTAssertEqual(adult(url), .blocked, url)
            XCTAssertEqual(kid(url), .blocked, url)
        }
    }

    func testPercentEncodedHostIsBlocked() {
        XCTAssertEqual(adult("https://evil.com%2f.pente.org"), .blocked)
        XCTAssertEqual(kid("https://evil.com%2f.pente.org"), .blocked)
    }

    func testRelativeAndEmptyAreBlocked() {
        for url in [nil, "", "   ", "/gameServer/x", "gameServer/x", "//pente.org/x", "?mobile&g=1", "pente.org", "#frag"] {
            XCTAssertEqual(adult(url), .blocked, url ?? "nil")
        }
        XCTAssertEqual(adult("https://"), .blocked)
        XCTAssertEqual(adult("https:///path"), .blocked)
    }

    func testSurroundingWhitespaceIsTrimmed() {
        XCTAssertEqual(adult("  https://www.pente.org/x\n"), .inApp)
    }

    func testIsPenteHost() {
        XCTAssertTrue(LinkPolicy.isPenteHost("PENTE.ORG", allowLocalhost: false))
        XCTAssertTrue(LinkPolicy.isPenteHost("www.pente.org", allowLocalhost: false))
        XCTAssertFalse(LinkPolicy.isPenteHost("evilpente.org", allowLocalhost: false))
        XCTAssertFalse(LinkPolicy.isPenteHost("localhost", allowLocalhost: false))
        XCTAssertTrue(LinkPolicy.isPenteHost("localhost", allowLocalhost: true))
    }

    func testLocalWebViewOnlyAllowsOwnBlankLoad() {
        XCTAssertTrue(LinkPolicy.shouldLoadInLocalWebView(URL(string: "about:blank"), linkActivated: false, from: nil))
        XCTAssertTrue(LinkPolicy.shouldLoadInLocalWebView(nil, linkActivated: false, from: nil))
        XCTAssertFalse(LinkPolicy.shouldLoadInLocalWebView(URL(string: "about:blank"), linkActivated: true, from: nil))
        XCTAssertFalse(LinkPolicy.shouldLoadInLocalWebView(URL(string: "javascript:alert(1)"), linkActivated: false, from: nil))
    }

    func testShouldTreatAsKidDerivation() {
        XCTAssertTrue(LinkPolicy.shouldTreatAsKid(loggedIn: false, kidStatusKnown: false, isKid: false))
        XCTAssertTrue(LinkPolicy.shouldTreatAsKid(loggedIn: false, kidStatusKnown: true, isKid: false))
        XCTAssertTrue(LinkPolicy.shouldTreatAsKid(loggedIn: true, kidStatusKnown: true, isKid: true))
        XCTAssertFalse(LinkPolicy.shouldTreatAsKid(loggedIn: true, kidStatusKnown: true, isKid: false))
        XCTAssertTrue(LinkPolicy.shouldTreatAsKid(loggedIn: true, kidStatusKnown: false, isKid: false))
    }
}
