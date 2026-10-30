import UIKit

/// Minimal native viewer for one database game (`GET /games/{gid}`).
/// Swipe left steps back, swipe right steps forward.
@objc final class DBGameViewerViewController: UIViewController {
    enum ViewState: Equatable {
        case loading, loaded, blocked, unauthorized, subscriptionRequired, failed
    }

    @objc let gid: Int64
    private let client: DBClient
    private let gate = DBRequestGate()
    private var loadTask: Task<Void, Never>?

    /// 401: the host shows its log-in alert from this controller (OK pops).
    @objc var onUnauthorized: ((UIViewController) -> Void)?
    /// 403 subscription_required: the host shows its subscribe alert from this controller.
    @objc var onSubscriptionRequired: ((UIViewController) -> Void)?

    private(set) var state: ViewState = .loading
    private(set) var cursor: DBViewerCursor?
    private(set) var detail: DBGameDetail?

    let boardView: DBBoardView = DBBoardView()
    let moveLabel = UILabel()
    let messageLabel = UILabel()
    let retryButton = UIButton(type: .system)
    let spinner = UIActivityIndicatorView(style: .medium)

    /// 19x19 buffer DBBoardView draws from; owned here, freed in deinit.
    private let board: UnsafeMutablePointer<AbstractBoard>
    private let game = LegacyPenteGame()

    init(gid: Int64, client: DBClient) {
        self.gid = gid
        self.client = client
        board = UnsafeMutablePointer<AbstractBoard>.allocate(capacity: 19)
        board.initialize(repeating: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), count: 19)
        super.init(nibName: nil, bundle: nil)
        game.abstractBoard = board
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        loadTask?.cancel()
        game.abstractBoard = nil
        board.deinitialize(count: 19)
        board.deallocate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        boardView.setAbstractBoard(board)
        boardView.lastMove = -1
        boardView.backgroundColor = DBPalette.boardColor(forGame: 1)
        boardView.isHidden = true
        boardView.accessibilityIdentifier = "dbViewerBoard"

        moveLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        moveLabel.textColor = DBPalette.secondaryText
        moveLabel.textAlignment = .center

        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.textColor = DBPalette.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.isHidden = true
        messageLabel.accessibilityIdentifier = "dbViewerMessage"

        retryButton.setTitle(NSLocalizedString("Retry", comment: ""), for: .normal)
        retryButton.setTitleColor(DBPalette.accent, for: .normal)
        retryButton.isHidden = true
        retryButton.accessibilityIdentifier = "dbViewerRetry"
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        spinner.hidesWhenStopped = true

