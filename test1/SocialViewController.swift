//
//  SocialViewController.swift
//  penteLive
//
//  Created by rainwolf on 31/01/2017.
//  Copyright © 2017 Triade. All rights reserved.
//

import UIKit

//class PlayerTableCell: UITableViewCell {
//    override func layoutSubviews() {
//        super.layoutSubviews()
//        frame.size.height = 44
//    }
//}

class SocialViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, GADBannerViewDelegate, GADInterstitialDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    
    let segmentControl = UISegmentedControl(items: [NSLocalizedString("following", comment: ""), NSLocalizedString("followers", comment: "")])
    var refreshControl = UIRefreshControl()
    var tableView: UITableView = UITableView()
    var showAds = true
    var bannerView: GADBannerView?
    var interstitial: GADInterstitial?
    var pentePlayer: PentePlayer!
    var wantsToSeeAvatars = UserDefaults.standard.bool(forKey: "wantToSeeAvatars")
    
    var followers = [LivePlayer]()
    var following = [LivePlayer]()
    
    let gameNames = ["Pente": 1, "Keryo-Pente": 3, "Gomoku": 5, "D-Pente": 7, "G-Pente": 9, "Poof-Pente": 11, "Connect6": 13,
                     "Boat-Pente": 15, "Speed Pente": 2, "Speed Keryo-Pente": 4, "Speed Gomoku": 6, "Speed D-Pente": 8,
                     "Speed G-Pente": 10, "Speed Poof-Pente": 12, "Speed Connect6": 14, "Speed Boat-Pente": 16,
                     "Turn-based Pente": 51, "Turn-based Keryo-Pente": 53, "Turn-based Gomoku": 55, "Turn-based D-Pente": 57,
                     "Turn-based G-Pente": 59, "Turn-based Poof-Pente": 61, "Turn-based Connect6": 63, "Turn-based Boat-Pente": 65]
    let gameNamesArray = ["Turn-based Pente", "Turn-based Keryo-Pente", "Turn-based Gomoku", "Turn-based D-Pente",
                          "Turn-based G-Pente", "Turn-based Poof-Pente", "Turn-based Connect6", "Turn-based Boat-Pente",
                          "Pente", "Keryo-Pente", "Gomoku", "D-Pente", "G-Pente", "Poof-Pente", "Connect6",
                          "Boat-Pente", "Speed Pente", "Speed Keryo-Pente", "Speed Gomoku", "Speed D-Pente",
                          "Speed G-Pente", "Speed Poof-Pente", "Speed Connect6", "Speed Boat-Pente"]
    let textField = UITextField()

    
    var gameString: String?
    
    init(player: PentePlayer) {
        self.pentePlayer = player
        super.init(nibName: nil, bundle: nil)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = segmentControl
        segmentControl.selectedSegmentIndex = 0
        segmentControl.addTarget(tableView, action: #selector(tableView.reloadData), for: UIControlEvents.valueChanged)
        self.view.addSubview(tableView)
        self.navigationItem.title = NSLocalizedString("Social", comment: "")
        
        self.refreshControl.attributedTitle = NSAttributedString(string: NSLocalizedString("Pull to refresh", comment: ""))
        self.refreshControl.addTarget(self, action: #selector(refresh), for: UIControlEvents.valueChanged)
        self.tableView.addSubview(refreshControl)
        
        let addButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.add, target: self, action: #selector(addFollowing))
        let settingsItem = UIBarButtonItem(image: UIImage(named: "gamesettings"), style: .plain, target: self, action: #selector(selectGame))
        self.navigationItem.rightBarButtonItems = [addButton, settingsItem]
        
    }
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.frame = self.view.frame
        // Do any additional setup after loading the view.
        gameString = UserDefaults.standard.string(forKey: "socialGame")
        if gameString == nil {
            gameString = "Pente"
        }
        loadFollowersing()
    }
    
    func refresh(sender:AnyObject) {
        loadFollowersing()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        showAds = pentePlayer.showAds
        
        if showAds && bannerView == nil {
            bannerView = GADBannerView(adSize: kGADAdSizeBanner)
            bannerView!.rootViewController = self
            bannerView!.delegate = self
            var frame = tableView.frame
            frame.size.height = tableView.frame.size.height - (bannerView?.frame.size.height)!
            tableView.frame = frame
            frame = (bannerView?.frame)!
            frame.origin.y = tableView.frame.origin.y + tableView.frame.size.height
            bannerView!.frame = frame
            bannerView!.adUnitID = "ca-app-pub-3326997956703582/3285001842"
            let request = GADRequest()
//            request.testDevices = [kGADSimulatorID]
            bannerView!.load(request)
            self.view.addSubview(bannerView!)
        }
        
        self.view.addSubview(textField)
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
        segmentControl.setTitle("\(NSLocalizedString("following", comment: "")) (\(following.count))", forSegmentAt: 0)
        segmentControl.setTitle("\(NSLocalizedString("followers", comment: "")) (\(followers.count))", forSegmentAt: 1)
        if segmentControl.selectedSegmentIndex == 1 {
            return followers.count
        } else {
            return following.count
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "playerCell") ?? PlayerTableCell(style: .value1, reuseIdentifier: "playerCell")
        let player: LivePlayer
        if segmentControl.selectedSegmentIndex == 1 {
            player = followers[indexPath.row]
        } else {
            player = following[indexPath.row]
        }
        cell.textLabel?.textAlignment = .center
        cell.textLabel?.attributedText = player.getNameString()
        cell.textLabel?.numberOfLines = 0
//        cell.detailTextLabel?.attributedText = player.getRatingString(game: 1)
        cell.selectionStyle = .none
        cell.accessoryType = .disclosureIndicator
        let game = gameNames[gameString!]!
        cell.detailTextLabel?.attributedText = player.getRatingString(game: game)
        if wantsToSeeAvatars {
            if let image = pentePlayer.avatars.object(forKey: player.name) as? UIImage {
                cell.imageView?.image = image
            } else {
                cell.imageView?.image = nil
            }
        } else {
            cell.imageView?.image = nil
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        var playerName: String
        if segmentControl.selectedSegmentIndex == 1 {
            playerName = followers[indexPath.row].name
        } else {
            playerName = following[indexPath.row].name
        }
        let vc = SVWebViewController(address: "https://www.pente.org/gameServer/profile?viewName=\(playerName)")
        self.navigationController?.pushViewController(vc!, animated: true)
    }
    
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if segmentControl.selectedSegmentIndex == 0 {
            return true
        }
        return false
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        do {
            let _ = try String(contentsOf: URL(string: "https://www.pente.org/gameServer/social?unfollow=\(following[indexPath.row].name)")!, encoding: String.Encoding.utf8)
        } catch let error {
            self.showErrorAlert(alertMessage: NSLocalizedString("There was an error unfollowing. Reason: \(error.localizedDescription)", comment: ""))
        }
        loadFollowersing()
    }
    
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return NSLocalizedString("unfollow", comment: "")
    }
    
    
    func UIColorFromRGB(rgbValue: Int) -> UIColor {
        return UIColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: CGFloat(1.0)
        )
    }
    
    
    
    func addFollowing() {
        let alertController = UIAlertController(title: NSLocalizedString("follow player", comment: ""), message: nil, preferredStyle: .alert)
        alertController.addTextField { (textField : UITextField!) -> Void in
            textField.placeholder = NSLocalizedString("player name", comment: "")
        }
        let addAction = UIAlertAction(title: NSLocalizedString("add player", comment: ""), style: .default) { (action) in
            let player = (alertController.textFields![0] as UITextField).text!
            do {
                let htmlString = try String(contentsOf: URL(string: "https://www.pente.org/gameServer/social?follow=\(player)&mobile=")!, encoding: String.Encoding.utf8)
                if htmlString.contains("non-subscribers. Subscribers can follow an unlimited number of players.") {
                    self.showErrorAlert(alertMessage: NSLocalizedString("Non-subscribers can only follow 5 players or less.", comment: ""))
                } else if htmlString.contains("database error, try again later") {
                    self.showErrorAlert(alertMessage: NSLocalizedString("Database error, please try again later.", comment: ""))
                } else if htmlString.contains("player not found") {
                    self.showErrorAlert(alertMessage: NSLocalizedString("No such username", comment: ""))
                } else {
                    self.loadFollowersing()
                }
//                print(htmlString)
            } catch let error {
                self.showErrorAlert(alertMessage: NSLocalizedString("There was an error following. Reason: \(error.localizedDescription)", comment: ""))
            }
        }
        alertController.addAction(addAction)
        let cancelAction = UIAlertAction(title: NSLocalizedString("cancel", comment: ""), style: .cancel) { (action) in
        }
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true)
        
    }
    
    func showErrorAlert(alertMessage: String) {
        let alertController = UIAlertController(title: NSLocalizedString("Error", comment: ""), message: alertMessage, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Dismiss", comment: ""), style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    func loadFollowersing() {
        do {
            let game = gameNames[gameString!]!
            followers.removeAll()
            following.removeAll()
            let followersing = try String(contentsOf: URL(string: "https://www.pente.org/gameServer/mobile/followers.jsp?game=\(game)")!, encoding: String.Encoding.utf8)
            //            let activeServers = try String(contentsOf: URL(string: "https://development.pente.org/gameServer/activeServers")!, encoding: String.Encoding.utf8)
//                        print(followersing)
            let followerLines = followersing.components(separatedBy: "\n")
            for line in followerLines {
                let splitLine: [String] = line.components(separatedBy: ";")
                if splitLine.count > 5 {
                    let player = LivePlayer(name: splitLine[1])
                    player.subscriber = (splitLine[2] == "1")
                    player.crown = Int(splitLine[4])!
                    player.color = UIColorFromRGB(rgbValue: Int(splitLine[3])!)
                    player.ratings = [game: Int(splitLine[5])!]
                    if splitLine[0] == "1" {
                        following.append(player)
                    } else {
                        followers.append(player)
                    }
                    if wantsToSeeAvatars {
                        pentePlayer.addUser(player.name)
                    }
                }
            }
            followers.sort { (p1, p2) -> Bool in
                return p1.ratings[game]! > p2.ratings[game]!
            }
            following.sort { (p1, p2) -> Bool in
                return p1.ratings[game]! > p2.ratings[game]!
            }
        } catch let error {
            self.showErrorAlert(alertMessage: NSLocalizedString("There was an error loading followers. Reason: \(error.localizedDescription)", comment: ""))
        }
        tableView.reloadData()
        if self.refreshControl.isRefreshing {
            self.refreshControl.endRefreshing()
        }
    }
    
    func selectGame() {
        let gamePicker = UIPickerView()
        let pickerToolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: self.view.frame.size.width, height: 44))
        pickerToolbar.barStyle = .blackTranslucent
        let extraSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target:nil, action:nil)
        let doneButton = UIBarButtonItem(title: NSLocalizedString("Done", comment: ""), style: .done, target: self, action: #selector(dismissPicker)) // method
        pickerToolbar.setItems([extraSpace, doneButton], animated: true)
        gamePicker.delegate = self
        gamePicker.dataSource = self
        gamePicker.tag = 1
//        var game = table.game
//        if game%2 == 0 {
//            game = game - 1
//        }
        gamePicker.selectRow(gameNamesArray.index(of: gameString!)!, inComponent: 0, animated: true)
        
        textField.inputView = gamePicker
        textField.tag = 1;
//        textField.delegate = self
        textField.inputAccessoryView = pickerToolbar
        
        textField.becomeFirstResponder()
    }
    func dismissPicker() {
        textField.resignFirstResponder()
        loadFollowersing()
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return self.gameNamesArray.count
    }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return self.gameNamesArray[row]
    }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        gameString = self.gameNamesArray[row]
        UserDefaults.standard.set(gameString, forKey: "socialGame")
    }

}

























