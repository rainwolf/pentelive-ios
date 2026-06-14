import Foundation

protocol Transport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Default transport wrapping the existing AFNetworking-backed PenteHTTPClient,
/// preserving its session/SSL behavior. Completion fires on the main queue.
struct PenteHTTPClientTransport: Transport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            PenteHTTPClient.send(request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: DashboardError.make(.network, message: error.localizedDescription))
                    return
                }
                guard let data = data, let response = response else {
                    continuation.resume(throwing: DashboardError.make(.network, message: "Empty response"))
                    return
                }
                continuation.resume(returning: (data, response))
            }
        }
    }
}
