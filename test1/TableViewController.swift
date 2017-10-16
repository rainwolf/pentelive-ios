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


class TableViewController: UIViewController, UITextFieldDelegate, GADBannerViewDelegate, GADInterstitialDelegate, UIGestureRecognizerDelegate, PopoverViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var socket: PenteLiveSocket!
    var table: Table!
    let board: LiveBoard!
    let zoomedBoard: LiveBoard!
    var textView: UITextView = UITextView()
    var textField = UITextField()
    let me = UserDefaults.standard.string(forKey: "username")!.lowercased()
    var showAds = true
    var bannerView: GADBannerView?
    var seatsView: SeatsView!
    let playButton = UIButton()
    var timer, waitTimer: Timer?
    var waitSeconds: Int = 7*60
    var cellSize: CGFloat = 0
    var zoomFactor: CGFloat = 3
    var stone: LiveStone!
    var zoomedStone: LiveStone!
    let horizontalLine = LiveHorizontalLine()
    let verticalLine = LiveVerticalLine()
    var zoomedCellSize:CGFloat = 0
    var offSet: CGPoint!
    var setupView: TableSetupView
    
    var waitAlertController, invitationAlertController, inviteAlertController: UIAlertController?
    var tablesAndPlayers: TablesAndPlayer!
    var invitablePlayers: [String]!
    var pentePlayer: PentePlayer!
    
    
    init(table: Table, socket: PenteLiveSocket, tablesAndPlayers: TablesAndPlayer) {
        self.table = table
        self.socket = socket
        self.board = LiveBoard(table: table)
        self.zoomedBoard = LiveBoard(table: table)
        self.setupView = TableSetupView(table: table, socket: socket)
        self.tablesAndPlayers = tablesAndPlayers
        super.init(nibName: nil, bundle: nil)
        edgesForExtendedLayout = []
        textView.layer.borderWidth = 2.0
        textView.layer.cornerRadius = 2.0
        textView.isEditable = false
        textView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(enterText)))
        self.view.addSubview(textView)
        textField.delegate = self
        textField.layer.borderWidth = 1.0
        textField.layer.cornerRadius = 1.0
        textField.returnKeyType = .send
        textField.backgroundColor = UIColor.white
        self.view.addSubview(textField)
        playButton.setTitle(NSLocalizedString("play", comment: ""), for: .normal)
        playButton.titleLabel?.font = UIFont.boldSystemFont(ofSize:25)
        playButton.setTitleColor(UIColor.blue, for: .normal)
        playButton.addTarget(self, action: #selector(play), for: .touchUpInside)
        var button = UIButton(type: .custom)
        button.setImage(UIImage(named: "gamesettings"), for: .normal)
        button.addTarget(self, action:#selector(showSettings), for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        let settingsItem = UIBarButtonItem(customView: button)
//        if #available(iOS 9.0, *) {
//            let widthConstraint = button.widthAnchor.constraint(equalToConstant: 32)
//            let heightConstraint = button.heightAnchor.constraint(equalToConstant: 32)
//            heightConstraint.isActive = true
//            widthConstraint.isActive = true
//        }
        button = UIButton(type: .custom)
        button.setImage(UIImage(named: "cancel"), for: .normal)
        button.addTarget(self, action:#selector(showOptions), for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        let optionsItem = UIBarButtonItem(customView: button)
        button = UIButton(type: .custom)
        button.setImage(UIImage(named: "onlineUsers"), for: .normal)
        button.addTarget(self, action:#selector(showPlayersOptions), for: .touchUpInside)
        button.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        let onlineUsersItem = UIBarButtonItem(image: UIImage(named: "onlineUsers"), style: .plain, target: self, action: #selector(showPlayersOptions))
        self.navigationItem.setRightBarButtonItems([settingsItem,
                                                    optionsItem,
                                                    onlineUsersItem], animated: true)
    }
    required init(coder aDecoder: NSCoder) {
        self.board = LiveBoard(table: Table(table: -1))
        self.zoomedBoard = LiveBoard(table: Table(table: -1))
        self.setupView = TableSetupView(coder: aDecoder)
        self.tablesAndPlayers = TablesAndPlayer()
        super.init(coder: aDecoder)!
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        let width = self.view.frame.width
        board.frame = CGRect(x: 0, y: 0, width: width, height: width)
        cellSize = CGFloat(width/19)
        zoomedCellSize = zoomFactor*cellSize
        self.view.addSubview(board)
        zoomedBoard.frame = CGRect(x: 0, y: 0, width: zoomFactor*width, height: zoomFactor*width)
        self.view.addSubview(zoomedBoard)
        zoomedBoard.isHidden = true
        var frame = self.view.frame
        frame.origin.y = board.frame.origin.y + board.frame.size.height
        frame.size.height = 44
        seatsView = SeatsView(frame: frame)
        self.view.addSubview(seatsView)
        seatsView.seat1Label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(sitStand(sender:))))
        seatsView.seat2Label.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(sitStand(sender:))))
        frame = playButton.frame
        frame = seatsView.ratedTimerLabel.frame
        frame.origin.y = seatsView.frame.origin.y
        playButton.frame = frame
        playButton.isHidden = true
        self.view.addSubview(playButton)
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(boardTouch(gestureReconizer:)))
//        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.boardTouch))
        gestureRecognizer.minimumPressDuration = 0.05
        gestureRecognizer.delaysTouchesBegan = true
        gestureRecognizer.delegate = self
        board.addGestureRecognizer(gestureRecognizer)
        horizontalLine.frame = CGRect(x: 0, y: 0, width: width, height: 10)
        horizontalLine.center = board.center
        horizontalLine.backgroundColor = UIColor.clear
        self.view.addSubview(horizontalLine)
        horizontalLine.isHidden = true
        verticalLine.frame = CGRect(x: 0, y: 0, width: 10, height: width)
        verticalLine.center = board.center
        self.view.addSubview(verticalLine)
        verticalLine.isHidden = true
        verticalLine.backgroundColor = UIColor.clear
        stone = LiveStone(size: cellSize)
        self.view.addSubview(stone)
        stone.isHidden = true
        zoomedStone = LiveStone(size: zoomedCellSize)
        zoomedStone.isHidden = true
        self.view.addSubview(zoomedStone)
        
        setupView.frame = CGRect(x: 0, y: 0, width: 4*width/5, height: 264)
        
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
            stone.color = table.currentPlayer()
            stone.setNeedsDisplay()
            zoomedStone.color = table.currentPlayer()
            zoomedStone.setNeedsDisplay()
        }
        zoomedBoard.center = CGPoint(x: offSet.x - zoomFactor*(offSet.x - board.center.x)-(currentPoint.x-offSet.x), y: offSet.y - zoomFactor*(offSet.y - board.center.y)-(currentPoint.y-offSet.y))
        let zoomedPoint = board.convert(currentPoint, to: zoomedBoard)
        i = Int(zoomedPoint.y/zoomedCellSize); j = Int(zoomedPoint.x/zoomedCellSize)
        let zoomedGridPoint = CGPoint(x: CGFloat(j)*zoomedCellSize + zoomedCellSize/2, y: CGFloat(i)*zoomedCellSize+zoomedCellSize/2)
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
        
        let hideBoard = ((currentPoint.x <= 0) || (currentPoint.x >= self.board.bounds.size.width) || (currentPoint.y <= 0) || (currentPoint.y >= self.board.bounds.size.height)) || gestureReconizer.state == .ended
        var hideStone = false
        if 0 <= i && i<19 && 0 <= j && j<19 {
            hideStone = table.abstractBoard[i][j] != 0
            if hideBoard && !hideStone {
                stone.isHidden = false
                stone.center = CGPoint(x: CGFloat(j)*cellSize + cellSize/2, y: CGFloat(i)*cellSize+cellSize/2)
                sendMove(move: i*19 + j)
            } else {
                stone.isHidden = true
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
    @objc func backToMainRoom(sender: UIBarButtonItem) {
        if table.state.state == GameState.State.started {
            return
        }
        print("leaving table")
        let eventDictionary = ["dsgExitTableEvent":["forced":false,"table":table.table,"booted":false, "time":0]]
        socket.sendEvent(eventDictionary: eventDictionary)
    }
    func disconnected() {
        let _ = self.navigationController?.popViewController(animated: true)
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
    override func viewDidAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShowHide), name:NSNotification.Name.UIKeyboardWillChangeFrame, object: nil);
        var frame = seatsView.frame
        frame.origin.y = frame.origin.y + frame.size.height
        frame.size.height = self.view.frame.size.height - board.frame.size.height - seatsView.frame.size.height
        textView.frame = frame
        frame.origin.y = frame.origin.y + frame.size.height
        frame.size.height = 40
        textField.frame = frame
        showAds = (self.navigationController as! PenteNavigationViewController).player.showAds
//        showAds = true
        if showAds && bannerView == nil {
            bannerView = GADBannerView(adSize: kGADAdSizeBanner)
            bannerView!.rootViewController = self
            bannerView!.delegate = self
            frame = textView.frame
            frame.size.height = frame.size.height - bannerView!.frame.size.height
            textView.frame = frame
            frame = bannerView!.frame
            frame.origin.y = textView.frame.origin.y + textView.frame.size.height
            bannerView!.frame = frame
            bannerView!.adUnitID = "ca-app-pub-3326997956703582/2339127047"
            let request = GADRequest()
//            request.testDevices = [ kGADSimulatorID ]
            bannerView!.load(request)
            self.view.addSubview(bannerView!)
            
//            interstitial = GADInterstitial(adUnitID: "ca-app-pub-3326997956703582/8025733844")
//            interstitial!.delegate = self
//            request = GADRequest()
//            request.testDevices = [ kGADSimulatorID ]
//            interstitial!.load(request)
        }
        let backBtn = UIBarButtonItem(title: NSLocalizedString("Exit", comment: ""), style: UIBarButtonItemStyle.plain, target: self, action: #selector(backToMainRoom))
        self.navigationItem.leftBarButtonItem = backBtn
    }
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func showSettings() {
        if me == table.owner && table.state.state == .notStarted {
            let popover = PopoverView()
            setupView.reloadData()
            popover.delegate = self
            popover.show(at: CGPoint(x: self.view.bounds.size.width - 20, y: board.frame.origin.y), in: self.view, withContentView: setupView)
        }
    }
    
    @objc func showOptions() {
        if table.state.state == .started && table.amIseated(i: me) {
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            if table.currentPlayerName() != me {
                let undoAction = UIAlertAction(title: NSLocalizedString("request undo", comment: ""), style: .default) { (action) in
                    let event = ["dsgUndoRequestTableEvent":["player":self.me,"table":self.table.table,"time":0]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                alertController.addAction(undoAction)
            }
            let cancelAction = UIAlertAction(title: NSLocalizedString("request game/set cancellation", comment: ""), style: .default) { (action) in
                let event = ["dsgCancelRequestTableEvent":["player":self.me,"table":self.table.table,"time":0]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(cancelAction)
            let resignAction = UIAlertAction(title: NSLocalizedString("resign game", comment: ""), style: .destructive) { (action) in
                let event = ["dsgResignTableEvent":["player":self.me,"table":self.table.table,"time":0]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(resignAction)
            let dismissAction = UIAlertAction(title: NSLocalizedString("dismiss", comment: ""), style: .cancel) { (action) in
            }
            alertController.addAction(dismissAction)
            if let popoverController = alertController.popoverPresentationController {
                popoverController.barButtonItem = self.navigationItem.rightBarButtonItems?[1]
            }
//            self.presentViewController(alertController, animated: true, completion: nil)
            self.present(alertController, animated: true)
//            print("kitten")
        }
    }
    
    func popoverViewDidDismiss(_ popoverView: PopoverView!) {
        
    }
    
    @objc func showPlayersOptions() {
        
        if table.owner == me {
            let alertController = UIAlertController(title: NSLocalizedString("Options", comment: ""), message: nil, preferredStyle: .alert)
            let inviteAction = UIAlertAction(title: NSLocalizedString("invite player", comment: ""), style: .default) { (action) in
                self.showInvitationDialog()
            }
            alertController.addAction(inviteAction)
            let bootAction = UIAlertAction(title: NSLocalizedString("boot player", comment: ""), style: .destructive) { (action) in
                self.showBootDialog()
            }
            alertController.addAction(bootAction)
            let viewAction = UIAlertAction(title: NSLocalizedString("view table players", comment: ""), style: .default) { (action) in
                self.showTablePlayers()
            }
            let dismissAction = UIAlertAction(title: NSLocalizedString("dismiss", comment: ""), style: .cancel) { (action) in
            }
            alertController.addAction(dismissAction)
            alertController.addAction(viewAction)

            self.present(alertController, animated: true)
        } else {
            self.showTablePlayers()
        }
    }
    
    func showTablePlayers() {
        let popover = PopoverView()
        let playerView = TablePlayers(frame: CGRect(x: 0, y: 0, width: 260, height: self.view.frame.size.height*2/3), style: .plain)
        playerView.pentePlayer = self.pentePlayer
        playerView.game = table.game
        playerView.players = Array(table.players.values)
        playerView.delegate = playerView
        playerView.dataSource = playerView
        playerView.layer.borderWidth = 1.0
        playerView.layer.cornerRadius = 1.0
        playerView.reloadData()
        popover.delegate = self
        popover.show(at: CGPoint(x: self.view.bounds.size.width - 20, y: board.frame.origin.y), in: self.view, withContentView: playerView)
    }

    
    func showInvitationDialog() {
        DispatchQueue.main.async {
            self.invitablePlayers = self.tablesAndPlayers.invitablePlayersFor(tableId: self.table.table)
            self.inviteAlertController = UIAlertController(title: NSLocalizedString("invite player", comment: ""), message: nil, preferredStyle: .alert)
            self.inviteAlertController?.addTextField { (textField : UITextField!) -> Void in
                textField.placeholder = NSLocalizedString("optional message", comment: "")
            }
            self.inviteAlertController?.addTextField { (textField : UITextField!) -> Void in
                textField.placeholder = NSLocalizedString("player", comment: "")
                let playerPicker = UIPickerView()
                let pickerToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 44))
                pickerToolbar.barStyle = .blackTranslucent
                let extraSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target:nil, action:nil)
                let doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: textField, action: #selector(textField.resignFirstResponder)) // method
                pickerToolbar.setItems([extraSpace, doneButton], animated: true)
                playerPicker.delegate = self
                playerPicker.dataSource = self
                playerPicker.tag = 2
                textField.inputView = playerPicker
                textField.tag = 1;
                textField.delegate = self
                textField.inputAccessoryView = pickerToolbar
            }
            let sendAction = UIAlertAction(title: NSLocalizedString("send invitation", comment: ""), style: .default) { (action) in
                let player = (self.inviteAlertController!.textFields![1] as UITextField).text!
                let message = (self.inviteAlertController!.textFields![0] as UITextField).text!
                if player != "" {
                    let event = ["dsgInviteTableEvent":["toInvite":player,"inviteText":message,"player":self.me,"table":self.table.table,"time":0]]
                    self.socket.sendEvent(eventDictionary: event)
                }
            }
            self.inviteAlertController?.addAction(sendAction)
            let cancelAction = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { (action) in
            }
            self.inviteAlertController?.addAction(cancelAction)
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
            self.inviteAlertController?.addTextField { (textField : UITextField!) -> Void in
                textField.placeholder = NSLocalizedString("player", comment: "")
                let playerPicker = UIPickerView()
                let pickerToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 44))
                pickerToolbar.barStyle = .blackTranslucent
                let extraSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target:nil, action:nil)
                let doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: textField, action: #selector(textField.resignFirstResponder)) // method
                pickerToolbar.setItems([extraSpace, doneButton], animated: true)
                playerPicker.delegate = self
                playerPicker.dataSource = self
                playerPicker.tag = 2
                textField.inputView = playerPicker
                textField.tag = 1;
                textField.delegate = self
                textField.inputAccessoryView = pickerToolbar
            }
            let bootAction = UIAlertAction(title: NSLocalizedString("boot player", comment: ""), style: .destructive) { (action) in
                let player = (self.inviteAlertController!.textFields![0] as UITextField).text!
                if player != "" {
                    let event = ["dsgBootTableEvent":["toBoot":player,"player":self.me,"table":self.table.table,"time":0]]
                    self.socket.sendEvent(eventDictionary: event)
                }
            }
            self.inviteAlertController?.addAction(bootAction)
            let cancelAction = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { (action) in
            }
            self.inviteAlertController?.addAction(cancelAction)
            self.present(self.inviteAlertController!, animated: true)
        }
    }

    func sendMove(move: Int) {
        let event = ["dsgMoveTableEvent":["move":move,"moves":[move],"player":me,"table":table.table,"time":0]]
        socket.sendEvent(eventDictionary: event)
    }

    func stateChanged () {
        setupView.reloadData()
        board.backgroundColor = table.gameColor()
        zoomedBoard.backgroundColor = table.gameColor()
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
        seatsView.setRatedTimer(rated: table.rated, initialMinutes: table.timer["initialMinutes"]!, incrementalSeconds: table.timer["incrementalSeconds"]!)
        playButton.isHidden = (table.seats.count < 2 || !table.amIseated(i: me)) || (table.state.state != GameState.State.notStarted && table.state.state != GameState.State.halfSet)
        if playButton.isHidden {
            seatsView.ratedTimerLabel.alpha = 1
        } else {
            seatsView.ratedTimerLabel.alpha = 0.3
        }
        seatsView.setTimers(timers: table.state.timers)
        if table.game == 7 || table.game == 8 || table.game == 17 || table.game == 18 {
            if table.seats[2] != nil && me == table.seats[2]?.name && table.moves.count == 4 && table.state.dPenteState == .noChoice {
                let alertController = UIAlertController(title: NSLocalizedString("Continue play as", comment: ""), message: nil, preferredStyle: .actionSheet)
                
                let p1Action = UIAlertAction(title: NSLocalizedString("Player 1 (white)", comment: ""), style: .default) { (action) in
                    let event = ["dsgSwapSeatsTableEvent":["swap":true,"silent":false,"player":self.me,"table":self.table.table,"time":0]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                alertController.addAction(p1Action)
                let p2Action = UIAlertAction(title: NSLocalizedString("Player 2 (black)", comment: ""), style: .default) { (action) in
                    let event = ["dsgSwapSeatsTableEvent":["swap":false,"silent":false,"player":self.me,"table":self.table.table,"time":0]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                alertController.addAction(p2Action)
                if let popoverController = alertController.popoverPresentationController {
                    popoverController.barButtonItem = self.navigationItem.rightBarButtonItems?[1]
                }
                self.present(alertController, animated: true)
            }
        }
    }
    func gameStateChanged() {
        if table.state.state == .started {
            var color = 2
            if let player = table.seats[1]  {
//                print(player.name)
//                print(me)
                if player.name == me {
                    color = 1
                }
            }
            stone.color = color
            zoomedStone.color = color
            stone.setNeedsDisplay()
            zoomedStone.setNeedsDisplay()
            board.setNeedsDisplay()
            zoomedBoard.setNeedsDisplay()
            if table.timed {
                timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(countDownTimer), userInfo: nil, repeats: true)
            }
            if waitTimer != nil {
                waitTimer?.invalidate()
            }
            if waitAlertController != nil {
                waitAlertController?.dismiss(animated: true, completion: nil)
            }
        } else {
            timer?.invalidate()
            if table.state.state == .paused && table.amIseated(i: me) {
                waitAlertController = UIAlertController(title: NSLocalizedString("Opponent disconnected", comment: ""), message: NSLocalizedString("You can resign the game now or choose to wait. If your opponent does not return in 7 minutes, you can choose to cancel the game, or force resign your opponent", comment: ""), preferredStyle: .actionSheet)

                let resignAction = UIAlertAction(title: NSLocalizedString("resign game", comment: ""), style: .destructive) { (action) in
                    let event = ["dsgResignTableEvent":["player":self.me,"table":self.table.table,"time":0]]
                    self.socket.sendEvent(eventDictionary: event)
                }
                waitAlertController?.addAction(resignAction)
                let dismissAction = UIAlertAction(title: NSLocalizedString("dismiss", comment: ""), style: .cancel) { (action) in
                    self.waitTimer?.invalidate()
                }
                waitAlertController?.addAction(dismissAction)
                if let popoverController = waitAlertController?.popoverPresentationController {
                    popoverController.barButtonItem = self.navigationItem.rightBarButtonItems?[1]
                }
                self.present(waitAlertController!, animated: true)
                waitSeconds = 7*60
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
        
        let resignAction = UIAlertAction(title: NSLocalizedString("resign game", comment: ""), style: .destructive) { (action) in
            let event = ["dsgResignTableEvent":["player":self.me,"table":self.table.table,"time":0]]
            self.socket.sendEvent(eventDictionary: event)
        }
        waitAlertController?.addAction(resignAction)
        let cancelAction = UIAlertAction(title: NSLocalizedString("cancel game", comment: ""), style: .default) { (action) in
            let event = ["dsgForceCancelResignTableEvent":["action":1,"player":self.me,"table":self.table.table,"time":0]]
            self.socket.sendEvent(eventDictionary: event)
        }
        waitAlertController?.addAction(cancelAction)
        let forceResignAction = UIAlertAction(title: NSLocalizedString("force resign opponent", comment: ""), style: .destructive) { (action) in
            let event = ["dsgForceCancelResignTableEvent":["action":2,"player":self.me,"table":self.table.table,"time":0]]
            self.socket.sendEvent(eventDictionary: event)
        }
        waitAlertController?.addAction(forceResignAction)
        let dismissAction = UIAlertAction(title: NSLocalizedString("keep waiting", comment: ""), style: .cancel) { (action) in
        }
        waitAlertController?.addAction(dismissAction)

        if let popoverController = waitAlertController?.popoverPresentationController {
            popoverController.barButtonItem = self.navigationItem.rightBarButtonItems?[1]
        }
        self.present(waitAlertController!, animated: true)
    }
    func addMove(move: Int) {
        table.addMove(move: move)
//        board.lastMove = move
//        zoomedBoard.lastMove = move
        board.setNeedsDisplay()
        zoomedBoard.setNeedsDisplay()
        stone.isHidden = true
        if table.gameHasCaptures() {
            self.navigationItem.title = "\u{25CF} x \(table.blackCaptures) - \u{25CB} x \(table.whiteCaptures)"
        } else {
            self.navigationItem.title = ""
        }
    }
    func requestUndo(player: String) {
        if me != player && table.amIseated(i: me) {
            let alertController = UIAlertController(title: NSLocalizedString("\(player) requested to undo his last move", comment: ""), message: nil, preferredStyle: .actionSheet)
            
            let p1Action = UIAlertAction(title: NSLocalizedString("accept undo", comment: ""), style: .default) { (action) in
                let event = ["dsgUndoReplyTableEvent":["accepted":true,"player":self.me,"table":self.table.table,"time":0]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(p1Action)
            let p2Action = UIAlertAction(title: NSLocalizedString("deny undo", comment: ""), style: .destructive) { (action) in
                let event = ["dsgUndoReplyTableEvent":["accepted":false,"player":self.me,"table":self.table.table,"time":0]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(p2Action)
            if let popoverController = alertController.popoverPresentationController {
                popoverController.barButtonItem = self.navigationItem.rightBarButtonItems?[1]
            }
            self.present(alertController, animated: true)
        }
    }
    func requestUndoReply(player: String, accepted: Bool) {
        if accepted {
            table.undoLastMove()
            board.setNeedsDisplay()
            zoomedBoard.setNeedsDisplay()
            addText(text: NSLocalizedString("* undo accepted *", comment: ""))
        } else {
            addText(text: NSLocalizedString("* undo denied *", comment: ""))
        }
    }
    func requestCancel(player: String) {
        if me != player && table.amIseated(i: me) {
            let alertController = UIAlertController(title: NSLocalizedString("\(player) is requesting to cancel the game", comment: ""), message: nil, preferredStyle: .actionSheet)
            
            let acceptAction = UIAlertAction(title: NSLocalizedString("accept", comment: ""), style: .default) { (action) in
                let event = ["dsgCancelReplyTableEvent":["accepted":true,"player":self.me,"table":self.table.table,"time":0]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(acceptAction)
            let declineAction = UIAlertAction(title: NSLocalizedString("decline", comment: ""), style: .destructive) { (action) in
                let event = ["dsgCancelReplyTableEvent":["accepted":false,"player":self.me,"table":self.table.table,"time":0]]
                self.socket.sendEvent(eventDictionary: event)
            }
            alertController.addAction(declineAction)
            if let popoverController = alertController.popoverPresentationController {
                popoverController.barButtonItem = self.navigationItem.rightBarButtonItems?[1]
            }
            self.present(alertController, animated: true)
        }
    }

    @objc func countDownTimer() {
        var seat = table.currentPlayer()
        if (table.game == 7 || table.game == 8 || table.game == 17 || table.game == 18) {
            if table.moves.count < 4 {
                seat = 1
            } else if table.moves.count == 4 && table.state.dPenteState == .noChoice {
                seat = 2
            }
        }

        let minutes = table.state.timers[seat]!["minutes"]
        let seconds = table.state.timers[seat]!["seconds"]
        if seconds == 0 {
            if minutes == 0 {
                timer?.invalidate()
            } else {
                table.state.timers[seat]!.updateValue(59, forKey: "seconds")
                table.state.timers[seat]!.updateValue(minutes! - 1, forKey: "minutes")
            }
        } else {
            table.state.timers[seat]!.updateValue(seconds! - 1, forKey: "seconds")
        }
        seatsView.setTimers(timers: table.state.timers)
        
    }
    @objc func sitStand(sender: UITapGestureRecognizer) {
        let seat = sender.view!.tag
        var event: [String:Any]
            event = ["dsgStandTableEvent":["table":table.table,"time":0]]
        if table.seats[seat] != nil {
        } else {
            event = ["dsgSitTableEvent":["seat":seat,"table":table.table,"time":0]]
        }
        socket.sendEvent(eventDictionary: event)
    }
    
    @objc func play() {
        socket.sendEvent(eventDictionary: ["dsgPlayTableEvent":["table":table.table,"time":0]])
        playButton.isHidden = true
        table.resetTimers()
    }
    func tableExitEvent(event: [String:Any]) {
        let playerName = event["player"] as! String
        addText(text: NSLocalizedString("\(playerName) has left the table", comment: ""))
        if playerName == me {
            let _ = self.navigationController?.popViewController(animated: true)
        }
    }
    func tableJoinEvent(event: [String:Any]) {
        let playerName = event["player"] as! String
        addText(text: NSLocalizedString("\(playerName) has joined the table", comment: ""))
    }
    func bootEvent(player: String, by: String) {
        if by != self.me {
            self.addText(text: NSLocalizedString("\(player) was booted from this table by \(by) and cannot return for 5 minutes", comment: ""))
        }
    }
    func addText(text: String) {
        self.textView.text = "\(self.textView.text!)\(text)\n"
        self.textView.scrollRangeToVisible(NSRange(location: self.textView.text.characters.count - 1, length: 1))
    }
    @objc func enterText() {
        textField.text = ""
        textField.becomeFirstResponder()
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if textField.text! != "" {
            let eventDictionary = ["dsgTextTableEvent":["text":textField.text!,"table":table.table, "time":0]]
            socket.sendEvent(eventDictionary: eventDictionary)
        }
        return false
    }
    @objc func keyboardWillShowHide(notification: NSNotification) {
        if self.inviteAlertController != nil && (self.inviteAlertController?.isBeingPresented)! {
            return
        }
        if self.invitationAlertController != nil && (self.invitationAlertController?.isBeingPresented)! {
            return
        }
        if setupView.gameCell != nil && (setupView.gameCell?.textField.isFirstResponder)! {
            return
        }
        if setupView.initialMinutesCell != nil && (setupView.initialMinutesCell?.textField.isFirstResponder)! {
            return
        }
        if setupView.incrementalSecondsCell != nil && (setupView.incrementalSecondsCell?.textField.isFirstResponder)! {
            return
        }
        let info = notification.userInfo
        var keyboardHeight: CGFloat = 0.0
        if (info?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.origin.y == self.view.frame.origin.y + self.view.bounds.size.height {
            keyboardHeight = 0
        } else {
            keyboardHeight = ((info?[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)!
        }
        //        print("keyboardWillShowHide \(keyboardHeight)")
        var frame = textView.frame
        if keyboardHeight == 0 {
            frame.origin.y = board.frame.origin.y + board.frame.size.height + seatsView.frame.height
        } else {
            frame.origin.y = self.view.frame.height - keyboardHeight - frame.height - textField.frame.height
        }
        textView.frame = frame
        frame = textField.frame
        if keyboardHeight == 0 {
            frame.origin.y = self.view.frame.height
        } else {
            frame.origin.y = self.view.frame.height - keyboardHeight - frame.height
        }
        textField.frame = frame
    }

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.invitablePlayers.count
    }
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let player = tablesAndPlayers.player(name: invitablePlayers[row])
        return player?.getNameString()
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row<(self.invitablePlayers.count) && row >= 0 {
            var textField = self.inviteAlertController!.textFields![0] as UITextField?
            if textField != nil && textField!.tag == 1 {
                textField!.text = invitablePlayers[row]
            } else {
                textField = self.inviteAlertController!.textFields![1] as UITextField?
                if textField != nil && textField!.tag == 1 {
                    textField!.text = invitablePlayers[row]
                }
            }
        }
    }

}
