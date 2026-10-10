//
//  ArenaJoinRequestList.swift
//  penteLive
//
//  Created by rainwolf on 06/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

/// The arena owner's request list. Rows come only from server snapshots through `model`;
/// taps and swipes go through the model, so a frozen or in-flight list sends nothing.
class ArenaJoinRequestList: UITableView, UITableViewDelegate, UITableViewDataSource {
    private static let cellId = "ArenaJoinRequestCell"

    var me: String!
    var socket: PenteLiveSocket!
    var tableAndPlayers: TablesAndPlayer!
    var tableId: Int!
    var gameId: Int!
    let model: ArenaJoinRequestListModel
    /// Dims the list and spins while a snapshot is frozen. The presenter adds it above the list.
    let freezeOverlay = UIView()
    /// Called after every model change, so the presenter can show or hide the popover.
    var onModelChange: (() -> Void)?
    private let freezeSpinner = UIActivityIndicatorView(style: .large)

    init(socket: PenteLiveSocket, me: String, tableAndPlayers: TablesAndPlayer, tableId: Int, gameId: Int, model: ArenaJoinRequestListModel = ArenaJoinRequestListModel()) {
        self.me = me
        self.socket = socket
        self.tableAndPlayers = tableAndPlayers
        self.tableId = tableId
        self.gameId = gameId
        self.model = model

        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0), style: UITableView.Style.plain)
        delegate = self
        dataSource = self
        layer.borderWidth = 1.0
        layer.cornerRadius = 1.0

        freezeOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.15)
        freezeOverlay.isHidden = true
        freezeSpinner.translatesAutoresizingMaskIntoConstraints = false
        freezeOverlay.addSubview(freezeSpinner)
        NSLayoutConstraint.activate([
            freezeSpinner.centerXAnchor.constraint(equalTo: freezeOverlay.centerXAnchor),
            freezeSpinner.centerYAnchor.constraint(equalTo: freezeOverlay.centerYAnchor),
        ])
        model.onChange = { [weak self] in
            self?.modelChanged()
        }
    }

    required init(coder aDecoder: NSCoder) {
        model = ArenaJoinRequestListModel()
        super.init(coder: aDecoder)!
    }

    private func modelChanged() {
        if model.isFrozen {
            setEditing(false, animated: true) // close an open swipe-to-reject
            freezeOverlay.isHidden = false
            freezeSpinner.startAnimating()
        } else {
            freezeSpinner.stopAnimating()
            freezeOverlay.isHidden = true
        }
        reloadData()
        onModelChange?()
    }

    func tableView(_: UITableView, canEditRowAt _: IndexPath) -> Bool {
        return model.isInteractive
    }

    func tableView(_: UITableView, editingStyleForRowAt _: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }

    func tableView(_: UITableView, titleForDeleteConfirmationButtonForRowAt _: IndexPath) -> String? {
        return NSLocalizedString("Reject", comment: "")
    }

    func tableView(_: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete, indexPath.row < model.rows.count else { return }
        let player = model.rows[indexPath.row].player
        // No optimistic removal: the row keeps a spinner until the server's snapshot (R11).
        guard model.beginAction(on: player) else { return }
        socket.sendEvent(eventDictionary: ArenaOutbound.reject(table: tableId, player: player))
    }

    func numberOfSections(in _: UITableView) -> Int {
        return 1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        return model.rows.count
    }

    func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        return NSLocalizedString("Tap player to accept", comment: "")
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ArenaJoinRequestList.cellId) ?? UITableViewCell(style: .value1, reuseIdentifier: ArenaJoinRequestList.cellId)
        cell.selectionStyle = .none

        let playerName = model.rows[indexPath.row].player
        let player = tableAndPlayers.player(name: playerName)
        cell.textLabel?.attributedText = player?.getNameString() ?? NSAttributedString(string: playerName)
        cell.detailTextLabel?.attributedText = player?.getRatingString(game: gameId)
        if playerName == model.inFlightPlayer {
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.startAnimating()
            cell.accessoryView = spinner
        } else {
            cell.accessoryView = nil
        }
        return cell
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row < model.rows.count else { return }
        let player = model.rows[indexPath.row].player
        guard model.beginAction(on: player) else { return }
        socket.sendEvent(eventDictionary: ArenaOutbound.accept(table: tableId, player: player))
    }
}
