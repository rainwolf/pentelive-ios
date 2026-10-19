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
