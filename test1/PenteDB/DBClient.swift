import Foundation

// MARK: - Endpoint

/// Builds `/api/db/*` requests. Pure: no I/O.
struct DBEndpoint {
    static let prodBase = "https://www.pente.org/api/db"
    static let localBase = "https://localhost/api/db"

    let base: String

    /// No credentials: auth is the session cookies the app's login stored in
    /// the shared HTTPCookieStorage. The plaintext password never goes out.
    init(useLocalhost: Bool) {
        base = useLocalhost ? DBEndpoint.localBase : DBEndpoint.prodBase
    }

    /// RFC 3986 unreserved characters only; everything else is percent-encoded.
    private static let strict: CharacterSet = {
        var s = CharacterSet.alphanumerics
        s.insert(charactersIn: "-._~")
        return s
    }()

    static func encode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: strict) ?? ""
    }

    func ping() -> URLRequest { get("/ping") }

    func positionStats(_ body: DBPositionStatsRequest) -> URLRequest {
        post("/position-stats", body)
    }

    func searchGames(_ body: DBGameSearchRequest) -> URLRequest {
        post("/games/search", body)
    }

    func game(gid: Int64) -> URLRequest { get("/games/\(gid)") }

    /// One of the caller's personal games (auth'd; same shape as `game`).
    func collectionGame(wgid: Int64) -> URLRequest { get("/collection/\(wgid)") }

    func players(query: String) -> URLRequest {
        get("/players?q=\(DBEndpoint.encode(query))")
    }

    private func make(_ path: String) -> URLRequest {
        var r = URLRequest(url: URL(string: base + path)!)
        r.setValue("application/json", forHTTPHeaderField: "Accept")
        return r
    }

    private func get(_ path: String) -> URLRequest {
        var r = make(path)
        r.httpMethod = "GET"
        return r
    }

    private func post<T: Encodable>(_ path: String, _ body: T) -> URLRequest {
        var r = make(path)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try? JSONEncoder().encode(body)
        return r
    }
}

// MARK: - Transport

/// Wraps PenteHTTPClient (shared session/SSL). Unlike the dashboard transport it
/// returns non-2xx responses with their body (PenteHTTPClient passes the body
/// through alongside its validation error) so `DBError.map` can read the envelope.
/// Throws only when no HTTP response arrives.
struct DBHTTPTransport: Transport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            PenteHTTPClient.send(request) { data, response, error in
                if let http = response as? HTTPURLResponse {
                    continuation.resume(returning: (data ?? Data(), http))
                    return
                }
                continuation.resume(throwing: error ?? URLError(.badServerResponse))
            }
        }
    }
}

// MARK: - Errors

enum DBError: Error, Equatable {
    case unauthorized
    case subscriptionRequired
    /// 403 `blocked`: same UI state as a `blocked: true` payload (spec §4.0).
    case blocked
    case http(Int, code: String?)
    case network
    case decoding

    static func map(status: Int, body: Data) -> DBError {
        let code = (try? JSONDecoder().decode(DBErrorEnvelope.self, from: body))?.error.code
        switch status {
        case 401: return .unauthorized
        case 403 where code == "subscription_required": return .subscriptionRequired
        case 403 where code == "blocked": return .blocked
        default: return .http(status, code: code)
        }
    }
}

// MARK: - Stale gate

/// Per-endpoint monotonically increasing request ids (spec §4.0 stale guard).
/// Main-thread only.
final class DBRequestGate {
    enum Kind { case stats, games, game, players }

    private var latest: [Kind: Int] = [:]

    func next(_ kind: Kind) -> Int {
        let id = (latest[kind] ?? 0) + 1
        latest[kind] = id
        return id
    }

    func isLatest(_ id: Int, _ kind: Kind) -> Bool {
        latest[kind] == id
    }
}

// MARK: - Client

final class DBClient {
    let endpoint: DBEndpoint
    private let transport: Transport

    init(endpoint: DBEndpoint, transport: Transport = DBHTTPTransport()) {
        self.endpoint = endpoint
        self.transport = transport
    }

    func ping() async throws -> DBPing {
        try await send(endpoint.ping())
    }

    func positionStats(_ request: DBPositionStatsRequest) async throws -> DBPositionStats {
        try await send(endpoint.positionStats(request))
    }

    func searchGames(_ request: DBGameSearchRequest) async throws -> DBGameSearchResult {
        try await send(endpoint.searchGames(request))
    }

    /// A blocked reply is returned as is. Otherwise the header must match `gid`.
    /// A gid <= 0 is never a real game: throws `.decoding` without a request.
    func game(gid: Int64) async throws -> DBGameDetail {
        guard gid > 0 else { throw DBError.decoding }
        return try checked(await send(endpoint.game(gid: gid)), gid: gid)
    }

    /// A personal ("mine") game by wgid; the header gid is the wgid.
    func collectionGame(wgid: Int64) async throws -> DBGameDetail {
        guard wgid > 0 else { throw DBError.decoding }
        return try checked(await send(endpoint.collectionGame(wgid: wgid)), gid: wgid)
    }

    private func checked(_ detail: DBGameDetail, gid: Int64) throws -> DBGameDetail {
        if detail.blocked { return detail }
        guard let header = detail.header, header.hasRealGid, header.gid == gid else {
            throw DBError.decoding
        }
        return detail
    }

    /// The server rejects q shorter than 2 characters; skip the request.
    func players(query: String) async throws -> [String] {
        guard query.count >= 2 else { return [] }
        let r: DBPlayersResult = try await send(endpoint.players(query: query))
        return r.players
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw DBError.network
        }
        guard let http = response as? HTTPURLResponse else { throw DBError.network }
        guard (200..<300).contains(http.statusCode) else {
            throw DBError.map(status: http.statusCode, body: data)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw DBError.decoding
        }
    }
}
