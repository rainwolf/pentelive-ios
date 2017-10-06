//
//  HelperClasses.swift
//  penteLive
//
//  Created by rainwolf on 02/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

class LivePlayer: NSObject {
    var name: String
    var ratings = [Int:Int]()
    var color: UIColor!
    var subscriber = false
    var crown: Int = 0
    
    init(name: String) {
        self.name = name
    }
    
    func getNameString() -> NSAttributedString {
        let text = NSMutableAttributedString(string: name)
        if subscriber {
            text.addAttribute(NSAttributedStringKey.foregroundColor, value: color, range: NSRange(location: 0, length: name.characters.count))
            text.addAttribute(NSAttributedStringKey.font, value: UIFont(name: "HelveticaNeue-Bold", size: 17)!, range: NSRange(location: 0, length: name.characters.count))
        } else {
            text.addAttribute(NSAttributedStringKey.font, value: UIFont(name: "HelveticaNeue", size: 17)!, range: NSRange(location: 0, length: name.characters.count))
        }
        let textAttachment = NSTextAttachment()
        switch crown {
            case 1:
                textAttachment.image = UIImage(named:"crown.gif")
            case 2:
                textAttachment.image = UIImage(named:"scrown.gif")
            case 3:
                textAttachment.image = UIImage(named:"bcrown.gif")
            default:
                if (crown > 3) {
                    textAttachment.image = UIImage(named:"kothcrown\((crown-3))")
                }
        }
        if crown > 0 {
            let crownStr = NSAttributedString(attachment: textAttachment)
            text.append(NSAttributedString(string: " "))
            text.append(crownStr)
        }
        return text
    }
    
    func getRatingString(game: Int) -> NSAttributedString {
        var ratingInt = 1600
        if ratings[game] != nil {
            ratingInt = ratings[game]!
        }
        var text = "\u{25A0} "
        if ratingInt < 1000 {
            text = text + " "
        }
        var ratingColor: UIColor
        if ratingInt >= 1900 {
            ratingColor = UIColor.red
        } else if (ratingInt >= 1700) {
            ratingColor = UIColor(red:0.98, green:0.96, blue:0.03, alpha:1.0)
        } else if (ratingInt >= 1400) {
            ratingColor = UIColor.blue
        } else if (ratingInt >= 1000) {
            ratingColor = UIColor(red:30.0/255, green: 130.0/255, blue:76.0/255, alpha:1.0)
        } else {
            ratingColor = UIColor.gray
        }
        text = text + "\(ratingInt)"
        let coloredText = NSMutableAttributedString(string: text)
        coloredText.addAttribute(NSAttributedStringKey.foregroundColor, value: ratingColor, range: NSRange(location: 0, length: 1))
        coloredText.addAttribute(NSAttributedStringKey.font, value: UIFont(name: "HelveticaNeue-Bold", size: 12.0)!, range: NSRange(location: 0, length: 1))
        return coloredText
    }

}

class Table: NSObject {
    var players = [String:LivePlayer]()
    var timed = false
    var timer = ["initialMinutes": 0, "incrementalSeconds": 0]
    var game = 1
    var open = true
    var rated = false
    var table = 1
    var seats = [Int:LivePlayer]()
    var owner = ""
    let state = GameState()
    var moves = [Int]()
    var abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
    var whiteCaptures = 0
    var blackCaptures = 0
    
    let gameNames = [1: "Pente", 2: "Speed Pente", 3: "Keryo-Pente", 4: "Speed Keryo-Pente", 5: "Gomoku", 6: "Speed Gomoku",
                     7: "D-Pente", 8: "Speed D-Pente", 9: "G-Pente", 10: "Speed G-Pente", 11: "Poof-Pente", 12: "Speed Poof-Pente",
                     13: "Connect6", 14: "Speed Connect6", 15: "Boat-Pente", 16: "Speed Boat-Pente", 17: "DK-Pente", 18: "Speed DK-Pente"]
    
