//
//  RoomViewController.swift
//  penteLive
//
//  Created by rainwolf on 01/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit
import AudioToolbox

class PlayerTableCell: UITableViewCell {
    override func layoutSubviews() {
        super.layoutSubviews()
        frame.size.height = 44
        if (imageView?.image) != nil {
//            let height = image.size.height
//            let width = image.size.width
//            var itemSize: CGSize
//            if height < width {
//                itemSize = CGSize(width: 44, height: 44*height/width)
//            } else {
//                itemSize = CGSize(width: 44*width/height, height: 44)
//            }
//            UIGraphicsBeginImageContextWithOptions(itemSize, false, 0.0)
//            let imageRect = CGRect(x: 0.0, y: 0.0, width: itemSize.width, height: itemSize.height)
//            imageView?.image!.draw(in: imageRect)
//            imageView?.image! = UIGraphicsGetImageFromCurrentImageContext()!
//            UIGraphicsEndImageContext()
            imageView?.frame = CGRect(x: 10, y: 0, width: 44, height: 44)
            imageView?.contentMode = .scaleAspectFit
            var frame = textLabel?.frame
            frame?.origin.x = (imageView?.frame.origin.x)! + 54
            textLabel?.frame = frame!
        }
    }
}

@objc class RoomViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate {
    
    @objc var room: GameRoom
    var socket: PenteLiveSocket!
    let segmentControl = UISegmentedControl(items: [NSLocalizedString("players", comment: ""), NSLocalizedString("tables", comment: "")])
    var playersAndTables = TablesAndPlayer()
//    var players: [String:LivePlayer] = [String:LivePlayer]()
//    var tables: [Int:Table] = [Int:Table]()
    var tableView: UITableView = UITableView()
    var textView: UITextView = UITextView()
    var textField = UITextField()
    var me = ""
    var tableViewController: TableViewController?
    var invitationAlertController: UIAlertController?
    var newplayerSndID:SystemSoundID!
    var invitationSndID:SystemSoundID!
    var newMoveSndID:SystemSoundID!
    @objc var pentePlayer: PentePlayer?
    var wantsToSeeAvatars = UserDefaults.standard.bool(forKey: "wantToSeeAvatars")
    let playSounds = !UserDefaults.standard.bool(forKey: "inAppSoundsOff")
    var playerNamesArray: [String] = []

    
    private let lockView = UIImageView(image: UIImage(named: "lock"))
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.room = GameRoom(name: "Main Room", port: 16000);
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.initerface(room: self.room)
    }
    
    init(room: GameRoom) {
        self.room = room
        super.init(nibName: nil, bundle: nil)
        self.initerface(room: room)
    }
    func initerface(room: GameRoom) {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = segmentControl
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44.0
        segmentControl.selectedSegmentIndex = 0
        segmentControl.addTarget(tableView, action: #selector(tableView.reloadData), for: UIControl.Event.valueChanged)
        self.view.addSubview(tableView)
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
        self.navigationItem.title = room.name

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.add, target: self, action: #selector(createTable))
        var sndPath = Bundle.main.path(forResource: "newplayer", ofType: "caf")
        var url = URL.init(fileURLWithPath: sndPath!)
        var sndID:SystemSoundID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &sndID)
        newplayerSndID = sndID
        sndPath = Bundle.main.path(forResource: "newplayer", ofType: "caf")
        url = URL.init(fileURLWithPath: sndPath!)
        sndID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &sndID)
        invitationSndID = sndID
        sndPath = Bundle.main.path(forResource: "penteLiveNotificationSound", ofType: "caf")
        url = URL.init(fileURLWithPath: sndPath!)
        sndID = 0
        AudioServicesCreateSystemSoundID(url as CFURL, &sndID)
        newMoveSndID = sndID
        //        if development {
        //            me = "iostest"
        //        }
    }
    required init(coder aDecoder: NSCoder) {
        self.room = GameRoom();
        super.init(coder: aDecoder)!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        var bottomOffset: CGFloat = 0
        if UIDevice.current.userInterfaceIdiom == .phone && Int(UIScreen.main.nativeBounds.size.height) == 2436 {
            bottomOffset = 34.0
        }
        // Do any additional setup after loading the view.
        var frame = self.view.frame
        frame.size.height = (frame.size.height - bottomOffset) * 2 / 3
        tableView.frame = frame
        frame.origin.y = frame.origin.y + frame.size.height
        frame.size.height = (self.view.frame.size.height - bottomOffset) * 1 / 3
        textView.frame = frame
        frame.origin.y = frame.origin.y + frame.size.height
        frame.size.height = 40
        textField.frame = frame
//        print("1")
//        self.pentePlayer = (self.navigationController as! PenteNavigationViewController).player
//                print("jitty \(self.pentePlayer?.playerName)")
        if development {
            socket = PenteLiveSocket(server: "localhost", port: room.port, room: self)
//            socket = PenteLiveSocket(server: "localhost", port: room.port, room: self)
        } else {
            socket = PenteLiveSocket(server: "pente.org", port: room.port, room: self)
        }
//        socket.room = self
//        print("2")
    }
    
    override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        if parent == nil {
            // The back button was pressed or interactive gesture used
            print("leaving")
//            let eventDictionary = ["dsgExitMainRoomEvent":["player":UserDefaults.standard.string(forKey: "username")!,"booted":false, "time":0]]
//            socket.sendEvent(eventDictionary: eventDictionary)
//            let url = URL(string: "https://\(socket.server)/gameServer/bootMeMobile.jsp")
//            let session = URLSession.shared
//            _ = session.dataTask(with: url as URL!, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
//                if error == nil {
//                    self.socket.disconnect()
//                }
//            }).resume()
            self.socket.disconnect()
        }
    }

    
    override func viewDidAppear(_ animated: Bool) {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShowHide), name:UIResponder.keyboardWillChangeFrameNotification, object: nil);
