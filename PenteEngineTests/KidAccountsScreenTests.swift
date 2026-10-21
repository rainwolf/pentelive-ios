@testable import penteLive
import UIKit
import XCTest

final class KidAccountsScreenTests: XCTestCase {
    private func kid(_ name: String, approved: Int) -> KidAccount {
        KidAccount(kidPid: 1, name: name, copyMessages: false, copyLiveChat: false,
                   whitelist: (0 ..< approved).map { KidPlayer(pid: Int64($0), name: "p\($0)") })
    }

    private func state(isKid: Bool = false, verified: Bool = true, parent: String? = nil,
                       kids: [KidAccount] = []) -> KidAccountsState
    {
        KidAccountsState(isKid: isKid, emailVerified: verified, parentName: parent,
                         whitelist: [], kids: kids, message: nil)
    }

    private func screen() -> KidAccountsViewController {
        let vc = KidAccountsViewController()
        vc.loadViewIfNeeded()
        return vc
    }

    func testGetRequestCarriesCredentialsAndIsNotCached() {
        let request = KidAccountsService.getRequest()
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/gameServer/kids")
        XCTAssertTrue(request.url?.query?.contains("name2=") ?? false)
        XCTAssertTrue(request.url?.query?.contains("password2=") ?? false)
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(request.timeoutInterval, 7.0)
    }

    func testActiveGamesRequest() {
        let request = KidAccountsService.activeGamesRequest(kidPid: 23_000_000_012_345)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/gameServer/kids")
        let query = request.url?.query ?? ""
        XCTAssertTrue(query.contains("action=activeGames"), query)
        XCTAssertTrue(query.contains("kidPid=23000000012345"), query)
        XCTAssertTrue(query.contains("name2="), query)
        XCTAssertTrue(query.contains("password2="), query)
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
        XCTAssertEqual(request.timeoutInterval, 7.0)
    }

    func testPostRequestFormEncodesActionAndCredentials() {
        let request = KidAccountsService.postRequest(.create(name: "kid one", password: "p&w"))
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.hasPrefix("action=create&"), body)
        XCTAssertTrue(body.contains("kidName=kid%20one") || body.contains("kidName=kid+one"), body)
        XCTAssertTrue(body.contains("kidPassword=p%26w"), body)
        XCTAssertTrue(body.contains("name2="), body)
        XCTAssertTrue(body.contains("password2="), body)
    }

    func testParentStateListsKidsWithApprovedCount() {
        let vc = screen()
        vc.apply(state: state(kids: [kid("a", approved: 1), kid("b", approved: 3)]), error: nil)
        XCTAssertEqual(vc.tableView(vc.tableView, numberOfRowsInSection: 0), 2)
        let cell = vc.tableView(vc.tableView, cellForRowAt: IndexPath(row: 1, section: 0))
        let content = cell.contentConfiguration as? UIListContentConfiguration
        XCTAssertEqual(content?.text, "b")
        XCTAssertEqual(content?.secondaryText, "3 approved players")
        XCTAssertEqual(cell.accessoryType, .disclosureIndicator)
        XCTAssertNotNil(vc.navigationItem.rightBarButtonItem)
    }

    func testEmptyParentStateShowsPlaceholder() {
        let vc = screen()
        vc.apply(state: state(), error: nil)
        XCTAssertEqual(vc.emptyText, "No kid accounts yet")
        XCTAssertFalse(vc.tableView.backgroundView?.isHidden ?? true)
    }

    func testUnverifiedEmailShowsFooter() {
        let vc = screen()
        vc.apply(state: state(verified: false), error: nil)
        XCTAssertEqual(vc.tableView(vc.tableView, titleForFooterInSection: 0),
                       "Verify your email address before adding kids")
        vc.apply(state: state(verified: true), error: nil)
        XCTAssertNil(vc.tableView(vc.tableView, titleForFooterInSection: 0))
    }

    func testKidStateHidesAddButtonRowsAndFooterAndFlagsPlayer() {
        let vc = screen()
        let player = PentePlayer()
        vc.player = player
        vc.apply(state: state(isKid: true, verified: false, parent: "mum", kids: [kid("a", approved: 1)]), error: nil)
        XCTAssertNil(vc.navigationItem.rightBarButtonItem)
        XCTAssertEqual(vc.tableView(vc.tableView, numberOfRowsInSection: 0), 0)
        XCTAssertEqual(vc.emptyText, "Your account is managed by your parent, mum.")
        XCTAssertNil(vc.tableView(vc.tableView, titleForFooterInSection: 0))
        XCTAssertTrue(player.isKid)
    }

    func testReleasedKidGetsParentViewBack() {
        let vc = screen()
        vc.apply(state: state(isKid: true, parent: "mum"), error: nil)
        XCTAssertNil(vc.navigationItem.rightBarButtonItem)
        vc.apply(state: state(), error: nil)
        XCTAssertNotNil(vc.navigationItem.rightBarButtonItem)
        XCTAssertEqual(vc.emptyText, "No kid accounts yet")
    }
}