    init(table: Int) {
        self.table = table
        super.init()
    }
    
    func addPlayer(player: LivePlayer) {
        if players.count == 0 {
            owner = player.name
        }
        players.updateValue(player, forKey: player.name)
    }
    func removePlayer(player: String) {
        players.removeValue(forKey: player)
    }
    func amIseated(i: String) -> Bool {
        for player in seats.values {
            if player.name == i {
                return true
            }
        }
        return false
    }
    func changeState(state: [String:Any]) {
        timed = state["timed"] as! Bool
        timer.updateValue(state["initialMinutes"] as! Int, forKey: "initialMinutes")
        timer.updateValue(state["incrementalSeconds"] as! Int, forKey: "incrementalSeconds")
        rated = state["rated"] as! Bool
        game = state["game"] as! Int
        table = state["table"] as! Int
        open = (state["tableType"] as! Int) == 1
        owner = state["player"] as! String
    }
    func sit(seat: Int, player: LivePlayer) {
        seats.updateValue(player, forKey: seat)
//        players.removeValue(forKey: player.name)
    }
    func stand(player: String) {
        if let seatedPlayer = seats[1] {
            if seatedPlayer.name == player {
                seats.removeValue(forKey: 1)
//                addPlayer(player: seatedPlayer)
            }
        }
        if let seatedPlayer = seats[2] {
            if seatedPlayer.name == player {
                seats.removeValue(forKey: 2)
//                addPlayer(player: seatedPlayer)
            }
        }
    }
    func addMoves(moves: [Int]) {
        self.moves.removeAll()
        abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
        blackCaptures = 0
        whiteCaptures = 0
        for move in moves {
            addMove(move: move)
        }
    }
    func gameHasCaptures() -> Bool {
        return (game != 5 && game != 6 && game != 13 && game != 14)
    }
    func addMove(move: Int) {
        let color = currentPlayer()
        moves.append(move)
        let i = move / 19
        let j = move % 19
        abstractBoard[i][j] = color
        if game != 5 && game != 6 && game != 13 && game != 14 {
            if game == 11 || game == 12 {
                detectPoof(move: move, color: color)
            }
            detectCapture(move: move, color: color)
            if game == 3 || game == 4 || game == 17 || game == 18 {
                detectKeryoCapture(move: move, color: color)
            }
        }
        if game != 5 && game != 6 && game != 13 && game != 14 && game != 7 && game != 8 && game != 17 && game != 18 && (rated || game == 9 || game == 10) {
            if moves.count == 2 {
                for i in 7..<12 {
                    for j in 7..<12 {
                        if (abstractBoard[i][j] == 0) {
                            abstractBoard[i][j] = -1
                        }
                    }
                }
                if (game == 9 || game == 10) {
                    for i in 1..<3 {
                        if (abstractBoard[9][11 + i] == 0) {
                            abstractBoard[9][11 + i] = -1
                        }
                        if (abstractBoard[9][7 - i] == 0) {
                            abstractBoard[9][7 - i] = -1
                        }
                        if (abstractBoard[11 + i][9] == 0) {
                            abstractBoard[11 + i][9] = -1
                        }
                        if (abstractBoard[7 - i][9] == 0) {
                            abstractBoard[7 - i][9] = -1
                        }
                    }
                }
            } else if moves.count == 3 {
                for i in 7..<12 {
                    for j in 7..<12 {
                        if (abstractBoard[i][j] == -1) {
                            abstractBoard[i][j] = 0
                        }
                    }
                }
                if (game == 9 || game == 10) {
                    for i in 1..<3 {
                        if (abstractBoard[9][11 + i] == -1) {
                            abstractBoard[9][11 + i] = 0
                        }
                        if (abstractBoard[9][7 - i] == -1) {
                            abstractBoard[9][7 - i] = 0
                        }
                        if (abstractBoard[11 + i][9] == -1) {
                            abstractBoard[11 + i][9] = 0
                        }
                        if (abstractBoard[7 - i][9] == -1) {
                            abstractBoard[7 - i][9] = 0
                        }
                    }
                }
            }
        }
        
        
    }
    func setOwner(owner: String) {
        self.owner = owner
    }
    func reset() {
        moves.removeAll()
        resetTimers()
        blackCaptures = 0
        whiteCaptures = 0
        abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
        state.dPenteState = .noChoice
    }
    func resetTimers() {
        let minutes = timer["initialMinutes"]!
        state.timers[1]!.updateValue(minutes, forKey: "minutes")
        state.timers[2]!.updateValue(minutes, forKey: "minutes")
        state.timers[1]!.updateValue(0, forKey: "seconds")
        state.timers[2]!.updateValue(0, forKey: "seconds")
    }
    func updateTimer(playerName: String, minutes:Int, seconds: Int) {
        var seat = 0
        if let player = seats[1] {
            if player.name == playerName {
                seat = 1
            }
        }
        if let player = seats[2] {
            if player.name == playerName {
                seat = 2
            }
        }
        if seat > 0 {
            state.timers[seat]!.updateValue(minutes, forKey: "minutes")
            state.timers[seat]!.updateValue(seconds, forKey: "seconds")
        }
    }
    