//        if let navc = self.navigationController {
//            print("navc")
//        } else {
//            print("oh no")
//        }
        
        self.tableViewController = nil
    }
    override func viewDidDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        segmentControl.setTitle("\(NSLocalizedString("players", comment: "")) (\(playersAndTables.players.count))", forSegmentAt: 0)
        segmentControl.setTitle("\(NSLocalizedString("tables", comment: "")) (\(playersAndTables.tables.count))", forSegmentAt: 1)
        if segmentControl.selectedSegmentIndex == 0 {
            return playersAndTables.players.count
        } else {
            return playersAndTables.tables.count
        }
    }
    
//    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        if segmentControl.selectedSegmentIndex == 0 {
//            return 44
//        }
//        return 0
//    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if segmentControl.selectedSegmentIndex == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "playerCell") ?? PlayerTableCell(style: .value1, reuseIdentifier: "playerCell")
            let player = playersAndTables.players[self.playerNamesArray[indexPath.row]]!
            cell.textLabel?.textAlignment = .center

            cell.textLabel?.font = UIFont(name: "HelveticaNeue", size: 16)
            cell.textLabel?.attributedText = player.getNameString()
            cell.textLabel?.numberOfLines = 0
            cell.detailTextLabel?.attributedText = player.getRatingString(game: 1)
            cell.selectionStyle = .none
            if wantsToSeeAvatars {
                if let image = pentePlayer?.avatars.object(forKey: player.name) as? UIImage {
                    cell.imageView?.image = image
                } else {
                    cell.imageView?.image = nil
                }
            } else {
                cell.imageView?.image = nil
            }
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "tableCell") ?? UITableViewCell(style: .default, reuseIdentifier: "tableCell")
            let tablesArray = Array(playersAndTables.tables.keys)
            let table = playersAndTables.tables[tablesArray[indexPath.row]]!
            cell.textLabel?.attributedText = table.makeAttributedString()
            cell.textLabel?.numberOfLines = 0
            cell.backgroundColor = table.gameColor()
            if table.open {
                cell.accessoryView = nil
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.accessoryView = lockView
            }
            cell.selectionStyle = .none
            cell.imageView?.image = nil
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if segmentControl.selectedSegmentIndex == 1 {
            let tablesArray = Array(playersAndTables.tables.keys)
            let table = playersAndTables.tables[tablesArray[indexPath.row]]!
            if table.open {
                let eventDictionary = ["dsgJoinTableEvent":["table":table.table, "time":0]]
                socket.sendEvent(eventDictionary: eventDictionary)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if segmentControl.selectedSegmentIndex == 0 && self.playerNamesArray[indexPath.row] != self.me {
            return true
        }
        return false
    }
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete;
    }
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        let player = playersAndTables.players[self.playerNamesArray[indexPath.row]]!
        if player.muted {
            return "unmute"
        } else {
            return "mute"
        }
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let player = playersAndTables.players[self.playerNamesArray[indexPath.row]]!
        player.muted = !player.muted
    }

    
    
    func loginEvent(event: [String: Any]) {
        pentePlayer?.playerName = (event["player"] as! String)
        self.me = pentePlayer!.playerName
        socket.me = self.me
        let serverData = event["serverData"] as! [String:Any]
        let messages: [String] = serverData["loginMessages"] as! [String]
        DispatchQueue.main.async {
            for message in messages {
                self.textView.text = "\(self.textView.text!)\(message)\n"
            }
        }
    }
    func joinMainRoomEvent(event: [String: Any]) {
//        print(event)
        let playerName = event["player"] as! String
        let playerData = event["dsgPlayerData"] as! [String:Any]
        let gameData: [[String:AnyObject]] = playerData["gameData"] as! [[String:AnyObject]]
        let player = LivePlayer(name: playerName)
        var myCrown = 0
        var myKotHCrown = 0
        for singleGame in gameData {
            if (singleGame["computer"] as? String) == "N" {
                player.ratings.updateValue(Int(singleGame["rating"] as! Double), forKey: singleGame["game"] as! Int)
                let tourneyWinner = singleGame["tourneyWinner"] as! Int
                if tourneyWinner != 0 {
                    if tourneyWinner == 4 {
                        myKotHCrown = myKotHCrown + 1
                    } else if myCrown == 0 {
                        myCrown = tourneyWinner
                    } else if tourneyWinner < myCrown {
                        myCrown = tourneyWinner
                    }
                }
            }
        }
        
        if myCrown > 0 {
            player.crown = myCrown
        } else if myKotHCrown > 0 {
            player.crown = myKotHCrown + 3
        } else {
            player.crown = 0
        }
        if let colorData = (playerData["nameColor"] as? [String:AnyObject]) {
            let colorInt = colorData["value"] as! Int
            player.color = UIColorFromRGB(rgbValue: colorInt)
        } else {
            player.color = UIColor.black
        }
//        player.color = UIColor.black
        player.subscriber = playerData["unlimitedTBGames"] as! Bool
        if wantsToSeeAvatars && player.subscriber {
            pentePlayer?.addUser(playerName)
        }
        DispatchQueue.main.async {
            if self.playSounds {
                AudioServicesPlaySystemSound(self.newplayerSndID)
            }
            self.playersAndTables.addPlayer(player: player)
            self.playerNamesArray = Array(self.playersAndTables.players.keys)
            self.tableView.reloadData()
            self.addText(text: NSLocalizedString("* \(playerName) has joined the main room", comment: ""))
        }
    }
    func updatePlayerDataEvent(event: [String: Any]) {
        let playerData = event["data"] as! [String:Any]
        let gameData: [[String:AnyObject]] = playerData["gameData"] as! [[String:AnyObject]]
        let playerName = playerData["name"] as! String
        let player = LivePlayer(name: playerName)
        var myCrown = 0
        var myKotHCrown = 0
        for singleGame in gameData {
            if (singleGame["computer"] as! String) == "N" {
                player.ratings.updateValue(Int(singleGame["rating"] as! Double), forKey: singleGame["game"] as! Int)
                let tourneyWinner = singleGame["tourneyWinner"] as! Int
                if tourneyWinner != 0 {
                    if tourneyWinner == 4 {
                        myKotHCrown = myKotHCrown + 1
                    } else if myCrown == 0 {
                        myCrown = tourneyWinner
                    } else if tourneyWinner < myCrown {
                        myCrown = tourneyWinner
                    }
                }
            }
        }
        if myCrown > 0 {
            player.crown = myCrown
        } else if myKotHCrown > 0 {
            player.crown = myKotHCrown + 3
        } else {
            player.crown = 0
        }
        if let colorData = (playerData["nameColor"] as? [String:AnyObject]) {
            let colorInt = colorData["value"] as! Int
            player.color = UIColorFromRGB(rgbValue: colorInt)
        } else {
            player.color = UIColor.black
        }
        player.subscriber = playerData["unlimitedTBGames"] as! Bool
        DispatchQueue.main.async {
            self.playersAndTables.addPlayer(player: player)
            self.playerNamesArray = Array(self.playersAndTables.players.keys)
            self.tableView.reloadData()
        }
    }
    func exitMainRoomEvent(event: [String:Any]) {
        let playerName = event["player"] as! String
        DispatchQueue.main.async {
            self.playersAndTables.removePlayer(player: playerName)
            self.playerNamesArray = Array(self.playersAndTables.players.keys)
            self.tableView.reloadData()
            self.addText(text: NSLocalizedString("\(playerName) has left the main room", comment: ""))
        }
    }
    func addRoomText(event: [String: Any]) {
        let playerName = event["player"] as! String
        let text = event["text"] as! String
        let player = playersAndTables.players[playerName]!
        if !player.muted {
            DispatchQueue.main.async {
                self.addText(text: "\(playerName): \(text)")
            }
        }
    }
    func addText(text: String) {
        self.textView.text = "\(self.textView.text!)\(text)\n"
        self.textView.scrollRangeToVisible(NSRange(location: self.textView.text.count - 1, length: 1))
    }
    @objc func createTable() {
        let createEvent = ["dsgJoinTableEvent":["table":-1,"time":0]]
        socket.sendEvent(eventDictionary: createEvent)
    }
    
    func disconnected() {
        if self.tableViewController != nil {
            self.tableViewController?.disconnected()
        }
        let _ = self.navigationController?.popViewController(animated: true)
    }

    func inviteTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
