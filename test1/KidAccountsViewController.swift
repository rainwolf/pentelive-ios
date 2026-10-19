import UIKit

/// Settings > Kid accounts: a parent's kid accounts, with create / convert.
/// A kid who reaches this screen sees a "managed by your parent" note instead.
@objc final class KidAccountsViewController: UITableViewController {
    private var state: KidAccountsState?
    private let emptyLabel = UILabel()
    private let cellID = "KidAccountCell"

    /// Set by Settings so a kid reply can flag the live player (hides the Settings row).
    @objc var player: PentePlayer?

    override init(style: UITableView.Style) {
        super.init(style: style)
    }

    @objc convenience init() {
        self.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    var emptyText: String? {
        emptyLabel.text
    }

    private var rows: [KidAccount] {
        guard let state, !state.isKid else { return [] }
        return state.kids
    }

    private lazy var addButton: UIBarButtonItem = {
        let menu = UIMenu(children: [
            UIAction(title: NSLocalizedString("Create kid account", comment: "Kid accounts menu"),
                     image: UIImage(systemName: "person.badge.plus")) { [weak self] _ in self?.promptCreate() },
            UIAction(title: NSLocalizedString("Convert existing account", comment: "Kid accounts menu"),
                     image: UIImage(systemName: "arrow.triangle.2.circlepath")) { [weak self] _ in self?.promptConvert() },
        ])
        let item = UIBarButtonItem(systemItem: .add)
        item.menu = menu
        return item
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = NSLocalizedString("Kid accounts", comment: "Kid accounts screen title")

        emptyLabel.text = NSLocalizedString("No kid accounts yet", comment: "Kid accounts empty state")
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
        tableView.backgroundView?.isHidden = true
        navigationItem.rightBarButtonItem = addButton
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    private func reload() {
        KidAccountsService.load { [weak self] state, error in
            self?.apply(state: state, error: error)
        }
    }

    /// Every reply goes through here.
    func apply(state: KidAccountsState?, error: String?) {
        guard let state else {
            PenteAlert.show(withTitle: title ?? "",
                            message: error ?? NSLocalizedString("Please try again.", comment: "Kid accounts error"),
                            cancelButtonTitle: NSLocalizedString("OK", comment: ""))
            return
        }
        self.state = state
        if state.isKid {
            navigationItem.rightBarButtonItem = nil
            emptyLabel.text = KidMode.managedByParentText(state.parentName)
            // Hides the Settings row on its next viewWillAppear.
            player?.isKid = true
        } else {
            navigationItem.rightBarButtonItem = addButton
            emptyLabel.text = NSLocalizedString("No kid accounts yet", comment: "Kid accounts empty state")
        }
        tableView.reloadData()
        tableView.backgroundView?.isHidden = !rows.isEmpty
    }

    /// Public for the detail screen to hand back a fresh state.
    func show(_ state: KidAccountsState) {
        apply(state: state, error: nil)
    }

    // MARK: Actions

    private func run(_ action: KidAction, onSuccess: ((KidAccountsState) -> Void)? = nil) {
        KidAccountsService.perform(action) { [weak self] state, error in
            guard let self else { return }
            self.apply(state: state, error: error)
            if let state {
                onSuccess?(state)
            }
        }
    }

    private func promptCreate() {
        let alert = UIAlertController(title: NSLocalizedString("Create kid account", comment: ""),
                                      message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = NSLocalizedString("username", comment: "")
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addTextField { field in
            field.placeholder = NSLocalizedString("password", comment: "")
            field.isSecureTextEntry = true
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Create", comment: ""), style: .default) { [weak self, weak alert] _ in
            let name = alert?.textFields?[0].text ?? ""
            let password = alert?.textFields?[1].text ?? ""
            self?.run(.create(name: name, password: password))
        })
        present(alert, animated: true)
    }

    private func promptConvert() {
        let alert = UIAlertController(title: NSLocalizedString("Convert existing account", comment: ""),
                                      message: NSLocalizedString("We'll email that account to confirm.", comment: ""),
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = NSLocalizedString("username", comment: "")
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("Send", comment: ""), style: .default) { [weak self, weak alert] _ in
            let name = alert?.textFields?[0].text ?? ""
            self?.run(.convert(name: name)) { state in
                if let message = state.message {
                    PenteAlert.show(withTitle: self?.title ?? "", message: message,
                                    cancelButtonTitle: NSLocalizedString("OK", comment: ""))
                }
            }
        })
        present(alert, animated: true)
    }

    // MARK: Table

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: cellID)
        let kid = rows[indexPath.row]
        var content = cell.defaultContentConfiguration()
        content.text = kid.name
        content.secondaryText = KidMode.approvedCountText(kid.whitelist.count)
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_: UITableView, titleForFooterInSection _: Int) -> String? {
        guard let state, !state.isKid, !state.emailVerified else { return nil }
        return NSLocalizedString("Verify your email address before adding kids", comment: "Kid accounts footer")
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Task 5: push KidDetailViewController(kid:list:)
    }
}
