import XCTest
@testable import penteLive

/// Answers /players by the `q` value; never touches the network.
private final class DBPlayersTransport: Transport, @unchecked Sendable {
    private let lock = NSLock()
    private var _queries: [String] = []
    var delays: [String: UInt64] = [:]

    var queries: [String] { lock.lock(); defer { lock.unlock() }; return _queries }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let q = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "q" }?.value ?? ""
        lock.lock(); _queries.append(q); lock.unlock()
        if let d = delays[q] { try await Task.sleep(nanoseconds: d) }
        let body = "{\"players\":[\"\(q)-hit\"]}".data(using: .utf8)!
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, resp)
    }
}

@MainActor
final class DBPlayerAutocompleteTests: XCTestCase {
    private func make(_ t: DBPlayersTransport, debounce: TimeInterval) -> DBPlayerAutocomplete {
        let ep = DBEndpoint(useLocalhost: false)
        return DBPlayerAutocomplete(client: DBClient(endpoint: ep, transport: t), debounce: debounce)
    }

    private func wait(_ cond: () -> Bool, timeout: TimeInterval = 3) async {
        let end = Date().addingTimeInterval(timeout)
        while !cond() && Date() < end { try? await Task.sleep(nanoseconds: 10_000_000) }
    }

    func testShortQueryNoRequest() async {
        let t = DBPlayersTransport()
        let ac = make(t, debounce: 0.01)
        var got: [[String]] = []
        ac.query("a") { got.append($0) }
        ac.query("  b ") { got.append($0) }
        XCTAssertEqual(got, [[], []], "short queries answer immediately")
        try? await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(t.queries.isEmpty)
    }

    func testOnlyLatestDelivered() async {
        let t = DBPlayersTransport()
        t.delays["alice"] = 300_000_000
        let ac = make(t, debounce: 0.01)
        var got: [[String]] = []
        ac.query("alice") { got.append($0) }
        try? await Task.sleep(nanoseconds: 100_000_000) // alice in flight
        ac.query("bob") { got.append($0) }
        await wait { !got.isEmpty }
        try? await Task.sleep(nanoseconds: 500_000_000) // let alice finish
        XCTAssertEqual(got, [["bob-hit"]])
    }

    func testShortQueryCancelsPending() async {
        let t = DBPlayersTransport()
        let ac = make(t, debounce: 0.2)
        var got: [[String]] = []
        ac.query("alice") { got.append($0) }
        ac.query("a") { got.append($0) }
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertEqual(got, [[]])
        XCTAssertTrue(t.queries.isEmpty)
    }

    func testDebounceCollapsesKeystrokes() async {
        let t = DBPlayersTransport()
        let ac = make(t, debounce: 0.25)
        var got: [[String]] = []
        ac.query("al") { got.append($0) }
        try? await Task.sleep(nanoseconds: 40_000_000)
        ac.query("ali") { got.append($0) }
        try? await Task.sleep(nanoseconds: 40_000_000)
        ac.query("alic") { got.append($0) }
        await wait { !got.isEmpty }
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(t.queries, ["alic"])
        XCTAssertEqual(got, [["alic-hit"]])
    }
}
