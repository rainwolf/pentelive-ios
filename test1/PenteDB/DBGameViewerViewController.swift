import UIKit

/// One cell of the move grid: optional turn number above the coordinate.
final class DBMoveGridCell: UICollectionViewCell {
    static let reuseId = "DBMoveGridCell"
    let numberLabel = UILabel()
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        numberLabel.font = .systemFont(ofSize: 10)
        numberLabel.textColor = DBPalette.secondaryText
        label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
        let stack = UIStackView(arrangedSubviews: [numberLabel, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        contentView.layer.cornerRadius = 6
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ cell: DBMoveCell) {
        numberLabel.text = cell.number
        label.text = cell.label
        switch cell.state {
        case .current:
            label.textColor = DBPalette.accent
            label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .bold)
            contentView.backgroundColor = DBPalette.chipSelectedFill
        case .future:
            label.textColor = UIColor(dbHex: DBMoveCell.futureHex)
            label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
            contentView.backgroundColor = .clear
        case .past:
            label.textColor = DBPalette.ink
            label.font = .monospacedDigitSystemFont(ofSize: 14, weight: .regular)
            contentView.backgroundColor = .clear
        }
    }
}

/// Minimal native viewer for one database game (`GET /games/{gid}`, or
/// `GET /collection/{wgid}` for a personal "mine" row).
/// Swipe left steps back, swipe right steps forward.
@objc final class DBGameViewerViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    enum ViewState: Equatable {
        case loading, loaded, blocked, unauthorized, subscriptionRequired, failed
    }

    @objc let gid: Int64
    /// True for a personal row: `gid` is a wgid loaded from the collection.
    @objc let isMine: Bool
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

    /// Three columns: player 1 | score, captures, date | player 2.
    struct HeaderLabels {
        let p1Name = UILabel(), p1Rating = UILabel()
        let score = UILabel(), captures = UILabel(), date = UILabel()
        let p2Name = UILabel(), p2Rating = UILabel()
    }
    let headerLabels = HeaderLabels()
    let headerView = UIView()
    let moveGrid = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    private(set) var gridCells: [DBMoveCell] = []

    /// 19x19 buffer (row stride 19) DBBoardView draws from; owned here,
    /// freed in deinit. Smaller boards use its top-left corner.
    private let board: UnsafeMutablePointer<AbstractBoard>

    /// Test seam: stands in for `isMovingFromParent` (no navigation stack).
    var movingFromParentOverride: Bool?

    init(gid: Int64, client: DBClient, isMine: Bool = false) {
        self.gid = gid
        self.isMine = isMine
        self.client = client
        board = UnsafeMutablePointer<AbstractBoard>.allocate(capacity: 19)
        board.initialize(repeating: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), count: 19)
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        loadTask?.cancel()
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

        configureChrome()

        let message = UIStackView(arrangedSubviews: [messageLabel, retryButton])
        message.axis = .vertical
        message.spacing = 8
        message.alignment = .center
        for v in [headerView, boardView, moveLabel, moveGrid, message, spinner] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        let g = view.safeAreaLayoutGuide
        // Width-based square board, capped so a tall iPad keeps room below it.
        let fullWidth = boardView.widthAnchor.constraint(equalTo: g.widthAnchor)
        fullWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: g.topAnchor, constant: 8),
            headerView.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 12),
            headerView.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -12),
            boardView.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 8),
            boardView.centerXAnchor.constraint(equalTo: g.centerXAnchor),
            boardView.widthAnchor.constraint(lessThanOrEqualTo: g.widthAnchor),
            boardView.widthAnchor.constraint(lessThanOrEqualTo: g.heightAnchor, multiplier: 0.62),
            fullWidth,
            boardView.heightAnchor.constraint(equalTo: boardView.widthAnchor),
            moveLabel.topAnchor.constraint(equalTo: boardView.bottomAnchor, constant: 8),
            moveLabel.centerXAnchor.constraint(equalTo: g.centerXAnchor),
            moveGrid.topAnchor.constraint(equalTo: moveLabel.bottomAnchor, constant: 8),
            moveGrid.leadingAnchor.constraint(equalTo: g.leadingAnchor),
            moveGrid.trailingAnchor.constraint(equalTo: g.trailingAnchor),
            moveGrid.bottomAnchor.constraint(equalTo: g.bottomAnchor),
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

    /// Only a pop that actually completed cancels the load: an interactive
    /// pop that is cancelled never reaches viewDidDisappear, so its load
    /// keeps running and the viewer still settles (no endless spinner).
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if movingFromParentOverride ?? isMovingFromParent { cancelLoadForPop() }
    }

    /// A popped viewer must not raise a late 401/403 alert from outside the window.
    func cancelLoadForPop() {
        loadTask?.cancel()
        _ = gate.next(.game) // supersede: a late reply is stale
    }

    // MARK: chrome

    private func configureChrome() {
        navigationItem.hidesBackButton = true
        let back = UIBarButtonItem(title: "\u{2190} " + NSLocalizedString("Position search", comment: ""),
                                   style: .plain, target: self, action: #selector(backChipTapped))
        back.tintColor = DBPalette.accent
        back.accessibilityIdentifier = "dbViewerBackChip"
        navigationItem.leftBarButtonItem = back

        let h = headerLabels
        for l in [h.p1Name, h.p1Rating, h.score, h.captures, h.date, h.p2Name, h.p2Rating] {
            l.numberOfLines = 1
            l.adjustsFontSizeToFitWidth = true
            l.minimumScaleFactor = 0.7
        }
        h.p1Name.textAlignment = .left
        h.p1Rating.textAlignment = .left
        h.p2Name.textAlignment = .right
        h.p2Rating.textAlignment = .right
        for l in [h.score, h.captures, h.date] { l.textAlignment = .center }
        h.score.font = .systemFont(ofSize: 17, weight: .semibold)
        h.score.textColor = DBPalette.ink
        h.date.font = .systemFont(ofSize: 12)
        h.date.textColor = DBPalette.secondaryText2
        func column(_ views: [UIView], _ align: UIStackView.Alignment) -> UIStackView {
            let c = UIStackView(arrangedSubviews: views)
            c.axis = .vertical
            c.alignment = align
            c.spacing = 2
            return c
        }
        let row = UIStackView(arrangedSubviews: [
            column([h.p1Name, h.p1Rating], .leading),
            column([h.score, h.captures, h.date], .center),
            column([h.p2Name, h.p2Rating], .trailing),
        ])
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.alignment = .top
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: headerView.topAnchor),
            row.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            row.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
        ])
        headerView.isHidden = true

        if let layout = moveGrid.collectionViewLayout as? UICollectionViewFlowLayout {
            layout.itemSize = CGSize(width: 56, height: 44)
            layout.minimumInteritemSpacing = 4
            layout.minimumLineSpacing = 4
            layout.sectionInset = UIEdgeInsets(top: 4, left: 12, bottom: 12, right: 12)
        }
        moveGrid.backgroundColor = .clear
        moveGrid.dataSource = self
        moveGrid.delegate = self
        moveGrid.register(DBMoveGridCell.self, forCellWithReuseIdentifier: DBMoveGridCell.reuseId)
        moveGrid.accessibilityIdentifier = "dbViewerMoveGrid"
        moveGrid.isHidden = true
    }

    @objc private func backChipTapped() {
        navigationController?.popViewController(animated: true)
    }

    // MARK: move grid

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        gridCells.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DBMoveGridCell.reuseId,
                                                      for: indexPath)
        if let c = cell as? DBMoveGridCell { c.configure(gridCells[indexPath.item]) }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard cursor != nil else { return }
        cursor?.jump(to: indexPath.item + 1)
        redraw()
    }

    // MARK: loading

    func load() {
        loadTask?.cancel()
        let id = gate.next(.game)
        render(.loading)
        let client = self.client
        let gid = self.gid
        let mine = isMine
        // No strong self across the await: a viewer popped mid-request is freed.
        loadTask = Task { @MainActor [weak self] in
            do {
                let detail = mine ? try await client.collectionGame(wgid: gid)
                    : try await client.game(gid: gid)
                guard let self = self, self.gate.isLatest(id, .game) else { return }
                if detail.blocked {
                    self.render(.blocked)
                    return
                }
                self.show(detail)
            } catch is CancellationError {
                return
            } catch {
                guard let self = self, self.gate.isLatest(id, .game) else { return }
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
        // Junk is dropped. Go/Renju passes (grid²) stay: they keep the colour
        // parity and show as "PASS"; DBBoardReplayer never places them.
        let keepsPass = DBGameCatalog.blackMovesFirst(game: gameId)
        let moves = detail.moves.filter { $0 >= 0 && ($0 < grid * grid || (keepsPass && $0 == grid * grid)) }
        cursor = DBViewerCursor(moves: moves, game: gameId)
        boardView.backgroundColor = DBPalette.boardColor(forGame: gameId)
        boardView.gridSize = Int32(grid)
        boardView.go = DBGameCatalog.isGo(gameId)
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
        headerView.isHidden = newState != .loaded
        moveGrid.isHidden = newState != .loaded
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
        DBBoardReplayer.replay(game: c.game, moves: c.moves, until: c.index,
                               into: UnsafeMutableRawPointer(board).assumingMemoryBound(to: Int32.self))
        boardView.lastMove = c.index > 0 ? Int32(c.moves[c.index - 1]) : -1
        boardView.setNeedsDisplay()
        moveLabel.text = String(format: NSLocalizedString("Move %ld / %ld", comment: ""), c.index, c.moves.count)
        if let header = detail?.header {
            let h = DBViewerHeader.make(header: header, moves: c.moves, cursor: c, now: Date())
            let l = headerLabels
            l.p1Name.attributedText = h.p1Name
            l.p1Rating.attributedText = h.p1Rating
            l.score.text = h.score
            l.captures.attributedText = h.captures
            l.date.text = h.date
            l.p2Name.attributedText = h.p2Name
            l.p2Rating.attributedText = h.p2Rating
        }
        gridCells = DBMoveCell.grid(moves: c.moves, game: c.game, cursorIndex: c.index)
        moveGrid.reloadData()
        if c.index > 0, c.index <= gridCells.count {
            moveGrid.scrollToItem(at: IndexPath(item: c.index - 1, section: 0),
                                  at: .centeredVertically, animated: false)
        }
    }

    /// Stone colour at `cell` after the current replay (0 = empty). For tests.
    func stone(at cell: Int) -> Int32 {
        let g = DBGameCatalog.gridSize(forGame: cursor?.game ?? 1)
        guard cell >= 0, cell < g * g else { return 0 }
        let index = (cell / g) * DBBoardReplayer.stride + cell % g
        return UnsafeMutableRawPointer(board).assumingMemoryBound(to: Int32.self)[index]
    }

    @objc private func retryTapped() {
        load()
    }
}
