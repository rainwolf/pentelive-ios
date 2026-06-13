//
//  GoGame.swift
//  penteLive
//
//  Stateful Go engine extracted verbatim from Table (HelperClasses.swift) and
//  BoardViewController.replayGoGame. Single source of truth for Go rules:
//  board, stone groups, liberties, captures, ko and dead-stone marking.
//  Player 1 plays colour 2 (black) and moves first; player 2 plays colour 1 (white).
//

import Foundation

@objc enum GoPhase: Int {
    case play = 0
    case markStones = 1
    case evaluateStones = 2
}

@objc final class GoGame: NSObject {
    @objc let gridSize: Int
    @objc let passMove: Int

    private var board: [[Int]]
    private var groupsByPlayerAndID: [Int: [Int: [Int]]] = [:]
    private var groupIDsByPlayer: [Int: [Int: Int]] = [:]
    private var deadStonesByPlayer: [Int: [Int]] = [:]
    private var territoryByPlayer: [Int: [Int]] = [:]
    private var moves: [Int] = []

    private var hasPass = false
    private var doublePass = false

    @objc private(set) var phase: GoPhase = .play
    @objc private(set) var koMove: Int = -1
    @objc private(set) var whiteCaptures: Int = 0
    @objc private(set) var blackCaptures: Int = 0

    @objc var blackDeadStones: [Int] { return deadStonesByPlayer[1] ?? [] }
    @objc var whiteDeadStones: [Int] { return deadStonesByPlayer[2] ?? [] }
    @objc var moveCount: Int { return moves.count }

    @objc init(gridSize: Int) {
        self.gridSize = gridSize
        self.passMove = gridSize * gridSize
        self.board = Array(repeating: Array(repeating: 0, count: gridSize), count: gridSize)
        super.init()
        clearState()
    }

    private func clearState() {
        board = Array(repeating: Array(repeating: 0, count: gridSize), count: gridSize)
        groupsByPlayerAndID = [1: [Int: [Int]](), 2: [Int: [Int]]()]
        groupIDsByPlayer = [1: [Int: Int](), 2: [Int: Int]()]
        deadStonesByPlayer = [1: [Int](), 2: [Int]()]
        territoryByPlayer = [1: [Int](), 2: [Int]()]
        moves = []
        hasPass = false
        doublePass = false
        phase = .play
        koMove = -1
        whiteCaptures = 0
        blackCaptures = 0
    }

    @objc func reset() {
        clearState()
    }

    @objc func replay(_ moves: [Int], until: Int) {
        clearState()
        let count = min(until, moves.count)
        for k in 0 ..< count {
            play(moves[k])
        }
    }

    @objc func stone(at rowCol: Int) -> Int {
        return getBoardValue(move: rowCol)
    }

    // MARK: - move application (ported from Table.addGoMove)

    @objc func play(_ move: Int) {
        let player = currentPlayer(), color = 3 - player
        if move == passMove {
            if phase == .markStones {
                phase = .evaluateStones
            } else if hasPass {
                doublePass = true
                phase = .markStones
            } else {
                hasPass = true
            }
        } else {
            hasPass = false
        }
        moves.append(move)
        if phase == .markStones {
            if move != passMove {
                let p = 3 - getBoardValue(move: move)
                deadStonesByPlayer[p]?.append(move)
                setBoardValue(move: move, value: 0)
            }
        } else {
            if move < passMove {
                var groupsByID = groupsByPlayerAndID[player]!, stoneGroupIDs = groupIDsByPlayer[player]!
                setBoardValue(move: move, value: color)
                settleGroups(groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs, move: move)
                groupsByPlayerAndID[player] = groupsByID; groupIDsByPlayer[player] = stoneGroupIDs

                groupsByID = groupsByPlayerAndID[color]!; stoneGroupIDs = groupIDsByPlayer[color]!
                makeCaptures(move: move, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs)
                groupsByPlayerAndID[color] = groupsByID; groupIDsByPlayer[color] = stoneGroupIDs
            }
        }
    }

