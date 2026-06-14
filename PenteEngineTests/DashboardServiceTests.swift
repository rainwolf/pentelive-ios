import XCTest
@testable import penteLive

private struct StubTransport: Transport {
    let data: Data
    let status: Int
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let resp = HTTPURLResponse(url: request.url!, statusCode: status,
                                   httpVersion: nil, headerFields: nil)!
        return (data, resp)
    }
}

final class DashboardServiceTests: XCTestCase {
    private func fixture() throws -> Data {
        let url = Bundle(for: type(of: self)).url(forResource: "dashboard_sample", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    func testLoadsAndMaps() async throws {
        let service = DashboardService(transport: StubTransport(data: try fixture(), status: 200))
        let dash = try await service.loadDashboard(username: "a", password: "b")
        XCTAssertEqual(dash.flags.playerName, "alice")
        XCTAssertEqual(dash.activeGames.first?.gameID, "5001")
    }

    func testNon200ThrowsHttp() async throws {
        let service = DashboardService(transport: StubTransport(data: Data("{}".utf8), status: 503))
        do { _ = try await service.loadDashboard(username: "a", password: "b"); XCTFail("expected throw") }
        catch { XCTAssertEqual((error as NSError).code, DashboardErrorCode.http.rawValue) }
    }

    func testMissingInvitationsReceivedThrowsInvalidCredentials() async throws {
        let service = DashboardService(transport: StubTransport(data: Data("{\"player\":{}}".utf8), status: 200))
        do { _ = try await service.loadDashboard(username: "a", password: "b"); XCTFail("expected throw") }
        catch { XCTAssertEqual((error as NSError).code, DashboardErrorCode.invalidCredentials.rawValue) }
    }

    func testMalformedJsonThrowsDecoding() async throws {
        let service = DashboardService(transport: StubTransport(data: Data("not json".utf8), status: 200))
        do { _ = try await service.loadDashboard(username: "a", password: "b"); XCTFail("expected throw") }
        catch { XCTAssertEqual((error as NSError).code, DashboardErrorCode.decoding.rawValue) }
    }
}
