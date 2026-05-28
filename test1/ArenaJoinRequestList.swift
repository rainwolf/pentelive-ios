//
//  ArenaJoinRequestList.swift
//  penteLive
//
//  Created by rainwolf on 06/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

class ArenaJoinRequestList: UITableView, UITableViewDelegate, UITableViewDataSource {
    var me: String!
    var socket: PenteLiveSocket!
    var popoverView: PopoverView?
    var data: [String] = []
    var tableAndPlayers: TablesAndPlayer!
    var tableId: Int!
    var gameId: Int!

    let joinTimeout: TimeInterval = 6
    private let progressLineTag = 9911
    private let progressLineHeight: CGFloat = 3
    private var joinTimes: [String: Date] = [:]
    private var expiryTimers: [String: Timer] = [:]

    func reset() {
        data.removeAll()
        expiryTimers.values.forEach { $0.invalidate() }
        expiryTimers.removeAll()
        joinTimes.removeAll()
        reloadData()
    }

    func addPlayer(player: String) {
        data.append(player)
        startCountdown(for: player)
        reloadData()
    }

    private func startCountdown(for name: String) {
        joinTimes[name] = Date()
        expiryTimers[name]?.invalidate()
        expiryTimers[name] = Timer.scheduledTimer(withTimeInterval: joinTimeout, repeats: false) { [weak self] _ in
            self?.removePlayer(name: name)
        }
    }

    private func removePlayer(name: String) {
        expiryTimers[name]?.invalidate()
        expiryTimers[name] = nil
        joinTimes[name] = nil
        if let index = data.firstIndex(of: name) {
            data.remove(at: index)
        }
        reloadData()
    }

    deinit {
        expiryTimers.values.forEach { $0.invalidate() }
    }
    
    init(socket: PenteLiveSocket,  me: String, tableAndPlayers: TablesAndPlayer, tableId: Int, gameId: Int) {
        self.me = me
        self.socket = socket
        self.tableAndPlayers = tableAndPlayers
        self.tableId = tableId
        self.gameId = gameId
        
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0), style: UITableView.Style.plain)
        delegate = self
        dataSource = self
        layer.borderWidth = 1.0
        layer.cornerRadius = 1.0
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    func addPlayer(name: String) {
        data.append(name)
        startCountdown(for: name)
        reloadData()
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    func tableView(_ tableView: UITableView, titleForDeleteConfirmationButtonForRowAt indexPath: IndexPath) -> String? {
        return NSLocalizedString("Reject", comment: "")
    }
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let event = ["DSGArenaRejectTableJoinEvent": ["player": self.me!, "playerToReject": data[indexPath.row], "table": tableId!, "message": nil]]
            socket.sendEvent(eventDictionary: event)
        }
    }
    

    func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return data.count
    }
    
    func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        return NSLocalizedString("Tap player to accept", comment: "")
    }
    
    

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell\(indexPath.row)") ?? UITableViewCell(style: .value1, reuseIdentifier: "Cell\(indexPath.row)")
        cell.selectionStyle = .none

        let playerName = data[indexPath.row]
        let player = tableAndPlayers.player(name: playerName)
        cell.textLabel?.attributedText = player?.getNameString()
        cell.detailTextLabel?.attributedText = player?.getRatingString(game: gameId)

        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        let event = ["dsgArenaAcceptTableJoinEvent": ["player": self.me!, "playerToAccept": data[indexPath.row], "table": tableId!]]
        socket.sendEvent(eventDictionary: event)
//        popoverView?.dismiss()
    }

    func tableView(_: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.contentView.viewWithTag(progressLineTag)?.removeFromSuperview()
        guard indexPath.row < data.count, let start = joinTimes[data[indexPath.row]] else { return }
        let remaining = max(0, joinTimeout - Date().timeIntervalSince(start))
        let fullWidth = cell.contentView.bounds.width

        let line = UIView(frame: CGRect(x: 0, y: 0, width: fullWidth * CGFloat(remaining / joinTimeout), height: progressLineHeight))
        line.tag = progressLineTag
        line.backgroundColor = .systemGreen
        cell.contentView.addSubview(line)

        UIView.animate(withDuration: remaining, delay: 0, options: [.curveLinear], animations: {
            line.frame.size.width = 0
        })
    }
}
