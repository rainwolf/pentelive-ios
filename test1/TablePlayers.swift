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
    var wantsToSeeAvatars = UserDefaults.standard.bool(forKey: "wantToSeeAvatars")
    var pentePlayer: PentePlayer!

    func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return players!.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "playerCell") ?? PlayerTableCell(style: .value1, reuseIdentifier: "playerCell")
        let player = players?[indexPath.row]
        cell.textLabel?.textAlignment = .center

        cell.textLabel?.font = UIFont(name: "HelveticaNeue", size: 16)
        cell.textLabel?.attributedText = player?.getNameString()
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.attributedText = player?.getRatingString(game: game!)
        cell.selectionStyle = .none
        if wantsToSeeAvatars {
            if let image = pentePlayer.avatars.object(forKey: player!.name) as? UIImage {
                cell.imageView?.image = image
            }
        } else {
            cell.imageView?.image = nil
        }
        return cell
    }
}
