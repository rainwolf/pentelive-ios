//
//  LobbyViewController.swift
//  penteLive
//
//  Created by rainwolf on 30/11/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

@objc class LobbyViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var servers: [GameRoom] = []
    

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.title = NSLocalizedString("Lobby", comment: "")
        let tableView = UITableView(frame: self.view.frame)
        tableView.delegate = self
        tableView.dataSource = self
        self.view.addSubview(tableView)
        
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "cell")
        cell.textLabel?.textAlignment = NSTextAlignment.center
        cell.textLabel?.text = "\(servers[indexPath.row].name)"
        cell.textLabel?.numberOfLines = 0
        cell.selectionStyle = .none
        return cell
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let vc = RoomViewController(room: servers[indexPath.row])
        vc.pentePlayer = (self.navigationController as! PenteNavigationViewController).player

        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func loadServers() {
        do {
            let activeServers = try String(contentsOf: URL(string: "https://www.pente.org/gameServer/activeServers")!, encoding: String.Encoding.utf8)
//            let activeServers = try String(contentsOf: URL(string: "https://development.pente.org/gameServer/activeServers")!, encoding: String.Encoding.utf8)
//            print(activeServers)
            let serverLines = activeServers.components(separatedBy: "\n")
            for line in serverLines {
                let result = line.characters.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
                if result.count > 1 {
//                    print("1: \(String(result[1]))")
//                    print("2: \(String(result[0]))")
                    let room = GameRoom(name: String(result[1]), port: Int(String(result[0]))!)
                    servers.append(room)
                }
            }
        } catch let error {
            let alertController = UIAlertController(title: NSLocalizedString("Error", comment: ""), message: NSLocalizedString("There was an error getting the game rooms. Reason: \(error.localizedDescription)", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Dismiss", comment: ""), style: UIAlertActionStyle.default, handler: backHome))
            self.present(alertController, animated: true, completion: nil)
        }
    }
    func backHome(action: UIAlertAction) {
        self.navigationController!.popToRootViewController(animated: true)
    }

}

class GameRoom: NSObject {
    var name: String
    var port: Int
    
    init(name: String, port: Int) {
        self.name = name
        self.port = port
    }
}
