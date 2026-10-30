import UIKit

/// One Moves row: heat dot, move label, win% bar, pct, games count (§3.6).
final class DBMoveRowCell: UITableViewCell {
    static let reuseId = "DBMoveRowCell"

    let dot = UIView()
    let moveLabel = UILabel()
    let barTrack = UIView()
    let barFill = UIView()
    let pctLabel = UILabel()
    let gamesLabel = UILabel()
    private var barWidth: NSLayoutConstraint?
    /// The row whose stone is flashing on the board.
    private(set) var isMarked = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        dot.layer.cornerRadius = 7
        dot.layer.borderWidth = 1
        dot.layer.borderColor = UIColor(white: 0, alpha: 0.25).cgColor
        moveLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        moveLabel.textColor = DBPalette.ink
        barTrack.backgroundColor = DBPalette.divider
        barTrack.layer.cornerRadius = 3
        barTrack.clipsToBounds = true
        pctLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        pctLabel.textColor = DBPalette.ink
        pctLabel.textAlignment = .right
        gamesLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        gamesLabel.textColor = DBPalette.secondaryText
        gamesLabel.textAlignment = .right
        for v in [dot, moveLabel, barTrack, pctLabel, gamesLabel] {
            v.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(v)
        }
        barFill.translatesAutoresizingMaskIntoConstraints = false
        barTrack.addSubview(barFill)
        let m = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            dot.leadingAnchor.constraint(equalTo: m.leadingAnchor),
            dot.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 14),
            dot.heightAnchor.constraint(equalToConstant: 14),
            moveLabel.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 10),
            moveLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            moveLabel.widthAnchor.constraint(equalToConstant: 44),
            barTrack.leadingAnchor.constraint(equalTo: moveLabel.trailingAnchor, constant: 8),
            barTrack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            barTrack.heightAnchor.constraint(equalToConstant: 6),
            pctLabel.leadingAnchor.constraint(equalTo: barTrack.trailingAnchor, constant: 8),
            pctLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            pctLabel.widthAnchor.constraint(equalToConstant: 44),
            gamesLabel.leadingAnchor.constraint(equalTo: pctLabel.trailingAnchor, constant: 8),
            gamesLabel.trailingAnchor.constraint(equalTo: m.trailingAnchor),
            gamesLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            gamesLabel.widthAnchor.constraint(equalToConstant: 64),
            barFill.leadingAnchor.constraint(equalTo: barTrack.leadingAnchor),
            barFill.topAnchor.constraint(equalTo: barTrack.topAnchor),
            barFill.bottomAnchor.constraint(equalTo: barTrack.bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ row: DBMoveRow, marked: Bool = false) {
        dot.backgroundColor = row.color
        // The bar wears the colour the move has on the board.
        barFill.backgroundColor = row.color
        setMarked(marked)
        moveLabel.text = row.label
        pctLabel.text = row.pctText
        gamesLabel.text = row.gamesText
        barWidth?.isActive = false
        barWidth = barFill.widthAnchor.constraint(equalTo: barTrack.widthAnchor,
                                                  multiplier: CGFloat(max(0.0001, row.barFraction)))
        barWidth?.isActive = true
        accessibilityLabel = "\(row.label), \(row.pctText), \(row.gamesText) games"
    }

    func setMarked(_ marked: Bool) {
        isMarked = marked
        contentView.backgroundColor = marked ? DBPalette.chipSelectedFill : .clear
        if marked {
            accessibilityTraits.insert(.selected)
        } else {
            accessibilityTraits.remove(.selected)
        }
    }
}

/// One Games row (spec 3.7): P1 | score over date | P2, the right column a
/// right-aligned mirror of the left.
final class DBGameRowCell: UITableViewCell {
    static let reuseId = "DBGameRowCell"

    let p1Name = UILabel()
    let p1Rating = UILabel()
    let scoreLabel = UILabel()
    let dateLabel = UILabel()
    let p2Name = UILabel()
    let p2Rating = UILabel()