    func swapSeats(swap: Bool, silent: Bool) {
        if swap {
            if !silent {
                let player1 = seats[1]
                let player2 = seats[2]
                seats.updateValue(player1!, forKey: 2)
                seats.updateValue(player2!, forKey: 1)
            }
            state.dPenteState = .swapped
        } else {
            state.dPenteState = .notSwapped
        }
    }
    func undoLastMove() {
        let newMoves = moves[0..<(moves.count-1)]
        blackCaptures = 0
        whiteCaptures = 0
        abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
        moves.removeAll()
        for move in newMoves {
            addMove(move: move)
        }
        
    }
    func currentPlayer() -> Int {
        if game != 13 && game != 14 {
            return 1 + (moves.count % 2)
        } else {
            if moves.count == 0 {
                return 1
            }
            return 2 - (((moves.count - 1) / 2) % 2)
        }
    }
    func currentPlayerName() -> String {
        var seat = currentPlayer()
        if (game == 7 || game == 8 || game == 17 || game == 18) && moves.count < 4 {
            seat = 1
        }

        if let player = seats[seat] {
            return player.name
        }
        return ""
    }
    func gameName() -> String {
        return gameNames[game]!
    }
    func gameColor() -> UIColor {
        if game < 3 {
            return UIColor(red:0.984, green:0.851, blue:0.541, alpha:1)
        } else if game < 5 {
            return UIColor(red:0.702, green:1, blue:0.518, alpha:1)
        } else if game < 7 {
            return UIColor(red:0.612, green:1, blue:0.898, alpha:1)
        } else if game < 9 {
            return UIColor(red:0.584, green:0.753, blue:0.98, alpha:1)
        } else if game < 11 {
            return UIColor(red:0.616, green:0.545, blue:0.965, alpha:1)
        } else if game < 13 {
            return UIColor(red:0.929, green:0.639, blue:0.992, alpha:1)
        } else if game < 15 {
            return UIColor(red:0.929, green:0.639, blue:0.992, alpha:1)
        } else if game < 17 {
            return UIColor(red:0.145, green:0.729, blue:1, alpha:1)
        } else {
            return UIColor(red:1, green:165.0/255.0, blue:0, alpha:1)
        }
    }
    func makeAttributedString() -> NSAttributedString {
//        let titleAttributes = [NSFontAttributeName: UIFont.preferredFont(forTextStyle: .headline), NSForegroundColorAttributeName: UIColor(red: 255/255, green: 193/255, blue: 7/255, alpha: 1.0)]
        let titleAttributes = [NSAttributedStringKey.font: UIFont.preferredFont(forTextStyle: .headline)]
        let subtitleAttributes = [NSAttributedStringKey.font: UIFont.preferredFont(forTextStyle: .subheadline)]
        
        let titleString = NSMutableAttributedString(string: "\(gameName())", attributes: titleAttributes)
        if seats.count > 0 {
            titleString.append(NSAttributedString(string: "\n"))
            if seats.count == 2 {
                titleString.append(NSAttributedString(string: "\u{25CF} ", attributes: [NSAttributedStringKey.foregroundColor: UIColor.white]))
                titleString.append((seats[1]?.getNameString())!)
                titleString.append(NSAttributedString(string: " - \u{25CF} "))
                titleString.append((seats[2]?.getNameString())!)
            } else {
                if seats[1] != nil {
                    titleString.append(NSAttributedString(string: "\u{25CF} ", attributes: [NSAttributedStringKey.foregroundColor: UIColor.white]))
                    titleString.append((seats[1]?.getNameString())!)
                } else if seats[2] != nil {
                    titleString.append(NSAttributedString(string: "\u{25CF} "))
                    titleString.append((seats[2]?.getNameString())!)
                }
            }
        }
        titleString.append(NSAttributedString(string: "\n"))
        let subtitleString = NSMutableAttributedString(string: NSLocalizedString("Timer: \(timer["initialMinutes"]!)/\(timer["incrementalSeconds"]!)", comment: ""))
        if rated {
            subtitleString.append(NSAttributedString(string: NSLocalizedString(", rated ", comment: "")))
        } else {
            subtitleString.append(NSAttributedString(string: NSLocalizedString(", not rated ", comment: "")))
        }
        if players.count > 0 {
            subtitleString.append(NSAttributedString(string: "\n"))
            subtitleString.append(NSAttributedString(string: NSLocalizedString("Watching: ", comment: "")))
        }
        subtitleString.setAttributes(subtitleAttributes, range: NSRange(location: 0, length: subtitleString.string.characters.count))
        for player in players.values {
            if !amIseated(i: player.name) {
                subtitleString.append(player.getNameString())
                subtitleString.append(NSAttributedString(string: ", "))
            }
        }
        titleString.append(subtitleString)
        
        return titleString
    }
    
