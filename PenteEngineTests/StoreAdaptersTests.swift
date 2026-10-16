import UIKit
import XCTest
@testable import penteLive

/// Records what PenteStoreServer sends and answers from a script.
private final class TransportRecorder {
    var requests: [URLRequest] = []
    var answers: [(statusCode: Int?, body: Data?)] = []

    func transport(_ request: URLRequest) async -> (statusCode: Int?, body: Data?) {
        requests.append(request)
        return answers.isEmpty ? (nil, nil) : answers.removeFirst()
    }
}

/// Spec 4 (endpoint, form POST, development switch), 5.3 (GET reply
/// handling) and the real adapters around StoreService.
@MainActor
final class StoreAdaptersTests: XCTestCase {
    private let tokenJSON = Data(#"{"appAccountToken":"6fa459ea-ee8a-3ca4-894e-db77e160355e","products":["vacation_10"]}"#.utf8)

    func testDevelopmentFlagIsOffInCommits() {
        XCTAssertFalse(developmentEnabled(), "#define development in test1/PentePlayer.h must be NO in every commit")
    }

    func testDefaultEndpointFollowsTheDevelopmentFlag() {
        XCTAssertEqual(StoreEndpoint().useLocalhost, developmentEnabled())
        XCTAssertEqual(StoreEndpoint(useLocalhost: false).url.absoluteString,
                       "https://www.pente.org/gameServer/appStorePurchase")
        XCTAssertEqual(StoreEndpoint(useLocalhost: true).url.absoluteString,
                       "https://localhost/gameServer/appStorePurchase")
    }

    func testInfoRequestIsAnUncachedGet() {
        let request = StoreEndpoint(useLocalhost: false).infoRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "https://www.pente.org/gameServer/appStorePurchase")
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertNil(request.httpBody)
    }

    func testPostIsTheFormEncodedSignedTransaction() throws {
        let request = StoreEndpoint(useLocalhost: false).postRequest(signedTransaction: "eyJh.b-c_d.e+f/g=")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        let body = try XCTUnwrap(request.httpBody)
        XCTAssertEqual(String(data: body, encoding: .utf8), "signedTransaction=eyJh.b-c_d.e%2Bf%2Fg%3D")
        XCTAssertEqual(StoreEndpoint.formEncode("a b&c=d"), "a%20b%26c%3Dd")
    }

    func testInfoResultMapping() {
        guard case .info(let info) = PenteStoreServer.infoResult(statusCode: 200, body: tokenJSON, username: "IOSTest") else {
            return XCTFail("a 200 with the JSON must be info")
        }
        XCTAssertEqual(info.username, "iostest")
        XCTAssertEqual(info.products, ["vacation_10"])
        // The login page Tomcat redirects to after the session expired.
        let loginPage = Data("<html><body><form action=\"login.jsp\">success</form></body></html>".utf8)
        XCTAssertEqual(PenteStoreServer.infoResult(statusCode: 200, body: loginPage, username: "iostest"), .failed)
        XCTAssertEqual(PenteStoreServer.infoResult(statusCode: 401, body: loginPage, username: "iostest"), .sessionLost)
        XCTAssertEqual(PenteStoreServer.infoResult(statusCode: 401, body: nil, username: "iostest"), .sessionLost)
        XCTAssertEqual(PenteStoreServer.infoResult(statusCode: 500, body: tokenJSON, username: "iostest"), .failed)
        XCTAssertEqual(PenteStoreServer.infoResult(statusCode: 302, body: tokenJSON, username: "iostest"), .failed)
        XCTAssertEqual(PenteStoreServer.infoResult(statusCode: nil, body: nil, username: "iostest"), .failed)
        XCTAssertEqual(PenteStoreServer.infoResult(statusCode: 200, body: nil, username: "iostest"), .failed)
    }

