import UIKit
import XCTest
@testable import penteLive

private extension UIView {
    func storeFind<T: UIView>(_ identifier: String, as type: T.Type) -> T? {
        if accessibilityIdentifier == identifier, let view = self as? T { return view }
        for subview in subviews {
            if let found = subview.storeFind(identifier, as: type) { return found }
        }
        return nil
    }

    func storeAll<T: UIView>(_ type: T.Type) -> [T] {
        ((self as? T).map { [$0] } ?? []) + subviews.flatMap { $0.storeAll(type) }
    }
}

/// Spec 5.2: every Store state drawn with the spec's copy, the taps, the
/// presentation, Dynamic Type.
@MainActor
final class StoreViewControllerTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func model(info: StoreInfo? = StoreFixtures.info(), loggedIn: Bool = true, infoFailed: Bool = false,
                       productsLoaded: Bool = true, products: [StoreProductInfo] = StoreFixtures.allProducts,
                       canMakePayments: Bool = true, busy: Bool = false) -> StoreScreenModel {
        StoreScreenModel.make(loggedIn: loggedIn, info: info, infoFailed: infoFailed, productsLoaded: productsLoaded,
                              products: products, canMakePayments: canMakePayments, busy: busy,
                              now: StoreFixtures.fixedNow, calendar: utc)
    }

    private func store(_ model: StoreScreenModel?, _ harness: StoreHarness? = nil) -> StoreViewController {
        let h = harness ?? StoreHarness()
        let store = StoreViewController(service: h.service)
        store.modelOverride = model
        store.loadViewIfNeeded()
        store.render()
        return store
    }

    private func label(_ store: StoreViewController, _ id: String) -> UILabel? {
        store.view.storeFind(id, as: UILabel.self)
    }

    private func button(_ store: StoreViewController, _ id: String) -> UIButton? {
        store.view.storeFind(id, as: UIButton.self)
    }

    /// Not hidden itself and no hidden ancestor up to the Store's view.
    private func shown(_ view: UIView?, in store: StoreViewController) -> Bool {
        var current = view
        while let candidate = current, candidate !== store.view {
            if candidate.isHidden { return false }
            current = candidate.superview
        }
        return view != nil
    }

    private let future = StoreFixtures.fixedNow.addingTimeInterval(30 * 86_400)

    func testStatusStatesShowOnlyTheirMessage() {
        let cases: [(StoreScreenModel, String)] = [
            (model(info: nil, productsLoaded: false), "Loading…"),
            (model(loggedIn: false), "Log in to buy"),
            (model(info: nil, infoFailed: true), "Could not load your pente.org account. Check your connection and try again."),
            (model(canMakePayments: false), "Purchases are not available on this device."),
            (model(products: []), "Purchases are not available right now. Please try again later."),
        ]
        for (state, text) in cases {
            let s = store(state)
            XCTAssertEqual(label(s, "store.status")?.text, text)
            XCTAssertTrue(shown(label(s, "store.status"), in: s), text)
            XCTAssertFalse(shown(s.view.storeFind("store.yearly", as: UIView.self), in: s), text)
            XCTAssertFalse(shown(s.view.storeFind("store.month", as: UIView.self), in: s), text)
            XCTAssertFalse(shown(s.view.storeFind("store.vacation", as: UIView.self), in: s), text)
            XCTAssertTrue(shown(button(s, "store.manage"), in: s), "Manage subscription is always visible")
            XCTAssertEqual(button(s, "store.manage")?.isEnabled, true)
        }
    }

    func testRestoreIsHiddenLoggedOutAndWorksWithoutPayments() {
        let loggedOut = store(model(loggedIn: false))
        XCTAssertFalse(shown(button(loggedOut, "store.restore"), in: loggedOut))
        let notAllowed = store(model(canMakePayments: false))
        XCTAssertTrue(shown(button(notAllowed, "store.restore"), in: notAllowed))
        XCTAssertEqual(button(notAllowed, "store.restore")?.isEnabled, true)
        XCTAssertEqual(button(notAllowed, "store.restore")?.configuration?.title, "Restore purchases")
        XCTAssertEqual(button(notAllowed, "store.manage")?.configuration?.title, "Manage subscription")
    }

    func testReadyCardsUseTheSpecCopy() {
        let s = store(model())
        XCTAssertFalse(shown(label(s, "store.status"), in: s))
        XCTAssertFalse(shown(label(s, "store.subscribedUntil"), in: s))
        XCTAssertEqual(label(s, "store.yearly.title")?.text, "1 year subscription")
        XCTAssertEqual(label(s, "store.yearly.price")?.text, "$9.99 / year")
        XCTAssertEqual(label(s, "store.yearly.benefits")?.text,
                       "\u{2022} No play limits\n\u{2022} Request undo in turn-based games\n\u{2022} Name colour and avatar\n\u{2022} Database access")
        XCTAssertEqual(label(s, "store.yearly.disclosure")?.text, StoreViewController.disclosureText)
        XCTAssertEqual(button(s, "store.yearly.subscribe")?.configuration?.title, "Subscribe")
        XCTAssertEqual(button(s, "store.yearly.subscribe")?.isEnabled, true)
        XCTAssertEqual(button(s, "store.privacy")?.configuration?.title, "Privacy Policy")
        XCTAssertEqual(button(s, "store.eula")?.configuration?.title, "Terms of Use (EULA)")
        XCTAssertFalse(shown(label(s, "store.yearly.owned"), in: s))
        XCTAssertFalse(shown(label(s, "store.yearly.overlap"), in: s))

        XCTAssertEqual(label(s, "store.month.title")?.text, "1 month pass")
        XCTAssertEqual(label(s, "store.month.detail")?.text, "31 days")
        XCTAssertEqual(button(s, "store.month.buy")?.configuration?.title, "Buy 1 month: $1.99")
        XCTAssertFalse(shown(label(s, "store.month.note"), in: s))

        XCTAssertEqual(label(s, "store.vacation.title")?.text, "Extra vacation days (no subscription required)")
        XCTAssertEqual(label(s, "store.vacation.daysLeft")?.text, "You have 12 vacation days left")
        XCTAssertEqual(label(s, "store.vacation.note")?.text, "These vacation days do not roll over to 2027.")
        XCTAssertEqual(button(s, "store.vacation.vacation_10")?.configuration?.title, "Extra vacation days (10): $0.99")
        XCTAssertEqual(button(s, "store.vacation.vacation_30")?.configuration?.title, "Extra vacation days (30): $1.99")
        XCTAssertEqual(button(s, "store.vacation.vacation_60")?.configuration?.title, "Extra vacation days (60): $2.99")
        XCTAssertTrue(shown(button(s, "store.restore"), in: s))
    }

    func testOwnedSubscriptionDisablesSubscribeAndHidesTheMonthPass() {
        let s = store(model(info: StoreFixtures.info(subscribedUntil: future, hasActive: true)))
        XCTAssertEqual(label(s, "store.subscribedUntil")?.text, StoreViewController.subscribedUntilText(future))
        XCTAssertTrue(shown(label(s, "store.subscribedUntil"), in: s))
        XCTAssertEqual(button(s, "store.yearly.subscribe")?.isEnabled, false)
        XCTAssertTrue(shown(label(s, "store.yearly.owned"), in: s))
        XCTAssertEqual(label(s, "store.yearly.owned")?.text,
                       "You already have this subscription. Use Manage subscription below.")
        XCTAssertFalse(shown(label(s, "store.yearly.overlap"), in: s))
        XCTAssertFalse(shown(s.view.storeFind("store.month", as: UIView.self), in: s))
        XCTAssertTrue(shown(s.view.storeFind("store.vacation", as: UIView.self), in: s), "D4: never gated")
    }

    func testAccessFromElsewhereShowsTheOverlapWarningAndThePassNote() {
        let s = store(model(info: StoreFixtures.info(subscribedUntil: future, hasActive: false)))
        XCTAssertTrue(shown(label(s, "store.yearly.overlap"), in: s))
        XCTAssertEqual(label(s, "store.yearly.overlap")?.text,
                       "You already have access until the date above. A new subscription starts now and runs alongside your current access; it is not added on after it.")
        XCTAssertEqual(button(s, "store.yearly.subscribe")?.isEnabled, true)
        XCTAssertTrue(shown(label(s, "store.month.note"), in: s))
        XCTAssertEqual(label(s, "store.month.note")?.text, "Your pass starts when your current access ends.")
    }

    func testBusyDisablesEveryBuyButtonAndRestore() {
        let s = store(model(busy: true))
        XCTAssertEqual(button(s, "store.yearly.subscribe")?.isEnabled, false)
        XCTAssertEqual(button(s, "store.month.buy")?.isEnabled, false)
        XCTAssertEqual(button(s, "store.vacation.vacation_10")?.isEnabled, false)
        XCTAssertEqual(button(s, "store.restore")?.isEnabled, false)
        XCTAssertEqual(button(s, "store.manage")?.isEnabled, true)
    }

    func testSubscribeTapBuysTheYearlyWithTheFreshToken() async {
        let h = StoreHarness()
        await h.loadBoth()
        let s = store(nil, h)
        XCTAssertEqual(s.renderedModel?.status, .ready)
        button(s, "store.yearly.subscribe")?.sendActions(for: .touchUpInside)
        await waitFor { h.source.purchasedProducts == [StoreProducts.yearly] }
        XCTAssertEqual(h.source.purchaseTokens, [StoreFixtures.tokenA])
    }

    func testMonthAndVacationTapsBuyThatProduct() async {
        let h = StoreHarness()
        await h.loadBoth()
        let s = store(nil, h)
        button(s, "store.month.buy")?.sendActions(for: .touchUpInside)
        await waitFor { h.source.purchasedProducts == [StoreProducts.monthPass] && !h.service.isBusy }
        button(s, "store.vacation.vacation_30")?.sendActions(for: .touchUpInside)
        await waitFor { h.source.purchasedProducts == [StoreProducts.monthPass, "vacation_30"] }
    }

    func testRestoreTapRestores() async {
        let h = StoreHarness()
        await h.loadBoth()
        let s = store(nil, h)
        button(s, "store.restore")?.sendActions(for: .touchUpInside)
        await waitFor { h.messages.shown == [.noPurchasesToRestore] }
        XCTAssertEqual(h.source.syncCalls, 1)
    }

    func testPrivacyAndEulaLinksPushTheWebPage() {
        let s = store(model())
        let nav = UINavigationController(rootViewController: s)
        button(s, "store.privacy")?.sendActions(for: .touchUpInside)
        XCTAssertTrue(nav.topViewController is PenteWebViewController)
        nav.popToRootViewController(animated: false)
        button(s, "store.eula")?.sendActions(for: .touchUpInside)
        XCTAssertTrue(nav.topViewController is PenteWebViewController)
        XCTAssertEqual(StoreViewController.privacyPolicyAddress, "https://www.pente.org/help/helpWindow.jsp?file=privacyPolicy")
        XCTAssertEqual(StoreViewController.eulaAddress, "https://www.pente.org/help/helpWindow.jsp?file=eula")
    }

    func testIPhonePushesAndIPadPresentsAFormSheet() {
        XCTAssertEqual(StoreViewController.presentation(idiom: .phone, hasNavigationController: true), .push)
        XCTAssertEqual(StoreViewController.presentation(idiom: .pad, hasNavigationController: true), .formSheet)
        XCTAssertEqual(StoreViewController.presentation(idiom: .phone, hasNavigationController: false), .formSheet)
    }

    func testAppearingLoadsInfoAndProducts() async {
        let h = StoreHarness()
        let s = store(nil, h)
        XCTAssertEqual(s.renderedModel?.status, .loading)
        s.beginAppearanceTransition(true, animated: false)
        s.endAppearanceTransition()
        await waitFor { h.server.fetches == ["iostest"] && h.service.productsLoaded }
        await waitFor { s.renderedModel?.status == .ready }
        XCTAssertEqual(s.title, "Store")
    }

    func testEveryLabelFollowsDynamicType() {
        let s = store(model(info: StoreFixtures.info(subscribedUntil: future)))
        let labels = s.view.storeAll(UILabel.self).filter { $0.accessibilityIdentifier?.hasPrefix("store.") == true }
        XCTAssertGreaterThanOrEqual(labels.count, 14)
        for label in labels {
            XCTAssertTrue(label.adjustsFontForContentSizeCategory, label.accessibilityIdentifier ?? "")
            XCTAssertEqual(label.numberOfLines, 0, label.accessibilityIdentifier ?? "")
        }
    }

    func testSubscribedUntilUsesTheMediumDate() {
        let date = StoreFixtures.fixedNow
        XCTAssertEqual(StoreViewController.subscribedUntilText(date),
                       "Subscribed until " + DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .none))
    }
}
