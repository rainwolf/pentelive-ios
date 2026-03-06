//
//  TableViewController.swift
//  penteLive
//
//  Created by rainwolf on 04/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

class TableNavigationBar: UINavigationBar {
    override func layoutSubviews() {
        super.layoutSubviews()

//        for view in  {
//            if view.isKind(of: UIBarButtonItem.self) {
//                view.layoutMargins = .zero
//            }
//        }
    }
}

class TableViewController: UIViewController, UITextFieldDelegate, UIGestureRecognizerDelegate, PopoverViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    var socket: PenteLiveSocket!
    var table: Table!
    let board: LiveBoard!
    let zoomedBoard: LiveBoard!
    var textView: UITextView = .init()
    var textField = UITextField()
    var me: String
    var seatsView: SeatsView!
    let playButton = UIButton()
    var timer, waitTimer: Timer?
    var waitSeconds: Int = 7 * 60
    var cellSize: CGFloat = 0
    var zoomFactor: CGFloat = 3
//    var stone: LiveStone!
    var zoomedStone: LiveStone!
    let horizontalLine = LiveHorizontalLine()
    let verticalLine = LiveVerticalLine()
    var zoomedCellSize: CGFloat = 0
    var offSet: CGPoint!
    var setupView: TableSetupView

    var waitAlertController, invitationAlertController, inviteAlertController: UIAlertController?
    var tablesAndPlayers: TablesAndPlayer!
    var invitablePlayers: [String]!
    var pentePlayer: PentePlayer!

    init(table: Table, socket: PenteLiveSocket, tablesAndPlayers: TablesAndPlayer, pente_player: PentePlayer, me: String) {
        self.table = table
        self.socket = socket
        board = LiveBoard(table: table)
        zoomedBoard = LiveBoard(table: table)
        setupView = TableSetupView(table: table, socket: socket, me: me)
        self.tablesAndPlayers = tablesAndPlayers
        pentePlayer = pente_player
        self.me = me
        super.init(nibName: nil, bundle: nil)
        edgesForExtendedLayout = []
        textView.layer.borderWidth = 2.0
        textView.layer.cornerRadius = 2.0
        textView.isEditable = false
        textView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(enterText)))
        view.addSubview(textView)
        textField.delegate = self
        textField.layer.borderWidth = 1.0
        textField.layer.cornerRadius = 1.0
        textField.returnKeyType = .send
        textField.backgroundColor = UIColor.white
        view.addSubview(textField)
        playButton.setTitle(NSLocalizedString("play", comment: ""), for: .normal)
        playButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 25)
        playButton.setTitleColor(UIColor.blue, for: .normal)
        playButton.addTarget(self, action: #selector(play), for: .touchUpInside)
//        var button = UIButton(type: .custom)
//        button.setImage(UIImage(named: "gamesettings"), for: .normal)
//        button.addTarget(self, action:#selector(showSettings), for: .touchUpInside)
//        button.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
//        let settingsItem = UIBarButtonItem(customView: button)
        let settingsItem = UIBarButtonItem(image: UIImage(named: "gamesettings"), style: .plain, target: self, action: #selector(showSettings))
//        button = UIButton(type: .custom)
//        button.setImage(UIImage(named: "cancel"), for: .normal)
//        button.addTarget(self, action:#selector(showOptions), for: .touchUpInside)
//        button.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
//        let optionsItem = UIBarButtonItem(customView: button)
        let optionsItem = UIBarButtonItem(image: UIImage(named: "cancel"), style: .plain, target: self, action: #selector(showOptions))
//        button = UIButton(type: .custom)
//        button.setImage(UIImage(named: "onlineUsers"), for: .normal)
//        button.addTarget(self, action:#selector(showPlayersOptions), for: .touchUpInside)
//        button.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        let onlineUsersItem = UIBarButtonItem(image: UIImage(named: "onlineUsers"), style: .plain, target: self, action: #selector(showPlayersOptions))
        navigationItem.setRightBarButtonItems([settingsItem,
                                               optionsItem,
                                               onlineUsersItem], animated: true)
    }

    required init(coder aDecoder: NSCoder) {
        board = LiveBoard(table: Table(table: -1))
        zoomedBoard = LiveBoard(table: Table(table: -1))
        setupView = TableSetupView(coder: aDecoder)
        tablesAndPlayers = TablesAndPlayer()
        me = "guest"
        super.init(coder: aDecoder)!
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let width = view.frame.width
        board.frame = CGRect(x: 0, y: 0, width: width, height: width)
        cellSize = CGFloat(width / 19)
        zoomedCellSize = zoomFactor * cellSize
        view.addSubview(board)
        zoomedBoard.frame = CGRect(x: 0, y: 0, width: zoomFactor * width, height: zoomFactor * width)
        view.addSubview(zoomedBoard)
        zoomedBoard.isHidden = true
        var frame = view.frame
        frame.origin.y = board.frame.origin.y + board.frame.size.height
        frame.size.height = 44
        seatsView = SeatsView(frame: frame)
        view.addSubview(seatsView)
        seatsView.seat1Label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(sitStand(sender:))))
        seatsView.seat2Label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(sitStand(sender:))))
        frame = playButton.frame
        frame = seatsView.ratedTimerLabel.frame
        frame.origin.y = seatsView.frame.origin.y
        playButton.frame = frame
        playButton.isHidden = true
        view.addSubview(playButton)
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(boardTouch(gestureReconizer:)))
//        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.boardTouch))
        gestureRecognizer.minimumPressDuration = 0.05
        gestureRecognizer.delaysTouchesBegan = true
        gestureRecognizer.delegate = self
        board.addGestureRecognizer(gestureRecognizer)
        horizontalLine.frame = CGRect(x: 0, y: 0, width: width, height: 10)
        horizontalLine.center = board.center
        horizontalLine.backgroundColor = UIColor.clear
        view.addSubview(horizontalLine)
        horizontalLine.isHidden = true
        verticalLine.frame = CGRect(x: 0, y: 0, width: 10, height: width)
        verticalLine.center = board.center
        view.addSubview(verticalLine)
        verticalLine.isHidden = true
        verticalLine.backgroundColor = UIColor.clear
