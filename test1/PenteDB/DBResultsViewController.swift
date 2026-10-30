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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        dot.layer.cornerRadius = 7
        dot.layer.borderWidth = 1
        dot.layer.borderColor = UIColor(white: 0, alpha: 0.25).cgColor
        moveLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        moveLabel.textColor = DBPalette.ink
        barTrack.backgroundColor = DBPalette.divider
        barTrack.layer.cornerRadius = 3
        barTrack.clipsToBounds = true
        barFill.backgroundColor = DBPalette.accent
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

    func configure(_ row: DBMoveRow) {
        dot.backgroundColor = row.color
        moveLabel.text = row.label
        pctLabel.text = row.pctText
        gamesLabel.text = row.gamesText
        barWidth?.isActive = false
        barWidth = barFill.widthAnchor.constraint(equalTo: barTrack.widthAnchor,
                                                  multiplier: CGFloat(max(0.0001, row.barFraction)))
        barWidth?.isActive = true
        accessibilityLabel = "\(row.label), \(row.pctText), \(row.gamesText) games"
    }
}

/// Moves results: an iPhone sheet or an inline iPad panel. Reads the
/// service but never sets its callbacks; the host forwards state to it.
@objc final class DBResultsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    private let service: DBPositionService
    @objc var onPlayMove: ((Int) -> Void)?
    @objc var onShowCountChanged: (() -> Void)?
    /// Retry after a failure; the host refetches every failed endpoint.
    @objc var onRetry: (() -> Void)?

    private(set) var rows: [DBMoveRow] = []
    let segmented = UISegmentedControl(items: [NSLocalizedString("Moves", comment: ""),
                                               NSLocalizedString("Games", comment: "")])
    let showButton = UIButton(type: .system)
    let tableView = UITableView(frame: .zero, style: .plain)
    let messageLabel = UILabel()
    let retryButton = UIButton(type: .system)
    let spinner = UIActivityIndicatorView(style: .medium)

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
        // Games tab arrives with the games list (Task 18).
        segmented.setEnabled(false, forSegmentAt: 1)
        segmented.accessibilityIdentifier = "dbResultsTabs"

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

        let header = UIStackView(arrangedSubviews: [segmented, showButton])
        header.axis = .horizontal
        header.spacing = 12
        header.alignment = .center
        let message = UIStackView(arrangedSubviews: [messageLabel, retryButton])
        message.axis = .vertical
        message.spacing = 8
        message.alignment = .center
        for v in [header, tableView, message, spinner] as [UIView] {
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
            message.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24),
            message.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 24),
            message.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -24),
            spinner.centerXAnchor.constraint(equalTo: g.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 24),
        ])
        updateGamesTitle()
    }

    // MARK: host API

    @objc func reload() {
        loadViewIfNeeded()
        if let stats = service.lastStats {
            let n = service.preferences.movesShown
            rows = DBMovesViewModel.rows(stats: stats, occupied: service.occupied,
                                         limit: n > 0 ? n : nil, game: service.game)
        } else {
            rows = []
        }
        updateGamesTitle()
        tableView.reloadData()
    }

    @objc func showState(_ state: DBLoadState) {
        loadViewIfNeeded()
        var message: String?
        switch state {
        case .loading:
            message = nil
        case .blocked:
            message = NSLocalizedString("Database unavailable during your rated game", comment: "")
        case .empty:
            message = NSLocalizedString("No moves from this position", comment: "")
        case .failed:
            message = NSLocalizedString("Couldn't load", comment: "")
        case .unsupported:
            message = NSLocalizedString("Not supported yet", comment: "")
        case .unauthorized:
            message = NSLocalizedString("Please log in again", comment: "")
        case .subscriptionRequired:
            message = NSLocalizedString("The database requires a subscription", comment: "")
        case .idle, .loaded:
            message = nil
        @unknown default:
            message = nil
        }
        if state == .loading {
            spinner.startAnimating()
            rows = []
            tableView.reloadData()
        } else {
            spinner.stopAnimating()
        }
        messageLabel.text = message
        messageLabel.isHidden = message == nil
        retryButton.isHidden = state != .failed
        tableView.isHidden = message != nil || state == .loading
    }

    /// Saves the "Show N moves" choice; the host recomputes heat and reloads.
    func selectShowCount(_ n: Int) {
        service.preferences.movesShown = n
        rebuildShowMenu()
        onShowCountChanged?()
    }

    // MARK: private

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

    private func updateGamesTitle() {
        var title = NSLocalizedString("Games", comment: "")
        if let total = service.lastStats?.totalGames {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            title += " · " + (f.string(from: NSNumber(value: total)) ?? "\(total)")
        }
        segmented.setTitle(title, forSegmentAt: 1)
    }

    @objc private func retryTapped() {
        onRetry?()
    }

    // MARK: table

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DBMoveRowCell.reuseId)
            as? DBMoveRowCell ?? DBMoveRowCell(style: .default, reuseIdentifier: DBMoveRowCell.reuseId)
        cell.configure(rows[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < rows.count else { return }
        onPlayMove?(rows[indexPath.row].cell)
    }
}
