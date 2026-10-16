import UIKit
import XCTest
@testable import penteLive

/// Spec 5.4: Settings opens the Store; upsells no longer route through
/// `showSubscribe`.
@MainActor
final class StoreEntryPointsTests: XCTestCase {
    private func settingsRows() throws -> [[String: Any]] {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "Root.inApp", withExtension: "plist",
                                                subdirectory: "Settings.bundle"))
        let plist = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: Any])
        return try XCTUnwrap(plist["PreferenceSpecifiers"] as? [[String: Any]])
    }

    func testSettingsOffersTheStoreAndNoReceiptRows() throws {
        let rows = try settingsRows()
        let keys = rows.compactMap { $0["Key"] as? String }
        XCTAssertTrue(keys.contains("SubscribeButton"))
        XCTAssertTrue(keys.contains("StoreButton"))
        XCTAssertFalse(keys.contains("RestorePurchaseButton"), "restore lives in the Store")
        XCTAssertFalse(keys.contains("manageSubscriptions"), "Manage subscription lives in the Store")
        let store = try XCTUnwrap(rows.first { $0["Key"] as? String == "StoreButton" })
        XCTAssertEqual(store["Title"] as? String, "Store")
        XCTAssertEqual(store["Type"] as? String, "IASKButtonSpecifier")
        let subscribe = try XCTUnwrap(keys.firstIndex(of: "SubscribeButton"))
        XCTAssertEqual(keys.firstIndex(of: "StoreButton"), subscribe + 1)
    }

    func testUpsellsNoLongerRouteThroughShowSubscribe() throws {
        XCTAssertFalse(PenteNavigationViewController.instancesRespond(to: NSSelectorFromString("showSubscribe")))
        XCTAssertFalse(PenteNavigationViewController.instancesRespond(to: NSSelectorFromString("setShowSubscribe:")))
        // SettingsViewController is Objective-C only (not in the bridging header).
        let settings: AnyClass = try XCTUnwrap(NSClassFromString("SettingsViewController"))
        XCTAssertFalse(class_respondsToSelector(settings, NSSelectorFromString("showSubscribeInfo")))
        XCTAssertFalse(class_respondsToSelector(settings, NSSelectorFromString("restorePurchase")))
        XCTAssertFalse(class_respondsToSelector(settings, NSSelectorFromString("subscribe:")))
        XCTAssertTrue(StoreViewController.responds(to: NSSelectorFromString("presentFrom:")))
    }
}
