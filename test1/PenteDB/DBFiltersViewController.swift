import UIKit

/// The single PenteDB filters sheet (§3.8). Edits a draft; Reset touches the
/// draft only and Apply hands it to `onApply`. Main-actor only.
@MainActor
final class DBFiltersViewController: UIViewController, UITextFieldDelegate {
    private(set) var draft: DBFilterState
    var onApply: ((DBFilterState) -> Void)?
    private let autocomplete: DBPlayerAutocomplete

    // Controls (internal so tests can drive them without a window).
    private(set) var gameChips: [UIButton] = []
    let speedSwitch = UISwitch()
    let player1Field = UITextField()
    let player2Field = UITextField()
    let p1RatingButton = UIButton(type: .system)
    let p2RatingButton = UIButton(type: .system)
    let eitherSeatSwitch = UISwitch()
    let excludeTimeoutsSwitch = UISwitch()
    let liveOrTurnBasedControl = UISegmentedControl(items: [
        NSLocalizedString("All", comment: ""), NSLocalizedString("Live", comment: ""),
        NSLocalizedString("Turn-based", comment: ""),
    ])
    let winnerControl = UISegmentedControl(items: [
        NSLocalizedString("Any", comment: ""), NSLocalizedString("Player 1", comment: ""),
        NSLocalizedString("Player 2", comment: ""),
    ])
    let afterPicker = UIDatePicker()
    let beforePicker = UIDatePicker()
    let afterSetButton = UIButton(type: .system)
    let beforeSetButton = UIButton(type: .system)
    let afterClearButton = UIButton(type: .system)
    let beforeClearButton = UIButton(type: .system)
    let sourceControl = UISegmentedControl(items: [
        NSLocalizedString("Archive", comment: ""), NSLocalizedString("Mine", comment: ""),
        NSLocalizedString("Both", comment: ""),
    ])
    let resetButton = UIButton(type: .system)
    let applyButton = UIButton(type: .system)
    private(set) var excludeTimeoutsRow = UIView()
    private(set) var liveOrTurnBasedRow = UIView()
    /// Row keys in the order they were laid out (§3.8 order).
    private(set) var fieldOrder: [String] = []

    private let player1SuggestionStack = UIStackView()
    private let player2SuggestionStack = UIStackView()
    var player1Suggestions: [UIButton] { player1SuggestionStack.arrangedSubviews.compactMap { $0 as? UIButton } }
    var player2Suggestions: [UIButton] { player2SuggestionStack.arrangedSubviews.compactMap { $0 as? UIButton } }

    private static let liveValues = [DBFilterState.liveOrTBAll, DBFilterState.liveOrTBLive,
                                     DBFilterState.liveOrTBTurnBased]
    private static let scopeValues = ["archive", "mine", "both"]
    private static let maxSuggestions = 5

    private let formStack = UIStackView()

