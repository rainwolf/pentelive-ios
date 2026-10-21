import Foundation

/// Network access for `/gameServer/kids`. Completions run on the main queue
/// (PenteHTTPClient guarantees it).
@objc final class KidAccountsService: NSObject {
    private static let timeout: TimeInterval = 7.0

    private static var url: URL {
        URL(string: (developmentEnabled() ? "https://localhost" : "https://www.pente.org") + "/gameServer/kids")!
    }

    private static func credentials() -> [(String, String)] {
        let defaults = UserDefaults.standard
        return [("name2", defaults.string(forKey: "username") ?? ""),
                ("password2", defaults.string(forKey: "password") ?? "")]
    }

    static func getRequest() -> URLRequest {
        var request = URLRequest(url: URL(string: url.absoluteString + "?" + BlockedPlayers.formEncode(credentials()))!)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    static func activeGamesRequest(kidPid: Int64) -> URLRequest {
        let query = BlockedPlayers.formEncode([("action", "activeGames"), ("kidPid", String(kidPid))] + credentials())
        var request = URLRequest(url: URL(string: url.absoluteString + "?" + query)!)
        request.httpMethod = "GET"
        request.timeoutInterval = timeout
        request.cachePolicy = .reloadIgnoringLocalCacheData
        return request
    }

    static func postRequest(_ action: KidAction) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(BlockedPlayers.formEncode(action.params + credentials()).utf8)
        return request
    }

    private static func send(_ request: URLRequest, _ completion: @escaping (KidAccountsState?, String?) -> Void) {
        PenteHTTPClient.send(request) { data, _, _ in
            if let state = KidAccounts.parse(data) {
                completion(state, nil)
            } else {
                completion(nil, KidAccounts.parseError(data)
                    ?? NSLocalizedString("Please try again.", comment: "Kid accounts error"))
            }
        }
    }

    static func load(_ completion: @escaping (KidAccountsState?, String?) -> Void) {
        send(getRequest(), completion)
    }

    /// POSTs a change; the reply is the caller's GET view after the change.
    static func perform(_ action: KidAction, _ completion: @escaping (KidAccountsState?, String?) -> Void) {
        send(postRequest(action), completion)
    }

    /// A kid's active turn-based games; on failure nil plus a message.
    static func activeGames(kidPid: Int64, _ completion: @escaping ([KidActiveGame]?, String?) -> Void) {
        PenteHTTPClient.send(activeGamesRequest(kidPid: kidPid)) { data, _, _ in
            if let games = KidAccounts.parseActiveGames(data) {
                completion(games, nil)
            } else {
                completion(nil, KidAccounts.parseError(data)
                    ?? NSLocalizedString("Could not load games.", comment: "Kid active games error"))
            }
        }
    }

    /// Names a kid may message (whitelist plus parent); `[]` on any failure or for a non-kid.
    @objc static func allowedRecipients(completion: @escaping ([String]) -> Void) {
        load { state, _ in
            completion(state.map { KidAccounts.allowedRecipients($0) } ?? [])
        }
    }
}
