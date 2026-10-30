import XCTest
@testable import penteLive

/// Answers /players by the `q` value; never touches the network.
private final class DBFiltersPlayersTransport: Transport, @unchecked Sendable {
    private let lock = NSLock()
    private var _queries: [String] = []
    var queries: [String] { lock.lock(); defer { lock.unlock() }; return _queries }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let q = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "q" }?.value ?? ""
        lock.lock(); _queries.append(q); lock.unlock()
        let body = "{\"players\":[\"\(q)ce\",\"\(q)x\"]}".data(using: .utf8)!
        let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (body, resp)
    }
}

/// The filters sheet, driven directly (never put in a window).
@MainActor
final class DBFiltersViewControllerTests: XCTestCase {
    private var transport: DBFiltersPlayersTransport!

    override func setUp() {
        super.setUp()
        transport = DBFiltersPlayersTransport()
    }

    private func make(_ applied: DBFilterState = DBFilterState(),
                      features: DBServerFeatures = .none) -> DBFiltersViewController {
        let ep = DBEndpoint(useLocalhost: false)
        let ac = DBPlayerAutocomplete(client: DBClient(endpoint: ep, transport: transport), debounce: 0)
        let vc = DBFiltersViewController(applied: applied, autocomplete: ac, features: features)
        vc.loadViewIfNeeded()
        return vc
    }

    private func wait(_ cond: () -> Bool, timeout: TimeInterval = 3) async {
        let end = Date().addingTimeInterval(timeout)
        while !cond() && Date() < end { try? await Task.sleep(nanoseconds: 10_000_000) }
    }

    func testSixteenChipsInWebOrderFourRowsOfFour() {
        let vc = make()
        XCTAssertEqual(vc.gameChips.map { $0.tag }, [1, 3, 5, 7, 9, 11, 13, 15, 17, 19, 21, 23, 25, 27, 29, 31])
        XCTAssertEqual(vc.gameChips.map { $0.title(for: .normal) ?? "" }.suffix(7),
                       ["Go", "Go (9x9)", "Go (13x13)", "O-Pente", "Swap2-Pente", "Swap2-Keryo", "Renju"])
        let rows = Set(vc.gameChips.compactMap { $0.superview.map(ObjectIdentifier.init) })
        XCTAssertEqual(rows.count, 4)
        for chip in vc.gameChips { XCTAssertEqual(chip.superview?.subviews.count, 4) }
    }

    func testGoAndRenjuChipsSelectGameAndAllowSpeed() {
        let vc = make()
        vc.gameChips.first { $0.tag == 21 }!.sendActions(for: .touchUpInside)
        XCTAssertEqual(vc.draft.baseGame, 21)
        XCTAssertTrue(vc.speedSwitch.isEnabled)
        vc.speedSwitch.isOn = true
        vc.speedSwitch.sendActions(for: .valueChanged)
        XCTAssertEqual(vc.draft.gameId, 22)
        var applied: DBFilterState?
        vc.onApply = { applied = $0 }
        vc.applyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(applied?.gameId, 22)
        vc.gameChips.first { $0.tag == 31 }!.sendActions(for: .touchUpInside)
        XCTAssertTrue(vc.speedSwitch.isEnabled)
        XCTAssertEqual(vc.draft.gameId, 32, "speed stays on: Speed Renju")
        XCTAssertEqual(vc.gameChips.filter { $0.isSelected }.map { $0.tag }, [31])
    }

    func testAppliedGoGameIsSelected() {
        var s = DBFilterState()
        s.setGame(id: 24)
        let vc = make(s)
        XCTAssertEqual(vc.gameChips.filter { $0.isSelected }.map { $0.tag }, [23])
        XCTAssertTrue(vc.speedSwitch.isOn)
    }

