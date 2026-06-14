import XCTest
@testable import penteLive

final class DashboardEndpointTests: XCTestCase {
    func testProdRequestShape() {
        let req = DashboardEndpoint().dashboardRequest(username: "al ice", password: "p&w", useLocalhost: false)
        let s = req.url!.absoluteString
        XCTAssertTrue(s.hasPrefix("https://www.pente.org/gameServer/mobile/json/index.jsp?"))
        XCTAssertTrue(s.contains("name=al%20ice") || s.contains("name=al+ice"))
        XCTAssertTrue(s.contains("password=p%26w"))
        XCTAssertEqual(req.httpMethod, "GET")
        XCTAssertEqual(req.timeoutInterval, 7.0, accuracy: 0.001)
    }

    func testLocalhostHost() {
        let req = DashboardEndpoint().dashboardRequest(username: "a", password: "b", useLocalhost: true)
        XCTAssertTrue(req.url!.absoluteString.hasPrefix("https://localhost/gameServer/mobile/json/index.jsp?"))
    }
}
