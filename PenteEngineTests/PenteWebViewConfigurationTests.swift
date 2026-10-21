@testable import penteLive
import WebKit
import XCTest

final class PenteWebViewConfigurationTests: XCTestCase {
    private final class LoadWaiter: NSObject, WKNavigationDelegate {
        let done: XCTestExpectation
        init(_ done: XCTestExpectation) { self.done = done }
        func webView(_: WKWebView, didFinish _: WKNavigation!) { done.fulfill() }
    }

    func testUserAgentCarriesAppToken() {
        let config = PenteWebViewController.makeConfiguration()
        XCTAssertEqual(config.applicationNameForUserAgent, "Mobile/15E148 penteLive-iOS")
    }

    func testNavigatorUserAgentHasToken() {
        let webView = WKWebView(frame: .zero, configuration: PenteWebViewController.makeConfiguration())
        let loaded = expectation(description: "loaded")
        let waiter = LoadWaiter(loaded)
        webView.navigationDelegate = waiter
        webView.loadHTMLString("<html></html>", baseURL: nil)
        wait(for: [loaded], timeout: 30)

        let evaluated = expectation(description: "evaluated")
        var agent = ""
        webView.evaluateJavaScript("navigator.userAgent") { result, _ in
            agent = (result as? String) ?? ""
            evaluated.fulfill()
        }
        wait(for: [evaluated], timeout: 30)
        print("NAVIGATOR_UA: \(agent)")
        XCTAssertTrue(agent.contains("penteLive-iOS"), agent)
    }
}
