import UIKit
import XCTest
@testable import penteLive

/// Spec 5.4 removals and D2; the shared service stays inert in the test host.
@MainActor
final class StoreWiringTests: XCTestCase {
    func testTheReceiptPathIsGone() {
        XCTAssertNil(NSClassFromString("penteLive.SubscriptionStore"))
        XCTAssertNil(NSClassFromString("penteLive.SubscriptionProduct"))
        XCTAssertNil(NSClassFromString("penteLive.ReceiptReply"))
        XCTAssertFalse(PenteNavigationViewController.instancesRespond(to: NSSelectorFromString("subscription")))
        XCTAssertFalse(PenteNavigationViewController.instancesRespond(to: NSSelectorFromString("setSubscription:")))
        XCTAssertFalse(AppDelegate.instancesRespond(to: NSSelectorFromString("sendPendingReceipt")))
        XCTAssertFalse(AppDelegate.instancesRespond(to: NSSelectorFromString("refreshReceiptThenSend")))
        XCTAssertFalse(AppDelegate.instancesRespond(to: NSSelectorFromString("receiptNeedsSendingNotification:")))
    }

    func testTheSharedServiceIsNotStartedWhileHostingTests() {
        XCTAssertFalse(StoreService.shared.isStarted,
                       "StoreKit Testing transactions must never reach pente.org from the test host")
    }

    func testLoggedInKeepsItsValueThroughTheNewSetter() {
        let nav = PenteNavigationViewController()
        XCTAssertFalse(nav.loggedIn)
        nav.loggedIn = true
        XCTAssertTrue(nav.loggedIn)
        nav.loggedIn = false
        XCTAssertFalse(nav.loggedIn)
    }

    /// The login hook runs after loggedInUsername is set (setter source order),
    /// which is what lets the post-login resync do the once-per-account sweep.
    func testLoginSetsTheHostUsernameLowercased() {
        let defaults = UserDefaults.standard
        let saved = defaults.string(forKey: "username")
        defer {
            if let saved { defaults.set(saved, forKey: "username") } else { defaults.removeObject(forKey: "username") }
        }
        defaults.set("MixedCase", forKey: "username")
        let nav = PenteNavigationViewController()
        XCTAssertNil(nav.loggedInUsername)
        nav.loggedIn = true
        XCTAssertEqual(nav.loggedInUsername, "mixedcase")
        nav.loggedIn = false
        XCTAssertNil(nav.loggedInUsername)
    }
}
