import XCTest
@testable import penteLive

/// Spec 5.2 states and card rules, 7.1 Store state selection.
final class StoreScreenModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_000_000) // 2026-10-03 UTC
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    private let prices = [
        StoreProductInfo(id: "1YRNOADSORLIMITS", displayPrice: "$9.99"),
        StoreProductInfo(id: "month_pass", displayPrice: "$1.99"),
        StoreProductInfo(id: "vacation_10", displayPrice: "$0.99"),
        StoreProductInfo(id: "vacation_30", displayPrice: "$1.99"),
        StoreProductInfo(id: "vacation_60", displayPrice: "$2.99"),
    ]

    private func info(until: Date? = nil, owned: Bool = false, days: Int = 12,
                      products: [String] = ["1YRNOADSORLIMITS", "month_pass", "vacation_10", "vacation_30", "vacation_60"]) -> StoreInfo {
        StoreInfo(username: "iostest", appAccountToken: UUID(), subscribedUntil: until,
                  hasActiveAppleSubscription: owned, vacationDaysLeft: days, products: products)
    }

    private func make(loggedIn: Bool = true, info: StoreInfo?, infoFailed: Bool = false, productsLoaded: Bool = true,
                      products: [StoreProductInfo]? = nil, canMakePayments: Bool = true, busy: Bool = false,
                      at date: Date? = nil) -> StoreScreenModel {
        StoreScreenModel.make(loggedIn: loggedIn, info: info, infoFailed: infoFailed, productsLoaded: productsLoaded,
                              products: products ?? prices, canMakePayments: canMakePayments, busy: busy,
                              now: date ?? now, calendar: utc)
    }

    func testLoggedOut() {
        let model = make(loggedIn: false, info: nil)
        XCTAssertEqual(model.status, .loggedOut)
        XCTAssertEqual(model.status.message, "Log in to buy")
        XCTAssertNil(model.yearly)
        XCTAssertFalse(model.buyEnabled)
        XCTAssertFalse(model.restoreEnabled)
    }

    func testNotAllowedOnThisDevice() {
        let model = make(info: info(), canMakePayments: false)
        XCTAssertEqual(model.status, .notAllowed)
        XCTAssertEqual(model.status.message, "Purchases are not available on this device.")
        XCTAssertNil(model.yearly)
        XCTAssertTrue(model.restoreEnabled)
    }

    func testLoadingUntilBothTheGetAndTheProductQueryFinish() {
        XCTAssertEqual(make(info: nil).status, .loading)
        XCTAssertEqual(make(info: info(), productsLoaded: false).status, .loading)
        XCTAssertEqual(make(info: nil, infoFailed: true, productsLoaded: false).status, .loading)
        XCTAssertEqual(StoreScreenModel.Status.loading.message, "Loading…")
        XCTAssertFalse(make(info: nil).buyEnabled)
    }

    func testFailedOnlyWithoutEarlierInfo() {
        let failed = make(info: nil, infoFailed: true)
        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(failed.status.message, "Could not load your pente.org account. Check your connection and try again.")
        XCTAssertEqual(make(info: info(), infoFailed: true).status, .ready)
    }

    func testUnavailableWhenNothingOfferedHasAPrice() {
        let message = "Purchases are not available right now. Please try again later."
        XCTAssertEqual(make(info: info(), products: []).status, .unavailable)
        XCTAssertEqual(make(info: info(products: [])).status, .unavailable)
        XCTAssertEqual(make(info: info(products: ["vacation_99"])).status, .unavailable)
        XCTAssertEqual(make(info: info(), products: []).status.message, message)
    }

    func testOnlyIdsTheGetListsAreOffered() {
        let model = make(info: info(products: ["month_pass", "vacation_30"]))
        XCTAssertEqual(model.status, .ready)
        XCTAssertNil(model.yearly)
        XCTAssertEqual(model.monthPass, StoreScreenModel.MonthPass(price: "$1.99", showStartsLaterNote: false))
        XCTAssertEqual(model.vacation?.options, [StoreScreenModel.VacationOption(productID: "vacation_30", days: 30, price: "$1.99")])
    }

    func testReadyWithoutASubscription() {
        let model = make(info: info())
        XCTAssertEqual(model.status, .ready)
        XCTAssertNil(model.status.message)
        XCTAssertNil(model.subscribedUntil)
        XCTAssertEqual(model.yearly, StoreScreenModel.Yearly(price: "$9.99", subscribeEnabled: true, showOwnedHint: false, showOverlapWarning: false))
        XCTAssertEqual(model.monthPass, StoreScreenModel.MonthPass(price: "$1.99", showStartsLaterNote: false))
        XCTAssertEqual(model.vacation, StoreScreenModel.Vacation(daysLeft: 12, nextYear: 2027, options: [
            StoreScreenModel.VacationOption(productID: "vacation_10", days: 10, price: "$0.99"),
            StoreScreenModel.VacationOption(productID: "vacation_30", days: 30, price: "$1.99"),
            StoreScreenModel.VacationOption(productID: "vacation_60", days: 60, price: "$2.99"),
        ]))
        XCTAssertTrue(model.buyEnabled)
        XCTAssertTrue(model.restoreEnabled)
    }

    func testOwnedAppleSubscriptionHidesTheMonthPass() {
        let until = now.addingTimeInterval(100 * 86_400)
        let model = make(info: info(until: until, owned: true))
        XCTAssertEqual(model.subscribedUntil, until)
        XCTAssertEqual(model.yearly, StoreScreenModel.Yearly(price: "$9.99", subscribeEnabled: false, showOwnedHint: true, showOverlapWarning: false))
        XCTAssertNil(model.monthPass)
        XCTAssertNotNil(model.vacation)
    }

    func testAccessUntilTheFutureWithoutAnAppleSubscriptionWarnsAboutOverlap() {
        let until = now.addingTimeInterval(20 * 86_400)
        let model = make(info: info(until: until))
        XCTAssertEqual(model.subscribedUntil, until)
        XCTAssertEqual(model.yearly, StoreScreenModel.Yearly(price: "$9.99", subscribeEnabled: true, showOwnedHint: false, showOverlapWarning: true))
        XCTAssertEqual(model.monthPass, StoreScreenModel.MonthPass(price: "$1.99", showStartsLaterNote: true))
    }

    func testPastAccessShowsNoHeaderAndNoNotes() {
        let model = make(info: info(until: now.addingTimeInterval(-86_400)))
        XCTAssertNil(model.subscribedUntil)
        XCTAssertEqual(model.yearly?.showOverlapWarning, false)
        XCTAssertEqual(model.monthPass?.showStartsLaterNote, false)
    }

    func testBusyDisablesBuyingAndRestoring() {
        let model = make(info: info(), busy: true)
        XCTAssertEqual(model.status, .ready)
        XCTAssertFalse(model.buyEnabled)
        XCTAssertFalse(model.restoreEnabled)
    }

    func testVacationsAreNeverGatedByASubscription() {
        XCTAssertEqual(make(info: info(until: now.addingTimeInterval(86_400), owned: true)).vacation?.options.count, 3)
    }

    func testNextYearOnNewYearsEve() {
        let newYearsEve = Date(timeIntervalSince1970: 1_798_758_000) // 2026-12-31 23:00 UTC
        XCTAssertEqual(make(info: info(), at: newYearsEve).vacation?.nextYear, 2027)
    }
}
