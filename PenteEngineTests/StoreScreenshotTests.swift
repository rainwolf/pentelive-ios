import UIKit
import XCTest
@testable import penteLive

/// Spec 7.4: every Store state on this simulator, light and dark, as the app
/// presents it (pushed on iPhone, form sheet on iPad). Writes PNGs to
/// $STORE_SHOTS_DIR (pass TEST_RUNNER_STORE_SHOTS_DIR=<dir> to xcodebuild);
/// skipped without it, so the normal suite writes nothing.
@MainActor
final class StoreScreenshotTests: XCTestCase {
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

    private var states: [(String, StoreScreenModel)] {
        let future = StoreFixtures.fixedNow.addingTimeInterval(30 * 86_400)
        return [
            ("1-loading", model(info: nil, productsLoaded: false)),
            ("2-logged-out", model(loggedIn: false)),
            ("3-could-not-load", model(info: nil, infoFailed: true)),
            ("4-not-allowed", model(canMakePayments: false)),
            ("5-unavailable", model(products: [])),
            ("6-ready", model()),
            ("7-owned", model(info: StoreFixtures.info(subscribedUntil: future, hasActive: true))),
            ("8-overlap", model(info: StoreFixtures.info(subscribedUntil: future, hasActive: false))),
            ("9-busy", model(busy: true)),
        ]
    }

    func testEveryStoreStateInLightAndDark() throws {
        guard let directory = ProcessInfo.processInfo.environment["STORE_SHOTS_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_STORE_SHOTS_DIR to write the Store screenshots")
        }
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let device = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        var written = 0
        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .dark ? "dark" : "light"
            for (name, state) in states {
                try write(try shoot(state, style: style, largeText: false), "\(device)-\(name)-\(suffix)", directory)
                written += 1
            }
            try write(try shoot(model(), style: style, largeText: true), "\(device)-10-ready-large-text-\(suffix)",
                      directory)
            written += 1
        }
        XCTAssertEqual(written, 20)
    }

    private func write(_ image: UIImage, _ name: String, _ directory: String) throws {
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name + ".png"))
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func shoot(_ state: StoreScreenModel, style: UIUserInterfaceStyle, largeText: Bool) throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.overrideUserInterfaceStyle = style
        if largeText, #available(iOS 17.0, *) {
            window.traitOverrides.preferredContentSizeCategory = .accessibilityExtraLarge
        }
        let harness = StoreHarness()
        let store = StoreViewController(service: harness.service)
        store.modelOverride = state
        let games = UIViewController()
        games.view.backgroundColor = .systemBackground
        games.title = "home"
        let root = UINavigationController(rootViewController: games)
        window.rootViewController = root
        window.makeKeyAndVisible()

        if UIDevice.current.userInterfaceIdiom == .pad {
            store.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: nil)
            let sheet = UINavigationController(rootViewController: store)
            sheet.modalPresentationStyle = .formSheet
            let presented = expectation(description: "form sheet presented")
            root.present(sheet, animated: false) { presented.fulfill() }
            wait(for: [presented], timeout: 5)
        } else {
            root.pushViewController(store, animated: false)
        }
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        window.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        root.dismiss(animated: false)
        window.isHidden = true
        return image
    }
}
