//
//  TablePlayers.swift
//  penteLive
//
//  Created by rainwolf on 09/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

class TablePlayers: UITableView, UITableViewDelegate, UITableViewDataSource {
    
    var players: [LivePlayer]?
    var game: Int?

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return players!.count
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "playerCell") ?? UITableViewCell(style: .value1, reuseIdentifier: "playerCell")
        let player = players?[indexPath.row]
        cell.textLabel?.textAlignment = .center
        
        cell.textLabel?.attributedText = player?.getNameString()
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.attributedText = player?.getRatingString(game: game!)
        cell.selectionStyle = .none
        return cell
    }

    
    
}
