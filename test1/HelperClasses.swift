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
    var ratings = [Int: Int]()
    var color: UIColor!
    var subscriber = false
    var crown: Int = 0
    var muted: Bool = false
    
    init(name: String) {
        self.name = name
    }
    
    func getNameString() -> NSAttributedString {
        let text = NSMutableAttributedString(string: name)
        if subscriber {
            text.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: NSRange(location: 0, length: name.count))
            text.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "HelveticaNeue-Bold", size: 17)!, range: NSRange(location: 0, length: name.count))
        } else {
            text.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "HelveticaNeue", size: 17)!, range: NSRange(location: 0, length: name.count))
        }
        let textAttachment = NSTextAttachment()
        switch crown {
        case 1:
            textAttachment.image = UIImage(named: "crown.gif")
        case 2:
            textAttachment.image = UIImage(named: "scrown.gif")
        case 3:
            textAttachment.image = UIImage(named: "bcrown.gif")
        default:
            if crown > 3 {
                textAttachment.image = UIImage(named: "kothcrown\(crown - 3)")
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
        } else if ratingInt >= 1700 {
            ratingColor = UIColor(red: 0.98, green: 0.96, blue: 0.03, alpha: 1.0)
        } else if ratingInt >= 1400 {
            ratingColor = UIColor.blue
        } else if ratingInt >= 1000 {
            ratingColor = UIColor(red: 30.0 / 255, green: 130.0 / 255, blue: 76.0 / 255, alpha: 1.0)
        } else {
            ratingColor = UIColor.gray
        }
        text = text + "\(ratingInt)"
        let coloredText = NSMutableAttributedString(string: text)
        coloredText.addAttribute(NSAttributedString.Key.foregroundColor, value: ratingColor, range: NSRange(location: 0, length: 1))
        coloredText.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "HelveticaNeue-Bold", size: 12.0)!, range: NSRange(location: 0, length: 1))
        return coloredText
    }
}

enum GameEnum: Int {
    case pente = 1, speedPente, keryoPente, speedKeryoPente, gomoku, speedGomoku, dPente, speedDPente, gPente, speedGPente, poofPente, speedPoofPente, connect6, speedConnect6, boatPente, speedBoatPente, dkPente, speedDKPente, go, speedGo, go9x9, speedGo9x9, go13x13, speedGo13x13, oPente, speedOPente, swap2Pente, speedSwap2Pente, swap2Keryo, speedSwap2Keryo
}

class Table: NSObject {
    var players = [String: LivePlayer]()
    var timed = false
    var timer = ["initialMinutes": 0, "incrementalSeconds": 0]
    var game = 1 {
        didSet {
            if game != oldValue {
                engine = PenteGame(variant: penteVariant(for: game))
            }
        }
    }
    var open = true
    var rated = false
    var table = 1
    var seats = [Int: LivePlayer]()
    var owner = ""
    let state = GameState()
    var moves = [Int]()
    var abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
    var whiteCaptures = 0
    var blackCaptures = 0
    private var engine = PenteGame(variant: .pente)
    private(set) var lastMoveResult: MoveResult?
    var onCaptures: (([Capture]) -> Void)?
    var goDeadStonesByPlayer = [Int: [Int]]()
    var goTerritoryByPlayer = [Int: [Int]]()
    
    var koMove = -1
    var goGame = GoGame(gridSize: 19)
    
    static let gameNames = [1: "Pente", 2: "Speed Pente", 3: "Keryo-Pente", 4: "Speed Keryo-Pente", 5: "Gomoku",
                     6: "Speed Gomoku", 7: "D-Pente", 8: "Speed D-Pente", 9: "G-Pente", 10: "Speed G-Pente",
                     11: "Poof-Pente", 12: "Speed Poof-Pente", 13: "Connect6", 14: "Speed Connect6",
                     15: "Boat-Pente", 16: "Speed Boat-Pente", 17: "DK-Pente", 18: "Speed DK-Pente",
                     19: "Go", 20: "Speed Go", 21: "Go (9x9)", 22: "Speed Go (9x9)", 23: "Go (13x13)",
                     24: "Speed Go (13x13)", 25: "O-Pente", 26: "Speed O-Pente", 27: "Swap2-Pente",
                     28: "Speed Swap2-Pente", 29: "Swap2-Keryo", 30: "Speed Swap2-Keryo"]
    
    init(table: Int) {
        self.table = table
        super.init()
    }
    