    func testGameChipsInCatalogOrderWithSelection() {
        var s = DBFilterState()
        s.setGame(id: 3)
        let vc = make(s)
        XCTAssertEqual(vc.gameChips.map { $0.title(for: .normal) },
                       DBGameCatalog.baseGames.map { DBGameCatalog.name(forGame: $0) })
        XCTAssertEqual(vc.gameChips.filter { $0.isSelected }.map { $0.tag }, [3])
        XCTAssertEqual(vc.gameChips[1].backgroundColor, DBPalette.chipSelectedFill)
        XCTAssertEqual(vc.gameChips[0].layer.borderColor, DBPalette.chipOutline.cgColor)
    }

    func testTappingChipSelectsGameAndGatesSpeed() {
        let vc = make()
        vc.speedSwitch.isOn = true
        vc.speedSwitch.sendActions(for: .valueChanged)
        XCTAssertEqual(vc.draft.gameId, 2)
        let swap2 = vc.gameChips.first { $0.tag == 27 }!
        swap2.sendActions(for: .touchUpInside)
        XCTAssertEqual(vc.draft.baseGame, 27)
        XCTAssertFalse(vc.speedSwitch.isEnabled, "Swap2 has no speed variant")
        XCTAssertEqual(vc.draft.gameId, 27)
        XCTAssertEqual(vc.gameChips.filter { $0.isSelected }.map { $0.tag }, [27])
    }

    func testFieldsAppearInSpecOrder() {
        let vc = make()
        XCTAssertEqual(vc.fieldOrder, ["game", "speed", "player1", "player2", "p1Rating", "p2Rating",
                                       "eitherSeat", "excludeTimeouts", "liveOrTurnBased", "winner",
                                       "after", "before", "source"])
    }

    func testExtendedRowsHiddenUntilEachFeatureAdvertised() {
        let vc = make()
        XCTAssertTrue(vc.excludeTimeoutsRow.isHidden)
        XCTAssertTrue(vc.liveOrTurnBasedRow.isHidden)
        let timeouts = make(features: DBServerFeatures(features: ["excludeTimeouts"]))
        XCTAssertFalse(timeouts.excludeTimeoutsRow.isHidden)
        XCTAssertTrue(timeouts.liveOrTurnBasedRow.isHidden)
        let live = make(features: DBServerFeatures(features: ["liveOrTurnBased"]))
        XCTAssertTrue(live.excludeTimeoutsRow.isHidden)
        XCTAssertFalse(live.liveOrTurnBasedRow.isHidden)
    }

    func testHiddenMigratedExtendedValuesSurviveApply() {
        var legacy = DBFilterState()
        legacy.excludeTimeouts = true
        legacy.liveOrTurnBased = "live"
        let vc = make(legacy)
        var applied: DBFilterState?
        vc.onApply = { applied = $0 }
        vc.applyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(applied?.excludeTimeouts, true)
        XCTAssertEqual(applied?.liveOrTurnBased, "live")
    }

    func testRatingMenuOffersAnyAndPlusChoices() {
        let vc = make()
        let titles = vc.p1RatingButton.menu?.children.map { $0.title } ?? []
        XCTAssertEqual(titles.first, "Any")
        XCTAssertEqual(titles.count, DBFilterStore.ratingChoices.count)
        XCTAssertTrue(titles.contains("1700+"))
        XCTAssertEqual(vc.p1RatingButton.title(for: .normal), "Any")
        vc.setRating(1700, player: 1)
        XCTAssertEqual(vc.draft.p1MinRating, 1700)
        XCTAssertEqual(vc.p1RatingButton.title(for: .normal), "1700+")
        vc.setRating(0, player: 2)
        XCTAssertEqual(vc.p2RatingButton.title(for: .normal), "Any")
    }

