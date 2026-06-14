import XCTest

/// Proves the PenteEngineTests bundle builds, hosts into the app, and runs.
final class HarnessSmokeTests: XCTestCase {
    func testHarnessRuns() {
        XCTAssertEqual(2 + 2, 4)
    }
}
