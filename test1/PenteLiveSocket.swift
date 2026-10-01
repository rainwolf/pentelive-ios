//
//  PenteLiveSocket.swift
//  penteLive
//
//  Created by rainwolf on 01/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import Network
import UIKit

@objc class PenteLiveSocket: NSObject {
    var connection: NWConnection!
    var separator: Data
    weak var room: RoomViewController!
    var server: String
    var port: Int
    var me: String
    // All connection callbacks, and so processEvent, run on this serial queue.
    private let queue = DispatchQueue(label: "penteLiveDelegateQueue")
    // Bytes after the last 0xFF separator, carried over to the next read. Only touched on queue.
    private var readBuffer = Data()
    // Set by the first terminal path (error, server close or disconnect()). Only touched on queue.
    private var closed = false

    init(server: String, port: Int, room: RoomViewController) {
        self.server = server
        self.port = port
        self.room = room
        me = "guest"
        separator = Data([255])
        super.init()
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = 5
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_tls_server_name(tlsOptions.securityProtocolOptions, server)
        if development {
            // localhost dev server only: accept any certificate. Production keeps the system's
            // default trust evaluation against the server name.
            sec_protocol_options_set_verify_block(tlsOptions.securityProtocolOptions, { _, _, completionHandler in
                completionHandler(true)
            }, queue)
        }
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        connection = NWConnection(host: NWEndpoint.Host(server), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: parameters)
        connection.stateUpdateHandler = { [weak self] state in
            self?.connectionStateChanged(state)
        }
        print("connecting: \(server):\(port)")
        connection.start(queue: queue)
    }

    deinit {
        connection.cancel()
    }