    func shouldTimerRun() -> Bool {
        if timed {
            if moves.isEmpty {
                let gameName = Table.gameNames[game]!
                if gameName.contains("D-") || gameName.contains("DK-") || gameName.contains("Go") || gameName.contains("Swap2") {
                    return true
                }
                return false
            }
            return true
        }
        return false
    }
    
    func isDPente() -> Bool {
        return game == GameEnum.dPente.rawValue || game == GameEnum.speedDPente.rawValue || game == GameEnum.dkPente.rawValue || game == GameEnum.speedDKPente.rawValue
    }
    
    func isSwap2() -> Bool {
        return game == GameEnum.swap2Pente.rawValue || game == GameEnum.speedSwap2Pente.rawValue || game == GameEnum.swap2Keryo.rawValue || game == GameEnum.speedSwap2Keryo.rawValue
    }
    
    func isSwap2ChoiceWithPassOption() -> Bool {
        return isSwap2() && moves.count == 3 && state.swap2State == .noChoice
    }
    
    func isSwap2ChoiceWithoutPassOption() -> Bool {
        return isSwap2() && moves.count == 5 && (state.swap2State == .swap2Pass || state.swap2State == .noChoice)
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
    
    func changeState(state: [String: Any]) {
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
        goDeadStonesByPlayer.removeAll(); goDeadStonesByPlayer[1] = [Int](); goDeadStonesByPlayer[2] = [Int]()
        goTerritoryByPlayer.removeAll(); goTerritoryByPlayer[1] = [Int](); goTerritoryByPlayer[2] = [Int]()
        goGame = GoGame(gridSize: 19)
        //        state.dPenteState = .noChoice
        //        state.swap2State = .noChoice
        state.goState = .play
        blackCaptures = 0
        whiteCaptures = 0
        if isGo() {
            for move in moves {
                addMove(move: move)
            }
            return
        }
        // Pente-family: rebuild the whole position in one engine call (replay resets
        // the engine internally) and mirror it back. Unlike the per-move addMove loop
        // this stays silent — no onCaptures animation fires during a bulk load.
        lastMoveResult = engine.replay(moves, until: moves.count)
        self.moves = moves
        syncFromEngine()
    }

    func showMarkStones(player: String) -> Bool {
        //        return false
        //        print(isGo())
        //        print(state.goState)
        //        print(doublePassMove())
        //        print(moves.count)
        //        print(currentPlayerName())
        //        print(player)
        return isGo() && (state.goState == .markStones) && (doublePassMove() == moves.count - 1) && (currentPlayerName() == player)
    }
    
    func showEvaluateStones(player: String) -> Bool {
        var notOver = true
        if doublePassMove() < moves.count - 2 && moves.count > 3 && moves[moves.count - 1] == passMove && moves[moves.count - 2] == passMove {
            notOver = false
        }
        return isGo() && (state.goState == .evaluateStones) && state.state == .started && (currentPlayerName() == player) && notOver
    }
    
    func lastMove() -> Int {
        if moves.count > 0 {
            return moves.last!
        }
        return -1
    }
    
    func gameHasCaptures() -> Bool {
        return game != GameEnum.gomoku.rawValue && game != GameEnum.speedGomoku.rawValue && game != GameEnum.connect6.rawValue && game != GameEnum.speedConnect6.rawValue
    }
    
    // Maps the live-room game id (GameEnum 1...30) to the engine variant.
    // Boat-Pente shares Pente rules; Go ids never reach the engine (isGo() short-circuits).
    private func penteVariant(for game: Int) -> PenteVariant {
        switch GameEnum(rawValue: game) {
        case .keryoPente, .speedKeryoPente: return .keryoPente
        case .oPente, .speedOPente: return .oPente
        case .poofPente, .speedPoofPente: return .poofPente
        case .dPente, .speedDPente: return .dPente
        case .dkPente, .speedDKPente: return .dkPente
        case .gPente, .speedGPente: return .gpente
        case .swap2Pente, .speedSwap2Pente: return .swap2Pente
        case .swap2Keryo, .speedSwap2Keryo: return .swap2Keryo
        case .gomoku, .speedGomoku: return .gomoku
        case .connect6, .speedConnect6: return .connect6
        default: return .pente
        }
    }

    // Read accessor used by tests and renderers: the engine is the source of truth
    // for Pente-family games; Go keeps its own board.
    func stone(at rowCol: Int) -> Int {
        if isGo() {
            return abstractBoard[rowCol / gridSize][rowCol % gridSize]
        }
        return engine.stone(at: rowCol)
    }

    // Mirror the engine board + counters into the stored arrays the renderers read.
    private func syncFromEngine() {
        // Legacy applied the tournament opening mask (the centre -1 cells) only when
        // `rated || (speed)gPente`. The engine now masks intrinsically for every
        // Pente/Keryo/Poof/OPente variant, so for unrated non-gPente games we must
        // drop those -1 cells back to empty — otherwise the renderer / tap-gating
        // (TableViewController: `hideStone = abstractBoard != 0`) would wrongly block
        // the centre. Rated games and (speed)gPente keep the mask, matching legacy.
        let maskAllowed = rated || game == GameEnum.gPente.rawValue || game == GameEnum.speedGPente.rawValue
        for r in 0 ..< 19 {
            for c in 0 ..< 19 {
                let value = engine.stone(at: r * 19 + c)
                abstractBoard[r][c] = (value == -1 && !maskAllowed) ? 0 : value
            }
        }
        whiteCaptures = engine.whiteCaptures
        blackCaptures = engine.blackCaptures
    }

    func addMove(move: Int) {
        if isGo() {
            addGoMove(move: move)
            return
        }
        let result = engine.play(move)
        moves.append(move)
        syncFromEngine()
        lastMoveResult = result
        if !result.captured.isEmpty {
            onCaptures?(result.captured)
        }
    }
    
    var hasPass = false, doublePass = false
    var gridSize = 19, passMove = 19 * 19
    
    func addGoMove(move: Int) {
        if game == GameEnum.speedGo9x9.rawValue || game == GameEnum.go9x9.rawValue {
            gridSize = 9
        } else if game == GameEnum.go13x13.rawValue || game == GameEnum.speedGo13x13.rawValue {
            gridSize = 13
        } else {
            gridSize = 19
        }
        passMove = gridSize * gridSize
        if goGame.gridSize != gridSize {
            goGame = GoGame(gridSize: gridSize)
            goGame.replay(moves, until: moves.count)
        }
        goGame.play(move)
        moves.append(move)
        syncFromGoGame()
    }

    func syncFromGoGame() {
        for pos in 0 ..< (gridSize * gridSize) {
            let i = pos / gridSize, j = pos % gridSize
            abstractBoard[i][j] = goGame.stone(at: pos)
        }
        whiteCaptures = goGame.whiteCaptures
        blackCaptures = goGame.blackCaptures
        koMove = goGame.koMove
        goDeadStonesByPlayer[1] = goGame.blackDeadStones
        goDeadStonesByPlayer[2] = goGame.whiteDeadStones
        switch goGame.phase {
        case .play: state.goState = .play
        case .markStones: state.goState = .markStones
        case .evaluateStones: state.goState = .evaluateStones
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
        engine.reset()
        lastMoveResult = nil
        goDeadStonesByPlayer.removeAll(); goDeadStonesByPlayer[1] = [Int](); goDeadStonesByPlayer[2] = [Int]()
        goTerritoryByPlayer.removeAll(); goTerritoryByPlayer[1] = [Int](); goTerritoryByPlayer[2] = [Int]()
        goGame = GoGame(gridSize: 19)
        state.dPenteState = .noChoice
        state.swap2State = .noChoice
        state.goState = .play
    }
    
    func resetTimers() {
        let minutes = timer["initialMinutes"]!
        var seconds = 0
        if minutes == 0 {
            seconds = timer["incrementalSeconds"]!
        }
        let millis = (minutes * 60 + seconds) * 1000
        state.timers[1]!.updateValue(millis, forKey: "millis")
        state.timers[2]!.updateValue(millis, forKey: "millis")
    }
    
    func updateTimer(playerName: String, millis: Int) {
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
            state.timers[seat]!.updateValue(millis, forKey: "millis")
            state.timers[seat]!.updateValue(0, forKey: "startTime")
        }
    }
    
    func swapSeats(swap: Bool, silent: Bool) {
        if swap {
            if !silent {
                let player1 = seats[1]
                let player2 = seats[2]
                seats.updateValue(player1!, forKey: 2)
                seats.updateValue(player2!, forKey: 1)
                if timed {
                    let millis1 = state.timers[1]!["millis"]
                    let millis2 = state.timers[2]!["millis"]
                    state.timers[1]!.updateValue(millis2!, forKey: "millis")
                    state.timers[2]!.updateValue(millis1!, forKey: "millis")
                }
            }
            state.dPenteState = .swapped
            state.swap2State = .swapped
        } else {
            state.dPenteState = .notSwapped
            state.swap2State = .notSwapped
        }
    }
    
    func swap2Pass(silent _: Bool) {
        state.swap2State = .swap2Pass
    }
    
    func undoLastMove() {
        guard !moves.isEmpty else { return }
        let newMoves = Array(moves[0 ..< (moves.count - 1)])
        blackCaptures = 0
        whiteCaptures = 0
        abstractBoard = Array(repeating: Array(repeating: 0, count: 19), count: 19)
        moves.removeAll()
        goDeadStonesByPlayer.removeAll(); goDeadStonesByPlayer[1] = [Int](); goDeadStonesByPlayer[2] = [Int]()
        goTerritoryByPlayer.removeAll(); goTerritoryByPlayer[1] = [Int](); goTerritoryByPlayer[2] = [Int]()
        goGame = GoGame(gridSize: 19)
        koMove = -1
        state.dPenteState = .noChoice
        state.goState = .play
        if isGo() {
            for move in newMoves {
                addMove(move: move)
            }
            return
        }
        // Pente-family: rebuild the surviving position in one engine call (replay
        // resets the engine internally) so undone stones/captures don't persist.
        lastMoveResult = engine.replay(newMoves, until: newMoves.count)
        moves = newMoves
        syncFromEngine()
    }
    
    func currentPlayer() -> Int {
        if isGo() {
            let d = doublePassMove()
            if state.goState == .evaluateStones {
                return 1 + d % 2
            } else if state.goState == .markStones {
                return 2 - d % 2
            } else {
                return 1 + (moves.count % 2)
            }
        } else if game != GameEnum.connect6.rawValue && game != GameEnum.speedConnect6.rawValue {
            return 1 + (moves.count % 2)
        } else {
            if moves.count == 0 {
                return 1
            }
            return 2 - (((moves.count - 1) / 2) % 2)
        }
    }
    
    func doublePassMove() -> Int {
        var pass = false, i = 0
        for move in moves {
            if move == passMove {
                if pass {
                    return i
                } else {
                    pass = true
                }
            } else {
                pass = false
            }
            i += 1
        }
        return -1
    }
    
    func currentPlayerName() -> String {
        var seat = currentPlayer()
        if (game == GameEnum.dPente.rawValue || game == GameEnum.speedDPente.rawValue || game == GameEnum.dkPente.rawValue || game == GameEnum.speedDKPente.rawValue) && moves.count < 4 {
            seat = 1
        }
        if isSwap2() {
            if moves.count < 3 {
                seat = 1
            } else if (state.swap2State == .swap2Pass || state.swap2State == .noChoice) && moves.count < 5 {
                seat = 2
            }
        }
        
        if let player = seats[seat] {
            return player.name
        }
        return ""
    }
    
    func gameName() -> String {
        return Table.gameNames[game]!
    }
    
    func gameColor() -> UIColor {
        if game < GameEnum.keryoPente.rawValue {
            return UIColor(red: 0.984, green: 0.851, blue: 0.541, alpha: 1)
        } else if game < GameEnum.gomoku.rawValue {
            return UIColor(red: 0.702, green: 1, blue: 0.518, alpha: 1)
        } else if game < GameEnum.dPente.rawValue {
            return UIColor(red: 0.612, green: 1, blue: 0.898, alpha: 1)
        } else if game < GameEnum.gPente.rawValue {
            return UIColor(red: 0.584, green: 0.753, blue: 0.98, alpha: 1)
        } else if game < GameEnum.poofPente.rawValue {
            return UIColor(red: 0.616, green: 0.545, blue: 0.965, alpha: 1)
        } else if game < GameEnum.connect6.rawValue {
            return UIColor(red: 0.929, green: 0.639, blue: 0.992, alpha: 1)
        } else if game < GameEnum.boatPente.rawValue {
            return UIColor(red: 0.929, green: 0.639, blue: 0.992, alpha: 1)
        } else if game < GameEnum.dkPente.rawValue {
            return UIColor(red: 0.145, green: 0.729, blue: 1, alpha: 1)
        } else if game < GameEnum.go.rawValue {
            return UIColor(red: 1, green: 165.0 / 255.0, blue: 0, alpha: 1)
        } else if game < GameEnum.oPente.rawValue {
            return UIColor(red: 250.0 / 255, green: 200.0 / 255.0, blue: 50.0 / 255.0, alpha: 1)
        } else if game < GameEnum.swap2Pente.rawValue {
            return UIColor(red: 0.32, green: 0.75, blue: 0.50, alpha: 1.0)
        } else if game < GameEnum.swap2Keryo.rawValue {
            return UIColor(red: 0.90, green: 0.67, blue: 0.44, alpha: 1.00)
        } else {
            return UIColor(red: 0.31, green: 0.78, blue: 0.47, alpha: 1.00)
        }
    }
    
    func isGo() -> Bool {
        return game >= GameEnum.go.rawValue && game < GameEnum.oPente.rawValue
    }
    
    func getGoScoreString() -> String {
        getTerritories()
        return goGame.scoreString()
    }

    // Mirror GoGame's territory back into goTerritoryByPlayer for the renderer.
    // Retained (not in the plan's literal replacement) because TableViewController
    // calls table.getTerritories() directly to refresh territory overlays.
    func getTerritories() {
        goTerritoryByPlayer[1] = goGame.territory(forPlayer: 1)
        goTerritoryByPlayer[2] = goGame.territory(forPlayer: 2)
    }
    
    func rejectDeadStones() {
        let i = doublePassMove() - 1
        let newMoves = Array(moves[0 ..< i])
        addMoves(moves: newMoves)
    }
    
    func makeFontBlackIfNeeded(seat: Int) -> NSAttributedString {
        if seats[seat]!.subscriber {
            return (seats[seat]?.getNameString())!
        } else {
            let str = NSMutableAttributedString(attributedString: (seats[seat]?.getNameString())!)
            str.addAttribute(.foregroundColor, value: UIColor.black, range: NSMakeRange(0, (seats[seat]?.name.count)!))
            return str
        }
    }
    
    func makeAttributedString() -> NSAttributedString {
        //        let titleAttributes = [NSFontAttributeName: UIFont.preferredFont(forTextStyle: .headline), NSForegroundColorAttributeName: UIColor(red: 255/255, green: 193/255, blue: 7/255, alpha: 1.0)]
        let titleAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline)]
        let subtitleAttributes = [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .subheadline), NSAttributedString.Key.foregroundColor: UIColor.black]
        
        let titleString = NSMutableAttributedString(string: "\(gameName())", attributes: titleAttributes)
        titleString.addAttribute(.foregroundColor, value: UIColor.black, range: NSMakeRange(0, titleString.length))
        if seats.count > 0 {
            titleString.append(NSAttributedString(string: "\n"))
            var p1Color = UIColor.white, p2Color = UIColor.black
            if isGo() {
                p2Color = UIColor.white; p1Color = UIColor.black
            }
            if seats.count == 2 {
                titleString.append(NSAttributedString(string: "\u{25CF} ", attributes: [NSAttributedString.Key.foregroundColor: p1Color]))
                titleString.append(makeFontBlackIfNeeded(seat: 1))
                titleString.append(NSAttributedString(string: " - \u{25CF} ", attributes: [NSAttributedString.Key.foregroundColor: p2Color]))
                titleString.append(makeFontBlackIfNeeded(seat: 2))
            } else {
                if seats[1] != nil {
                    titleString.append(NSAttributedString(string: "\u{25CF} ", attributes: [NSAttributedString.Key.foregroundColor: p1Color]))
                    titleString.append(makeFontBlackIfNeeded(seat: 1))
                } else if seats[2] != nil {
                    titleString.append(NSAttributedString(string: "\u{25CF} ", attributes: [NSAttributedString.Key.foregroundColor: p2Color]))
                    titleString.append(makeFontBlackIfNeeded(seat: 2))
                }
            }
        }
        titleString.append(NSAttributedString(string: "\n"))
        var subtitleString = NSMutableAttributedString()
        if timed {
            subtitleString = NSMutableAttributedString(string: NSLocalizedString("Timer: \(timer["initialMinutes"]!)/\(timer["incrementalSeconds"]!)", comment: ""))
        } else {
            subtitleString = NSMutableAttributedString(string: "Not timed")
        }
        if rated {
            subtitleString.append(NSAttributedString(string: NSLocalizedString(", rated ", comment: "")))
        } else {
            subtitleString.append(NSAttributedString(string: NSLocalizedString(", not rated ", comment: "")))
        }
        if players.count > 0 {
            subtitleString.append(NSAttributedString(string: "\n"))
            subtitleString.append(NSAttributedString(string: NSLocalizedString("Watching: ", comment: "")))
        }
        subtitleString.setAttributes(subtitleAttributes, range: NSRange(location: 0, length: subtitleString.string.count))
        for player in players.values {
            if !amIseated(i: player.name) {
                if !player.subscriber {
                    let nameStr = NSMutableAttributedString(attributedString: player.getNameString())
                    nameStr.addAttribute(.foregroundColor, value: UIColor.black, range: NSMakeRange(0, player.name.count))
                    subtitleString.append(nameStr)
                } else {
                    subtitleString.append(player.getNameString())
                }
                subtitleString.append(NSAttributedString(string: ", "))
            }
        }
        titleString.append(subtitleString)
        
        return titleString
    }
}