    init(applied: DBFilterState, autocomplete: DBPlayerAutocomplete) {
        draft = applied
        self.autocomplete = autocomplete
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Sheet with medium/large detents on compact width, form sheet on
    /// regular width.
    func configurePresentation(regularWidth: Bool) {
        if regularWidth {
            modalPresentationStyle = .formSheet
            return
        }
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
    }

    // MARK: - Layout

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let header = makeHeader()
        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        formStack.axis = .vertical
        formStack.spacing = 12
        formStack.isLayoutMarginsRelativeArrangement = true
        formStack.layoutMargins = UIEdgeInsets(top: 8, left: 16, bottom: 24, right: 16)
        [header, scroll].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        formStack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(formStack)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            formStack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            formStack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            formStack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            formStack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            formStack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])
        buildForm()
        refresh()
    }

    private func makeHeader() -> UIView {
        resetButton.setTitle(NSLocalizedString("Reset", comment: ""), for: .normal)
        resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        applyButton.setTitle(NSLocalizedString("Apply filters", comment: ""), for: .normal)
        applyButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        applyButton.tintColor = DBPalette.accent
        applyButton.addTarget(self, action: #selector(applyTapped), for: .touchUpInside)
        let title = UILabel()
        title.text = NSLocalizedString("Filters", comment: "")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.textColor = DBPalette.ink
        title.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [resetButton, title, applyButton])
        stack.distribution = .equalCentering
        stack.alignment = .center
        return stack
    }

    private func label(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 15)
        l.textColor = DBPalette.ink
        return l
    }

    @discardableResult
    private func addRow(_ key: String, _ title: String?, _ control: UIView) -> UIView {
        let row: UIView
        if let title = title {
            let h = UIStackView(arrangedSubviews: [label(title), control])
            h.alignment = .center
            h.spacing = 8
            row = h
        } else {
            row = control
        }
        formStack.addArrangedSubview(row)
        fieldOrder.append(key)
        return row
    }

    private func buildForm() {
        // 1. Game chips, 3 rows of 4.
        let chipRows = UIStackView()
        chipRows.axis = .vertical
        chipRows.spacing = 6
        var current: UIStackView?
        for (i, base) in DBGameCatalog.baseGames.enumerated() {
            if i % 4 == 0 {
                let r = UIStackView()
                r.distribution = .fillEqually
                r.spacing = 6
                chipRows.addArrangedSubview(r)
                current = r
            }
            let b = UIButton(type: .custom)
            b.tag = base
            b.setTitle(DBGameCatalog.name(forGame: base), for: .normal)
            b.setTitleColor(DBPalette.ink, for: .normal)
            b.setTitleColor(DBPalette.accent, for: .selected)
            b.titleLabel?.font = .systemFont(ofSize: 13)
            b.titleLabel?.adjustsFontSizeToFitWidth = true
            b.titleLabel?.minimumScaleFactor = 0.7
            b.layer.borderWidth = 1
            b.layer.borderColor = DBPalette.chipOutline.cgColor
            b.layer.cornerRadius = 14
            b.heightAnchor.constraint(equalToConstant: 30).isActive = true
            b.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            gameChips.append(b)
            current?.addArrangedSubview(b)
        }
        addRow("game", nil, chipRows)

        // 2. Speed.
        speedSwitch.addTarget(self, action: #selector(speedChanged), for: .valueChanged)
        addRow("speed", NSLocalizedString("Speed", comment: ""), speedSwitch)

        // 3. Player names with suggestions.
        for (field, stack, key, placeholder) in [
            (player1Field, player1SuggestionStack, "player1", NSLocalizedString("Player 1", comment: "")),
            (player2Field, player2SuggestionStack, "player2", NSLocalizedString("Player 2", comment: "")),
        ] {
            field.placeholder = placeholder
            field.borderStyle = .roundedRect
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
            field.clearButtonMode = .whileEditing
            field.returnKeyType = .done
            field.delegate = self
            field.addTarget(self, action: #selector(nameChanged(_:)), for: .editingChanged)
            stack.axis = .vertical
            stack.alignment = .leading
            let v = UIStackView(arrangedSubviews: [field, stack])
            v.axis = .vertical
            v.spacing = 2
            addRow(key, nil, v)
        }

        // 4. Min ratings.
        for (button, player, key) in [(p1RatingButton, 1, "p1Rating"), (p2RatingButton, 2, "p2Rating")] {
            button.showsMenuAsPrimaryAction = true
            button.menu = UIMenu(children: DBFilterStore.ratingChoices.map { r in
                UIAction(title: Self.ratingTitle(r)) { [weak self] _ in self?.setRating(r, player: player) }
            })
            let title = player == 1 ? NSLocalizedString("P1 min rating", comment: "")
                : NSLocalizedString("P2 min rating", comment: "")
            addRow(key, title, button)
        }

        // 5. Either seat.
        eitherSeatSwitch.addTarget(self, action: #selector(eitherSeatChanged), for: .valueChanged)
        addRow("eitherSeat", NSLocalizedString("Either seat", comment: ""), eitherSeatSwitch)

        // 6. Exclude timeouts + Games, gated on the server capability.
        excludeTimeoutsSwitch.addTarget(self, action: #selector(excludeTimeoutsChanged), for: .valueChanged)
        excludeTimeoutsRow = addRow("excludeTimeouts", NSLocalizedString("Exclude timeouts", comment: ""),
                                    excludeTimeoutsSwitch)
        liveOrTurnBasedControl.addTarget(self, action: #selector(liveOrTurnBasedChanged), for: .valueChanged)
        liveOrTurnBasedRow = addRow("liveOrTurnBased", NSLocalizedString("Games", comment: ""),
                                    liveOrTurnBasedControl)
        excludeTimeoutsRow.isHidden = !DBCapabilities.extendedFilters
        liveOrTurnBasedRow.isHidden = !DBCapabilities.extendedFilters

        // 7. Winner.
        winnerControl.addTarget(self, action: #selector(winnerChanged), for: .valueChanged)
        addRow("winner", NSLocalizedString("Winner", comment: ""), winnerControl)

        // 8. Dates.
        for (picker, set, clear, key, title) in [
            (afterPicker, afterSetButton, afterClearButton, "after", NSLocalizedString("After", comment: "")),
            (beforePicker, beforeSetButton, beforeClearButton, "before", NSLocalizedString("Before", comment: "")),
        ] {
            picker.datePickerMode = .date
            picker.preferredDatePickerStyle = .compact
            picker.addTarget(self, action: #selector(dateChanged(_:)), for: .valueChanged)
            set.setTitle(NSLocalizedString("Any", comment: ""), for: .normal)
            set.addTarget(self, action: #selector(dateSetTapped(_:)), for: .touchUpInside)
            clear.setTitle(NSLocalizedString("Clear", comment: ""), for: .normal)
            clear.addTarget(self, action: #selector(dateClearTapped(_:)), for: .touchUpInside)
            let h = UIStackView(arrangedSubviews: [set, picker, clear])
            h.spacing = 8
            h.alignment = .center
            addRow(key, title, h)
        }

        // 9. Source.
        sourceControl.addTarget(self, action: #selector(sourceChanged), for: .valueChanged)
        addRow("source", NSLocalizedString("Source", comment: ""), sourceControl)
    }

    static func ratingTitle(_ r: Int) -> String {
        r > 0 ? "\(r)+" : NSLocalizedString("Any", comment: "")
    }

    /// Pushes the draft into every control.
    private func refresh() {
        for b in gameChips {
            b.isSelected = b.tag == draft.baseGame
            b.backgroundColor = b.isSelected ? DBPalette.chipSelectedFill : .clear
        }
        let speedOK = DBGameCatalog.supportsSpeed(base: draft.baseGame)
        speedSwitch.isEnabled = speedOK
        speedSwitch.isOn = speedOK && draft.speed
        if player1Field.text != draft.player1 { player1Field.text = draft.player1 }
        if player2Field.text != draft.player2 { player2Field.text = draft.player2 }
        p1RatingButton.setTitle(Self.ratingTitle(draft.p1MinRating), for: .normal)
        p2RatingButton.setTitle(Self.ratingTitle(draft.p2MinRating), for: .normal)
        eitherSeatSwitch.isOn = draft.eitherSeat
        excludeTimeoutsSwitch.isOn = draft.excludeTimeouts
        liveOrTurnBasedControl.selectedSegmentIndex = Self.liveValues.firstIndex(of: draft.liveOrTurnBased) ?? 0
        winnerControl.selectedSegmentIndex = (0 ... 2).contains(draft.winner) ? draft.winner : 0
        sourceControl.selectedSegmentIndex = Self.scopeValues.firstIndex(of: draft.scope) ?? 0
        refreshDate(draft.after, picker: afterPicker, set: afterSetButton, clear: afterClearButton)
        refreshDate(draft.before, picker: beforePicker, set: beforeSetButton, clear: beforeClearButton)
    }

    private func refreshDate(_ d: Date?, picker: UIDatePicker, set: UIButton, clear: UIButton) {
        picker.isHidden = d == nil
        clear.isHidden = d == nil
        set.isHidden = d != nil
        if let d = d { picker.date = d }
    }

    // MARK: - Actions

    @objc private func chipTapped(_ sender: UIButton) {
        draft.baseGame = sender.tag
        refresh()
    }

    @objc private func speedChanged() {
        draft.speed = speedSwitch.isOn
    }

    @objc private func nameChanged(_ field: UITextField) {
        let text = field.text ?? ""
        let isP1 = field === player1Field
        if isP1 { draft.player1 = text } else { draft.player2 = text }
        let stack = isP1 ? player1SuggestionStack : player2SuggestionStack
        autocomplete.query(text) { [weak self] names in
            self?.showSuggestions(names, in: stack, for: field)
        }
    }

    private func showSuggestions(_ names: [String], in stack: UIStackView, for field: UITextField) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for name in names.prefix(Self.maxSuggestions) {
            let b = UIButton(type: .system)
            b.setTitle(name, for: .normal)
            b.contentHorizontalAlignment = .leading
            b.addTarget(self, action: #selector(suggestionTapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(b)
        }
    }

    @objc private func suggestionTapped(_ sender: UIButton) {
        guard let name = sender.title(for: .normal) else { return }
        let isP1 = player1SuggestionStack.arrangedSubviews.contains(sender)
        let field = isP1 ? player1Field : player2Field
        field.text = name
        if isP1 { draft.player1 = name } else { draft.player2 = name }
        (isP1 ? player1SuggestionStack : player2SuggestionStack)
            .arrangedSubviews.forEach { $0.removeFromSuperview() }
        // Supersede any query still pending for this field.
        autocomplete.query("") { _ in }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func setRating(_ r: Int, player: Int) {
        if player == 1 { draft.p1MinRating = r } else { draft.p2MinRating = r }
        refresh()
    }

    @objc private func eitherSeatChanged() {
        draft.eitherSeat = eitherSeatSwitch.isOn
    }

    @objc private func excludeTimeoutsChanged() {
        draft.excludeTimeouts = excludeTimeoutsSwitch.isOn
    }

    @objc private func liveOrTurnBasedChanged() {
        let i = liveOrTurnBasedControl.selectedSegmentIndex
        draft.liveOrTurnBased = Self.liveValues.indices.contains(i) ? Self.liveValues[i] : DBFilterState.liveOrTBAll
    }

    @objc private func winnerChanged() {
        draft.winner = max(0, winnerControl.selectedSegmentIndex)
    }

    @objc private func sourceChanged() {
        let i = sourceControl.selectedSegmentIndex
        draft.scope = Self.scopeValues.indices.contains(i) ? Self.scopeValues[i] : "archive"
    }

    @objc private func dateChanged(_ picker: UIDatePicker) {
        if picker === afterPicker { draft.after = picker.date } else { draft.before = picker.date }
    }

    @objc private func dateSetTapped(_ sender: UIButton) {
        if sender === afterSetButton { draft.after = Date() } else { draft.before = Date() }
        refresh()
    }

    @objc private func dateClearTapped(_ sender: UIButton) {
        if sender === afterClearButton { draft.after = nil } else { draft.before = nil }
        refresh()
    }

    @objc private func resetTapped() {
        draft = DBFilterState()
        player1SuggestionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        player2SuggestionStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        refresh()
    }

    /// Dismisses first (when presented), so the host's follow-up alerts
    /// (401, subscription) present from a settled hierarchy.
    @objc private func applyTapped() {
        view.endEditing(true)
        let state = draft
        let apply = onApply
        if presentingViewController != nil {
            dismiss(animated: true) { apply?(state) }
        } else {
            apply?(state)
        }
    }
}
