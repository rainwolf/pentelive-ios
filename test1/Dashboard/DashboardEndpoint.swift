import Foundation

struct DashboardEndpoint {
    /// `useLocalhost` defaults to the app's dev flag (`developmentEnabled()`), matching the
    /// legacy `if (development)` URL swap. Tests pass it explicitly.
    func dashboardRequest(username: String, password: String,
                          useLocalhost: Bool = developmentEnabled()) -> URLRequest {
        let host = useLocalhost ? "https://localhost" : "https://www.pente.org"
        var comps = URLComponents(string: "\(host)/gameServer/mobile/json/index.jsp")!
        comps.queryItems = [URLQueryItem(name: "name", value: username),
                            URLQueryItem(name: "password", value: password)]
        var req = URLRequest(url: comps.url!)
        req.httpMethod = "GET"
        req.timeoutInterval = 7.0
        return req
    }
}
