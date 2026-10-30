import Foundation
import ObjectiveC

/// Unit-test-host network tripwire. main.m calls `install()` before
/// UIApplicationMain only when +[AppDelegate isRunningUnitTests] is true, so in
/// production nothing here is registered and `blocks(_:)` always answers false.
///
/// Once installed, every URL-loading-system request whose host is not
/// localhost/127.0.0.1/::1 fails locally with `errorDomain`/`errorCode`, is
/// NSLogged as "TEST-NETWORK-BLOCKED <method> <url>" and recorded in
/// `recordedURLs`. Coverage: URLSession.shared and the legacy loaders
/// (registerClass), plus every session built from
/// URLSessionConfiguration.default/.ephemeral (swizzled getters put this class
/// first in protocolClasses). WKWebView and NWConnection bypass the URL loading
/// system; their call sites ask `blocks(_:)` directly.
@objc(PenteTestNetworkTripwire)
final class TestNetworkTripwire: URLProtocol {
    @objc static let errorDomain = "PenteTestNetworkTripwire"
    @objc static let errorCode = -47_001

    private static let lock = NSLock()
    private static var installed = false
    private static var recorded: [URL] = []

    @objc static var isInstalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return installed
    }

    /// Every URL the tripwire refused, in order.
    @objc static var recordedURLs: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return recorded
    }

    /// Idempotent. Callers must gate on +[AppDelegate isRunningUnitTests].
    @objc static func install() {
        lock.lock()
        let already = installed
        installed = true
        lock.unlock()
        if already { return }
        URLProtocol.registerClass(TestNetworkTripwire.self)
        injectIntoConfigurationGetter("defaultSessionConfiguration")
        injectIntoConfigurationGetter("ephemeralSessionConfiguration")
        NSLog("TEST-NETWORK-TRIPWIRE installed")
    }

    /// True when the tripwire is installed and `url` would leave the device.
    /// Pure: does not record or log (see `refuse(_:method:)`).
    @objc static func blocks(_ url: URL) -> Bool {
        guard isInstalled else { return false }
        return isRemote(url)
    }

    /// For callers outside the URL loading system (WKWebView, NWConnection):
    /// returns true, logging and recording, when the load must not happen.
    @objc static func refuse(_ url: URL, method: String) -> Bool {
        guard blocks(url) else { return false }
        record(url, method: method)
        return true
    }

    /// Raw-socket variant of `refuse(_:method:)`.
    @objc static func refuseSocket(host: String, port: Int) -> Bool {
        guard isInstalled, !isLocalHost(host) else { return false }
        record(URL(string: "tcp://\(host):\(port)") ?? URL(string: "tcp://invalid-host")!,
               label: "tcp://\(host):\(port)", method: "CONNECT")
        return true
    }

    static func isRemote(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "file" || scheme == "data" || scheme == "about" || scheme == "blob" { return false }
        return !isLocalHost(url.host ?? "")
    }

    static func isLocalHost(_ rawHost: String) -> Bool {
        let host = rawHost.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    private static func record(_ url: URL, label: String? = nil, method: String) {
        lock.lock()
        recorded.append(url)
        lock.unlock()
        NSLog("TEST-NETWORK-BLOCKED %@ %@", method, label ?? url.absoluteString)
    }

    private static func injectIntoConfigurationGetter(_ name: String) {
        let selector = NSSelectorFromString(name)
        guard let method = class_getClassMethod(URLSessionConfiguration.self, selector) else {
            NSLog("TEST-NETWORK-TRIPWIRE could not swizzle %@", name)
            return
        }
        typealias Getter = @convention(c) (AnyClass, Selector) -> URLSessionConfiguration
        let original = unsafeBitCast(method_getImplementation(method), to: Getter.self)
        let replacement: @convention(block) (AnyClass) -> URLSessionConfiguration = { cls in
            let configuration = original(cls, selector)
            var classes = configuration.protocolClasses ?? []
            if !classes.contains(where: { $0 == TestNetworkTripwire.self }) {
                classes.insert(TestNetworkTripwire.self, at: 0)
                configuration.protocolClasses = classes
            }
            return configuration
        }
        method_setImplementation(method, imp_implementationWithBlock(replacement))
    }

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return isRemote(url)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let url = request.url ?? URL(string: "about:blank")!
        TestNetworkTripwire.record(url, method: request.httpMethod ?? "GET")
        let error = NSError(domain: TestNetworkTripwire.errorDomain,
                            code: TestNetworkTripwire.errorCode,
                            userInfo: [NSLocalizedDescriptionKey: "Network blocked in unit-test host: \(url.absoluteString)",
                                       NSURLErrorFailingURLErrorKey: url])
        client?.urlProtocol(self, didFailWithError: error)
    }

    override func stopLoading() {}
}