//        stone = LiveStone(size: cellSize)
//        self.view.addSubview(stone)
//        stone.isHidden = true
        zoomedStone = LiveStone(size: zoomedCellSize)
        zoomedStone.isHidden = true
        view.addSubview(zoomedStone)

        setupView.frame = CGRect(x: 0, y: 0, width: 4 * width / 5, height: 264)
    }

    @objc func boardTouch(gestureReconizer: UILongPressGestureRecognizer) {
        if me != table.currentPlayerName() || table.state.state != .started {
            return
        }
        let currentPoint = gestureReconizer.location(in: board)
//        print(currentPoint)
        var i = 0, j = 0

        if gestureReconizer.state == .began {
            offSet = currentPoint
            if table.isGo() {
//                stone.color = StoneColor(rawValue: 3-table.currentPlayer())!
                if table.state.goState == .markStones {
                    zoomedStone.color = StoneColor.red
                } else {
                    zoomedStone.color = StoneColor(rawValue: 3 - table.currentPlayer())!
                }
            } else {
//                stone.color = StoneColor(rawValue: table.currentPlayer())!
                zoomedStone.color = StoneColor(rawValue: table.currentPlayer())!
            }
//            stone.setNeedsDisplay()
            zoomedStone.setNeedsDisplay()
        }
        zoomedBoard.center = CGPoint(x: offSet.x - zoomFactor * (offSet.x - board.center.x) - (currentPoint.x - offSet.x), y: offSet.y - zoomFactor * (offSet.y - board.center.y) - (currentPoint.y - offSet.y))
        let zoomedPoint = board.convert(currentPoint, to: zoomedBoard)
        i = Int(zoomedPoint.y / zoomedCellSize); j = Int(zoomedPoint.x / zoomedCellSize)
        let zoomedGridPoint = CGPoint(x: CGFloat(j) * zoomedCellSize + zoomedCellSize / 2, y: CGFloat(i) * zoomedCellSize + zoomedCellSize / 2)
        let gridPoint = zoomedBoard.convert(zoomedGridPoint, to: board)
        zoomedStone.center = gridPoint
        var center = horizontalLine.center
        center.y = gridPoint.y
        horizontalLine.center = center
        center = verticalLine.center
        center.x = gridPoint.x
        verticalLine.center = center

//        switch gestureReconizer.state {
//            case .began:
//                print("began")
//                break
//            case .changed:
//                print("changed")
//                break
//            case .ended:
//                print("ended")
//                break
//            default: break
//        }

        let hideBoard = gestureReconizer.state == .ended
        var hideStone = false
        let gridSize = table.gridSize
        if i >= 0 && i < gridSize && j >= 0 && j < gridSize {
            if table.isGo(), table.state.goState == .markStones {
                hideStone = table.abstractBoard[i][j] == 0
            } else {
                hideStone = table.abstractBoard[i][j] != 0
            }
            if hideBoard, !hideStone {
//                stone.isHidden = false
//                stone.center = CGPoint(x: CGFloat(j)*cellSize + cellSize/2, y: CGFloat(i)*cellSize+cellSize/2)
                if !((currentPoint.x <= 0) || (currentPoint.x >= board.bounds.size.width) || (currentPoint.y <= 0) || (currentPoint.y >= board.bounds.size.height)) {
                    sendMove(move: i * gridSize + j)
                }
            } else {
//                stone.isHidden = true
            }
        }
        horizontalLine.isHidden = hideBoard || hideStone
        verticalLine.isHidden = hideBoard || hideStone
        zoomedStone.isHidden = hideBoard || hideStone
        zoomedBoard.isHidden = hideBoard
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func backToMainRoom(sender _: UIBarButtonItem) {
        if table.state.state == GameState.State.started {
            return
        }
        print("leaving table")
        let eventDictionary = ["dsgExitTableEvent": ["forced": false, "table": table.table, "booted": false, "time": 0] as [String: Any]]
        socket.sendEvent(eventDictionary: eventDictionary)
    }

    func disconnected() {
        _ = navigationController?.popViewController(animated: true)
    }

//    override func willMove(toParentViewController parent: UIViewController?) {
//        if table.state.state == GameState.State.started {
//            return
//        }
//        super.willMove(toParentViewController: parent)
//        if parent == nil {
//            // The back button was pressed or interactive gesture used
//            print("leaving table")
//            let eventDictionary = ["dsgExitTableEvent":["forced":false,"table":table.table,"booted":false, "time":0]]
//            socket.sendEvent(eventDictionary: eventDictionary)
//        }
//    }
    override func viewDidAppear(_: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShowHide), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        var bottomOffset: CGFloat = 0
        if UIDevice.current.userInterfaceIdiom == .phone, Int(UIScreen.main.nativeBounds.size.height) == 2436 {
            bottomOffset = 34.0
        }
        var frame = seatsView.frame
        frame.origin.y = frame.origin.y + frame.size.height
        frame.size.height = view.frame.size.height - board.frame.size.height - seatsView.frame.size.height - bottomOffset
        textView.frame = frame
        frame.origin.y = view.frame.size.height
        frame.size.height = 40
        textField.frame = frame
        let backBtn = UIBarButtonItem(title: NSLocalizedString("Exit", comment: ""), style: UIBarButtonItem.Style.plain, target: self, action: #selector(backToMainRoom))
        navigationItem.leftBarButtonItem = backBtn
    }

    override func viewDidDisappear(_: Bool) {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func showSettings() {
        if me == table.owner, table.state.state == .notStarted {
            let popover = PopoverView()
            setupView.reloadData()
            popover.delegate = self
            popover.show(at: CGPoint(x: view.bounds.size.width - 20, y: board.frame.origin.y), in: view, withContentView: setupView)
        }
    }

    func showScore() {
        table.getTerritories()
        board.goDeadStones = table.goDeadStonesByPlayer; zoomedBoard.goDeadStones = table.goDeadStonesByPlayer
        board.goTerritory = table.goTerritoryByPlayer; zoomedBoard.goTerritory = table.goTerritoryByPlayer
        board.setNeedsDisplay(); zoomedBoard.setNeedsDisplay()

        TSMessage.showNotification(in: self, title: "score", subtitle: table.getGoScoreString(), image: nil, type: TSMessageNotificationType.message, duration: TimeInterval(TSMessageNotificationDuration.endless.rawValue), callback: {
            TSMessage.dismissActiveNotification()
            if self.table.state.goState == .play {
                self.board.clearGoStructures(); self.zoomedBoard.clearGoStructures()
                self.board.setNeedsDisplay(); self.zoomedBoard.setNeedsDisplay()
            }
        }, buttonTitle: NSLocalizedString("dismiss", comment: ""), buttonCallback: {
            TSMessage.dismissActiveNotification()
            if self.table.state.goState == .play {
                self.board.clearGoStructures(); self.zoomedBoard.clearGoStructures()
                self.board.setNeedsDisplay(); self.zoomedBoard.setNeedsDisplay()
            }
        }, at: TSMessageNotificationPosition.bottom, canBeDismissedByUser: true)
    }

    @objc func showOptions() {
        if table.state.state == .started, table.amIseated(i: me) {
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

            if table.isGo() {
                let scoreAction = UIAlertAction(title: NSLocalizedString("score Go game", comment: ""), style: .default) { _ in
                    self.showScore()
                }
                alertController.addAction(scoreAction)
            }
            if table.currentPlayerName() != me || (table.state.goState == .markStones && table.currentPlayerName() == me) {
                let undoAction = UIAlertAction(title: NSLocalizedString("request undo", comment: ""), style: .default) { _ in
                    let event = ["dsgUndoRequestTableEvent": ["player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                alertController.addAction(undoAction)
            }
            let cancelAction = UIAlertAction(title: NSLocalizedString("request game/set cancellation", comment: ""), style: .default) { _ in
                let event = ["dsgCancelRequestTableEvent": ["player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(cancelAction)
            let resignAction = UIAlertAction(title: NSLocalizedString("resign game", comment: ""), style: .destructive) { _ in
                let event = ["dsgResignTableEvent": ["player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(resignAction)
            let dismissAction = UIAlertAction(title: NSLocalizedString("dismiss", comment: ""), style: .cancel) { _ in
            }
            alertController.addAction(dismissAction)
            if let popoverController = alertController.popoverPresentationController {
                popoverController.barButtonItem = navigationItem.rightBarButtonItems?[1]
            }
//            self.presentViewController(alertController, animated: true, completion: nil)
            present(alertController, animated: true)
//            print("kitten")
        }
    }

    func popoverViewDidDismiss(_: PopoverView!) {}

    @objc func showPlayersOptions() {
        if table.owner == me {
            let alertController = UIAlertController(title: NSLocalizedString("Options", comment: ""), message: nil, preferredStyle: .alert)
            let inviteAction = UIAlertAction(title: NSLocalizedString("invite player", comment: ""), style: .default) { _ in
                self.showInvitationDialog()
            }
            alertController.addAction(inviteAction)
            let bootAction = UIAlertAction(title: NSLocalizedString("boot player", comment: ""), style: .destructive) { _ in
                self.showBootDialog()
            }
            alertController.addAction(bootAction)
            let viewAction = UIAlertAction(title: NSLocalizedString("view table players", comment: ""), style: .default) { _ in
                self.showTablePlayers()
            }
            let dismissAction = UIAlertAction(title: NSLocalizedString("dismiss", comment: ""), style: .cancel) { _ in
            }
            alertController.addAction(dismissAction)
            alertController.addAction(viewAction)
            if let popoverController = alertController.popoverPresentationController {
                popoverController.barButtonItem = navigationItem.rightBarButtonItems?[1]
            }

            present(alertController, animated: true)
        } else {
            showTablePlayers()
        }
    }

    func showTablePlayers() {
        let popover = PopoverView()
        let playerView = TablePlayers(frame: CGRect(x: 0, y: 0, width: 260, height: view.frame.size.height * 2 / 3), style: .plain)
        playerView.pentePlayer = pentePlayer
        playerView.game = table.game
        playerView.players = Array(table.players.values)
        playerView.delegate = playerView
        playerView.dataSource = playerView
        playerView.layer.borderWidth = 1.0
        playerView.layer.cornerRadius = 1.0
        playerView.reloadData()
        popover.delegate = self
        popover.show(at: CGPoint(x: view.bounds.size.width - 20, y: board.frame.origin.y), in: view, withContentView: playerView)
    }

    func showInvitationDialog() {
        DispatchQueue.main.async {
            self.invitablePlayers = self.tablesAndPlayers.invitablePlayersFor(tableId: self.table.table)
            self.inviteAlertController = UIAlertController(title: NSLocalizedString("invite player", comment: ""), message: nil, preferredStyle: .alert)
            self.inviteAlertController?.addTextField { (textField: UITextField!) in
                textField.placeholder = NSLocalizedString("optional message", comment: "")
            }
            self.inviteAlertController?.addTextField { (textField: UITextField!) in
                textField.placeholder = NSLocalizedString("player", comment: "")
                let playerPicker = UIPickerView()
                let pickerToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 44))
                pickerToolbar.isTranslucent = true
                let extraSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
                let doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: textField, action: #selector(textField.resignFirstResponder)) // method
                pickerToolbar.setItems([extraSpace, doneButton], animated: true)
                playerPicker.delegate = self
                playerPicker.dataSource = self
                playerPicker.tag = 2
                textField.inputView = playerPicker
                textField.tag = 1
                textField.delegate = self
                textField.inputAccessoryView = pickerToolbar
            }
            let sendAction = UIAlertAction(title: NSLocalizedString("send invitation", comment: ""), style: .default) { _ in
                let player = (self.inviteAlertController!.textFields![1] as UITextField).text!
                let message = (self.inviteAlertController!.textFields![0] as UITextField).text!
                if player != "" {
                    let event = ["dsgInviteTableEvent": ["toInvite": player, "inviteText": message, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                    self.socket.sendEvent(eventDictionary: event)
                }
            }
            self.inviteAlertController?.addAction(sendAction)
            let cancelAction = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { _ in
            }
            self.inviteAlertController?.addAction(cancelAction)
            if let popoverController = self.inviteAlertController?.popoverPresentationController {
                popoverController.sourceView = self.playButton
            }
            self.present(self.inviteAlertController!, animated: true)
        }
    }

    func showBootDialog() {
        DispatchQueue.main.async {
            self.invitablePlayers = self.tablesAndPlayers.bootablePlayersFor(tableId: self.table.table)
            self.inviteAlertController = UIAlertController(title: NSLocalizedString("boot player", comment: ""), message: nil, preferredStyle: .alert)
//            self.inviteAlertController?.addTextField { (textField : UITextField!) -> Void in
//                textField.placeholder = NSLocalizedString("optional message", comment: "")
//                textField.isHidden = true
//            }
            self.inviteAlertController?.addTextField { (textField: UITextField!) in
                textField.placeholder = NSLocalizedString("player", comment: "")
                let playerPicker = UIPickerView()
                let pickerToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 44))
                pickerToolbar.isTranslucent = true
                let extraSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
                let doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: textField, action: #selector(textField.resignFirstResponder)) // method
                pickerToolbar.setItems([extraSpace, doneButton], animated: true)
                playerPicker.delegate = self
                playerPicker.dataSource = self
                playerPicker.tag = 2
                textField.inputView = playerPicker
                textField.tag = 1
                textField.delegate = self
                textField.inputAccessoryView = pickerToolbar
            }
            let bootAction = UIAlertAction(title: NSLocalizedString("boot player", comment: ""), style: .destructive) { _ in
                let player = (self.inviteAlertController!.textFields![0] as UITextField).text!
                if player != "" {
                    let event = ["dsgBootTableEvent": ["toBoot": player, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                    self.socket.sendEvent(eventDictionary: event)
                }
            }
            self.inviteAlertController?.addAction(bootAction)
            let cancelAction = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { _ in
            }
            self.inviteAlertController?.addAction(cancelAction)
            if let popoverController = self.inviteAlertController?.popoverPresentationController {
                popoverController.sourceView = self.playButton
            }
            self.present(self.inviteAlertController!, animated: true)
        }
    }

    func sendMove(move: Int) {
        let event = ["dsgMoveTableEvent": ["move": move, "moves": [move], "player": me, "table": table.table, "time": 0] as [String: Any]]
        socket.sendEvent(eventDictionary: event)
    }

    func stateChanged() {
        setupView.reloadData()
        board.backgroundColor = table.gameColor(); zoomedBoard.backgroundColor = table.gameColor()
        board.go = table.isGo(); zoomedBoard.go = table.isGo()
        if table.game == 22 || table.game == 21 {
            table.gridSize = 9
        } else if table.game == 23 || table.game == 24 {
            table.gridSize = 13
        } else {
            table.gridSize = 19
        }
        board.gridSize = table.gridSize; zoomedBoard.gridSize = table.gridSize
        cellSize = CGFloat(view.bounds.width / CGFloat(table.gridSize))
        zoomedCellSize = zoomFactor * cellSize
        zoomedStone.resize(size: zoomedCellSize); zoomedStone.setNeedsDisplay(); board.setNeedsDisplay(); zoomedBoard.setNeedsDisplay()

        if let player = table.seats[1] {
            seatsView.sit(player: player.getNameString(), seat: 1)
        } else {
            seatsView.stand(seat: 1)
        }
        if let player = table.seats[2] {
            seatsView.sit(player: player.getNameString(), seat: 2)
        } else {
            seatsView.stand(seat: 2)
        }
        seatsView.setRatedTimer(rated: table.rated, timed: table.timed, initialMinutes: table.timer["initialMinutes"]!, incrementalSeconds: table.timer["incrementalSeconds"]!)
        if table.isGo(), table.state.state == .started, table.currentPlayerName() == me {
            playButton.isHidden = false; playButton.setTitle(NSLocalizedString("PASS", comment: ""), for: .normal)
        } else {
            playButton.setTitle(NSLocalizedString("PLAY", comment: ""), for: .normal)
            playButton.isHidden = (table.seats.count < 2 || !table.amIseated(i: me)) || (table.state.state != GameState.State.notStarted && table.state.state != GameState.State.halfSet)
        }
        if playButton.isHidden {
            seatsView.ratedTimerLabel.alpha = 1
        } else {
            seatsView.ratedTimerLabel.alpha = 0.3
        }
        seatsView.setTimers(timers: table.state.timers)
        if table.isDPente() {
            if table.seats[2] != nil, me == table.seats[2]?.name, table.moves.count == 4, table.state.dPenteState == .noChoice {
                let alertController = UIAlertController(title: NSLocalizedString("Continue play as", comment: ""), message: nil, preferredStyle: .actionSheet)
                let p1Action = UIAlertAction(title: NSLocalizedString("Player 1 (white)", comment: ""), style: .default) { _ in
                    let event = ["dsgSwapSeatsTableEvent": ["swap": true, "silent": false, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                alertController.addAction(p1Action)
                let p2Action = UIAlertAction(title: NSLocalizedString("Player 2 (black)", comment: ""), style: .default) { _ in
                    let event = ["dsgSwapSeatsTableEvent": ["swap": false, "silent": false, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                alertController.addAction(p2Action)
                if let popoverController = alertController.popoverPresentationController {
                    popoverController.barButtonItem = navigationItem.rightBarButtonItems?[1]
                }
                present(alertController, animated: true)
            }
        }
        if table.isSwap2() {
            if table.isSwap2ChoiceWithPassOption(), table.seats[2] != nil, me == table.seats[2]?.name {
                let alertController = UIAlertController(title: NSLocalizedString("Continue play as", comment: ""), message: nil, preferredStyle: .actionSheet)
                let p1Action = UIAlertAction(title: NSLocalizedString("Player 1 (white)", comment: ""), style: .default) { _ in
                    let event = ["dsgSwapSeatsTableEvent": ["swap": true, "silent": false, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                alertController.addAction(p1Action)
                let p2Action = UIAlertAction(title: NSLocalizedString("Player 2 (black)", comment: ""), style: .default) { _ in
                    let event = ["dsgSwapSeatsTableEvent": ["swap": false, "silent": false, "player": self.me, "table": self.table.table, "time": 0] as [String: Any] as [String: Any]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                alertController.addAction(p2Action)
                let passAction = UIAlertAction(title: NSLocalizedString("Pass Decision", comment: ""), style: .default) { _ in
                    let event = ["dsgSwap2PassTableEvent": ["silent": false, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                alertController.addAction(passAction)
                if let popoverController = alertController.popoverPresentationController {
                    popoverController.barButtonItem = navigationItem.rightBarButtonItems?[1]
                }
                present(alertController, animated: true)
            } else if table.isSwap2ChoiceWithoutPassOption(), table.seats[1] != nil, me == table.seats[1]?.name {
                let alertController = UIAlertController(title: NSLocalizedString("Continue play as", comment: ""), message: nil, preferredStyle: .actionSheet)
                let p1Action = UIAlertAction(title: NSLocalizedString("Player 1 (white)", comment: ""), style: .default) { _ in
                    let event = ["dsgSwapSeatsTableEvent": ["swap": false, "silent": false, "player": self.me, "table": self.table.table, "time": 0] as [String: Any] as [String: Any]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                alertController.addAction(p1Action)
                let p2Action = UIAlertAction(title: NSLocalizedString("Player 2 (black)", comment: ""), style: .default) { _ in
                    let event = ["dsgSwapSeatsTableEvent": ["swap": true, "silent": false, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                alertController.addAction(p2Action)
                if let popoverController = alertController.popoverPresentationController {
                    popoverController.barButtonItem = navigationItem.rightBarButtonItems?[1]
                }
                present(alertController, animated: true)
            }
        }
    }

    func gameStateChanged() {
        if table.state.state == .started {
            var color = 2
            if !table.isGo() {
                if let player = table.seats[1] {
                    if player.name == me {
                        color = 1
                    }
                }
            } else {
                if let player = table.seats[2] {
                    if player.name == me {
                        color = 1
                    }
                }
            }
//            stone.color = StoneColor(rawValue: color)!
            zoomedStone.color = StoneColor(rawValue: color)!
//            stone.setNeedsDisplay()
            if table.state.goState == .play {
                board.clearGoStructures(); zoomedBoard.clearGoStructures()
            }
            zoomedStone.setNeedsDisplay(); board.setNeedsDisplay(); zoomedBoard.setNeedsDisplay()
            if table.timed {
                timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(countDownTimer), userInfo: nil, repeats: true)
            }
            if waitTimer != nil {
                waitTimer?.invalidate()
            }
            if waitAlertController != nil {
                waitAlertController?.dismiss(animated: true, completion: nil)
            }
        } else {
            timer?.invalidate()
            if table.state.state == .paused, table.amIseated(i: me) {
                waitAlertController = UIAlertController(title: NSLocalizedString("Opponent disconnected", comment: ""), message: NSLocalizedString("You can resign the game now or choose to wait. If your opponent does not return in 7 minutes, you can choose to cancel the game, or force resign your opponent", comment: ""), preferredStyle: .actionSheet)

                let resignAction = UIAlertAction(title: NSLocalizedString("resign game", comment: ""), style: .destructive) { _ in
                    let event = ["dsgResignTableEvent": ["player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                waitAlertController?.addAction(resignAction)
                let dismissAction = UIAlertAction(title: NSLocalizedString("dismiss", comment: ""), style: .cancel) { _ in
                    self.waitTimer?.invalidate()
                }
                waitAlertController?.addAction(dismissAction)
                if let popoverController = waitAlertController?.popoverPresentationController {
                    popoverController.barButtonItem = navigationItem.rightBarButtonItems?[1]
                }
                present(waitAlertController!, animated: true)
                waitSeconds = 1 * 60
                waitTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(countDownWait), userInfo: nil, repeats: true)
            }
        }
//        playButton.isHidden = (table.seats.count < 2 || !table.amIseated(i: me)) || (table.state.state != GameState.State.notStarted && table.state.state != GameState.State.halfSet)
//        if playButton.isHidden {
//            seatsView.ratedTimerLabel.alpha = 1
//        } else {
//            seatsView.ratedTimerLabel.alpha = 0.3
//        }
    }

    @objc func countDownWait() {
        waitSeconds = waitSeconds - 1
        if waitSeconds == 0 {
            waitTimer?.invalidate()
            waitAlertController?.dismiss(animated: true, completion: nil)
        }
        let waitMins = waitSeconds / 60
        let waitSecs = waitSeconds % 60
        waitAlertController?.setValue(NSLocalizedString(NSLocalizedString("Opponent disconnected: \(waitMins):\(waitSecs)", comment: ""), comment: ""), forKey: "title")
    }

    func waitingPlayerReturnTimeUp() {
        waitTimer?.invalidate()
        waitAlertController?.dismiss(animated: true, completion: nil)
        waitAlertController = UIAlertController(title: NSLocalizedString("Opponent unavailable", comment: ""), message: NSLocalizedString("You now can choose to resign, cancel the game, or force resign your opponent", comment: ""), preferredStyle: .actionSheet)

        let resignAction = UIAlertAction(title: NSLocalizedString("resign game", comment: ""), style: .destructive) { _ in
            let event = ["dsgResignTableEvent": ["player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
            self.socket.sendEvent(eventDictionary: event)
        }
        waitAlertController?.addAction(resignAction)
        let cancelAction = UIAlertAction(title: NSLocalizedString("cancel game", comment: ""), style: .default) { _ in
            let event = ["dsgForceCancelResignTableEvent": ["action": 1, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
            self.socket.sendEvent(eventDictionary: event)
        }
        waitAlertController?.addAction(cancelAction)
        let forceResignAction = UIAlertAction(title: NSLocalizedString("force resign opponent", comment: ""), style: .destructive) { _ in
            let event = ["dsgForceCancelResignTableEvent": ["action": 2, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
            self.socket.sendEvent(eventDictionary: event)
        }
        waitAlertController?.addAction(forceResignAction)
        let dismissAction = UIAlertAction(title: NSLocalizedString("keep waiting", comment: ""), style: .cancel) { _ in
        }
        waitAlertController?.addAction(dismissAction)

        if let popoverController = waitAlertController?.popoverPresentationController {
            popoverController.barButtonItem = navigationItem.rightBarButtonItems?[1]
        }
        present(waitAlertController!, animated: true)
    }

    func addMove(move: Int) {
        table.addMove(move: move)
        if table.state.goState != .markStones {
            board.clearGoStructures(); zoomedBoard.clearGoStructures()
        }
        board.setNeedsDisplay()
        zoomedBoard.setNeedsDisplay()
//        stone.isHidden = true
        if table.gameHasCaptures() {
            navigationItem.title = "\u{25CF} x \(table.blackCaptures) - \u{25CB} x \(table.whiteCaptures)"
            if #available(iOS 13.0, *) {
                if UITraitCollection.current.userInterfaceStyle == .dark {
                    navigationItem.title = "\u{25CB} x \(table.blackCaptures) - \u{25CF} x \(table.whiteCaptures)"
                }
            }
        } else {
            navigationItem.title = ""
        }
        if table.isGo(), table.state.state == .started, table.currentPlayerName() == me {
            playButton.isHidden = false; playButton.setTitle(NSLocalizedString("PASS", comment: ""), for: .normal)
        } else {
            playButton.isHidden = true
        }
        showGoDialog()
    }

    func addMoves(moves: [Int]) {
        table.addMoves(moves: moves)
        if table.state.goState != .markStones {
            board.clearGoStructures(); zoomedBoard.clearGoStructures()
        }
        //        board.lastMove = move
        //        zoomedBoard.lastMove = move
        board.setNeedsDisplay()
        zoomedBoard.setNeedsDisplay()
//        stone.isHidden = true
        if table.gameHasCaptures() {
            navigationItem.title = "\u{25CF} x \(table.blackCaptures) - \u{25CB} x \(table.whiteCaptures)"
        } else {
            navigationItem.title = ""
        }
        if table.isGo(), table.state.state == .started, table.currentPlayerName() == me {
            playButton.isHidden = false; playButton.setTitle(NSLocalizedString("PASS", comment: ""), for: .normal)
        }
        showGoDialog()
    }

    func rejectDeadStones() {
        table.rejectDeadStones()
        board.clearGoStructures(); zoomedBoard.clearGoStructures()
        board.setNeedsDisplay()
        zoomedBoard.setNeedsDisplay()
        navigationItem.title = "\u{25CF} x \(table.blackCaptures) - \u{25CB} x \(table.whiteCaptures)"
        if table.isGo(), table.state.state == .started, table.currentPlayerName() == me {
            playButton.isHidden = false; playButton.setTitle(NSLocalizedString("PASS", comment: ""), for: .normal)
        } else {
            playButton.isHidden = true
        }
    }

    func showGoDialog() {
//        return
//        print("showGoDialog")
        if table.state.goState == .markStones || table.state.goState == .evaluateStones {
            table.getTerritories()
            board.goDeadStones = table.goDeadStonesByPlayer
            board.goTerritory = table.goTerritoryByPlayer
        }
        if table.showMarkStones(player: me) {
            TSMessage.showNotification(in: self, title: NSLocalizedString("Double pass", comment: ""), subtitle: NSLocalizedString("Your opponent made a pass as well, mark dead stones and end with a pass", comment: ""), image: nil, type: TSMessageNotificationType.message, duration: TimeInterval(TSMessageNotificationDuration.endless.rawValue), callback: {
                TSMessage.dismissActiveNotification()
            }, buttonTitle: NSLocalizedString("dismiss", comment: ""), buttonCallback: {
                TSMessage.dismissActiveNotification()
            }, at: TSMessageNotificationPosition.bottom, canBeDismissedByUser: true)

        } else if table.showEvaluateStones(player: me) {
//            print("showGoDialog evaluate")
            let alertController = UIAlertController(title: NSLocalizedString("Accept score?", comment: ""), message: table.getGoScoreString(), preferredStyle: .alert)

            let acceptAction = UIAlertAction(title: NSLocalizedString("accept", comment: ""), style: .default) { _ in
                self.sendMove(move: self.table.gridSize * self.table.gridSize)
            }
            let rejectAction = UIAlertAction(title: NSLocalizedString("continue play", comment: ""), style: .destructive) { _ in
                let event = ["dsgRejectGoStateEvent": ["player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(acceptAction)
            alertController.addAction(rejectAction)

            if let popoverController = alertController.popoverPresentationController {
                popoverController.sourceView = playButton
            }
            present(alertController, animated: true)
        }
    }

    func requestUndo(player: String) {
        if me != player, table.amIseated(i: me) {
            let alertController = UIAlertController(title: NSLocalizedString("\(player) requested to undo his last move", comment: ""), message: nil, preferredStyle: .alert)

            let p1Action = UIAlertAction(title: NSLocalizedString("accept undo", comment: ""), style: .default) { _ in
                let event = ["dsgUndoReplyTableEvent": ["accepted": true, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(p1Action)
            let p2Action = UIAlertAction(title: NSLocalizedString("deny undo", comment: ""), style: .destructive) { _ in
                let event = ["dsgUndoReplyTableEvent": ["accepted": false, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(p2Action)
            if let popoverController = alertController.popoverPresentationController {
                popoverController.barButtonItem = navigationItem.rightBarButtonItems?[1]
            }
            present(alertController, animated: true)
        }
    }

    func requestUndoReply(player _: String, accepted: Bool) {
        if accepted {
            table.undoLastMove()
            showGoDialog()
            board.setNeedsDisplay()
            zoomedBoard.setNeedsDisplay()
            addText(text: NSLocalizedString("* undo accepted *", comment: ""))
            if table.gameHasCaptures() {
                navigationItem.title = "\u{25CF} x \(table.blackCaptures) - \u{25CB} x \(table.whiteCaptures)"
            } else {
                navigationItem.title = ""
            }
        } else {
            addText(text: NSLocalizedString("* undo denied *", comment: ""))
        }
    }

    func requestCancel(player: String) {
        if me != player, table.amIseated(i: me) {
            let alertController = UIAlertController(title: NSLocalizedString("\(player) is requesting to cancel the game", comment: ""), message: nil, preferredStyle: .actionSheet)

            let acceptAction = UIAlertAction(title: NSLocalizedString("accept", comment: ""), style: .default) { _ in
                let event = ["dsgCancelReplyTableEvent": ["accepted": true, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(acceptAction)
            let declineAction = UIAlertAction(title: NSLocalizedString("decline", comment: ""), style: .destructive) { _ in
                let event = ["dsgCancelReplyTableEvent": ["accepted": false, "player": self.me, "table": self.table.table, "time": 0] as [String: Any]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(declineAction)
            if let popoverController = alertController.popoverPresentationController {
                popoverController.barButtonItem = navigationItem.rightBarButtonItems?[1]
            }
            present(alertController, animated: true)
        }
    }

    @objc func countDownTimer() {
        if !table.shouldTimerRun() {
            return
        }
        var seat = table.currentPlayer()
        if table.game == 7 || table.game == 8 || table.game == 17 || table.game == 18 {
            if table.moves.count < 4 {
                seat = 1
            } else if table.moves.count == 4, table.state.dPenteState == .noChoice {
                seat = 2
            }
        }

        var timers = table.state.timers
        let seatTimer = timers[seat]!
        let millis = seatTimer["millis"]
        var startTime = seatTimer["startTime"] ?? 0
        if startTime == 0 {
            startTime = Int(Date().timeIntervalSince1970 * 1000)
            table.state.timers[seat]!.updateValue(startTime, forKey: "startTime")
        }
        let millisElapsed = Int(Date().timeIntervalSince1970 * 1000) - startTime
        var millisLeft = millis! - millisElapsed
        if millisLeft <= 0 {
            millisLeft = 0
            timer?.invalidate()
            table.state.timers[seat]!.updateValue(0, forKey: "startTime")
        }
        timers[seat]!.updateValue(millisLeft, forKey: "millis")
        seatsView.setTimers(timers: timers)
    }

    @objc func sitStand(sender: UITapGestureRecognizer) {
        let seat = sender.view!.tag
        var event: [String: Any]
        event = ["dsgStandTableEvent": ["table": table.table, "time": 0]]
        if table.seats[seat] != nil {
        } else {
            event = ["dsgSitTableEvent": ["seat": seat, "table": table.table, "time": 0]]
        }
        socket.sendEvent(eventDictionary: event)
    }

    @objc func play() {
        if table.isGo(), table.state.state == .started, table.currentPlayerName() == me {
            sendMove(move: table.gridSize * table.gridSize)
        } else {
            socket.sendEvent(eventDictionary: ["dsgPlayTableEvent": ["table": table.table, "time": 0]])
            playButton.isHidden = true
            table.resetTimers()
        }
    }

    func tableExitEvent(event: [String: Any]) {
        let playerName = event["player"] as! String
        addText(text: NSLocalizedString("\(playerName) has left the table", comment: ""))
        if playerName == me {
            _ = navigationController?.popViewController(animated: true)
        }
    }

    func tableJoinEvent(event: [String: Any]) {
        let playerName = event["player"] as! String
        addText(text: NSLocalizedString("\(playerName) has joined the table", comment: ""))
    }

    func bootEvent(player: String, by: String) {
        if by != me {
            addText(text: NSLocalizedString("\(player) was booted from this table by \(by) and cannot return for 5 minutes", comment: ""))
        }
    }

    func addText(text: String) {
        textView.text = "\(textView.text!)\(text)\n"
        textView.scrollRangeToVisible(NSRange(location: textView.text.count - 1, length: 1))
    }

    @objc func enterText() {
        textField.text = ""
        textField.becomeFirstResponder()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if textField.text! != "" {
            let eventDictionary = ["dsgTextTableEvent": ["text": textField.text!, "table": table.table, "time": 0] as [String: Any]]
            socket.sendEvent(eventDictionary: eventDictionary)
        }
        return false
    }

    @objc func keyboardWillShowHide(notification: NSNotification) {
        if inviteAlertController != nil, (inviteAlertController?.isBeingPresented)! {
            return
        }
        if invitationAlertController != nil, (invitationAlertController?.isBeingPresented)! {
            return
        }
        if setupView.gameCell != nil, (setupView.gameCell?.textField.isFirstResponder)! {
            return
        }
        if setupView.initialMinutesCell != nil, (setupView.initialMinutesCell?.textField.isFirstResponder)! {
            return
        }
        if setupView.incrementalSecondsCell != nil, (setupView.incrementalSecondsCell?.textField.isFirstResponder)! {
            return
        }
        var bottomOffset: CGFloat = 0
        if UIDevice.current.userInterfaceIdiom == .phone, Int(UIScreen.main.nativeBounds.size.height) == 2436 {
            bottomOffset = 34.0
        }
        let info = notification.userInfo
        var keyboardHeight: CGFloat = 0.0
        if (info?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.origin.y == view.frame.origin.y + view.bounds.size.height {
            keyboardHeight = 0
        } else {
            keyboardHeight = ((info?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)!
        }
        //        print("keyboardWillShowHide \(keyboardHeight)")
        var frame = textView.frame
        if keyboardHeight == 0 {
            frame.origin.y = board.frame.origin.y + board.frame.size.height + seatsView.frame.height
        } else {
            frame.origin.y = view.frame.height - keyboardHeight - frame.height - textField.frame.height + bottomOffset
        }
        textView.frame = frame
        frame = textField.frame
        if keyboardHeight == 0 {
            frame.origin.y = view.frame.height
        } else {
            frame.origin.y = view.frame.height - keyboardHeight - frame.height
        }
        textField.frame = frame
    }

    func numberOfComponents(in _: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_: UIPickerView, numberOfRowsInComponent _: Int) -> Int {
        return invitablePlayers.count
    }

    func pickerView(_: UIPickerView, attributedTitleForRow row: Int, forComponent _: Int) -> NSAttributedString? {
        let player = tablesAndPlayers.player(name: invitablePlayers[row])
        return player?.getNameString()
    }

    func pickerView(_: UIPickerView, didSelectRow row: Int, inComponent _: Int) {
        if row < (invitablePlayers.count), row >= 0 {
            var textField = inviteAlertController!.textFields![0] as UITextField?
            if textField != nil, textField!.tag == 1 {
                textField!.text = invitablePlayers[row]
            } else {
                textField = inviteAlertController!.textFields![1] as UITextField?
                if textField != nil, textField!.tag == 1 {
                    textField!.text = invitablePlayers[row]
                }
            }
        }
    }
}