    func testControlsEditTheDraft() {
        let vc = make()
        vc.player1Field.text = "alice"
        vc.player1Field.sendActions(for: .editingChanged)
        vc.eitherSeatSwitch.isOn = true
        vc.eitherSeatSwitch.sendActions(for: .valueChanged)
        vc.winnerControl.selectedSegmentIndex = 2
        vc.winnerControl.sendActions(for: .valueChanged)
        vc.sourceControl.selectedSegmentIndex = 2
        vc.sourceControl.sendActions(for: .valueChanged)
        XCTAssertEqual(vc.draft.player1, "alice")
        XCTAssertTrue(vc.draft.eitherSeat)
        XCTAssertEqual(vc.draft.winner, 2)
        XCTAssertEqual(vc.draft.scope, "both")
        vc.liveOrTurnBasedControl.selectedSegmentIndex = 2
        vc.liveOrTurnBasedControl.sendActions(for: .valueChanged)
        XCTAssertEqual(vc.draft.liveOrTurnBased, "turnBased")
    }

    func testDatesSetAndClear() {
        let vc = make()
        XCTAssertNil(vc.draft.after)
        XCTAssertTrue(vc.afterPicker.isHidden)
        vc.afterSetButton.sendActions(for: .touchUpInside)
        XCTAssertNotNil(vc.draft.after)
        XCTAssertFalse(vc.afterPicker.isHidden)
        let d = Date(timeIntervalSince1970: 1_600_000_000)
        vc.afterPicker.date = d
        vc.afterPicker.sendActions(for: .valueChanged)
        XCTAssertEqual(vc.draft.after, d)
        vc.afterClearButton.sendActions(for: .touchUpInside)
        XCTAssertNil(vc.draft.after)
        XCTAssertTrue(vc.afterPicker.isHidden)
        vc.beforeSetButton.sendActions(for: .touchUpInside)
        XCTAssertNotNil(vc.draft.before)
    }

    func testResetClearsDraftOnlyAndDoesNotApply() {
        var applied = DBFilterState()
        applied.setGame(id: 3)
        applied.player1 = "bob"
        let vc = make(applied)
        var calls = 0
        vc.onApply = { _ in calls += 1 }
        vc.resetButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(vc.draft, DBFilterState())
        XCTAssertEqual(vc.player1Field.text, "")
        XCTAssertEqual(vc.gameChips.filter { $0.isSelected }.map { $0.tag }, [1])
        XCTAssertEqual(calls, 0, "Reset never applies")
    }

    func testApplyDeliversDraft() {
        let vc = make()
        var got: DBFilterState?
        vc.onApply = { got = $0 }
        vc.player2Field.text = "carol"
        vc.player2Field.sendActions(for: .editingChanged)
        vc.setRating(1700, player: 2)
        vc.applyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(got?.player2, "carol")
        XCTAssertEqual(got?.p2MinRating, 1700)
    }

    func testSuggestionTapFillsField() async {
        let vc = make()
        vc.player1Field.text = "ali"
        vc.player1Field.sendActions(for: .editingChanged)
        await wait { !vc.player1Suggestions.isEmpty }
        XCTAssertEqual(vc.player1Suggestions.map { $0.title(for: .normal) }, ["alice", "alix"])
        XCTAssertEqual(transport.queries, ["ali"])
        vc.player1Suggestions[0].sendActions(for: .touchUpInside)
        XCTAssertEqual(vc.player1Field.text, "alice")
        XCTAssertEqual(vc.draft.player1, "alice")
        XCTAssertTrue(vc.player1Suggestions.isEmpty, "suggestions close after a pick")
    }

    func testPresentationStyleBySizeClass() {
        let compact = make()
        compact.configurePresentation(regularWidth: false)
        XCTAssertEqual(compact.modalPresentationStyle, .pageSheet)
        XCTAssertEqual(compact.sheetPresentationController?.detents.count, 2)
        if #available(iOS 16.0, *) {
            XCTAssertEqual(compact.sheetPresentationController?.detents.map { $0.identifier },
                           [.medium, .large])
        }
        let regular = make()
        regular.configurePresentation(regularWidth: true)
        XCTAssertEqual(regular.modalPresentationStyle, .formSheet)
    }
}
