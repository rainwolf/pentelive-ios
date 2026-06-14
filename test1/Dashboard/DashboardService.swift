import Foundation

@objc final class DashboardService: NSObject {
    private let transport: Transport
    private let endpoint: DashboardEndpoint

    /// Designated init used by tests (non-@objc because Transport is a Swift protocol).
    init(transport: Transport = PenteHTTPClientTransport(),
         endpoint: DashboardEndpoint = DashboardEndpoint()) {
        self.transport = transport
        self.endpoint = endpoint
        super.init()
    }

    /// Zero-arg init for ObjC callers: `[[DashboardService alloc] init]`.
    @objc override init() {
        self.transport = PenteHTTPClientTransport()
        self.endpoint = DashboardEndpoint()
        super.init()
    }

    /// ObjC sees `loadDashboardWithUsername:password:completionHandler:`.
    @objc func loadDashboard(username: String, password: String) async throws -> Dashboard {
        let request = endpoint.dashboardRequest(username: username, password: password)
        let (data, response) = try await transport.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw DashboardError.make(.http, message: "HTTP \(http.statusCode)")
        }

        let wire: WireDashboard
        do {
            wire = try JSONDecoder().decode(WireDashboard.self, from: data)
        } catch {
            throw DashboardError.make(.decoding, message: error.localizedDescription)
        }

        guard wire.invitationsReceived != nil else {
            throw DashboardError.make(.invalidCredentials, message: "Not registered")
        }
        return DashboardMapping.map(wire)
    }
}
