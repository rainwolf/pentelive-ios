import UIKit

/// Settings > Blocked players: lists the account's ignore list, filtered by
/// kind, with a swipe action to unblock.
@objc final class BlockedPlayersViewController: UITableViewController {
    private var entries: [IgnoreEntry] = []
    private var filter: BlockFilter = .both
    private var loaded = false
    private let filterButton = UIButton(type: .system)
    private let emptyLabel = UILabel()
    private let cellID = "BlockedPlayerCell"

    override init(style: UITableView.Style) {
        super.init(style: style)
    }

    @objc convenience init() {
        self.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private var visible: [IgnoreEntry] { BlockedPlayers.filter(entries, by: filter) }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Blocked players", comment: "Blocked players screen title")

        emptyLabel.text = NSLocalizedString("No blocked players", comment: "Blocked players empty state")
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        let background = UIView()
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(emptyLabel)
        NSLayoutConstraint.activate([
            emptyLabel.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: background.layoutMarginsGuide.leadingAnchor),
            emptyLabel.trailingAnchor.constraint(equalTo: background.layoutMarginsGuide.trailingAnchor),
        ])
        tableView.backgroundView = background

        let header = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 44))
        filterButton.showsMenuAsPrimaryAction = true
        filterButton.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(filterButton)
        NSLayoutConstraint.activate([
            filterButton.leadingAnchor.constraint(equalTo: header.layoutMarginsGuide.leadingAnchor),
            filterButton.centerYAnchor.constraint(equalTo: header.centerYAnchor),
        ])
        tableView.tableHeaderView = header
        updateFilterButton()
        updateEmptyState()

        reload()
    }

    private func updateFilterButton() {
        var config = UIButton.Configuration.plain()
        config.title = filter.title
        config.image = UIImage(systemName: "chevron.down")
        config.imagePlacement = .trailing
        config.imagePadding = 6
        filterButton.configuration = config
        filterButton.menu = UIMenu(children: BlockFilter.allCases.map { option in
            UIAction(title: option.title, state: option == filter ? .on : .off) { [weak self] _ in
                guard let self = self else { return }
                self.filter = option
                self.updateFilterButton()
                self.tableView.reloadData()
                self.updateEmptyState()
            }
        })
    }

    private func updateEmptyState() {
        tableView.backgroundView?.isHidden = !(loaded && visible.isEmpty)
    }

    private func reload() {
        BlockedPlayersService.load { [weak self] entries, error in
            guard let self = self else { return }
            if let entries = entries {
                self.entries = entries
                self.loaded = true
                self.tableView.reloadData()
                self.updateEmptyState()
            } else {
                PenteAlert.show(withTitle: self.title ?? "",
                                message: error ?? NSLocalizedString("Please try again.", comment: "Blocked players error"),
                                cancelButtonTitle: NSLocalizedString("OK", comment: ""))
            }
        }
    }

    // MARK: Table

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        visible.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: cellID)
        let entry = visible[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.attributedText = entry.styledName
        content.secondaryText = filter == .both
            ? BlockedPlayers.kindText(invite: entry.ignoreInvite, chat: entry.ignoreChat)
            : nil
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let entry = visible[indexPath.row]
        let action = UIContextualAction(style: .destructive,
                                        title: NSLocalizedString("Unblock", comment: "Unblock swipe action")) { [weak self] _, _, done in
            self?.confirmUnblock(entry)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [action])
    }

    private func confirmUnblock(_ entry: IgnoreEntry) {
        let kind: String
        switch filter {
        case .messages: kind = BlockedPlayers.kindText(invite: false, chat: true)
        case .invitations: kind = BlockedPlayers.kindText(invite: true, chat: false)
        case .both: kind = BlockedPlayers.kindText(invite: entry.ignoreInvite, chat: entry.ignoreChat)
        }
        let title = String(format: NSLocalizedString("Unblock %@?", comment: "Unblock dialog title"), entry.name)
        let message = String(format: NSLocalizedString("%@ will be able to send you %@ again.",
                                                       comment: "Unblock dialog message"), entry.name, kind)
        PenteAlert.show(withTitle: title, message: message,
                        cancelButtonTitle: NSLocalizedString("Cancel", comment: ""),
                        otherButtonTitles: [NSLocalizedString("Unblock", comment: "Unblock dialog button")],
                        destructiveButtonIndex: 1) { [weak self] index in
            if index == 1 { self?.unblock(entry) }
        }
    }

    private func unblock(_ entry: IgnoreEntry) {
        let left = BlockedPlayers.remainingFlags(entry, unblocking: filter)
        BlockedPlayersService.update(pid: entry.ignorePid, invite: left.invite, chat: left.chat) { [weak self] list, error in
            guard let self = self else { return }
            if let list = list {
                self.entries = list
                self.loaded = true
                self.tableView.reloadData()
                self.updateEmptyState()
            } else {
                BlockedPlayersService.showError(blocking: false, name: entry.name, message: error)
            }
        }
    }
}