    func detectCapture(move: Int, color: Int) {
        let i = move / 19
        let j = move % 19
        let myColor = color
        let opponentColor = 3 - color
        if ((i-3) > -1) {
            if (abstractBoard[i-3][j] == myColor) {
                if ((abstractBoard[i-1][j] == opponentColor) && (abstractBoard[i-2][j] == opponentColor)) {
                    abstractBoard[i-1][j] = 0
                    abstractBoard[i-2][j] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 2
                    } else {
                        blackCaptures = blackCaptures + 2
                    }
                }
            }
        }
        if (((i-3) > -1) && ((j-3) > -1)) {
            if (abstractBoard[i-3][j-3] == myColor) {
                if ((abstractBoard[i-1][j-1] == opponentColor) && (abstractBoard[i-2][j-2] == opponentColor)) {
                    abstractBoard[i-1][j-1] = 0
                    abstractBoard[i-2][j-2] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 2
                    } else {
                        blackCaptures = blackCaptures + 2
                    }
                }
            }
        }
        if ((j-3) > -1) {
            if (abstractBoard[i][j-3] == myColor) {
                if ((abstractBoard[i][j-1] == opponentColor) && (abstractBoard[i][j-2] == opponentColor)) {
                    abstractBoard[i][j-1] = 0
                    abstractBoard[i][j-2] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 2
                    } else {
                        blackCaptures = blackCaptures + 2
                    }
                }
            }
        }
        if (((i+3) < 19) && ((j-3) > -1)) {
            if (abstractBoard[i+3][j-3] == myColor) {
                if ((abstractBoard[i+1][j-1] == opponentColor) && (abstractBoard[i+2][j-2] == opponentColor)) {
                    abstractBoard[i+1][j-1] = 0
                    abstractBoard[i+2][j-2] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 2
                    } else {
                        blackCaptures = blackCaptures + 2
                    }
                }
            }
        }
        if ((i+3) < 19) {
            if (abstractBoard[i+3][j] == myColor) {
                if ((abstractBoard[i+1][j] == opponentColor) && (abstractBoard[i+2][j] == opponentColor)) {
                    abstractBoard[i+1][j] = 0
                    abstractBoard[i+2][j] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 2
                    } else {
                        blackCaptures = blackCaptures + 2
                    }
                }
            }
        }
        if (((i+3) < 19) && ((j+3) < 19)) {
            if (abstractBoard[i+3][j+3] == myColor) {
                if ((abstractBoard[i+1][j+1] == opponentColor) && (abstractBoard[i+2][j+2] == opponentColor)) {
                    abstractBoard[i+1][j+1] = 0
                    abstractBoard[i+2][j+2] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 2
                    } else {
                        blackCaptures = blackCaptures + 2
                    }
                }
            }
        }
        if ((j+3) < 19) {
            if (abstractBoard[i][j+3] == myColor) {
                if ((abstractBoard[i][j+1] == opponentColor) && (abstractBoard[i][j+2] == opponentColor)) {
                    abstractBoard[i][j+1] = 0
                    abstractBoard[i][j+2] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 2
                    } else {
                        blackCaptures = blackCaptures + 2
                    }
                }
            }
        }
        if (((i-3) > -1) && ((j+3) < 19)) {
            if (abstractBoard[i-3][j+3] == myColor) {
                if ((abstractBoard[i-1][j+1] == opponentColor) && (abstractBoard[i-2][j+2] == opponentColor)) {
                    abstractBoard[i-1][j+1] = 0
                    abstractBoard[i-2][j+2] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 2
                    } else {
                        blackCaptures = blackCaptures + 2
                    }
                }
            }
        }
    }
    func detectKeryoCapture(move: Int, color: Int) {
        let i = move / 19
        let j = move % 19
        let myColor = color
        let opponentColor = 3 - color
        if ((i-4) > -1) {
            if (abstractBoard[i-4][j] == myColor) {
                if ((abstractBoard[i-1][j] == opponentColor) && (abstractBoard[i-2][j] == opponentColor) && (abstractBoard[i-3][j] == opponentColor)) {
                    abstractBoard[i-1][j] = 0
                    abstractBoard[i-2][j] = 0
                    abstractBoard[i-3][j] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 3
                    } else {
                        blackCaptures = blackCaptures + 3
                    }
                }
            }
        }
        if (((i-4) > -1) && ((j-4) > -1)) {
            if (abstractBoard[i-4][j-4] == myColor) {
                if ((abstractBoard[i-1][j-1] == opponentColor) && (abstractBoard[i-2][j-2] == opponentColor) && (abstractBoard[i-3][j-3] == opponentColor)) {
                    abstractBoard[i-1][j-1] = 0
                    abstractBoard[i-2][j-2] = 0
                    abstractBoard[i-3][j-3] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 3
                    } else {
                        blackCaptures = blackCaptures + 3
                    }
                }
            }
        }
        if ((j-4) > -1) {
            if (abstractBoard[i][j-4] == myColor) {
                if ((abstractBoard[i][j-1] == opponentColor) && (abstractBoard[i][j-2] == opponentColor) && (abstractBoard[i][j-3] == opponentColor)) {
                    abstractBoard[i][j-1] = 0
                    abstractBoard[i][j-2] = 0
                    abstractBoard[i][j-3] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 3
                    } else {
                        blackCaptures = blackCaptures + 3
                    }
                }
            }
        }
        if (((i+4) < 19) && ((j-4) > -1)) {
            if (abstractBoard[i+4][j-4] == myColor) {
                if ((abstractBoard[i+1][j-1] == opponentColor) && (abstractBoard[i+2][j-2] == opponentColor) && (abstractBoard[i+3][j-3] == opponentColor)) {
                    abstractBoard[i+1][j-1] = 0
                    abstractBoard[i+2][j-2] = 0
                    abstractBoard[i+3][j-3] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 3
                    } else {
                        blackCaptures = blackCaptures + 3
                    }
                }
            }
        }
        if ((i+4) < 19) {
            if (abstractBoard[i+4][j] == myColor) {
                if ((abstractBoard[i+1][j] == opponentColor) && (abstractBoard[i+2][j] == opponentColor) && (abstractBoard[i+3][j] == opponentColor)) {
                    abstractBoard[i+1][j] = 0
                    abstractBoard[i+2][j] = 0
                    abstractBoard[i+3][j] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 3
                    } else {
                        blackCaptures = blackCaptures + 3
                    }
                }
            }
        }
        if (((i+4) < 19) && ((j+4) < 19)) {
            if (abstractBoard[i+4][j+4] == myColor) {
                if ((abstractBoard[i+1][j+1] == opponentColor) && (abstractBoard[i+2][j+2] == opponentColor) && (abstractBoard[i+3][j+3] == opponentColor)) {
                    abstractBoard[i+1][j+1] = 0
                    abstractBoard[i+2][j+2] = 0
                    abstractBoard[i+3][j+3] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 3
                    } else {
                        blackCaptures = blackCaptures + 3
                    }
                }
            }
        }
        if ((j+4) < 19) {
            if (abstractBoard[i][j+4] == myColor) {
                if ((abstractBoard[i][j+1] == opponentColor) && (abstractBoard[i][j+2] == opponentColor) && (abstractBoard[i][j+3] == opponentColor)) {
                    abstractBoard[i][j+1] = 0
                    abstractBoard[i][j+2] = 0
                    abstractBoard[i][j+3] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 3
                    } else {
                        blackCaptures = blackCaptures + 3
                    }
                }
            }
        }
        if (((i-4) > -1) && ((j+4) < 19)) {
            if (abstractBoard[i-4][j+4] == myColor) {
                if ((abstractBoard[i-1][j+1] == opponentColor) && (abstractBoard[i-2][j+2] == opponentColor) && (abstractBoard[i-3][j+3] == opponentColor)) {
                    abstractBoard[i-1][j+1] = 0
                    abstractBoard[i-2][j+2] = 0
                    abstractBoard[i-3][j+3] = 0
                    if (opponentColor == 1) {
                        whiteCaptures = whiteCaptures + 3
                    } else {
                        blackCaptures = blackCaptures + 3
                    }
                }
            }
        }
    }
    func detectPoof(move: Int, color: Int) {
        let i = move / 19
        let j = move % 19
        let myColor = color
        let opponentColor = 3 - color
        var poof = false
        if (((i-2) > -1) && ((i+1) < 19)) {
            if (abstractBoard[i-1][j] == myColor) {
                if ((abstractBoard[i-2][j] == opponentColor) && (abstractBoard[i+1][j] == opponentColor)) {
                    poof = true
                    abstractBoard[i-1][j] = 0
                    abstractBoard[i][j] = 0
                    if (myColor == 1) {
                        whiteCaptures = whiteCaptures + 1
                    } else {
                        blackCaptures = blackCaptures + 1
                    }
                }
            }
        }
        if (((i-2) > -1) && ((j-2) > -1) && ((i+1) < 19) && ((j+1) < 19)) {
            if (abstractBoard[i-1][j-1] == myColor) {
                if ((abstractBoard[i-2][j-2] == opponentColor) && (abstractBoard[i+1][j+1] == opponentColor)) {
                    poof = true
                    abstractBoard[i-1][j-1] = 0
                    abstractBoard[i][j] = 0
                    if (myColor == 1) {
                        whiteCaptures = whiteCaptures + 1
                    } else {
                        blackCaptures = blackCaptures + 1
                    }
                }
            }
        }
        if (((j-2) > -1) && ((j+1) < 19)) {
            if (abstractBoard[i][j-1] == myColor) {
                if ((abstractBoard[i][j-2] == opponentColor) && (abstractBoard[i][j+1] == opponentColor)) {
                    poof = true
                    abstractBoard[i][j-1] = 0
                    abstractBoard[i][j] = 0
                    if (myColor == 1) {
                        whiteCaptures = whiteCaptures + 1
                    } else {
                        blackCaptures = blackCaptures + 1
                    }
                }
            }
        }
        if (((i-1) > -1) && ((j-2) > -1) && ((i+2) < 19) && ((j+1) < 19)) {
            if (abstractBoard[i+1][j-1] == myColor) {
                if ((abstractBoard[i-1][j+1] == opponentColor) && (abstractBoard[i+2][j-2] == opponentColor)) {
                    poof = true
                    abstractBoard[i+1][j-1] = 0
                    abstractBoard[i][j] = 0
                    if (myColor == 1) {
                        whiteCaptures = whiteCaptures + 1
                    } else {
                        blackCaptures = blackCaptures + 1
                    }
                }
            }
        }
        if (((i+2) < 19) && ((i-1) > -1)) {
            if (abstractBoard[i+1][j] == myColor) {
                if ((abstractBoard[i+2][j] == opponentColor) && (abstractBoard[i-1][j] == opponentColor)) {
                    poof = true
                    abstractBoard[i+1][j] = 0
                    abstractBoard[i][j] = 0
                    if (myColor == 1) {
                        whiteCaptures = whiteCaptures + 1
                    } else {
                        blackCaptures = blackCaptures + 1
                    }
                }
            }
        }
        if (((i-1) > -1) && ((j-1) > -1) && ((i+2) < 19) && ((j+2) < 19)) {
            if (abstractBoard[i+1][j+1] == myColor) {
                if ((abstractBoard[i-1][j-1] == opponentColor) && (abstractBoard[i+2][j+2] == opponentColor)) {
                    poof = true
                    abstractBoard[i+1][j+1] = 0
                    abstractBoard[i][j] = 0
                    if (myColor == 1) {
                        whiteCaptures = whiteCaptures + 1
                    } else {
                        blackCaptures = blackCaptures + 1
                    }
                }
            }
        }
        if (((j+2) < 19) && ((j-1) > -1)) {
            if (abstractBoard[i][j+1] == myColor) {
                if ((abstractBoard[i][j-1] == opponentColor) && (abstractBoard[i][j+2] == opponentColor)) {
                    poof = true
                    abstractBoard[i][j+1] = 0
                    abstractBoard[i][j] = 0
                    if (myColor == 1) {
                        whiteCaptures = whiteCaptures + 1
                    } else {
                        blackCaptures = blackCaptures + 1
                    }
                }
            }
        }
        if (((i-2) > -1) && ((j-1) > -1) && ((i+1) < 19) && ((j+2) < 19)) {
            if (abstractBoard[i-1][j+1] == myColor) {
                if ((abstractBoard[i+1][j-1] == opponentColor) && (abstractBoard[i-2][j+2] == opponentColor)) {
                    poof = true
                    abstractBoard[i-1][j+1] = 0
                    abstractBoard[i][j] = 0
                    if (myColor == 1) {
                        whiteCaptures = whiteCaptures + 1
                    } else {
                        blackCaptures = blackCaptures + 1
                    }
                }
            }
        }
        
        if (poof) {
            if (myColor == 1) {
                whiteCaptures = whiteCaptures + 1
            } else {
                blackCaptures = blackCaptures + 1
            }
        }
    }
}