    func testServerSendsThroughItsTransportAndParsesReplies() async {
        let recorder = TransportRecorder()
        let server = PenteStoreServer(endpoint: StoreEndpoint(useLocalhost: true), transport: recorder.transport)
        recorder.answers = [(200, Data("success:shared\n".utf8)), (401, nil), (nil, nil), (200, tokenJSON)]

        let shared = await server.post(signedTransaction: "a.b.c")
        let lost = await server.post(signedTransaction: "a.b.c")
        let unreachable = await server.post(signedTransaction: "a.b.c")
        let info = await server.fetchInfo(username: "Graviton")

        XCTAssertEqual(shared, .shared)
        XCTAssertEqual(lost, .sessionLost)
        XCTAssertEqual(unreachable, .noReply)
        guard case .info(let fetched) = info else { return XCTFail("expected info") }
        XCTAssertEqual(fetched.username, "graviton")
        XCTAssertEqual(recorder.requests.map(\.httpMethod), ["POST", "POST", "POST", "GET"])
        XCTAssertEqual(Set(recorder.requests.compactMap { $0.url?.absoluteString }),
                       ["https://localhost/gameServer/appStorePurchase"])
    }

    func testSystemClockRunsTheWorkLater() async {
        let clock = SystemStoreClock()
        var ran = false
        let before = clock.now()
        clock.schedule(after: 0.05) { ran = true }
        XCTAssertFalse(ran)
        await waitFor { ran }
        XCTAssertGreaterThanOrEqual(clock.now().timeIntervalSince(before), 0.05)
    }

    func testHostUsernameNeedsTheLoggedInFlag() {
        let nav = PenteNavigationViewController()
        let host = AppStoreHost(navigation: { nav }, notificationCenter: NotificationCenter())

        XCTAssertNil(host.username, "not logged in yet")
        nav.loggedIn = true
        nav.loggedInUsername = "IOSTest"
        XCTAssertEqual(host.username, "iostest")
        nav.loggedInUsername = ""
        XCTAssertNil(host.username)
        nav.loggedInUsername = "IOSTest"
        nav.loggedIn = false
        XCTAssertNil(host.username)
        XCTAssertNil(nav.loggedInUsername, "a logout forgets the name")
        XCTAssertNil(AppStoreHost(navigation: { nil }, notificationCenter: NotificationCenter()).username)
        XCTAssertTrue(host.isInForeground)
    }

    func testTheUsernameIsTakenAtLoginNotReadLive() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: "username")
        defer { defaults.set(saved, forKey: "username") }
        defaults.set("IOSTest", forKey: "username")
        let nav = PenteNavigationViewController()
        nav.loggedIn = true
        XCTAssertEqual(nav.loggedInUsername, "iostest")
        defaults.set("graviton", forKey: "username") // Settings saves each keystroke before Login
        XCTAssertEqual(AppStoreHost(navigation: { nav }, notificationCenter: NotificationCenter()).username,
                       "iostest")
    }

    func testHostReportsEntitlementsAndLostSessions() {
        // A private center: the host app's games list observes the real one.
        let center = NotificationCenter()
        let nav = PenteNavigationViewController()
        nav.loggedIn = true
        nav.loggedInUsername = "iostest"
        let host = AppStoreHost(navigation: { nav }, notificationCenter: center)

        let changed = XCTNSNotificationExpectation(name: StoreService.entitlementsChangedNotification,
                                                   object: nil, notificationCenter: center)
        host.entitlementsChanged()
        wait(for: [changed], timeout: 1)

        let lost = XCTNSNotificationExpectation(name: StoreService.sessionLostNotification,
                                                object: nil, notificationCenter: center)
        host.sessionLost()
        wait(for: [lost], timeout: 1)
        XCTAssertFalse(nav.loggedIn, "a lost session is a logout until the app logs in again")
        XCTAssertNil(host.username)
    }

    func testSharedServiceUsesTheRealAdapters() {
        let shared = StoreService.shared
        XCTAssertTrue(shared.server is PenteStoreServer)
        XCTAssertTrue(shared.source is StoreKitTransactionSource)
        XCTAssertTrue(shared.clock is SystemStoreClock)
        XCTAssertTrue(shared.messages is AlertStoreMessageSink)
        XCTAssertTrue(shared.host is AppStoreHost)
        XCTAssertTrue(shared.defaults === UserDefaults.standard)
        XCTAssertTrue(StoreService.shared === shared)
    }
}
