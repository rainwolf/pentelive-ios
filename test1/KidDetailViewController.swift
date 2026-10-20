import UIKit

/// One kid's settings: approved chat players, email copies, password and release.
final class KidDetailViewController: UITableViewController {
    private var kid: KidAccount
    private weak var list: KidAccountsViewController?

    /// Seam for tests; defaults to the network.
    var performAction: (KidAction, @escaping (KidAccountsState?, String?) -> Void) -> Void = KidAccountsService.perform

    private enum Section: Int, CaseIterable { case approved, copies, account }

    init(kid: KidAccount, list: KidAccountsViewController) {
        self.kid = kid
        self.list = list
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = kid.name
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
        let isMessages = sender.tag == 0
        let value = sender.isOn
        run(.settings(kidPid: kid.kidPid,
                      copyMessages: isMessages ? value : nil,
                      copyLiveChat: isMessages ? nil : value),
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
        case .copies, .account: return 2
        }
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .approved: return NSLocalizedString("Approved players", comment: "Kid detail")
        case .copies: return NSLocalizedString("Email copies to you", comment: "Kid detail")
        case .account: return NSLocalizedString("Account", comment: "Kid detail")
        }
    }

    override func tableView(_: UITableView, titleForFooterInSection section: Int) -> String? {
        switch Section(rawValue: section)! {
        case .approved: return NSLocalizedString("Your kid can always chat with you and with pente.org admins.", comment: "Kid detail")
        case .copies: return KidMode.liveChatCopyNote
        case .account: return nil
        }
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
            toggle.isOn = indexPath.row == 0 ? kid.copyMessages : kid.copyLiveChat
            toggle.addTarget(self, action: #selector(copySwitchChanged(_:)), for: .valueChanged)
            cell.accessoryView = toggle
            cell.selectionStyle = .none
            content.text = indexPath.row == 0
                ? NSLocalizedString("Private messages", comment: "Kid detail")
                : NSLocalizedString("Live-room chat", comment: "Kid detail")
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