//            let table = self.tables[tableId]!
            let invitingPlayer = event["player"] as! String
            let invitedPlayer = event["toInvite"] as! String
            let inviteText = event["inviteText"] as! String
            if invitedPlayer == self.me {
                let player = self.playersAndTables.players[invitingPlayer]!
                if player.muted {
                    return
                } else if self.tableViewController != nil && (self.tableViewController?.table.amIseated(i: self.me))! && self.tableViewController?.table.state.state != .notStarted {
                    let event = ["dsgInviteResponseTableEvent":["toPlayer":invitingPlayer,"responseText":"I can 't accept your invitation because I'm currently playing. This is an automated response","accept":false,"ignore":false,"table":tableId,"time":0]]
                    self.socket.sendEvent(eventDictionary: event)
                } else {
                    if self.playSounds {
                        AudioServicesPlaySystemSound(self.invitationSndID)
                    }
                    self.invitationAlertController = UIAlertController(title: NSLocalizedString("\(invitingPlayer) has invited you to his table", comment: ""), message: "message: \(inviteText)", preferredStyle: .alert)
                    self.invitationAlertController?.addTextField { (textField : UITextField!) -> Void in
                        textField.placeholder = NSLocalizedString("reply message", comment: "")
                    }
                    let acceptAction = UIAlertAction(title: NSLocalizedString("accept", comment: ""), style: .default) { (action) in
                        let textField = self.invitationAlertController!.textFields![0] as UITextField
                        let event = ["dsgInviteResponseTableEvent":["toPlayer":invitingPlayer,"responseText":textField.text!,"accept":true,"ignore":false,"table":tableId,"time":0]]
                        self.socket.sendEvent(eventDictionary: event)
                        if self.tableViewController != nil {
                            let leaveEvent = ["dsgExitTableEvent":["forced":false,"table":(self.tableViewController?.table.table)!,"booted":false, "time":0]]
                            self.socket.sendEvent(eventDictionary: leaveEvent)
                        }
                        let joinEvent = ["dsgJoinTableEvent":["table":tableId, "time":0]]
                        self.socket.sendEvent(eventDictionary: joinEvent)
                    }
                    self.invitationAlertController?.addAction(acceptAction)
                    let declineAction = UIAlertAction(title: NSLocalizedString("decline", comment: ""), style: .default) { (action) in
                        let textField = self.invitationAlertController!.textFields![0] as UITextField
                        let event = ["dsgInviteResponseTableEvent":["toPlayer":invitingPlayer,"responseText":textField.text!,"accept":false,"ignore":false,"table":tableId,"time":0]]
                        self.socket.sendEvent(eventDictionary: event)
                    }
                    self.invitationAlertController?.addAction(declineAction)
                    let ignoreAction = UIAlertAction(title: NSLocalizedString("ignore invites from this player", comment: ""), style: .destructive) { (action) in
                        let textField = self.invitationAlertController!.textFields![0] as UITextField
                        let event = ["dsgInviteResponseTableEvent":["toPlayer":invitingPlayer,"responseText":textField.text!,"accept":false,"ignore":true,"table":tableId,"time":0]]
                        self.socket.sendEvent(eventDictionary: event)
                    }
                    self.invitationAlertController?.addAction(ignoreAction)
                    if self.tableViewController == nil {
                        self.present(self.invitationAlertController!, animated: true)
                    } else {
                        self.tableViewController?.invitationAlertController = self.invitationAlertController
                        self.tableViewController?.present(self.invitationAlertController!, animated: true)
                    }
                }
            }
        }
    }
    func inviteResponseTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let toPlayer = event["toPlayer"] as! String
            if toPlayer == self.me {
                let tableId = event["table"] as! Int
                let player = event["player"] as! String
                let responseText = event["responseText"] as! String
                let accepted = event["accept"] as! Bool
                let ignoring = event["ignore"] as! Bool
                if self.tableViewController != nil && self.tableViewController?.table.table == tableId {
                    if accepted {
                        self.tableViewController?.addText(text: NSLocalizedString("* \(player) has accepted your invitation", comment: ""))
                        if responseText != "" {
                            self.tableViewController?.addText(text: NSLocalizedString("* \(player)'s response: \(responseText)", comment: ""))
                        }
                    } else {
                        self.tableViewController?.addText(text: NSLocalizedString("* \(player) has declined your invitation", comment: ""))
                        if ignoring {
                            self.tableViewController?.addText(text: NSLocalizedString("* \(player) is ignoring your invitations", comment: ""))
                        }
                        if responseText != "" {
                            self.tableViewController?.addText(text: NSLocalizedString("* \(player)'s response: \(responseText)", comment: ""))
                        }
                    }
                }
            }
        }
    