class GameState: NSObject {
    enum State: Int {
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
    
    enum Swap2State: Int {
        case noChoice = 0
        case swap2Pass
        case swapped
        case notSwapped
    }
    
    enum GoState: Int {
        case play = 0
        case markStones
        case evaluateStones
    }
    
    var state = State.notStarted
    var dPenteState = DPenteState.noChoice
    var swap2State = Swap2State.noChoice
    var goState = GoState.play
    var timers = [1: ["millis": 0], 2: ["millis": 0]]
}

class TablesAndPlayer: NSObject {
    var tables: [Int: Table] = [:]
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
        if tables[tableId] == nil {
            tables.updateValue(Table(table: tableId), forKey: tableId)
        }
        let table = tables[tableId]!
        table.addPlayer(player: players[player]!)
    }
    
    func table(tableId: Int) -> Table? {
        return tables[tableId]
    }
    
    func exitTable(tableId: Int, player: String) {
        if tables[tableId] == nil {
            return
        }
        let table = tables[tableId]!
        table.removePlayer(player: player)
        if table.players.count == 0, table.seats.count == 0 {
            tables.removeValue(forKey: tableId)
        }
    }
    
    func changeTable(event: [String: Any]) {
        let tableId = event["table"] as! Int
        if tables[tableId] == nil {
            tables.updateValue(Table(table: tableId), forKey: tableId)
        }
        let table = tables[tableId]!
        table.changeState(state: event)
    }
    