    // MARK: - turn order (ported from Table.currentPlayer / doublePassMove)

    private func currentPlayer() -> Int {
        let d = doublePassMove()
        if phase == .evaluateStones {
            return 1 + d % 2
        } else if phase == .markStones {
            return 2 - d % 2
        } else {
            return 1 + (moves.count % 2)
        }
    }

    private func doublePassMove() -> Int {
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

    // MARK: - captures (ported from Table.makeCaptures / getCaptures / checkKo / captureGroup)

    private func makeCaptures(move: Int, groupsByID: inout [Int: [Int]], stoneGroupIDs: inout [Int: Int]) {
        var captures = 0
        if move % gridSize != 0 {
            let neighborStone = move - 1
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                captures = getCaptures(move: move, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs, captures: captures, neighborStone: neighborStone, neighborStoneID: neighborStoneID)
            }
        }
        if move % gridSize != gridSize - 1 {
            let neighborStone = move + 1
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                captures = getCaptures(move: move, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs, captures: captures, neighborStone: neighborStone, neighborStoneID: neighborStoneID)
            }
        }
        if move / gridSize != 0 {
            let neighborStone = move - gridSize
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                captures = getCaptures(move: move, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs, captures: captures, neighborStone: neighborStone, neighborStoneID: neighborStoneID)
            }
        }
        if move / gridSize != gridSize - 1 {
            let neighborStone = move + gridSize
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                captures = getCaptures(move: move, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs, captures: captures, neighborStone: neighborStone, neighborStoneID: neighborStoneID)
            }
        }
        // Dead accumulator: this running total is discarded. It is kept only for
        // verbatim fidelity with the legacy Table.makeCaptures; the actual per-colour
        // capture counting happens inside captureGroup (blackCaptures/whiteCaptures).
        _ = captures
    }

    private func getCaptures(move: Int, groupsByID: inout [Int: [Int]], stoneGroupIDs: inout [Int: Int], captures: Int, neighborStone: Int, neighborStoneID: Int) -> Int {
        var newCaptures = captures
        if let neighborStoneGroup = groupsByID[neighborStoneID] {
            if !groupHasLiberties(group: neighborStoneGroup) {
                if koMove < 0 && neighborStoneGroup.count == 1 && checkKo(move: move) {
                    koMove = neighborStone
                } else {
                    koMove = -1
                }
                newCaptures += neighborStoneGroup.count
                captureGroup(groupID: neighborStoneID, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs)
            }
        }
        return newCaptures
    }

    private func checkKo(move: Int) -> Bool {
        let position = getBoardValue(move: move)
        if move % gridSize != 0 {
            let neighborStone = move - 1
            let neighborPosition = getBoardValue(move: neighborStone)
            if position != 3 - neighborPosition {
                return false
            }
        }
        if move % gridSize != gridSize - 1 {
            let neighborStone = move + 1
            let neighborPosition = getBoardValue(move: neighborStone)
            if position != 3 - neighborPosition {
                return false
            }
        }
        if move / gridSize != 0 {
            let neighborStone = move - gridSize
            let neighborPosition = getBoardValue(move: neighborStone)
            if position != 3 - neighborPosition {
                return false
            }
        }
        if move / gridSize != gridSize - 1 {
            let neighborStone = move + gridSize
            let neighborPosition = getBoardValue(move: neighborStone)
            if position != 3 - neighborPosition {
                return false
            }
        }
        return true
    }

    private func captureGroup(groupID: Int, groupsByID: inout [Int: [Int]], stoneGroupIDs: inout [Int: Int]) {
        let group = groupsByID[groupID]!
        let color = getBoardValue(move: group[0])
        for stone in group {
            setBoardValue(move: stone, value: 0)
            stoneGroupIDs.removeValue(forKey: stone)
        }
        groupsByID.removeValue(forKey: groupID)
        if color == 2 {
            blackCaptures += group.count
        } else if color == 1 {
            whiteCaptures += group.count
        }
    }

    // MARK: - liberties (ported from Table.groupHasLiberties / stoneHasLiberties)

    private func groupHasLiberties(group: [Int]) -> Bool {
        for stone in group {
            if stoneHasLiberties(move: stone) {
                return true
            }
        }
        return false
    }

    private func stoneHasLiberties(move: Int) -> Bool {
        if move % gridSize != 0 {
            let neighborStone = move - 1
            let pos = getBoardValue(move: neighborStone)
            if pos != 1 && pos != 2 {
                return true
            }
        }
        if move % gridSize != gridSize - 1 {
            let neighborStone = move + 1
            let pos = getBoardValue(move: neighborStone)
            if pos != 1 && pos != 2 {
                return true
            }
        }
        if move / gridSize != 0 {
            let neighborStone = move - gridSize
            let pos = getBoardValue(move: neighborStone)
            if pos != 1 && pos != 2 {
                return true
            }
        }
        if move / gridSize != gridSize - 1 {
            let neighborStone = move + gridSize
            let pos = getBoardValue(move: neighborStone)
            if pos != 1 && pos != 2 {
                return true
            }
        }
        return false
    }

    // MARK: - board accessors (ported from Table.getBoardValue / setBoardValue)

    private func getBoardValue(move: Int) -> Int {
        let i = move / gridSize
        let j = move % gridSize
        return board[i][j]
    }

    private func setBoardValue(move: Int, value: Int) {
        let i = move / gridSize
        let j = move % gridSize
        board[i][j] = value
    }

    // MARK: - groups (ported from Table.settleGroups / mergeGroups)

    private func settleGroups(groupsByID: inout [Int: [Int]], stoneGroupIDs: inout [Int: Int], move: Int) {
        let newGroup = [move]
        groupsByID[move] = newGroup
        stoneGroupIDs[move] = move
        if move % gridSize != 0 {
            let neighborStone = move - 1
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                mergeGroups(group1: move, group2: neighborStoneID, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs)
            }
        }
        if move % gridSize != gridSize - 1 {
            let neighborStone = move + 1
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                mergeGroups(group1: stoneGroupIDs[move]!, group2: neighborStoneID, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs)
            }
        }
        if move / gridSize != 0 {
            let neighborStone = move - gridSize
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                mergeGroups(group1: stoneGroupIDs[move]!, group2: neighborStoneID, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs)
            }
        }
        if move / gridSize != gridSize - 1 {
            let neighborStone = move + gridSize
            if let neighborStoneID = stoneGroupIDs[neighborStone] {
                mergeGroups(group1: stoneGroupIDs[move]!, group2: neighborStoneID, groupsByID: &groupsByID, stoneGroupIDs: &stoneGroupIDs)
            }
        }
    }

    private func mergeGroups(group1: Int, group2: Int, groupsByID: inout [Int: [Int]], stoneGroupIDs: inout [Int: Int]) {
        var oldGroup, newGroup: [Int]
        var oldGroupID, newGroupID: Int
        if group1 < group2 {
            oldGroup = groupsByID[group1]!
            newGroup = groupsByID[group2]!
            oldGroupID = group1
            newGroupID = group2
        } else {
            newGroup = groupsByID[group1]!
            oldGroup = groupsByID[group2]!
            oldGroupID = group2
            newGroupID = group1
        }
        groupsByID.removeValue(forKey: oldGroupID)
        newGroup.append(contentsOf: oldGroup)
        groupsByID[newGroupID] = newGroup
        for stone in oldGroup {
            stoneGroupIDs[stone] = newGroupID
        }
    }

    // MARK: - territory (ported from Table.getTerritories / floodFill / floodFillWorker / getEmptyNeighbor / getMoves / resetGoBeforeFlood / getGoScoreString)

    @objc func territory(forPlayer player: Int) -> [Int] {
        getTerritories()
        return territoryByPlayer[player] ?? []
    }

    @objc func scoreString() -> String {
        getTerritories()
        let p1Stones = getMoves(value: 2).count, p2Stones = getMoves(value: 1).count, p1Territory = territoryByPlayer[1]!.count, p2Territory = territoryByPlayer[2]!.count
        // Komi 7.5 is encoded as integer `(... + 7)` then a literal ".5" string — this is
        // verbatim from the legacy Table.getGoScoreString and is intentional, not a truncation
        // bug. Do NOT "fix" it to Float arithmetic; the integer + ".5" reproduces the exact display.
        return "black score is \(p1Territory) + \(p1Stones) = \(p1Stones + p1Territory)\nwhite score is \(p2Territory) + \(p2Stones) + 7.5 = \(p2Stones + p2Territory + 7).5"
    }

    private func getTerritories() {
        floodFill(player: 1)
        var p1Territory = getMoves(value: 3)
        resetGoBeforeFlood()
        floodFill(player: 2)
        var p2Territory = getMoves(value: 4)
        resetGoBeforeFlood()
        var i1 = p1Territory.count - 1, i2 = p2Territory.count - 1
        while i1 > -1, i2 > -1 {
            let p1 = p1Territory[i1], p2 = p2Territory[i2]
            if p1 == p2 {
                p1Territory.remove(at: i1); p2Territory.remove(at: i2)
                i1 -= 1; i2 -= 1
            } else if p1 < p2 {
                i2 -= 1
            } else {
                i1 -= 1
            }
        }
        territoryByPlayer[1] = p1Territory; territoryByPlayer[2] = p2Territory
    }

    private func resetGoBeforeFlood() {
        for i in 0 ..< gridSize {
            for j in 0 ..< gridSize {
                let pos = board[i][j]
                if pos != 1, pos != 2 {
                    board[i][j] = 0
                }
            }
        }
    }

    private func getEmptyNeighbor(move: Int) -> Int {
        if move % gridSize != 0 {
            let neighborStone = move - 1
            if getBoardValue(move: neighborStone) == 0 {
                return neighborStone
            }
        }
        if move % gridSize != gridSize - 1 {
            let neighborStone = move + 1
            if getBoardValue(move: neighborStone) == 0 {
                return neighborStone
            }
        }
        if move / gridSize != 0 {
            let neighborStone = move - gridSize
            if getBoardValue(move: neighborStone) == 0 {
                return neighborStone
            }
        }
        if move / gridSize != gridSize - 1 {
            let neighborStone = move + gridSize
            if getBoardValue(move: neighborStone) == 0 {
                return neighborStone
            }
        }
        return -1
    }

    private func getMoves(value: Int) -> [Int] {
        var result = [Int]()
        for i in 0 ..< gridSize {
            for j in 0 ..< gridSize {
                let pos = board[i][j]
                if pos == value {
                    result.append(i * gridSize + j)
                }
            }
        }
        return result
    }

    private func floodFillWorker(move: Int, value: Int) {
        setBoardValue(move: move, value: value)
        var neighbor = getEmptyNeighbor(move: move)
        while neighbor > -1 {
            floodFillWorker(move: neighbor, value: value)
            neighbor = getEmptyNeighbor(move: move)
        }
    }

    private func floodFill(player: Int) {
        for i in 0 ..< gridSize {
            for j in 0 ..< gridSize {
                let pos = board[i][j]
                if pos == 3 - player {
                    let move = i * gridSize + j
                    var neighbor = getEmptyNeighbor(move: move)
                    while neighbor > -1 {
                        floodFillWorker(move: neighbor, value: player + 2)
                        neighbor = getEmptyNeighbor(move: move)
                    }
                }
            }
        }
    }
}
