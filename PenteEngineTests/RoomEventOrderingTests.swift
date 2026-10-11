@testable import penteLive
import XCTest

/// Room/table events arrive on the socket's serial queue; the model they touch must be
/// updated in event order even though the UI-facing work hops to main.
final class RoomEventOrderingTests: XCTestCase {
    private func makeRoom() throws -> RoomViewController {
        // init(coder:) skips initerface(), so no socket connects and no sounds are loaded.
        let archiver = NSKeyedArchiver(requiringSecureCoding: false)
        archiver.finishEncoding()
        let unarchiver = try NSKeyedUnarchiver(forReadingFrom: archiver.encodedData)
        unarchiver.requiresSecureCoding = false
        let room = RoomViewController(coder: unarchiver)
        room.isArena = true // arena rooms play no sound on a main-room join
        room.me = "iostest"
        return room
    }

    func testTableJoinRightAfterRoomJoinSeatsThePlayer() throws {
        let room = try makeRoom()
        let socketQueue = DispatchQueue(label: "RoomEventOrderingTests.socket")
        let joinRoom: [String: Any] = ["player": "owner", "dsgPlayerData": ["gameData": [[String: AnyObject]](), "unlimitedTBGames": false]]
        let joinTable: [String: Any] = ["player": "owner", "table": 7]
        // Main is blocked in sync while both events are handled back to back, exactly as when
        // they arrive in the same socket read: nothing dispatched to main can have run yet.
        socketQueue.sync {
            room.joinMainRoomEvent(event: joinRoom)
            room.joinTableEvent(event: joinTable)
        }
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
        XCTAssertNotNil(room.playersAndTables.player(name: "owner"))
        XCTAssertNotNil(room.playersAndTables.table(tableId: 7)?.players["owner"])
    }
}
