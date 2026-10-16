import Foundation

/// What the Store screen shows, decided from the service's state alone
/// (spec 5.2), so every state is unit-tested without UIKit.
struct StoreScreenModel: Equatable {
    enum Status: Equatable {
        case loading
        case loggedOut
        case failed
        case notAllowed
        case unavailable
        case ready

        /// The status line, or nil when the cards are shown.
        var message: String? {
            switch self {
            case .loading:
                return NSLocalizedString("Loading…", comment: "")
            case .loggedOut:
                return NSLocalizedString("Log in to buy", comment: "")
            case .failed:
                return NSLocalizedString("Could not load your pente.org account. Check your connection and try again.", comment: "")
            case .notAllowed:
                return NSLocalizedString("Purchases are not available on this device.", comment: "")
            case .unavailable:
                return NSLocalizedString("Purchases are not available right now. Please try again later.", comment: "")
            case .ready:
                return nil
            }
        }
    }

    struct Yearly: Equatable {
        let price: String
        let subscribeEnabled: Bool
        let showOwnedHint: Bool
        let showOverlapWarning: Bool
    }

    struct MonthPass: Equatable {
        let price: String
        let showStartsLaterNote: Bool
    }

    struct VacationOption: Equatable {
        let productID: String
        let days: Int
        let price: String
    }

    struct Vacation: Equatable {
        let daysLeft: Int
        let nextYear: Int
        let options: [VacationOption]
    }

    let status: Status
    /// Header "Subscribed until <medium date>", only when in the future.
    let subscribedUntil: Date?
    let yearly: Yearly?
    let monthPass: MonthPass?
    let vacation: Vacation?
    /// Buy buttons work only when ready and no buy or restore is running.
    let buyEnabled: Bool
    let restoreEnabled: Bool

    static func make(loggedIn: Bool, info: StoreInfo?, infoFailed: Bool, productsLoaded: Bool,
                     products: [StoreProductInfo], canMakePayments: Bool, busy: Bool, now: Date,
                     calendar: Calendar = .current) -> StoreScreenModel {
        func only(_ status: Status, subscribedUntil: Date? = nil) -> StoreScreenModel {
            StoreScreenModel(status: status, subscribedUntil: subscribedUntil, yearly: nil, monthPass: nil,
                             vacation: nil, buyEnabled: false, restoreEnabled: loggedIn && !busy)
        }
        guard loggedIn else { return only(.loggedOut) }
        guard canMakePayments else { return only(.notAllowed) }
        if !productsLoaded || (info == nil && !infoFailed) { return only(.loading) }
        guard let info = info else { return only(.failed) }

        let future = info.subscribedUntil.flatMap { $0 > now ? $0 : nil }
        let offered = Set(info.products)
        var prices: [String: String] = [:]
        for product in products where offered.contains(product.id) {
            prices[product.id] = product.displayPrice
        }
        guard !prices.isEmpty else { return only(.unavailable, subscribedUntil: future) }

        let owned = info.hasActiveAppleSubscription
        let yearly = prices[StoreProducts.yearly].map {
            Yearly(price: $0, subscribeEnabled: !owned, showOwnedHint: owned,
                   showOverlapWarning: future != nil && !owned)
        }
        let monthPass = owned ? nil : prices[StoreProducts.monthPass].map {
            MonthPass(price: $0, showStartsLaterNote: future != nil)
        }
        let options = StoreProducts.vacations.compactMap { id -> VacationOption? in
            guard let price = prices[id], let days = StoreProducts.vacationDays[id] else { return nil }
            return VacationOption(productID: id, days: days, price: price)
        }
        let vacation = options.isEmpty ? nil : Vacation(daysLeft: info.vacationDaysLeft,
                                                        nextYear: calendar.component(.year, from: now) + 1,
                                                        options: options)
        return StoreScreenModel(status: .ready, subscribedUntil: future, yearly: yearly, monthPass: monthPass,
                                vacation: vacation, buyEnabled: !busy, restoreEnabled: !busy)
    }
}
