import UIKit

/// One kid's settings: approved chat players, email copies, password and release.
final class KidDetailViewController: UITableViewController {
    private var kid: KidAccount
    private weak var list: KidAccountsViewController?

    /// Seam for tests; defaults to the network.
    var performAction: (KidAction, @escaping (KidAccountsState?, String?) -> Void) -> Void = KidAccountsService.perform

    /// Seam for tests; defaults to the network.
    var loadActiveGames: (Int64, @escaping ([KidActiveGame]?, String?) -> Void) -> Void = KidAccountsService.activeGames

    /// Seam for tests; set to push the read-only board in `init`.
    var openBoard: (KidActiveGame) -> Void = { _ in }

    private enum Section: Int, CaseIterable { case approved, copies, games, account }

    private enum GamesState {
        case loading
        case loaded([KidActiveGame])
        case failed(String)
    }

    private var gamesState = GamesState.loading
    private var gamesRequest = 0

    private lazy var dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f
    }()

    init(kid: KidAccount, list: KidAccountsViewController) {
        self.kid = kid
        self.list = list
        super.init(style: .insetGrouped)
        openBoard = { [unowned self] in self.pushReadOnlyBoard($0) }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = kid.name
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadActiveGames()
    }

    func reloadActiveGames() {
        guard kid.copyTbMessages != nil else { return }
        gamesRequest += 1
        let token = gamesRequest
        gamesState = .loading
        tableView.reloadData()
        loadActiveGames(kid.kidPid) { [weak self] games, error in
            guard let self, token == self.gamesRequest else { return }
            if let games {
                self.gamesState = .loaded(games)
            } else {
                self.gamesState = .failed(error ?? NSLocalizedString("Could not load games.", comment: "Kid active games"))
            }
            self.tableView.reloadData()
        }
    }

    static func makeReadOnlyBoard(_ g: KidActiveGame, replay: (BoardViewController) -> Void = { $0.replayGame() }) -> BoardViewController {
        let game = Game()
        game.gameID = String(g.gid)
        game.remainingTime = "0 days"
        let board = UIStoryboard(name: "MainStoryboard", bundle: nil)
            .instantiateViewController(withIdentifier: "boardViewController") as! BoardViewController
        board.activeGame = false
        board.game = game
        replay(board)
        // The outlet exists only once replay has loaded the view.
        board.boardTapRecognizer?.isEnabled = false
        return board
    }

    private func pushReadOnlyBoard(_ g: KidActiveGame) {
        navigationController?.pushViewController(Self.makeReadOnlyBoard(g), animated: true)
    }

    // MARK: Actions

    private func run(_ action: KidAction, onSuccess: (() -> Void)? = nil, onFailure: (() -> Void)? = nil) {
        performAction(action) { [weak self] state, error in
            guard let self else { return }
            guard let state else {
                onFailure?()
                PenteAlert.show(withTitle: self.kid.name,
                                message: error ?? NSLocalizedString("Please try again.", comment: "Kid accounts error"),
                                cancelButtonTitle: NSLocalizedString("OK", comment: ""))
                return
            }
            self.list?.show(state)
            if let fresh = KidAccounts.kid(self.kid.kidPid, in: state) {
                self.kid = fresh
                self.tableView.reloadData()
                onSuccess?()
            } else if let list = self.list {
                self.navigationController?.popToViewController(list, animated: true)
            }
        }
    }

    func remove(playerPid: Int64) {
        run(.whitelistRemove(kidPid: kid.kidPid, playerPid: playerPid))
    }

    func release() {
        run(.release(kidPid: kid.kidPid))
    }

    @objc func copySwitchChanged(_ sender: UISwitch) {
        let value = sender.isOn
        run(.settings(kidPid: kid.kidPid,
                      copyMessages: sender.tag == 0 ? value : nil,
                      copyLiveChat: sender.tag == 1 ? value : nil,
                      copyTbMessages: sender.tag == 2 ? value : nil),
            onFailure: { sender.setOn(!value, animated: true) })
    }

    private func confirmRemove(_ player: KidPlayer) {
        let alert = UIAlertController(
            title: String(format: NSLocalizedString("Remove %@?", comment: "Kid whitelist"), player.name),
            message: String(format: NSLocalizedString("%@ won't be able to chat with %@.", comment: "Kid whitelist"),
                            kid.name, player.name),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Remove", comment: ""), style: .destructive) { [weak self] _ in
            self?.remove(playerPid: player.pid)
        })
        present(alert, animated: true)
    }

    private func promptAddPlayer() {
        let alert = UIAlertController(title: NSLocalizedString("Add player", comment: "Kid whitelist"),
                                      message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = NSLocalizedString("username", comment: "")
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Add", comment: ""), style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let name = alert?.textFields?.first?.text ?? ""
            self.run(.whitelistAdd(kidPid: self.kid.kidPid, playerName: name))
        })
        present(alert, animated: true)
    }

    private func promptPassword() {
        let alert = UIAlertController(title: NSLocalizedString("Change password", comment: "Kid account"),
                                      message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = NSLocalizedString("new password", comment: "")
            field.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Save", comment: ""), style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let password = alert?.textFields?.first?.text ?? ""
            self.run(.password(kidPid: self.kid.kidPid, password: password), onSuccess: { [weak self] in
                PenteAlert.show(withTitle: self?.kid.name ?? "",
                                message: NSLocalizedString("Password changed", comment: "Kid account"),
                                cancelButtonTitle: NSLocalizedString("OK", comment: ""))
            })
        })
        present(alert, animated: true)
    }

    private func confirmRelease() {
        let alert = UIAlertController(
            title: String(format: NSLocalizedString("Release %@?", comment: "Kid account"), kid.name),
            message: String(format: NSLocalizedString("%@ becomes a normal account. Approved players and copy settings are deleted.", comment: "Kid account"), kid.name),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Release", comment: ""), style: .destructive) { [weak self] _ in
            self?.release()
        })
        present(alert, animated: true)
    }

    // MARK: Table

    override func numberOfSections(in _: UITableView) -> Int {
        Section.allCases.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section)! {
        case .approved: return kid.whitelist.count + 1
        case .copies: return kid.copyTbMessages != nil ? 3 : 2
        case .games:
            guard kid.copyTbMessages != nil else { return 0 }
            if case let .loaded(games) = gamesState, !games.isEmpty { return games.count }
            return 1
        case .account: return 2
        }
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .approved: return NSLocalizedString("Approved players", comment: "Kid detail")
        case .copies: return NSLocalizedString("Email copies to you", comment: "Kid detail")
        case .games:
            return kid.copyTbMessages != nil ? NSLocalizedString("Active turn-based games", comment: "Kid detail") : nil
        case .account: return NSLocalizedString("Account", comment: "Kid detail")
        }
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .approved: return NSLocalizedString("Your kid can always chat with you and with pente.org admins.", comment: "Kid detail")
        case .copies: return kid.copyTbMessages != nil ? KidMode.copiesFooter : KidMode.liveChatCopyNote
        case .games, .account: return nil
        }
    }

    private func placeholderCell(_ text: String) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        content.text = text
        content.textProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        var content = cell.defaultContentConfiguration()
        switch Section(rawValue: indexPath.section)! {
        case .approved:
            if indexPath.row < kid.whitelist.count {
                content.attributedText = kid.whitelist[indexPath.row].styledName
            } else {
                content.text = NSLocalizedString("Add player…", comment: "Kid whitelist")
                content.textProperties.color = tableView.tintColor
            }
        case .copies:
            let toggle = UISwitch()
            toggle.tag = indexPath.row
            switch indexPath.row {
            case 0: toggle.isOn = kid.copyMessages
            case 1: toggle.isOn = kid.copyLiveChat
            default: toggle.isOn = kid.copyTbMessages ?? false
            }
            toggle.addTarget(self, action: #selector(copySwitchChanged(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
            switch indexPath.row {
            case 0: content.text = NSLocalizedString("Private messages", comment: "Kid detail")
            case 1: content.text = NSLocalizedString("Live-room chat", comment: "Kid detail")
            default: content.text = NSLocalizedString("Turn-based game messages", comment: "Kid detail")
            }
        case .games:
            switch gamesState {
            case .loading:
                return placeholderCell(NSLocalizedString("Loading…", comment: "Kid active games"))
            case let .failed(message):
                return placeholderCell(message)
            case let .loaded(games):
                if games.isEmpty {
                    return placeholderCell(NSLocalizedString("No active turn-based games.", comment: "Kid active games"))
                }
                let game = games[indexPath.row]
                let gameCell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                var config = UIListContentConfiguration.subtitleCell()
                config.text = game.title
                config.secondaryText = game.subtitle(kidName: kid.name) { [dateFormatter] in dateFormatter.string(from: $0) }
                gameCell.contentConfiguration = config
                gameCell.accessoryType = .disclosureIndicator
                return gameCell
            }
        case .account:
            if indexPath.row == 0 {
                content.text = NSLocalizedString("Change password…", comment: "Kid account")
                content.textProperties.color = tableView.tintColor
            } else {
                content.text = NSLocalizedString("Release kid account…", comment: "Kid account")
                content.textProperties.color = .systemRed
            }
        }
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section)! {
        case .approved:
            if indexPath.row == kid.whitelist.count {
                promptAddPlayer()
            }
        case .copies: break
        case .games:
            if case let .loaded(games) = gamesState, indexPath.row < games.count {
                openBoard(games[indexPath.row])
            }
        case .account:
            if indexPath.row == 0 {
                promptPassword()
            } else {
                confirmRelease()
            }
        }
    }

    override func tableView(_: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == Section.approved.rawValue, indexPath.row < kid.whitelist.count else { return nil }
        let player = kid.whitelist[indexPath.row]
        let remove = UIContextualAction(style: .destructive, title: NSLocalizedString("Remove", comment: "")) { [weak self] _, _, done in
            self?.confirmRemove(player)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [remove])
    }
}