final class KidDetailScreenTests: XCTestCase {
    private let kidAccount = KidAccount(kidPid: 7, name: "tim", copyMessages: true, copyLiveChat: false,
                                        whitelist: [KidPlayer(pid: 1, name: "ann"), KidPlayer(pid: 2, name: "bob")])

    private func state(kids: [KidAccount]) -> KidAccountsState {
        KidAccountsState(isKid: false, emailVerified: true, parentName: nil,
                         whitelist: [], kids: kids, message: nil)
    }

    private func detail(_ reply: @escaping (KidAction) -> (KidAccountsState?, String?),
                        actions: ActionLog = ActionLog()) -> KidDetailViewController
    {
        let list = KidAccountsViewController()
        list.loadViewIfNeeded()
        let vc = KidDetailViewController(kid: kidAccount, list: list)
        vc.performAction = { action, completion in
            actions.items.append(action)
            let (state, error) = reply(action)
            completion(state, error)
        }
        vc.loadViewIfNeeded()
        return vc
    }

    final class ActionLog { var items: [KidAction] = [] }

    private func switchOf(_ vc: KidDetailViewController, row: Int) -> UISwitch? {
        vc.tableView(vc.tableView, cellForRowAt: IndexPath(row: row, section: 1)).accessoryView as? UISwitch
    }

    func testLayoutAndFooters() {
        let vc = detail { _ in (nil, "x") }
        XCTAssertEqual(vc.title, "tim")
        XCTAssertEqual(vc.numberOfSections(in: vc.tableView), 3)
        XCTAssertEqual(vc.tableView(vc.tableView, numberOfRowsInSection: 0), 3) // 2 approved + Add player…
        XCTAssertEqual(vc.tableView(vc.tableView, numberOfRowsInSection: 1), 2)
        XCTAssertEqual(vc.tableView(vc.tableView, numberOfRowsInSection: 2), 2)
        XCTAssertEqual(vc.tableView(vc.tableView, titleForFooterInSection: 0),
                       "Your kid can always chat with you and with pente.org admins.")
        XCTAssertEqual(vc.tableView(vc.tableView, titleForFooterInSection: 1), KidMode.liveChatCopyNote)
        XCTAssertTrue(switchOf(vc, row: 0)?.isOn ?? false)
        XCTAssertFalse(switchOf(vc, row: 1)?.isOn ?? true)
    }

    func testTogglingSendsOnlyTheToggledFlag() {
        let log = ActionLog()
        let updated = KidAccount(kidPid: 7, name: "tim", copyMessages: true, copyLiveChat: true, whitelist: [])
        let vc = detail({ _ in (self.state(kids: [updated]), nil) }, actions: log)
        let live = switchOf(vc, row: 1)!
        live.isOn = true
        vc.copySwitchChanged(live)
        XCTAssertEqual(log.items, [.settings(kidPid: 7, copyMessages: nil, copyLiveChat: true)])
        let msgs = switchOf(vc, row: 0)!
        msgs.isOn = false
        vc.copySwitchChanged(msgs)
        XCTAssertEqual(log.items.last, .settings(kidPid: 7, copyMessages: false, copyLiveChat: nil))
    }

    func testFailedToggleRevertsSwitch() {
        let vc = detail { _ in (nil, "boom") }
        let live = switchOf(vc, row: 1)!
        live.isOn = true
        vc.copySwitchChanged(live)
        XCTAssertFalse(live.isOn)
    }

    func testSuccessReplacesKidAndReloads() {
        let updated = KidAccount(kidPid: 7, name: "tim", copyMessages: true, copyLiveChat: false,
                                 whitelist: [KidPlayer(pid: 1, name: "ann")])
        let log = ActionLog()
        let vc = detail({ _ in (self.state(kids: [updated]), nil) }, actions: log)
        vc.remove(playerPid: 2)
        XCTAssertEqual(log.items, [.whitelistRemove(kidPid: 7, playerPid: 2)])
        XCTAssertEqual(vc.tableView(vc.tableView, numberOfRowsInSection: 0), 2)
    }

    func testReleasedKidPopsToList() {
        let list = KidAccountsViewController()
        let nav = UINavigationController(rootViewController: list)
        let vc = KidDetailViewController(kid: kidAccount, list: list)
        vc.performAction = { _, completion in completion(self.state(kids: []), nil) }
        nav.pushViewController(vc, animated: false)
        vc.release()
        let deadline = Date().addingTimeInterval(3)
        while nav.topViewController !== list, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(nav.topViewController === list)
    }
}
