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

    private func loginEvent(parentPid: Any?) -> [String: Any] {
        var me: [String: Any] = ["name": "iostest"]
        if let parentPid { me["parentPid"] = parentPid }
        return ["player": "iostest", "serverData": ["loginMessages": [String]()], "me": me]
    }

    private func drainMain() {
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)
    }

    func testKidLoginSetsKidFlagAndChatHint() throws {
        let room = try makeRoom()
        room.socket = PenteLiveSocket(server: "127.0.0.1", port: 1, room: room)
        defer { room.socket.disconnect() }
        room.loginEvent(event: loginEvent(parentPid: 42))
        drainMain()
        XCTAssertTrue(room.isKid)
        XCTAssertEqual(room.textField.placeholder, KidMode.chatHint)
    }

    func testNonKidLoginClearsKidFlagAndChatHint() throws {
        let room = try makeRoom()
        room.socket = PenteLiveSocket(server: "127.0.0.1", port: 1, room: room)
        defer { room.socket.disconnect() }
        room.loginEvent(event: loginEvent(parentPid: 42))
        drainMain()
        room.loginEvent(event: loginEvent(parentPid: nil))
        drainMain()
        XCTAssertFalse(room.isKid)
        XCTAssertNil(room.textField.placeholder)
    }

    func testTableViewControllerShowsChatHintOnlyForKids() throws {
        let room = try makeRoom()
        room.socket = PenteLiveSocket(server: "127.0.0.1", port: 1, room: room)
        defer { room.socket.disconnect() }
        let player = PentePlayer()
        let kidTable = TableViewController(table: Table(table: 1), socket: room.socket, tablesAndPlayers: room.playersAndTables, pente_player: player, me: "iostest", isKid: true)
        XCTAssertTrue(kidTable.isKid)
        XCTAssertEqual(kidTable.textField.placeholder, KidMode.chatHint)
        let adultTable = TableViewController(table: Table(table: 2), socket: room.socket, tablesAndPlayers: room.playersAndTables, pente_player: player, me: "iostest")
        XCTAssertFalse(adultTable.isKid)
        XCTAssertNil(adultTable.textField.placeholder)
    }
}
