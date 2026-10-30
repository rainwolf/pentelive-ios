import XCTest
@testable import penteLive

final class DBFilterStateTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "DBFilterStateTests-\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    func testDefaultIsNilWire() {
        XCTAssertNil(DBFilterState().toWire())
        XCTAssertTrue(DBFilterState().isDefault)
    }

    func testEitherSeatSendsZeroZero() {
        var s = DBFilterState()
        s.eitherSeat = true
        XCTAssertNil(s.toWire(), "either seat alone is not a filter")
        s.player1 = " alice "
        let w = s.toWire()
        XCTAssertEqual(w?.player1Name, "alice")
        XCTAssertEqual(w?.player1Seat, 0)
        XCTAssertEqual(w?.player2Seat, 0)
        s.player1 = ""
        s.p2MinRating = 1700
        XCTAssertEqual(s.toWire()?.player1Seat, 0)
    }

    func testRatingIsInclusiveValue() {
        var s = DBFilterState()
        s.p1MinRating = 1700
        s.p2MinRating = -5
        let w = s.toWire()
        XCTAssertEqual(w?.player1RatingAbove, 1700)
        XCTAssertEqual(w?.player2RatingAbove, 0)
    }

    func testSpeedGameId() {
        var s = DBFilterState()
        s.baseGame = 3
        s.speed = true
        XCTAssertEqual(s.gameId, 4)
        s.baseGame = 27
        XCTAssertEqual(s.gameId, 27, "Swap2 has no speed variant")
        s.speed = false
        s.baseGame = 3
        XCTAssertEqual(s.gameId, 3)
    }

    func testSetGameFromId() {
        var s = DBFilterState()
        s.setGame(id: 4)
        XCTAssertEqual(s.baseGame, 3)
        XCTAssertTrue(s.speed)
        s.setGame(id: 0)
        XCTAssertEqual(s.baseGame, 3)
        XCTAssertTrue(s.speed)
    }

    func testExtendedKeysGatedPerServerFeature() {
        var s = DBFilterState()
        s.excludeTimeouts = true
        s.liveOrTurnBased = "live"
        s.winner = 1
        XCTAssertEqual(s.toWire()?.features, DBServerFeatures.none)
        let timeouts = s.toWire(features: DBServerFeatures(features: ["excludeTimeouts"]))
        XCTAssertEqual(timeouts?.features.excludeTimeouts, true)
        XCTAssertEqual(timeouts?.features.liveOrTurnBased, false)
        let both = DBServerFeatures(features: ["excludeTimeouts", "liveOrTurnBased", "badges"])
        let w = s.toWire(features: both)
        XCTAssertEqual(w?.excludeTimeouts, true)
        XCTAssertEqual(w?.liveOrTurnBased, "live")
        s.liveOrTurnBased = "turnBased"
        XCTAssertEqual(s.toWire(features: both)?.liveOrTurnBased, "turnBased")
    }

    func testExtendedValuesIgnoredInChipAndDefaultWhenCapabilityOff() {
        var s = DBFilterState()
        s.excludeTimeouts = true
        s.liveOrTurnBased = "live"
        XCTAssertTrue(s.isDefault)
        XCTAssertNil(s.toWire())
        XCTAssertFalse(s.chipSummary().contains("no timeouts"))
        XCTAssertFalse(s.chipSummary().contains("live only"))
        let timeouts = DBServerFeatures(features: ["excludeTimeouts"])
        XCTAssertFalse(s.isDefault(features: timeouts))
        XCTAssertTrue(s.chipSummary(features: timeouts).contains("no timeouts"))
        XCTAssertFalse(s.chipSummary(features: timeouts).contains("live only"))
        let live = DBServerFeatures(features: ["liveOrTurnBased"])
        XCTAssertFalse(s.isDefault(features: live))
        XCTAssertTrue(s.chipSummary(features: live).contains("live only"))
        XCTAssertFalse(s.chipSummary(features: live).contains("no timeouts"))
        s.liveOrTurnBased = "turnBased"
        XCTAssertTrue(s.chipSummary(features: live).contains("turn-based only"))
    }

    func testDatesEncodeGregorianUnderBuddhistCalendar() {
        let tz = TimeZone(identifier: "Pacific/Kiritimati")!
        var cal = Calendar(identifier: .buddhist)
        cal.timeZone = tz
        cal.locale = Locale(identifier: "th_TH")
        var comps = DateComponents()
        comps.era = 1
        comps.year = 2568 // Buddhist year == 2025 CE
        comps.month = 3
        comps.day = 4
        comps.hour = 12
        let noon = cal.date(from: comps)!
        var s = DBFilterState()
        s.after = noon
        s.before = noon
        let w = s.toWire(timeZone: tz)
        XCTAssertEqual(w?.afterDate, "2025-03-04")
        XCTAssertEqual(w?.beforeDate, "2025-03-04")
    }

    func testChipSummary() {
        var s = DBFilterState()
        XCTAssertEqual(s.chipSummary(), "Pente")
        s.player1 = "alice"
        s.p1MinRating = 1700
        s.eitherSeat = true
        XCTAssertEqual(s.chipSummary(), "Pente · alice 1700+ · either seat")
    }

    func testChipSummaryVariants() {
        var s = DBFilterState()
        s.setGame(id: 4)
        s.p1MinRating = 1700
        s.player2 = "bob"
        s.winner = 2
        XCTAssertEqual(s.chipSummary(), "Speed Keryo-Pente · P1 1700+ · bob · P2 wins")
        s.winner = 1
        XCTAssertTrue(s.chipSummary().contains("P1 wins"))
        s.scope = "mine"
        XCTAssertTrue(s.chipSummary().contains("Mine"))
        s.scope = "both"
        XCTAssertTrue(s.chipSummary().contains("Both"))
        s.after = Date(timeIntervalSince1970: 0)
        XCTAssertTrue(s.chipSummary().contains("after "))
    }

    func testLegacyMigration() {
        let d = freshDefaults()
        d.set("Speed Keryo-Pente", forKey: "DBGame")
        d.set("1600", forKey: "DBP1Rating")
        d.set("both", forKey: "DBBothOrEither")
        d.set("no", forKey: "DBExcludeTimeouts")
        let s = DBFilterStore(defaults: d).load()
        XCTAssertEqual(s.baseGame, 3)
        XCTAssertTrue(s.speed)
        XCTAssertEqual(s.p1MinRating, 1600)
        XCTAssertFalse(s.eitherSeat)
        XCTAssertFalse(s.excludeTimeouts)
        XCTAssertNotNil(d.data(forKey: "DBFiltersV1"), "migration writes V1")
    }

    func testLegacyMigrationMapping() {
        let d = freshDefaults()
        d.set("either", forKey: "DBBothOrEither")
        d.set("yes", forKey: "DBExcludeTimeouts")
        d.set("live only", forKey: "DBLiveOrTB")
        d.set("Go", forKey: "DBGame")
        let s = DBFilterStore(defaults: d).load()
        XCTAssertTrue(s.eitherSeat)
        XCTAssertTrue(s.excludeTimeouts)
        XCTAssertEqual(s.liveOrTurnBased, "live")
        XCTAssertEqual(s.baseGame, 1, "unsupported legacy game keeps Pente")
        XCTAssertFalse(s.speed)
        for (legacy, wire) in [("turn-based only", "turnBased"), ("all", "all"), ("bogus", "all")] {
            let d2 = freshDefaults()
            d2.set(legacy, forKey: "DBLiveOrTB")
            XCTAssertEqual(DBFilterStore(defaults: d2).load().liveOrTurnBased, wire)
        }
    }

    func testLegacyMigrationHighRatingKept() {
        let d = freshDefaults()
        d.set("2700", forKey: "DBP2Rating")
        let s = DBFilterStore(defaults: d).load()
        XCTAssertEqual(s.p2MinRating, 2700)
        XCTAssertTrue(DBFilterStore.ratingChoices.contains(2700))
        XCTAssertEqual(DBFilterStore.ratingChoices.first, 0)
        XCTAssertEqual(DBFilterStore.ratingChoices[1], 1000)
    }

    func testRoundTripPersistence() {
        let d = freshDefaults()
        let store = DBFilterStore(defaults: d)
        var s = DBFilterState()
        s.setGame(id: 14)
        s.player1 = "alice"
        s.p2MinRating = 1900
        s.winner = 2
        s.after = Date(timeIntervalSince1970: 1_700_000_000)
        s.scope = "mine"
        s.eitherSeat = true
        store.save(s)
        XCTAssertEqual(DBFilterStore(defaults: d).load(), s)
    }

    func testStoredV1WinsOverLegacyKeys() {
        let d = freshDefaults()
        let store = DBFilterStore(defaults: d)
        var s = DBFilterState()
        s.player1 = "zed"
        store.save(s)
        d.set("2700", forKey: "DBP2Rating")
        XCTAssertEqual(store.load().p2MinRating, 0)
    }
}
