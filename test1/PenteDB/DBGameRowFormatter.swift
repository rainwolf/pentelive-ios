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
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = timeZone
        f.setLocalizedDateFormatFromTemplate(sameYear ? "MMMd" : "yMMMd")
        return f.string(from: parsed)
    }

    private static func parseISO(_ s: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let d = plain.date(from: s) { return d }
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return frac.date(from: s)
    }
}
