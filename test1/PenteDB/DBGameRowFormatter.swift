import Foundation

enum DBGameRowFormatter {
    static func score(winner: Int) -> String {
        switch winner {
        case 1: return "1 \u{2013} 0"
        case 2: return "0 \u{2013} 1"
        default: return "\u{2013}"
        }
    }

    static func date(iso: String?, now: Date, locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        guard let iso = iso, let parsed = parseISO(iso) else { return "" }
        // Compare years on the Gregorian calendar so a Buddhist/other locale never skews the check.
        var greg = Calendar(identifier: .gregorian)
        greg.timeZone = timeZone
        let sameYear = greg.component(.year, from: parsed) == greg.component(.year, from: now)
        return displayFormatter(template: sameYear ? "MMMd" : "yMMMd", locale: locale, timeZone: timeZone)
            .string(from: parsed)
    }

    // The list formats a date per cell, so formatters are built once per
    // (template, locale, time zone) and reused. DateFormatter and
    // ISO8601DateFormatter are thread-safe for formatting and parsing.
    private static let lock = NSLock()
    private static var displayCache: [String: DateFormatter] = [:]
    private static let plainISO = ISO8601DateFormatter()
    private static let fractionalISO: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func displayFormatter(template: String, locale: Locale, timeZone: TimeZone) -> DateFormatter {
        let key = "\(template)|\(locale.identifier)|\(timeZone.identifier)"
        lock.lock()
        defer { lock.unlock() }
        if let f = displayCache[key] { return f }
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = timeZone
        f.setLocalizedDateFormatFromTemplate(template)
        displayCache[key] = f
        return f
    }

    private static func parseISO(_ s: String) -> Date? {
        plainISO.date(from: s) ?? fractionalISO.date(from: s)
    }
}
