@testable import penteLive
import XCTest

final class KidModeTests: XCTestCase {
    private func login(_ json: String) -> [String: Any] {
        let object = try! JSONSerialization.jsonObject(with: Data(json.utf8), options: [])
        return (object as! [String: Any])["dsgLoginEvent"] as! [String: Any]
    }

    func testIsKidFromLoginEvent() {
        XCTAssertTrue(KidMode.isKid(loginEvent: login(#"{"dsgLoginEvent":{"player":"kid_one","me":{"name":"kid_one","parentPid":23000000012345}}}"#)))
        XCTAssertFalse(KidMode.isKid(loginEvent: login(#"{"dsgLoginEvent":{"player":"bob","me":{"name":"bob"}}}"#)))
        XCTAssertFalse(KidMode.isKid(loginEvent: login(#"{"dsgLoginEvent":{"player":"bob","me":{"name":"bob","parentPid":null}}}"#)))
        XCTAssertFalse(KidMode.isKid(loginEvent: login(#"{"dsgLoginEvent":{"player":"bob"}}"#)))
        XCTAssertFalse(KidMode.isKid(loginEvent: login(#"{"dsgLoginEvent":{"player":"bob","me":"x"}}"#)))
    }

    func testMessageSendError() {
        XCTAssertEqual(KidMode.messageSendError("<html>You can only send messages to players your parent approved.</html>"),
                       "You can only send messages to players your parent approved.")
        XCTAssertEqual(KidMode.messageSendError("<p>Player is ignoring your messages.</p>"), "Player is ignoring your messages.")
        XCTAssertNil(KidMode.messageSendError("Error: Player bob not found."))
        XCTAssertNil(KidMode.messageSendError(""))
        XCTAssertNil(KidMode.messageSendError(nil))
    }

    func testBroadcastRefused() {
        XCTAssertTrue(KidMode.isBroadcastRefused("<p>Kid accounts can't broadcast.</p>"))
        XCTAssertFalse(KidMode.isBroadcastRefused("You can't broadcast more than once per hour"))
    }

    func testManagedByParentText() {
        XCTAssertEqual(KidMode.managedByParentText("iostest"), "Your account is managed by your parent, iostest.")
        XCTAssertEqual(KidMode.managedByParentText(nil), "Your account is managed by your parent.")
        XCTAssertEqual(KidMode.managedByParentText(""), "Your account is managed by your parent.")
    }

    func testApprovedCountText() {
        XCTAssertEqual(KidMode.approvedCountText(0), "0 approved players")
        XCTAssertEqual(KidMode.approvedCountText(1), "1 approved player")
        XCTAssertEqual(KidMode.approvedCountText(2), "2 approved players")
    }

    func testInviteAlertMessage() {
        XCTAssertNil(KidMode.inviteAlertMessage(""))
        XCTAssertEqual(KidMode.inviteAlertMessage("hi there"), "message: hi there")
    }

    func testSettingsHiddenKeysMatchExistingRulesForNonKids() {
        XCTAssertEqual(KidMode.settingsHiddenKeys(loggedIn: false, subscriber: false, isKid: false),
                       ["SubscribeButton", "StoreButton", "blockedPlayersButton", "kidAccountsButton"])
        XCTAssertEqual(KidMode.settingsHiddenKeys(loggedIn: true, subscriber: true, isKid: false),
                       ["SubscribeButton", "SignUpButton", "SignUpLabel", "personalizeAds"])
        XCTAssertEqual(KidMode.settingsHiddenKeys(loggedIn: true, subscriber: false, isKid: false),
                       ["SignUpButton", "SignUpLabel"])
    }

    func testSettingsHiddenKeysForKids() {
        // Kids keep the Blocked players row (blocking only restricts further); only Kid accounts is hidden.
        XCTAssertEqual(KidMode.settingsHiddenKeys(loggedIn: true, subscriber: false, isKid: true),
                       ["SignUpButton", "SignUpLabel", "kidAccountsButton"])
        XCTAssertEqual(KidMode.settingsHiddenKeys(loggedIn: true, subscriber: true, isKid: true),
                       ["SubscribeButton", "SignUpButton", "SignUpLabel", "personalizeAds", "kidAccountsButton"])
        // isKid is ignored when logged out (a stale flag from the previous login).
        XCTAssertEqual(KidMode.settingsHiddenKeys(loggedIn: false, subscriber: false, isKid: true),
                       ["SubscribeButton", "StoreButton", "blockedPlayersButton", "kidAccountsButton"])
    }
}