        let message = UIStackView(arrangedSubviews: [messageLabel, retryButton])
        message.axis = .vertical
        message.spacing = 8
        message.alignment = .center
        for v in [boardView, moveLabel, message, spinner] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        let g = view.safeAreaLayoutGuide
        // Width-based square board, capped so a tall iPad keeps room below it.
        let fullWidth = boardView.widthAnchor.constraint(equalTo: g.widthAnchor)
        fullWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            boardView.topAnchor.constraint(equalTo: g.topAnchor),
            boardView.centerXAnchor.constraint(equalTo: g.centerXAnchor),
            boardView.widthAnchor.constraint(lessThanOrEqualTo: g.widthAnchor),
            boardView.widthAnchor.constraint(lessThanOrEqualTo: g.heightAnchor, multiplier: 0.62),
            fullWidth,
            boardView.heightAnchor.constraint(equalTo: boardView.widthAnchor),
            moveLabel.topAnchor.constraint(equalTo: boardView.bottomAnchor, constant: 8),
            moveLabel.centerXAnchor.constraint(equalTo: g.centerXAnchor),
            message.centerYAnchor.constraint(equalTo: g.centerYAnchor),
            message.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 24),
            message.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -24),
            spinner.centerXAnchor.constraint(equalTo: g.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: g.centerYAnchor),
        ])

        let back = UISwipeGestureRecognizer(target: self, action: #selector(stepBack))
        back.direction = .left
        view.addGestureRecognizer(back)
        let forward = UISwipeGestureRecognizer(target: self, action: #selector(stepForward))
        forward.direction = .right
        view.addGestureRecognizer(forward)

        load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Swipe right steps forward instead of popping (mirrors DatabaseViewController).
        if #available(iOS 26.0, *) {
            navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = false
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if #available(iOS 26.0, *) {
            navigationController?.interactiveContentPopGestureRecognizer?.isEnabled = true
        }
    }

    // MARK: loading

    func load() {
        loadTask?.cancel()
        let id = gate.next(.game)
        render(.loading)
        loadTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let detail = try await self.client.game(gid: self.gid)
                guard self.gate.isLatest(id, .game) else { return }
                if detail.blocked {
                    self.render(.blocked)
                    return
                }
                self.show(detail)
            } catch is CancellationError {
                return
            } catch {
                guard self.gate.isLatest(id, .game) else { return }
                switch error as? DBError {
                case .unauthorized?:
                    self.render(.unauthorized)
                    self.onUnauthorized?(self)
                case .subscriptionRequired?:
                    self.render(.subscriptionRequired)
                    self.onSubscriptionRequired?(self)
                case .blocked?:
                    self.render(.blocked)
                default:
                    self.render(.failed)
                }
            }
        }
    }

    private func show(_ detail: DBGameDetail) {
        self.detail = detail
        let gameId = detail.header?.game ?? 1
        let grid = DBGameCatalog.gridSize(forGame: gameId)
        // Pass sentinels and junk are never written into the board.
        let moves = detail.moves.filter { $0 >= 0 && $0 < grid * grid }
        cursor = DBViewerCursor(moves: moves, game: gameId)
        boardView.backgroundColor = DBPalette.boardColor(forGame: gameId)
        if let h = detail.header {
            title = "\(h.player1?.name ?? "?") \u{2013} \(h.player2?.name ?? "?")"
        }
        render(.loaded)
        redraw()
    }

    private func render(_ newState: ViewState) {
        state = newState
        var message: String?
        switch newState {
        case .loading, .loaded:
            message = nil
        case .blocked:
            message = NSLocalizedString("Database unavailable during your rated game", comment: "")
        case .unauthorized:
            message = NSLocalizedString("Please log in again", comment: "")
        case .subscriptionRequired:
            message = NSLocalizedString("The database requires a subscription", comment: "")
        case .failed:
            message = NSLocalizedString("Couldn't load this game", comment: "")
        }
        if newState == .loading {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
        messageLabel.text = message
        messageLabel.isHidden = message == nil
        retryButton.isHidden = newState != .failed
        boardView.isHidden = newState != .loaded
        moveLabel.isHidden = newState != .loaded
    }

    // MARK: stepping

    @objc func stepBack() {
        guard cursor?.back() == true else { return }
        redraw()
    }

    @objc func stepForward() {
        guard cursor?.forward() == true else { return }
        redraw()
    }

    private func redraw() {
        guard let c = cursor else { return }
        let variant = PenteGameVariant(rawValue: DBGameCatalog.variant(forGame: c.game).rawValue) ?? .pente
        game.replayMoves(c.moves.map { NSNumber(value: $0) }, variant: variant, untilMove: c.index)
        boardView.lastMove = c.index > 0 ? Int32(c.moves[c.index - 1]) : -1
        boardView.setNeedsDisplay()
        moveLabel.text = String(format: NSLocalizedString("Move %ld / %ld", comment: ""), c.index, c.moves.count)
    }

    /// Stone colour at `cell` after the current replay (0 = empty). For tests.
    func stone(at cell: Int) -> Int32 {
        guard cell >= 0, cell < 361 else { return 0 }
        return UnsafeMutableRawPointer(board).assumingMemoryBound(to: Int32.self)[cell]
    }

    @objc private func retryTapped() {
        load()
    }
}
