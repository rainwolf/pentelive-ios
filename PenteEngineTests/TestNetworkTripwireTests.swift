@testable import penteLive
import XCTest

/// The unit-test host must never reach a real server. main.m installs
/// TestNetworkTripwire before UIApplicationMain whenever
/// +[AppDelegate isRunningUnitTests] is true; these tests prove that requests
/// to a remote host fail locally with the tripwire error and get recorded.
final class TestNetworkTripwireTests: XCTestCase {
    private let remote = URL(string: "https://www.pente.org/tripwire-test")!

    func testTripwireIsInstalledInTestHost() {
        XCTAssertTrue(TestNetworkTripwire.isInstalled)
    }

    func testSharedSessionRequestIsBlockedAndRecorded() {
        let error = runRequest(URLSession.shared, url: remote)
        assertTripwireError(error)
        XCTAssertTrue(TestNetworkTripwire.recordedURLs.contains(remote))
    }

    func testDefaultConfigurationSessionRequestIsBlockedAndRecorded() {
        let session = URLSession(configuration: .default)
        defer { session.invalidateAndCancel() }
        XCTAssertEqual(session.configuration.protocolClasses?.first.map { ObjectIdentifier($0) },
                       ObjectIdentifier(TestNetworkTripwire.self))
        let error = runRequest(session, url: remote)
        assertTripwireError(error)
        XCTAssertTrue(TestNetworkTripwire.recordedURLs.contains(remote))
    }

    func testEphemeralConfigurationCarriesTripwire() {
        let config = URLSessionConfiguration.ephemeral
        XCTAssertEqual(config.protocolClasses?.first.map { ObjectIdentifier($0) },
                       ObjectIdentifier(TestNetworkTripwire.self))
        // Not duplicated if one getter is implemented in terms of the other.
        XCTAssertEqual(config.protocolClasses?.filter { $0 == TestNetworkTripwire.self }.count, 1)
    }

    /// String(contentsOf:) uses the global URL loading system. A .invalid host
    /// never resolves, so if this were not intercepted nothing would leave anyway.
    func testSynchronousContentsOfURLIsBlocked() {
        let url = URL(string: "https://tripwire.invalid/contents-of")!
        XCTAssertThrowsError(try String(contentsOf: url, encoding: .utf8))
        XCTAssertTrue(TestNetworkTripwire.recordedURLs.contains(url))
    }

    func testLocalhostIsNotBlocked() {
        for s in ["http://localhost/x", "https://127.0.0.1:8443/x", "http://[::1]/x", "file:///tmp/x", "data:text/plain,hi"] {
            XCTAssertFalse(TestNetworkTripwire.blocks(URL(string: s)!), s)
        }
        for s in ["https://www.pente.org/", "https://pente.org", "http://10.0.0.1/", "wss://example.com"] {
            XCTAssertTrue(TestNetworkTripwire.blocks(URL(string: s)!), s)
        }
    }

    private func runRequest(_ session: URLSession, url: URL) -> Error? {
        let done = expectation(description: "request completes")
        var result: Error?
        session.dataTask(with: url) { _, _, error in
            result = error
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: 10)
        return result
    }

    private func assertTripwireError(_ error: Error?, file: StaticString = #filePath, line: UInt = #line) {
        guard let nsError = error as NSError? else {
            return XCTFail("expected tripwire error, got success", file: file, line: line)
        }
        XCTAssertEqual(nsError.domain, TestNetworkTripwire.errorDomain, file: file, line: line)
        XCTAssertEqual(nsError.code, TestNetworkTripwire.errorCode, file: file, line: line)
    }
}