    func sitTable(tableId: Int, player: String, seat: Int) {
        if tables[tableId] == nil {
            return
        }
        let table = tables[tableId]!
        let livePlayer = players[player]!
        table.sit(seat: seat, player: livePlayer)
    }
    
    func standTable(tableId: Int, player: String) {
        if tables[tableId] == nil {
            return
        }
        let table = tables[tableId]!
        table.stand(player: player)
    }
    
    func ownerTable(tableId: Int, player: String) {
        if tables[tableId] == nil {
            return
        }
        let table = tables[tableId]!
        table.owner = player
    }
    
    func updateTimerTable(tableId: Int, player: String, millis: Int) {
        if tables[tableId] == nil {
            return
        }
        let table = tables[tableId]!
        table.updateTimer(playerName: player, millis: millis)
    }
    
    func gameStateChange(tableId: Int, state: GameState.State) {
        if tables[tableId] == nil {
            return
        }
        let table = tables[tableId]!
        if state == .started, table.state.state != .paused {
            table.reset()
        }
        table.state.state = state
    }
    
    func swapSeats(tableId: Int, swap: Bool, silent: Bool) {
        if tables[tableId] == nil {
            return
        }
        let table = tables[tableId]!
        table.swapSeats(swap: swap, silent: silent)
    }
    
    func swap2Pass(tableId: Int, silent: Bool) {
        if tables[tableId] == nil {
            return
        }
        let table = tables[tableId]!
        table.swap2Pass(silent: silent)
    }
    
    func invitablePlayersFor(tableId: Int) -> [String] {
        if tables[tableId] == nil {
            return []
        }
        let table = tables[tableId]!
        var invitablePlayers: [String] = Array(players.keys)
        for player in table.players.keys {
            invitablePlayers = invitablePlayers.filter { $0 != player }
        }
        for table in tables.values {
            if table.table == tableId {
                continue
            }
            for player in table.seats.values {
                invitablePlayers = invitablePlayers.filter { $0 != player.name }
            }
        }
        return invitablePlayers
    }
    
    func bootablePlayersFor(tableId: Int) -> [String] {
        if tables[tableId] == nil {
            return []
        }
        let table = tables[tableId]!
        var bootablePlayers: [String] = Array(table.players.keys)
        bootablePlayers = bootablePlayers.filter { $0 != table.owner }
        return bootablePlayers
    }
}
