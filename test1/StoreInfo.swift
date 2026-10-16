import Foundation

/// The GET /gameServer/appStorePurchase JSON of one pente.org account
/// (spec 4). `vacationAllowed` is ignored (D4); prices never come from here.
struct StoreInfo: Equatable {
    /// Lowercased pente.org username this info belongs to. Info for another
    /// username is never used (spec 5.1).
    let username: String
    let appAccountToken: UUID
    let subscribedUntil: Date?
    let hasActiveAppleSubscription: Bool
    let vacationDaysLeft: Int
    let products: [String]

    /// nil when the body is not a JSON object or has no valid
    /// `appAccountToken`: a purchase cannot be bound without one. Every other
    /// field falls back when missing, null or of the wrong type.
    static func parse(_ data: Data, username: String) -> StoreInfo? {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let json = object as? [String: Any],
              let tokenString = json["appAccountToken"] as? String,
              let token = UUID(uuidString: tokenString) else { return nil }
        let until = number(json["subscribedUntil"]).map { Date(timeIntervalSince1970: $0 / 1000) }
        let days = number(json["vacationDaysLeft"]).map { Int(min(max($0, 0), 100_000)) } ?? 0
        let products = (json["products"] as? [Any])?.compactMap { $0 as? String } ?? []
        return StoreInfo(username: username.lowercased(),
                         appAccountToken: token,
                         subscribedUntil: until,
                         hasActiveAppleSubscription: bool(json["hasActiveAppleSubscription"]) ?? false,
                         vacationDaysLeft: days,
                         products: products)
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber, !isBoolean(number) else { return nil }
        let double = number.doubleValue
        return double.isFinite ? double : nil
    }

    private static func bool(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, isBoolean(number) else { return nil }
        return number.boolValue
    }
}