    private static let nameFont = UIFont.systemFont(ofSize: 15)
    private static let smallFont = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        for l in [p1Name, p2Name] {
            l.font = DBGameRowCell.nameFont
            l.lineBreakMode = .byTruncatingTail
        }
        for l in [p1Rating, p2Rating, dateLabel] {
            l.font = DBGameRowCell.smallFont
            l.textColor = DBPalette.secondaryText
        }
        scoreLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        scoreLabel.textColor = DBPalette.ink
        for l in [scoreLabel, dateLabel] { l.textAlignment = .center }
        for l in [p2Name, p2Rating] { l.textAlignment = .right }

        let left = column([p1Name, p1Rating], alignment: .leading)
        let centre = column([scoreLabel, dateLabel], alignment: .center)
        let right = column([p2Name, p2Rating], alignment: .trailing)
        let m = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            left.leadingAnchor.constraint(equalTo: m.leadingAnchor),
            right.trailingAnchor.constraint(equalTo: m.trailingAnchor),
            centre.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            centre.widthAnchor.constraint(equalToConstant: 96),
            left.trailingAnchor.constraint(lessThanOrEqualTo: centre.leadingAnchor, constant: -4),
            right.leadingAnchor.constraint(greaterThanOrEqualTo: centre.trailingAnchor, constant: 4),
        ])
        for c in [left, centre, right] {
            c.centerYAnchor.constraint(equalTo: contentView.centerYAnchor).isActive = true
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func column(_ views: [UIView], alignment: UIStackView.Alignment) -> UIStackView {
        let s = UIStackView(arrangedSubviews: views)
        s.axis = .vertical
        s.spacing = 2
        s.alignment = alignment
        s.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(s)
        return s
    }

    func configure(_ g: DBGameHeader, now: Date) {
        p1Name.attributedText = DBRatingStyle.nameString(g.player1, font: DBGameRowCell.nameFont, alignRight: false)
        p2Name.attributedText = DBRatingStyle.nameString(g.player2, font: DBGameRowCell.nameFont, alignRight: true)
        p1Rating.attributedText = DBRatingStyle.ratingString(g.player1, font: DBGameRowCell.smallFont)
        let r2 = NSMutableAttributedString(attributedString:
            DBRatingStyle.ratingString(g.player2, font: DBGameRowCell.smallFont))
        if r2.length > 0 {
            let style = NSMutableParagraphStyle()
            style.alignment = .right
            r2.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: r2.length))
        }
        p2Rating.attributedText = r2
        scoreLabel.text = DBGameRowFormatter.score(winner: g.winner)
        dateLabel.text = DBGameRowFormatter.date(iso: g.playDate, now: now)
        accessibilityLabel = [g.player1?.name ?? "?", scoreLabel.text ?? "", g.player2?.name ?? "?",
                              dateLabel.text ?? ""].joined(separator: ", ")
    }
}

