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

    // MARK: unknown (experimental) live game ids

    private func tableEvent(_ table: Int, game: Int) -> [String: Any] {
        return ["table": table, "game": game, "timed": false, "initialMinutes": 0, "incrementalSeconds": 0,
                "rated": false, "tableType": 1, "player": "owner"]
    }

    private func modelWithPlayers() -> TablesAndPlayer {
        let model = TablesAndPlayer()
        model.addPlayer(player: LivePlayer(name: "owner"))
        return model
    }

    func testUnknownGameTableIsNeverListedAndItsEventsAreIgnored() {
        let model = modelWithPlayers()
        XCTAssertFalse(model.changeTable(event: tableEvent(9, game: 33)))
        XCTAssertNil(model.table(tableId: 9))
        XCTAssertTrue(model.tables.isEmpty)
        model.joinTable(tableId: 9, player: "owner")
        model.sitTable(tableId: 9, player: "owner", seat: 1)
        model.updateTimerTable(tableId: 9, player: "owner", millis: 1000)
        model.gameStateChange(tableId: 9, state: .started)
        XCTAssertTrue(model.tables.isEmpty)
        XCTAssertTrue(model.isHidden(tableId: 9))
        XCTAssertFalse(model.changeTable(event: tableEvent(10, game: 34)))
        XCTAssertTrue(model.tables.isEmpty)
    }

    func testKnownGameTableIsUnaffected() {
        let model = modelWithPlayers()
        XCTAssertTrue(model.changeTable(event: tableEvent(3, game: 31)))
        model.joinTable(tableId: 3, player: "owner")
        XCTAssertEqual(model.table(tableId: 3)?.game, 31)
        XCTAssertEqual(model.table(tableId: 3)?.gameName(), "Renju")
        XCTAssertNotNil(model.table(tableId: 3)?.players["owner"])
        XCTAssertFalse(model.isHidden(tableId: 3))
    }

    func testKnownTableChangingToUnknownGameIsRemoved() {
        let model = modelWithPlayers()
        model.changeTable(event: tableEvent(4, game: 1))
        XCTAssertNotNil(model.table(tableId: 4))
        XCTAssertFalse(model.changeTable(event: tableEvent(4, game: 33)))
        XCTAssertNil(model.table(tableId: 4))
        // and back to a known game it reappears
        XCTAssertTrue(model.changeTable(event: tableEvent(4, game: 5)))
        XCTAssertEqual(model.table(tableId: 4)?.game, 5)
    }

    func testTableWithUnknownGameNameDoesNotCrash() {
        let table = Table(table: 1)
        table.game = 33
        table.timed = true
        XCTAssertEqual(table.gameName(), "")
        XCTAssertFalse(table.shouldTimerRun())
    }

    func testRoomIgnoresUnknownTableJoinAndLeavesCurrentTableThatBecomesUnknown() throws {
        let room = try makeRoom()
        room.socket = PenteLiveSocket(server: "127.0.0.1", port: 1, room: room)
        defer { room.socket.disconnect() }
        room.playersAndTables.addPlayer(player: LivePlayer(name: "iostest"))
        // hidden table: joining as myself must not crash or open a table view
        room.changeTableEvent(event: tableEvent(8, game: 33))
        room.joinTableEvent(event: ["player": "iostest", "table": 8])
        drainMain()
        XCTAssertNil(room.tableViewController)
        XCTAssertTrue(room.playersAndTables.tables.isEmpty)
        // table I am in switches to an unknown game: it is closed
        room.changeTableEvent(event: tableEvent(2, game: 1))
        drainMain()
        let table = try XCTUnwrap(room.playersAndTables.table(tableId: 2))
        let nav = UINavigationController(rootViewController: UIViewController())
        let tvc = TableViewController(table: table, socket: room.socket, tablesAndPlayers: room.playersAndTables, pente_player: PentePlayer(), me: "iostest")
        room.tableViewController = tvc
        nav.pushViewController(tvc, animated: false)
        room.changeTableEvent(event: tableEvent(2, game: 34))
        drainMain()
        XCTAssertNil(room.tableViewController)
        XCTAssertNil(room.playersAndTables.table(tableId: 2))
        // the table view was popped, and the server's exit echo for me does not pop the room too
        XCTAssertEqual(nav.viewControllers.count, 1)
        room.exitTableEvent(event: ["player": "iostest", "table": 2])
        drainMain()
        XCTAssertEqual(nav.viewControllers.count, 1)
    }
}
