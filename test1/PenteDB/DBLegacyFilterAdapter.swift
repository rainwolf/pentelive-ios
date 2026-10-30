import Foundation

/// Maps the legacy iOS setup-view fields to wire filters.
enum DBLegacyFilterAdapter {
    static func filters(p1Name: String?, p2Name: String?, p1Rating: String?, p2Rating: String?,
                        eitherSeat: Bool, winner: Int, after: Date?, before: Date?) -> DBFilters? {
        var f = DBFilters()
        f.player1Name = clean(p1Name)
        f.player2Name = clean(p2Name)
        f.player1RatingAbove = rating(p1Rating)
        f.player2RatingAbove = rating(p2Rating)
        f.winner = winner
        f.afterDate = after.map(dateString)
        f.beforeDate = before.map(dateString)
        let hasPlayerFilter = f.player1Name != nil || f.player2Name != nil
            || f.player1RatingAbove > 0 || f.player2RatingAbove > 0
        if eitherSeat && hasPlayerFilter {
            f.player1Seat = 0
            f.player2Seat = 0
        }
        return f.isDefault ? nil : f
    }

    private static func clean(_ s: String?) -> String? {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return t
    }

    private static func rating(_ s: String?) -> Int {
        guard let t = s?.trimmingCharacters(in: .whitespacesAndNewlines), let v = Int(t), v > 0 else { return 0 }
        return v
    }

    /// Gregorian yyyy-MM-dd in the device time zone: keeps the calendar day the user picked.
    private static func dateString(_ d: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