    private func connectionStateChanged(_ state: NWConnection.State) {
        switch state {
        case .ready:
            // TCP is connected and TLS is up.
            print("connected")
            let url = URL(string: "https://\(server)")
            let session = URLSession.shared
            session.dataTask(with: url!, completionHandler: { (_: Data?, _: URLResponse?, _: Error?) in
            }).resume()
            let seconds = 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
                self?.login()
            }
            print("did secure")
            readNextChunk()
        case let .waiting(error):
            // No route or DNS failure. Fail fast instead of letting NWConnection wait for a better path.
            close(error: error)
        case let .failed(error):
            close(error: error)
        default:
            break
        }
    }

    private func readNextChunk() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self, !self.closed else { return }
            if let content = content, !content.isEmpty {
                self.readBuffer.append(content)
                for message in PenteLiveSocket.extractMessages(from: &self.readBuffer) {
                    let jsonString = String(bytes: message, encoding: .utf8)
                    self.processEvent(eventString: jsonString!)
                }
            }
            if let error = error {
                self.close(error: error)
            } else if isComplete {
                self.close(error: NSError(domain: "PenteLiveSocket", code: 7, userInfo: [NSLocalizedDescriptionKey: "Socket closed by remote peer"]))
            } else {
                self.readNextChunk()
            }
        }
    }

    // Splits complete 0xFF-terminated messages off the front of buffer, without their separator.
    // An unterminated tail stays in buffer for the next read.
    static func extractMessages(from buffer: inout Data, separator: UInt8 = 255) -> [Data] {
        var messages: [Data] = []
        var start = buffer.startIndex
        while let end = buffer[start...].firstIndex(of: separator) {
            messages.append(Data(buffer[start ..< end]))
            start = buffer.index(after: end)
        }
        buffer = Data(buffer[start...])
        return messages
    }

    // Terminal error path: tells the room once, on main. Must be called on queue.
    private func close(error: Error) {
        guard !closed else { return }
        closed = true
        connection.cancel()
        print("disconnected \(String(describing: error.localizedDescription))")
        DispatchQueue.main.async { [weak room = self.room] in
            room?.disconnected()
        }
    }

    // App-initiated close: as before, the room is not told.
    func disconnect() {
        queue.async {
            guard !self.closed else { return }
            self.closed = true
            self.connection.cancel()
            print("disconnected nil")
        }
    }

    // A write that has not been handed to the network stack within timeout closes the connection with an error.
    private func write(_ data: Data, timeout: TimeInterval) {
        let timeoutItem = DispatchWorkItem { [weak self] in
            self?.close(error: NSError(domain: "PenteLiveSocket", code: 5, userInfo: [NSLocalizedDescriptionKey: "Write operation timed out"]))
        }
        queue.asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
        connection.send(content: data, completion: .contentProcessed { [weak self] error in
            timeoutItem.cancel()
            if let error = error {
                self?.close(error: error)
            }
        })
    }

    func processEvent(eventString: String) {
        print("=======================")
        print(eventString)
        print("=======================")
        let event = convertJSONStringToDictionary(text: eventString)
        if (event?["dsgPingEvent"]) != nil {
            replyPing(pingString: eventString)
        } else if let content = event?["dsgLoginEvent"] {
            room.loginEvent(event: content as! [String: Any])
        } else if let content = event?["dsgJoinMainRoomEvent"] {
            room.joinMainRoomEvent(event: content as! [String: Any])
        } else if let content = event?["dsgUpdatePlayerDataEvent"] {
            room.updatePlayerDataEvent(event: content as! [String: Any])
        } else if (event?["dsgJoinMainRoomErrorEvent"]) != nil {
            reLogin()
        } else if let content = event?["dsgExitMainRoomEvent"] {
            room.exitMainRoomEvent(event: content as! [String: Any])
        } else if let content = event?["dsgJoinTableEvent"] {
            room.joinTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgChangeStateTableEvent"] {
            room.changeTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgExitTableEvent"] {
            room.exitTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgSitTableEvent"] {
            room.sitTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgStandTableEvent"] {
            room.standTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgOwnerTableEvent"] {
            room.ownerTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgTextMainRoomEvent"] {
            room.addRoomText(event: content as! [String: Any])
        } else if let content = event?["dsgTextTableEvent"] {
            room.addTableText(event: content as! [String: Any])
        } else if let content = event?["dsgBootTableEvent"] {
            room.bootFromTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgJoinTableErrorEvent"] {
            room.joinTableErrorEvent(event: content as! [String: Any])
        } else if let content = event?["dsgTimerChangeTableEvent"] {
            room.timerChangeTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgGameStateTableEvent"] {
            room.gameStateTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgMoveTableEvent"] {
            room.moveTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgSystemMessageTableEvent"] {
            room.systemMessageTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgSwapSeatsTableEvent"] {
            room.swapSeatsTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgUndoRequestTableEvent"] {
            room.undoRequestTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgUndoReplyTableEvent"] {
            room.replyUndoRequestTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgRenjuAcceptDrawTableEvent"] {
            room.renjuAcceptDrawTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgRenjuRejectDrawTableEvent"] {
            room.renjuRejectDrawTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgRenjuDrawTableErrorEvent"] {
            print("dsgRenjuDrawTableErrorEvent (ignored): \(content)")
        } else if let content = event?["dsgCancelRequestTableEvent"] {
            room.cancelRequestTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgCancelReplyTableEvent"] {
            room.cancelRequestReplyTableEvent(event: content as! [String: Any])
//        } else if let content = event?["dsgForceCancelResignTableEvent"] {
//            room.forceCancelResignTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgWaitingPlayerReturnTimeUpTableEvent"] {
            room.waitingPlayerReturnTimeUpTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgInviteTableEvent"] {
            room.inviteTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgInviteResponseTableEvent"] {
            room.inviteResponseTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgRejectGoStateEvent"] {
            room.rejectGoDeadStonesTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgSwap2PassTableEvent"] {
            room.swap2PassTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgRenjuTaraguchiSwapTableEvent"] {
            room.renjuSwapTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgRenjuTaraguchiOffer10TableEvent"] {
            room.renjuOffer10TableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgRenjuTaraguchi10Select1TableEvent"] {
            room.renjuSelect1TableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgMoveTableErrorEvent"] {
            room.moveErrorTableEvent(event: content as! [String: Any])
        } else if let content = event?["dsgArenaRequestJoinTableEvent"] {
            room.arenaRequestJoinTableEvent(event: content as! [String: Any])
        }
    }

    func convertJSONStringToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            return convertJSONDataToDictionary(data: data)
        }
        return nil
    }

    func convertJSONDataToDictionary(data: Data) -> [String: Any]? {
        do {
            return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } catch {
            print(error.localizedDescription)
        }
        return nil
    }

    func login() {
        if (room.pentePlayer?.playerName.contains("guest"))! {
            let loginStr = "{\"dsgLoginEvent\":{\"guest\":true,\"time\":0}}"
            var loginData = loginStr.data(using: .utf8)
            loginData?.append(separator)
            write(loginData!, timeout: 5)
        } else {
            let username = UserDefaults.standard.string(forKey: "username")!.lowercased()
            let password = UserDefaults.standard.string(forKey: "password")!
            //        var username = UserDefaults.standard.string(forKey: "username")!
            //        var password = UserDefaults.standard.string(forKey: "password")!
            //        if development {
            //            username = "Iostest".lowercased()
            //            password = "tsetsoi"
            //        }
            let loginStr = "{\"dsgLoginEvent\":{\"player\":\"\(username)\",\"password\":\"\(password)\",\"guest\":false,\"time\":0}}"
            var loginData = loginStr.data(using: .utf8)
            loginData?.append(separator)
            write(loginData!, timeout: 5)
        }
    }

    func reLogin() {
        let url = URL(string: "https://\(server)/gameServer/bootMeMobile.jsp")
        let session = URLSession.shared
        session.dataTask(with: url!, completionHandler: { (_: Data?, _: URLResponse?, error: Error?) in
            if error == nil {
                self.login()
            }
        }).resume()
    }

    func sendEvent(eventData: Data) {
        var data = eventData
        data.append(separator)
        write(data, timeout: 30)
    }

    func sendEvent(eventString: String) {
        let data = eventString.data(using: .utf8)
        sendEvent(eventData: data!)
    }

    func sendEvent(eventDictionary: [String: Any]) {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: eventDictionary, options: .init(rawValue: 0))
            sendEvent(eventData: jsonData)
        } catch {
            print(error.localizedDescription)
        }
    }

    func replyPing(pingString: String) {
        var data = pingString.data(using: .utf8)
        data?.append(separator)
        write(data!, timeout: 30)
    }
}
