import UIKit

/// Single place that decides where a link may open.
/// - pente.org (and subdomains, plus localhost when the app's dev flag is on): in the in-app web view.
/// - any other http(s) link, mailto:, tel:: system handler, or blocked on kid accounts.
/// - everything else (javascript:, file:, data:, intent:, unknown, relative, empty): never navigated.
@objc final class LinkPolicy: NSObject {
    enum Action: Equatable {
        case inApp
        case external
        case blockedForKid
        case blocked
    }

    static let kidBlockedMessage = "Links outside pente.org are not available on kid accounts."

    /// Pure rule: only a logged-in account whose kid status is known and false is an adult.
    /// Logged out, guest, or status not yet loaded all count as kid.
    static func shouldTreatAsKid(loggedIn: Bool, kidStatusKnown: Bool, isKid: Bool) -> Bool {
        !(loggedIn && kidStatusKnown && !isKid)
    }

    /// The one place the kid input is derived, from the app's live login state at call time.
    @objc static func shouldTreatAsKid() -> Bool {
        guard let nav = AppDelegate.rootNavigationController() else { return true }
        return shouldTreatAsKid(loggedIn: nav.loggedIn,
                                kidStatusKnown: nav.player?.kidStatusKnown ?? false,
                                isKid: nav.player?.isKid ?? true)
    }

    /// Parses `string` into a URL, rejecting anything with backslashes or control/space characters
    /// (parsers disagree on those, which is how host-check bypasses work).
    static func parse(_ string: String?) -> URL? {
        guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
        for scalar in trimmed.unicodeScalars where scalar == "\\" || scalar.value <= 0x20 || scalar.value == 0x7F {
            return nil
        }
        return URL(string: trimmed)
    }

    static func isPenteHost(_ host: String, allowLocalhost: Bool) -> Bool {
        let host = host.lowercased()
        return host == "pente.org" || host.hasSuffix(".pente.org") || (allowLocalhost && host == "localhost")
    }

    static func classify(_ string: String?, isKid: Bool, allowLocalhost: Bool) -> Action {
        guard let url = parse(string), let scheme = url.scheme?.lowercased() else { return .blocked }
        switch scheme {
        case "http", "https":
            // Userinfo (https://pente.org@evil.com) is never legitimate here.
            guard url.user == nil, url.password == nil, let host = url.host, !host.isEmpty,
                  host.unicodeScalars.allSatisfy({ "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-".unicodeScalars.contains($0) })
            else { return .blocked }
            if isPenteHost(host, allowLocalhost: allowLocalhost) { return .inApp }
            return isKid ? .blockedForKid : .external
        case "mailto", "tel":
            return isKid ? .blockedForKid : .external
        default:
            return .blocked
        }
    }

    static func classify(_ string: String?) -> Action {
        classify(string, isKid: shouldTreatAsKid(), allowLocalhost: developmentEnabled())
    }

    /// Opens `urlString` per the policy. In-app pages are pushed on `presenter`'s navigation controller.
    @objc static func open(_ urlString: String?, from presenter: UIViewController?) {
        switch classify(urlString) {
        case .inApp:
            guard let urlString = parse(urlString)?.absoluteString else { return }
            presenter?.navigationController?.pushViewController(PenteWebViewController(address: urlString), animated: true)
        case .external:
            if let url = parse(urlString) { UIApplication.shared.open(url, options: [:], completionHandler: nil) }
        case .blockedForKid:
            showKidBlockedAlert(from: presenter)
        case .blocked:
            break
        }
    }

    /// For the app's local-HTML web views (stats pages): only the app's own about:blank load may proceed;
    /// link taps and any other navigation go through the policy instead.
    @objc static func shouldLoadInLocalWebView(_ url: URL?, linkActivated: Bool, from presenter: UIViewController?) -> Bool {
        if !linkActivated, url == nil || url?.scheme?.lowercased() == "about" { return true }
        open(url?.absoluteString, from: presenter)
        return false
    }

    @objc static func showKidBlockedAlert(from presenter: UIViewController?) {
        guard let host = presenter ?? topViewController() else { return }
        let alert = UIAlertController(title: nil,
                                      message: NSLocalizedString(kidBlockedMessage, comment: ""),
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
        host.present(alert, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}