//        {"dsgInviteResponseTableEvent":{"toPlayer":"rainwolf","responseText":"okay then","accept":true,"ignore":false,"player":"iostest","table":1,"time":1481281037855}}
    }
    

    
    
    func joinTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            let playerName = event["player"] as! String
            self.playersAndTables.joinTable(tableId: tableId, player: playerName)
            let table = self.playersAndTables.table(tableId: tableId)
            self.tableView.reloadData()
            if playerName == self.me {
                self.tableViewController = TableViewController(table: table!, socket: self.socket, tablesAndPlayers: self.playersAndTables, pente_player: self.pentePlayer!, me: self.me)
//                self.tableViewController?.pentePlayer = self.pentePlayer
                self.navigationController?.pushViewController(self.tableViewController!, animated: true)
            } else {
                if tableId == self.tableViewController?.table.table {
                    self.tableViewController?.tableJoinEvent(event: event)
                }
            }
        }
    }
    func exitTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            let playerName = event["player"] as! String
            self.playersAndTables.exitTable(tableId: tableId, player: playerName)
            self.tableView.reloadData()
            if tableId == self.tableViewController?.table.table {
                self.tableViewController?.tableExitEvent(event: event)
            }
        }
    }
    func changeTableEvent(event: [String: Any]) {
        let tableId = event["table"] as! Int
        playersAndTables.changeTable(event: event)
        DispatchQueue.main.async {
            self.tableView.reloadData()
            if tableId == self.tableViewController?.table.table {
                self.tableViewController?.stateChanged()
            }
        }
    }
    func sitTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            let playerName = event["player"] as! String
            let seat = event["seat"] as! Int
            self.playersAndTables.sitTable(tableId: tableId, player: playerName, seat: seat)
            self.tableView.reloadData()
            if tableId == self.tableViewController?.table.table {
                self.tableViewController?.stateChanged()
            }
        }
    }
    func standTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            let playerName = event["player"] as! String
            self.playersAndTables.standTable(tableId: tableId, player: playerName)
            self.tableView.reloadData()
            if tableId == self.tableViewController?.table.table {
                self.tableViewController?.stateChanged()
            }
        }
    }
    func ownerTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            let playerName = event["player"] as! String
            self.playersAndTables.ownerTable(tableId: tableId, player: playerName)
            self.tableView.reloadData()
            if tableId == self.tableViewController?.table.table {
                self.tableViewController?.addText(text: NSLocalizedString("\(playerName) is now owner of this table", comment: ""))
                self.tableViewController?.stateChanged()
            }
        }
    }
    func timerChangeTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            var minutes = event["minutes"] as! Int
            var seconds = event["seconds"] as! Int
            var millis = 0;
            if (event["millis"] as? Int == nil) {
                millis = (60*minutes + seconds) * 1000
            } else {
                millis = event["millis"] as! Int
            }
            let playerName = event["player"] as! String
            self.playersAndTables.updateTimerTable(tableId: tableId, player: playerName, millis: millis)
            if tableId == self.tableViewController?.table.table {
                self.tableViewController?.stateChanged()
            }
        }
    }
    func gameStateTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            let gameState = event["state"] as! Int
            self.playersAndTables.gameStateChange(tableId: tableId, state: GameState.State(rawValue: gameState)!)
            if tableId == self.tableViewController?.table.table {
                self.tableViewController?.stateChanged()
                self.tableViewController?.gameStateChanged()
                //                if gameState == 4 {
                //                    if let winner = event["winner"] as? String {
                //                        self.tableViewController?.addText(text: NSLocalizedString("\(winner) wins game 1 of the set. Server swapped your seats for the 2nd game.", comment: ""))
                //                    }
                //                }
                if let message = event ["changeText"] as? String {
                    self.tableViewController?.addText(text: "* \(message) *")
                }
            }
        }
    }
    func swapSeatsTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            let swap = event["swap"] as! Bool
            let silent = event["silent"] as! Bool
            self.playersAndTables.swapSeats(tableId: tableId, swap: swap, silent: silent)
            if tableId == self.tableViewController?.table.table {
                self.tableViewController?.stateChanged()
                //                if let message = event ["changeText"] as? String {
                //                    self.tableViewController?.addText(text: "* \(message) *")
                //                }
            }
        }
    }
    func swap2PassTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            let silent = event["silent"] as! Bool
            self.playersAndTables.swap2Pass(tableId: tableId, silent: silent)
            if tableId == self.tableViewController?.table.table {
                self.tableViewController?.stateChanged()
            }
        }
    }
    func rejectGoDeadStonesTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            if self.playersAndTables.table(tableId: tableId) == nil {
                return
            }
            if tableId == self.tableViewController?.table.table {
                let playerName = event["player"] as! String
                self.tableViewController?.rejectDeadStones()
                self.tableViewController?.addText(text: "* \(playerName) rejected the marked dead stones, play continues *")
            }
        }
    }
    func undoRequestTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            if self.playersAndTables.table(tableId: tableId) == nil {
                return
            }
