//
//  LobbyViewController.swift
//  penteLive
//
//  Created by rainwolf on 30/11/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

let development = true

@objc class LobbyViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIPickerViewDelegate, UIPickerViewDataSource {
    
    var servers: [GameRoom] = []
    var broadcastAlertController: UIAlertController?
    let gameNames = ["any game", "Pente", "Speed Pente", "Keryo-Pente", "Speed Keryo-Pente", "Gomoku", "Speed Gomoku",
                     "D-Pente", "Speed D-Pente", "G-Pente", "Speed G-Pente", "Poof-Pente", "Speed Poof-Pente",
                     "Connect6", "Speed Connect6", "Boat-Pente", "Speed Boat-Pente", "DK-Pente", "Speed DK-Pente",
                     "Go", "Speed Go", "Go (9x9)", "Speed Go (9x9)", "Go (13x13)", "Speed Go (13x13)", "O-Pente", "Speed O-Pente"]
    var pentePlayer: PentePlayer?

    var wantsToSeeAvatars = UserDefaults.standard.bool(forKey: "wantToSeeAvatars")

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = NSLocalizedString("Lobby", comment: "")
        let tableView = UITableView(frame: self.view.frame)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 44.0
        self.view.addSubview(tableView)
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "broadcast"), style: .plain, target: self, action: #selector(broadcast))
        self.pentePlayer = (self.navigationController as! PenteNavigationViewController).player

        loadServers()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return servers.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .default, reuseIdentifier: "cell")
