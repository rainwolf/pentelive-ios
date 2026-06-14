import Foundation

@objc enum DashboardErrorCode: Int {
    case network = 1
    case http = 2
    case decoding = 3
    case invalidCredentials = 4
}

enum DashboardError {
    static let domain = "org.pente.DashboardError"
    static func make(_ code: DashboardErrorCode, message: String) -> NSError {
        NSError(domain: domain, code: code.rawValue,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}