/// Moves and Games results: an iPhone sheet or an inline iPad panel. Reads
/// the service but never sets its callbacks; the host forwards state to it.
@objc final class DBResultsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let service: DBPositionService
    /// A Moves row was selected (its cell), or the selection ended (-1). The
    /// host flashes that cell on the board; nothing is played or searched.
    @objc var onSelectionChanged: ((Int) -> Void)?
    @objc var onShowCountChanged: (() -> Void)?
    /// The Win % / Popularity choice changed; the host recomputes heat and reloads.
    @objc var onSortChanged: (() -> Void)?
    /// Retry after a failure; the host refetches every failed endpoint.
    @objc var onRetry: (() -> Void)?
    /// "Show more" (or its retry after a failed page).
    @objc var onLoadMore: (() -> Void)?
    /// A Games row was tapped (any gid length). The flag is true for a
    /// personal `source:"mine"` row, whose gid is a wgid.
    @objc var onOpenGame: ((Int64, Bool) -> Void)?

    private(set) var rows: [DBMoveRow] = []
    /// The Moves row whose cell flashes on the board (one at a time).
    private(set) var selectedCell: Int?
    private(set) var games: [DBGameHeader] = []
    private var statsState: DBLoadState = .idle
    private(set) var gamesState: DBLoadState = .idle
    private var loadingMore = false
    private var loadMoreFailed = false

    let segmented = UISegmentedControl(items: [NSLocalizedString("Moves", comment: ""),
                                               NSLocalizedString("Games", comment: "")])
    let sortControl = UISegmentedControl(items: [NSLocalizedString("Win %", comment: ""),
                                                 NSLocalizedString("Popularity", comment: "")])
    let showButton = UIButton(type: .system)
    /// "i" next to the sort control: why Win % rows are not strictly descending.
    let infoButton = UIButton(type: .system)
    /// Test seam: receives the explanation instead of presenting it.
    var presentInfo: ((UIViewController) -> Void)?
    private let movesBar = UIStackView()
    let tableView = UITableView(frame: .zero, style: .plain)
    let gamesTableView = UITableView(frame: .zero, style: .plain)
    let gamesHeader = UIStackView()
    /// What the games list actually is for the scope (react_pentedb's
    /// `listHeaderLabel`); sits above the header row.
    let scopeLabel = UILabel()
    let footerButton = UIButton(type: .system)
    let messageLabel = UILabel()
    let retryButton = UIButton(type: .system)
    let spinner = UIActivityIndicatorView(style: .medium)
    private let footer = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 48))

    private static let countFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    @objc init(service: DBPositionService) {
        self.service = service
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        segmented.selectedSegmentIndex = 0
        segmented.accessibilityIdentifier = "dbResultsTabs"
        segmented.addTarget(self, action: #selector(tabChanged), for: .valueChanged)

        sortControl.selectedSegmentIndex = service.preferences.moveSort == .games ? 1 : 0
        sortControl.accessibilityIdentifier = "dbMoveSort"
        sortControl.addTarget(self, action: #selector(sortChanged), for: .valueChanged)

        infoButton.setImage(UIImage(systemName: "info.circle"), for: .normal)
        infoButton.tintColor = DBPalette.accent
        infoButton.accessibilityLabel = NSLocalizedString("About win %", comment: "")
        infoButton.accessibilityIdentifier = "dbSortInfoButton"
        infoButton.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
        infoButton.setContentHuggingPriority(.required, for: .horizontal)

        showButton.showsMenuAsPrimaryAction = true
        showButton.titleLabel?.font = .systemFont(ofSize: 14)
        showButton.setTitleColor(DBPalette.accent, for: .normal)
        showButton.accessibilityIdentifier = "dbShowMovesButton"
        rebuildShowMenu()

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DBMoveRowCell.self, forCellReuseIdentifier: DBMoveRowCell.reuseId)
        tableView.rowHeight = 40
        tableView.separatorColor = DBPalette.divider
        tableView.accessibilityIdentifier = "dbMovesTable"

        gamesTableView.dataSource = self
        gamesTableView.delegate = self
        gamesTableView.register(DBGameRowCell.self, forCellReuseIdentifier: DBGameRowCell.reuseId)
        gamesTableView.rowHeight = 52
        gamesTableView.separatorColor = DBPalette.divider
        gamesTableView.accessibilityIdentifier = "dbGamesTable"

        footerButton.titleLabel?.font = .systemFont(ofSize: 15)
        footerButton.setTitleColor(DBPalette.accent, for: .normal)
        footerButton.setTitleColor(DBPalette.secondaryText, for: .disabled)
        footerButton.accessibilityIdentifier = "dbGamesShowMore"
        footerButton.addTarget(self, action: #selector(footerTapped), for: .touchUpInside)
        footerButton.frame = footer.bounds
        footerButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        footer.addSubview(footerButton)

        gamesHeader.axis = .horizontal
        gamesHeader.distribution = .fillEqually
        let titles = [NSLocalizedString("Player 1", comment: ""), NSLocalizedString("Newest first", comment: ""),
                      NSLocalizedString("Player 2", comment: "")]
        let alignments: [NSTextAlignment] = [.left, .center, .right]
        for (t, a) in zip(titles, alignments) {
            let l = UILabel()
            l.text = t
            l.font = .systemFont(ofSize: 12, weight: .semibold)
            l.textColor = DBPalette.secondaryText
            l.textAlignment = a
            gamesHeader.addArrangedSubview(l)
        }
        scopeLabel.font = .systemFont(ofSize: 12)
        scopeLabel.textColor = DBPalette.secondaryText
        scopeLabel.numberOfLines = 0
        scopeLabel.accessibilityIdentifier = "dbGamesScopeLabel"
        gamesHeader.isLayoutMarginsRelativeArrangement = true
        gamesHeader.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)

        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.textColor = DBPalette.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.isHidden = true
        messageLabel.accessibilityIdentifier = "dbResultsMessage"

        retryButton.setTitle(NSLocalizedString("Retry", comment: ""), for: .normal)
        retryButton.setTitleColor(DBPalette.accent, for: .normal)
        retryButton.isHidden = true
        retryButton.accessibilityIdentifier = "dbResultsRetry"
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        spinner.hidesWhenStopped = true

        movesBar.addArrangedSubview(sortControl)
        movesBar.addArrangedSubview(infoButton)
        movesBar.addArrangedSubview(showButton)
        movesBar.axis = .horizontal
        movesBar.spacing = 12
        movesBar.alignment = .center
        let header = UIStackView(arrangedSubviews: [segmented, movesBar])
        header.axis = .vertical
        header.spacing = 8
        header.alignment = .leading
        let message = UIStackView(arrangedSubviews: [messageLabel, retryButton])
        message.axis = .vertical
        message.spacing = 8
        message.alignment = .center
        for v in [header, tableView, scopeLabel, gamesHeader, gamesTableView, message, spinner] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: g.topAnchor, constant: 12),
            header.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
            header.trailingAnchor.constraint(lessThanOrEqualTo: g.trailingAnchor, constant: -16),
            tableView.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scopeLabel.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),
            scopeLabel.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 16),
            scopeLabel.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
            gamesHeader.topAnchor.constraint(equalTo: scopeLabel.bottomAnchor, constant: 4),
            gamesHeader.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            gamesHeader.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            gamesHeader.heightAnchor.constraint(equalToConstant: 24),
            gamesTableView.topAnchor.constraint(equalTo: gamesHeader.bottomAnchor),
            gamesTableView.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            gamesTableView.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            gamesTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            message.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24),
            message.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 24),
            message.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -24),
            spinner.centerXAnchor.constraint(equalTo: g.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24),
        ])
        updateGamesTitle()
        updateFooter()
        render()
    }

    // MARK: host API

    @objc func reload() {
        loadViewIfNeeded()
        clearSelection()
        if let stats = service.lastStats {
            let n = service.preferences.movesShown
            rows = DBMovesViewModel.rows(stats: stats, occupied: service.occupied,
                                         limit: n > 0 ? n : nil, game: service.game,
                                         sort: service.preferences.moveSort)
        } else {
            rows = []
        }
        tableView.reloadData()
    }

    @objc func showState(_ state: DBLoadState) {
        loadViewIfNeeded()
        statsState = state
        if state == .loading {
            clearSelection()
            rows = []
            tableView.reloadData()
        }
        render()
    }

    /// Takes the service's accumulated games pages.
    @objc func reloadGames() {
        loadViewIfNeeded()
        games = service.pager.games
        gamesTableView.reloadData()
        updateFooter()
        updateGamesTitle()
    }

    /// `isLoadMore`: the state belongs to a "Show more" page, so it only
    /// changes the footer and the rows already loaded stay.
    @objc func showGamesState(_ state: DBLoadState, isLoadMore: Bool) {
        loadViewIfNeeded()
        if isLoadMore {
            loadingMore = state == .loading
            loadMoreFailed = !(state == .loading || state == .loaded || state == .empty)
        } else {
            gamesState = state
            loadingMore = false
            loadMoreFailed = false
        }
        updateFooter()
        updateGamesTitle()
        render()
    }

    /// Saves the "Show N moves" choice; the host recomputes heat and reloads.
    func selectShowCount(_ n: Int) {
        service.preferences.movesShown = n
        clearSelection()
        rebuildShowMenu()
        onShowCountChanged?()
    }

    /// Saves the Win % / Popularity choice; the host recomputes heat and reloads.
    func selectSort(_ sort: DBMoveSort) {
        service.preferences.moveSort = sort
        sortControl.selectedSegmentIndex = sort == .games ? 1 : 0
        clearSelection()
        onSortChanged?()
    }

    /// Ends the row selection (and tells the host to stop the flashing).
    /// Silent when nothing is selected.
    @objc func clearSelection() {
        guard selectedCell != nil else { return }
        selectedCell = nil
        tableView.reloadData()
        onSelectionChanged?(-1)
    }

    var gamesFooterTitle: String? {
        gamesTableView.tableFooterView == nil ? nil : footerButton.title(for: .normal)
    }

    var gamesHeaderTitles: [String] {
        gamesHeader.arrangedSubviews.compactMap { ($0 as? UILabel)?.text }
    }

    /// Pure: what the games list is for a scope. games/search ignores the
    /// position and the filters for personal games, so the label must not
    /// claim otherwise (react_pentedb ResultsList.js `listHeaderLabel`).
    static func listHeaderLabel(scope: String, moveCount: Int) -> String {
        let archive = moveCount > 0
            ? String(format: NSLocalizedString("Games through this position (%ld moves)", comment: ""), moveCount)
            : NSLocalizedString("All matching games", comment: "")
        switch scope {
        case "mine":
            return NSLocalizedString("My games (position and filters not applied)", comment: "")
        case "both":
            return archive + NSLocalizedString(", plus all your games (personal games not position-filtered)",
                                               comment: "")
        default:
            return archive
        }
    }

    // MARK: private

    private var showsGames: Bool { segmented.selectedSegmentIndex == 1 }

    private static func message(for state: DBLoadState, games: Bool) -> String? {
        switch state {
        case .blocked:
            return NSLocalizedString("Database unavailable during your rated game", comment: "")
        case .empty:
            return games ? NSLocalizedString("No games", comment: "")
                : NSLocalizedString("No moves from this position", comment: "")
        case .failed:
            return NSLocalizedString("Couldn't load", comment: "")
        case .unsupported:
            return NSLocalizedString("Not supported yet", comment: "")
        case .unauthorized:
            return NSLocalizedString("Please log in again", comment: "")
        case .subscriptionRequired:
            return NSLocalizedString("The database requires a subscription", comment: "")
        case .idle, .loading, .loaded:
            return nil
        @unknown default:
            return nil
        }
    }

    /// Shows the selected tab's state; each tab keeps its own.
    private func render() {
        let games = showsGames
        let state = games ? gamesState : statsState
        let message = DBResultsViewController.message(for: state, games: games)
        if state == .loading {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
        messageLabel.text = message
        messageLabel.isHidden = message == nil
        retryButton.isHidden = state != .failed
        let listHidden = message != nil || state == .loading
        tableView.isHidden = games || listHidden
        gamesTableView.isHidden = !games || listHidden
        gamesHeader.isHidden = !games || listHidden
        scopeLabel.isHidden = !games || listHidden
        scopeLabel.text = DBResultsViewController.listHeaderLabel(scope: service.scope,
                                                                  moveCount: service.moveCount)
        showButton.isHidden = games
        sortControl.isHidden = games
        movesBar.isHidden = games
    }

    private func updateGamesTitle() {
        var title = NSLocalizedString("Games", comment: "")
        // Only a settled first page has a total for this position.
        if gamesState == .loaded || gamesState == .empty {
            let total = service.pager.total
            title += " · " + (DBResultsViewController.countFormatter.string(from: NSNumber(value: total)) ?? "\(total)")
        }
        segmented.setTitle(title, forSegmentAt: 1)
    }

    private func updateFooter() {
        let title: String?
        if loadMoreFailed {
            title = NSLocalizedString("Couldn't load more. Retry", comment: "")
        } else if loadingMore {
            title = NSLocalizedString("Loading…", comment: "")
        } else if service.pager.hasMore && !games.isEmpty {
            title = NSLocalizedString("Show more", comment: "")
        } else {
            title = nil
        }
        footerButton.setTitle(title, for: .normal)
        footerButton.isEnabled = !loadingMore
        let wanted: UIView? = title == nil ? nil : footer
        if gamesTableView.tableFooterView !== wanted {
            gamesTableView.tableFooterView = wanted
        }
    }

    private static func showTitle(_ n: Int) -> String {
        n > 0 ? String(format: NSLocalizedString("Show %ld moves", comment: ""), n)
            : NSLocalizedString("Show all moves", comment: "")
    }

    private func rebuildShowMenu() {
        let current = service.preferences.movesShown
        let actions = DBMovesViewModel.showOptions.map { n in
            UIAction(title: DBResultsViewController.showTitle(n),
                     state: n == current ? .on : .off) { [weak self] _ in
                self?.selectShowCount(n)
            }
        }
        showButton.menu = UIMenu(title: "", children: actions)
        showButton.setTitle(DBResultsViewController.showTitle(current), for: .normal)
    }

    @objc private func infoTapped() {
        let vc = UIViewController()
        let label = UILabel()
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .label
        label.text = NSLocalizedString(
            "Win % ranks moves by a confidence-adjusted win rate (Wilson lower bound), so a move with a high percentage from few games ranks below a slightly lower percentage from many games. That is why the percentages are not strictly descending.\n\nPopularity sorts by number of games.",
            comment: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)
        let m = vc.view.layoutMarginsGuide
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: m.topAnchor),
            label.bottomAnchor.constraint(equalTo: m.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: m.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: m.trailingAnchor),
        ])
        vc.preferredContentSize = CGSize(width: 300, height: 190)
        vc.modalPresentationStyle = .popover
        vc.popoverPresentationController?.sourceView = infoButton
        vc.popoverPresentationController?.sourceRect = infoButton.bounds
        vc.popoverPresentationController?.delegate = DBInfoPopoverDelegate.shared
        if let seam = presentInfo { seam(vc) } else { present(vc, animated: true) }
    }

    @objc private func sortChanged() {
        selectSort(sortControl.selectedSegmentIndex == 1 ? .games : .winRate)
    }

    @objc private func tabChanged() {
        render()
    }

    @objc private func retryTapped() {
        onRetry?()
    }

    @objc private func footerTapped() {
        guard !loadingMore else { return }
        onLoadMore?()
    }

    // MARK: table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tableView === gamesTableView ? games.count : rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView === gamesTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: DBGameRowCell.reuseId)
                as? DBGameRowCell ?? DBGameRowCell(style: .default, reuseIdentifier: DBGameRowCell.reuseId)
            cell.configure(games[indexPath.row], now: Date())
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: DBMoveRowCell.reuseId)
            as? DBMoveRowCell ?? DBMoveRowCell(style: .default, reuseIdentifier: DBMoveRowCell.reuseId)
        cell.configure(rows[indexPath.row], marked: rows[indexPath.row].cell == selectedCell)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if tableView === gamesTableView {
            guard indexPath.row < games.count, games[indexPath.row].hasRealGid else { return }
            onOpenGame?(games[indexPath.row].gid, games[indexPath.row].isMine)
            return
        }
        guard indexPath.row < rows.count else { return }
        let cell = rows[indexPath.row].cell
        selectedCell = selectedCell == cell ? nil : cell
        tableView.reloadData()
        onSelectionChanged?(selectedCell ?? -1)
    }
}

/// Keeps the explanation a popover on iPhone too (no full-screen adaptation).
final class DBInfoPopoverDelegate: NSObject, UIPopoverPresentationControllerDelegate {
    static let shared = DBInfoPopoverDelegate()
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle { .none }
}