//        cell.textLabel?.textAlignment = NSTextAlignment.center
        cell.textLabel?.attributedText = servers[indexPath.row].makeAttributedString()
        cell.textLabel?.numberOfLines = 0
        cell.selectionStyle = .none
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = RoomViewController(room: servers[indexPath.row])
        vc.pentePlayer = self.pentePlayer

        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func loadServers() {
        do {
            var activeServers: String;
            if development {
                activeServers = try String(contentsOf: URL(string: "https://development.pente.org/gameServer/mobile/liveServers.jsp?iPhone")!, encoding: String.Encoding.utf8)
            } else {
                activeServers = try String(contentsOf: URL(string: "https://www.pente.org/gameServer/mobile/liveServers.jsp?iPhone")!, encoding: String.Encoding.utf8)
            }
            let serverLines = activeServers.components(separatedBy: "\n")
            for line in serverLines {
                if line.contains(":") {
                    let serverAndPlayers = line.components(separatedBy: ":")
//                    let result = serverAndPlayers[0].characters.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
                    let result = serverAndPlayers[0].split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
                    if result.count > 1 {
                        let room = GameRoom(name: String(result[1]), port: Int(String(result[0]))!)
                        servers.append(room)
                        let players = serverAndPlayers[1].components(separatedBy: ";")
                        for playerString in players {
                            let playerComponents = playerString.components(separatedBy: ",")
                            if playerComponents.count < 4 {
                                continue
                            }
                            let player = LivePlayer(name: playerComponents[0])
                            player.crown = Int(playerComponents[3])!
                            player.color = UIColorFromRGB(rgbValue: Int(playerComponents[2])!)
                            player.ratings.updateValue(Int(playerComponents[1])!, forKey: 1)
                            player.subscriber = Int(playerComponents[2])! != 0
                            if wantsToSeeAvatars && player.color != nil {
                                pentePlayer?.addUser(player.name)
                            }
                            room.players.append(player)
                        }
                    }
                    

                } else {
//                    let result = line.characters.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
                    let result = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
                    if result.count > 1 {
                        let room = GameRoom(name: String(result[1]), port: Int(String(result[0]))!)
                        servers.append(room)
                    }
                }
            }
        } catch let error {
            self.showErrorAlert(alertMessage: NSLocalizedString("There was an error getting the game rooms. Reason: \(error.localizedDescription)", comment: ""))
        }
    }
    func backHome(action: UIAlertAction) {
        self.navigationController!.popToRootViewController(animated: true)
    }
    
    @objc func broadcast() {
        if (pentePlayer?.subscriber)! {
            self.broadcastAlertController = UIAlertController(title: NSLocalizedString("broadcast to followers or friends", comment: ""), message: nil, preferredStyle: .alert)
            self.broadcastAlertController?.addTextField { (textField : UITextField!) -> Void in
                let gamePicker = UIPickerView()
                let pickerToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 44))
                pickerToolbar.barStyle = .blackTranslucent
                let extraSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target:nil, action:nil)
                let doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: textField, action: #selector(textField.resignFirstResponder)) // method
                pickerToolbar.setItems([extraSpace, doneButton], animated: true)
                gamePicker.delegate = self
                gamePicker.dataSource = self
                gamePicker.tag = 2
                textField.inputView = gamePicker
                textField.tag = 1;
                //            textField.delegate = self
                textField.inputAccessoryView = pickerToolbar
                textField.placeholder = NSLocalizedString("select game", comment: "")
            }
            let broadcastFollowerAction = UIAlertAction(title: NSLocalizedString("broadcast to followers", comment: ""), style: .default) { (action) in
                var gameName = (self.broadcastAlertController!.textFields![0] as UITextField).text!
                if gameName == "" {
                    gameName = "any"
                }
                self.broadcastNow(to: "followers", game: gameName)
            }
            self.broadcastAlertController?.addAction(broadcastFollowerAction)
            let broadcastFriendsAction = UIAlertAction(title: NSLocalizedString("broadcast to friends", comment: ""), style: .default) { (action) in
                var gameName = (self.broadcastAlertController!.textFields![0] as UITextField).text!
                if gameName == "" {
                    gameName = "any"
                }
                self.broadcastNow(to: "friends", game: gameName)
            }
            self.broadcastAlertController?.addAction(broadcastFriendsAction)
            let cancelAction = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { (action) in
            }
            self.broadcastAlertController?.addAction(cancelAction)
            self.present(self.broadcastAlertController!, animated: true)
        } else {
            let alertController = UIAlertController(title: NSLocalizedString("Subscriber feature", comment: ""), message: NSLocalizedString("As a subscriber you will be able to alert your followers or friends (followers you follow) that you're available to play in the live game room. This feature is not available for non-subscribers", comment: ""), preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: NSLocalizedString("dismiss", comment: ""), style: .cancel) { (action) in
            }
            alertController.addAction(cancelAction)
            let subscribeAction = UIAlertAction(title: NSLocalizedString("subscription info", comment: ""), style: .default) { (action) in
                (self.navigationController as! PenteNavigationViewController).showSubscribe = true
                let _ = self.navigationController?.popToRootViewController(animated: true)
            }
            alertController.addAction(subscribeAction)
            self.present(alertController, animated: true)
        }
    }
    
    func broadcastNow(to: String, game: String) {
//        print("https://www.pente.org/gameServer/broadcast?sendTo=\(to)&game=\(game.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)")
        do {
            let htmlString = try String(contentsOf: URL(string: "https://www.pente.org/gameServer/broadcast?sendTo=\(to)&game=\(game.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!)&mobile=")!, encoding: String.Encoding.utf8)
            if htmlString.contains("Broadcasting to followers or friends is only available to subscribers") {
                self.showErrorAlert(alertMessage: NSLocalizedString("Broadcasting to followers or friends is only available to subscribers", comment: ""))
            } else if htmlString.contains("database error, try again later") {
                self.showErrorAlert(alertMessage: NSLocalizedString("Database error, please try again later.", comment: ""))
            } else if htmlString.contains("You can't broadcast more than once per hour") {
                self.showErrorAlert(alertMessage: NSLocalizedString("You can't broadcast more than once per hour", comment: ""))
            }
//            print(htmlString)
        } catch let error {
            self.showErrorAlert(alertMessage: NSLocalizedString("There was an error following. Reason: \(error.localizedDescription)", comment: ""))
        }
    }
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return gameNames.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return gameNames[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row<(self.gameNames.count) && row >= 0 {
            let textField = self.broadcastAlertController!.textFields![0] as UITextField?
            if textField != nil && textField!.tag == 1 {
                textField!.text = gameNames[row]
            }
        }
    }
    
    func showErrorAlert(alertMessage: String) {
        let alertController = UIAlertController(title: NSLocalizedString("Error", comment: ""), message: alertMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Dismiss", comment: ""), style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }

    
    func UIColorFromRGB(rgbValue: Int) -> UIColor {
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }


}

@objc class GameRoom: NSObject {
    @objc var name: String
    @objc var port: Int
    var players = [LivePlayer]()
    
    init(name: String, port: Int) {
        self.name = name
        self.port = port
    }
    
    required override init() {
        self.name = ""
        self.port = 0
        super.init()
    }

    func makeAttributedString() -> NSAttributedString {
        let titleAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline)]
//        let subtitleAttributes = [NSFontAttributeName: UIFont.preferredFont(forTextStyle: .subheadline)]
        
        let titleString = NSMutableAttributedString(string: "\(name)", attributes: titleAttributes)
        if players.count > 0 {
            titleString.append(NSAttributedString(string: "\n"))
            let subtitleString = NSMutableAttributedString(string: "")
            //        subtitleString.setAttributes(subtitleAttributes, range: NSRange(location: 0, length: subtitleString.string.characters.count))
            for player in players {
                if subtitleString.length > 0 {
                    subtitleString.append(NSAttributedString(string: ", "))
                }
                subtitleString.append(player.getNameString())
            }
            titleString.append(subtitleString)
        }
        
        return titleString
    }

}