class GameState: NSObject {
    enum State:Int {
        case notStarted = 1
        case started
        case paused
        case halfSet
    }
    enum DPenteState: Int {
        case noChoice = 0
        case swapped
        case notSwapped
    }
    var state = State.notStarted
    var dPenteState = DPenteState.noChoice
    var timers = [1: ["minutes":0, "seconds":0], 2: ["minutes":0, "seconds":0]]
    
}


class TablesAndPlayer: NSObject {
    var tables: [Int:Table] = [:]
    var players: [String: LivePlayer] = [:]
    
    func player(name: String) -> LivePlayer? {
        return players[name]
    }
    func addPlayer(player: LivePlayer) {
        players.updateValue(player, forKey: player.name)
    }
    func removePlayer(player: String) {
        players.removeValue(forKey: player)
    }
    func joinTable(tableId: Int, player: String) {
        if self.tables[tableId] == nil {
            self.tables.updateValue(Table(table: tableId), forKey: tableId)
        }
        let table = self.tables[tableId]!
        table.addPlayer(player: self.players[player]!)
    }
    func table(tableId: Int) -> Table? {
        return tables[tableId]
    }
    func exitTable(tableId: Int, player: String) {
        if self.tables[tableId] == nil {
            return
        }
        let table = self.tables[tableId]!
        table.removePlayer(player: player)
        if table.players.count == 0 && table.seats.count == 0 {
            self.tables.removeValue(forKey: tableId)
        }
    }
    func changeTable(event: [String: Any]) {
        let tableId = event["table"] as! Int
        if tables[tableId] == nil {
            self.tables.updateValue(Table(table: tableId), forKey: tableId)
        }
        let table = tables[tableId]!
        table.changeState(state: event)
    }
    func sitTable(tableId: Int, player: String, seat: Int) {
        if self.tables[tableId] == nil {
            return
        }
        let table = self.tables[tableId]!
        let livePlayer = self.players[player]!
        table.sit(seat: seat, player: livePlayer)
    }
    func standTable(tableId: Int, player: String) {
        if self.tables[tableId] == nil {
            return
        }
        let table = self.tables[tableId]!
        table.stand(player: player)
    }
    func ownerTable(tableId: Int, player: String) {
        if self.tables[tableId] == nil {
            return
        }
        let table = self.tables[tableId]!
        table.owner = player
    }
    func updateTimerTable(tableId: Int, player: String, minutes: Int, seconds: Int) {
        if self.tables[tableId] == nil {
            return
        }
        let table = self.tables[tableId]!
        table.updateTimer(playerName: player, minutes: minutes, seconds: seconds)
    }
    func gameStateChange(tableId: Int, state: GameState.State) {
        if self.tables[tableId] == nil {
            return
        }
        let table = self.tables[tableId]!
        if state == .started && table.state.state != .paused {
            table.reset()
        }
        table.state.state = state
    }
    func swapSeats(tableId: Int, swap: Bool, silent: Bool) {
        if self.tables[tableId] == nil {
            return
        }
        let table = self.tables[tableId]!
        table.swapSeats(swap: swap, silent: silent)
    }
    
    func invitablePlayersFor(tableId: Int) -> [String] {
        if self.tables[tableId] == nil {
            return []
        }
        let table = self.tables[tableId]!
        var invitablePlayers: [String] = Array(self.players.keys)
        for player in table.players.keys {
            invitablePlayers = invitablePlayers.filter {$0 != player}
        }
        for table in self.tables.values {
            if table.table == tableId {
                continue
            }
            for player in table.seats.values {
                invitablePlayers = invitablePlayers.filter {$0 != player.name}
            }
        }
        return invitablePlayers
    }
    func bootablePlayersFor(tableId: Int) -> [String] {
        if self.tables[tableId] == nil {
            return []
        }
        let table = self.tables[tableId]!
        var bootablePlayers: [String] = Array(table.players.keys)
        bootablePlayers = bootablePlayers.filter {$0 != table.owner}
        return bootablePlayers
    }
    
    
}



