//            let table = self.tables[tableId]!
            if tableId == self.tableViewController?.table.table {
                let playerName = event["player"] as! String
                self.tableViewController?.requestUndo(player: playerName)
            }
        }
    }
    func replyUndoRequestTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            if self.playersAndTables.table(tableId: tableId) == nil {
                return
            }
            if tableId == self.tableViewController?.table.table {
                let playerName = event["player"] as! String
                let accepted = event["accepted"] as! Bool
                self.tableViewController?.requestUndoReply(player: playerName, accepted: accepted)
            }
        }
    }
    func cancelRequestTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            if self.playersAndTables.table(tableId: tableId) == nil {
                return
            }
            if tableId == self.tableViewController?.table.table {
                let playerName = event["player"] as! String
                self.tableViewController?.requestCancel(player: playerName)
            }
        }
    }
    func cancelRequestReplyTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            if self.playersAndTables.table(tableId: tableId) == nil {
                return
            }
            if tableId == self.tableViewController?.table.table {
                //                let playerName = event["player"] as! String
                let accepted = event["accepted"] as! Bool
                if !accepted {
                    self.tableViewController?.addText(text: NSLocalizedString("* game cancellation declined *", comment: ""))
                }
            }
        }
    }
    func waitingPlayerReturnTimeUpTableEvent(event: [String: Any]) {
        DispatchQueue.main.async {
            let tableId = event["table"] as! Int
            if self.playersAndTables.table(tableId: tableId) == nil {
                return
            }
            let playerName = event["player"] as! String
            if tableId == self.tableViewController?.table.table && self.me == playerName {
                self.tableViewController?.waitingPlayerReturnTimeUp()
            }
        }
    }
//    func forceCancelResignTableEvent(event: [String: Any]) {
//        DispatchQueue.main.async {
//            let tableId = event["table"] as! Int
//            if self.tables[tableId] == nil {
//                return
//            }
//            if tableId == self.tableViewController?.table.table {
//                //                let playerName = event["player"] as! String
//                let accepted = event["accepted"] as! Bool
//                if !accepted {
//                    self.tableViewController?.addText(text: NSLocalizedString("* game cancellation declined *", comment: ""))
//                }
//            }
//        }
//    }
    
    

    


    func moveTableEvent(event: [String: Any]) {
        let tableId = event["table"] as! Int
        if self.playersAndTables.table(tableId: tableId) == nil {
            return
        }
//        let table = tables[tableId]!
        let move = event["move"] as! Int
        let moves = event["moves"] as! [Int]
        DispatchQueue.main.async {
            if tableId == self.tableViewController?.table.table {
                if move != 0 {
                    if self.playSounds {
                        AudioServicesPlaySystemSound(self.newMoveSndID)
                    }
                    self.tableViewController?.addMove(move: move)
                } else {
                    self.tableViewController?.addMoves(moves: moves)
                }
                self.tableViewController?.stateChanged()
            }
        }
    }
    func systemMessageTableEvent(event: [String: Any]) {
        let tableId = event["table"] as! Int
        if self.playersAndTables.table(tableId: tableId) == nil {
            return
        }
//        let table = tables[tableId]!
        let message = event["message"] as! String
        DispatchQueue.main.async {
            if tableId == self.tableViewController?.table.table {
                self.tableViewController?.addText(text: "* \(message)")
            }
        }
    }
    

    func UIColorFromRGB(rgbValue: Int) -> UIColor {
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    func addTableText(event: [String: Any]) {
        let playerName = event["player"] as! String
        let text = event["text"] as! String
        let table = event["table"] as! Int
        let player = self.playersAndTables.players[playerName]!
        if table == self.tableViewController?.table.table && !player.muted {
            DispatchQueue.main.async {
                self.tableViewController?.addText(text: "\(playerName): \(text)")
            }
        }
    }
    func bootFromTableEvent(event: [String: Any]) {
            DispatchQueue.main.async {
                let table = event["table"] as! Int
                if table == self.tableViewController?.table.table {
                    let bootedPlayer = event["toBoot"] as! String
                    let playerName = event["player"] as! String
                    if self.me == bootedPlayer {
                        TSMessage.showNotification(in: self, title: NSLocalizedString("You were booted by \(playerName)", comment: ""), subtitle: NSLocalizedString("You can join this table again in 5 minutes", comment: ""), type: TSMessageNotificationType.error, duration: TimeInterval(TSMessageNotificationDuration.automatic.rawValue), canBeDismissedByUser: true)
                    } else {
                        self.tableViewController?.bootEvent(player: bootedPlayer, by: playerName)
                    }
                }
            }
    }
    func joinTableErrorEvent(event: [String: Any]) {
        let error = event["error"] as! Int
        if error == 22 {
            DispatchQueue.main.async {
                TSMessage.showNotification(in: self, title: NSLocalizedString("Error joining table", comment: ""), subtitle: NSLocalizedString("You were booted, you can join again after 5 minutes", comment: ""), type: TSMessageNotificationType.error, duration: TimeInterval(TSMessageNotificationDuration.automatic.rawValue), canBeDismissedByUser: true)
            }
        }
    }
    @objc func enterText() {
        textField.text = ""
        textField.becomeFirstResponder()
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        if textField.text! != "" {
            let eventDictionary = ["dsgTextMainRoomEvent":["text":textField.text!, "time":0]]
            socket.sendEvent(eventDictionary: eventDictionary)
        }
        return false
    }
    @objc func keyboardWillShowHide(notification: NSNotification) {
        if self.invitationAlertController != nil && (self.invitationAlertController?.isBeingPresented)! {
            return
        }
        var bottomOffset: CGFloat = 0
        if UIDevice.current.userInterfaceIdiom == .phone && Int(UIScreen.main.nativeBounds.size.height) == 2436 {
            bottomOffset = 34.0
        }

        let info = notification.userInfo
        var keyboardHeight: CGFloat = 0.0
        if (info?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.origin.y == self.view.frame.origin.y + self.view.bounds.size.height {
            keyboardHeight = 0
        } else {
            keyboardHeight = ((info?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.height)!
        }
//        print("keyboardWillShowHide \(keyboardHeight)")
        var frame = textView.frame
        if keyboardHeight == 0 {
            frame.origin.y = tableView.frame.origin.y + tableView.frame.size.height
        } else {
            frame.origin.y = tableView.frame.origin.y + tableView.frame.size.height - keyboardHeight - textField.frame.height + bottomOffset
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
}

























