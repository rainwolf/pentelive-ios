//
//  PenteLiveSocket.swift
//  penteLive
//
//  Created by rainwolf on 01/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

@objc class PenteLiveSocket: NSObject, GCDAsyncSocketDelegate {
    var socket: GCDAsyncSocket!
    var separator: Data
    weak var room: RoomViewController!
    var server: String
    var port: Int
    
    init(server: String, port: Int) {
//        self.socket = GCDAsyncSocket()
        self.server = server
        self.port = port
        separator = Data(bytes: [255])
        super.init()
        self.socket = GCDAsyncSocket(delegate: self, delegateQueue: DispatchQueue(label: "penteLiveDelegateQueue"))
        do {
            print("connecting")
            try self.socket.connect(toHost: server, onPort: UInt16(port), withTimeout: 5)
        } catch let error {
            print("connecting error: \(error.localizedDescription)")
            let alertController = UIAlertController(title: NSLocalizedString("Error", comment: ""), message: NSLocalizedString("There was an error getting the game rooms. Reason: \(error.localizedDescription)", comment: ""), preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("Dismiss", comment: ""), style: UIAlertActionStyle.default, handler: nil))
            //            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func socketDidSecure(_ sock: GCDAsyncSocket) {
        print("did secure")
        socket.readData(to: separator, withTimeout: -1, tag: 0)
    }
    
    func socket(_ sock: GCDAsyncSocket, didConnectToHost host: String, port: UInt16) {
        let username = (UserDefaults.standard.string(forKey: "username")!).lowercased()
        let password = UserDefaults.standard.string(forKey: "password")!
        let url = URL(string: "https://\(server)/gameServer/login.jsp?name2=\(username)&password2=\(password)")
        let session = URLSession.shared
        _ = session.dataTask(with: url as URL!, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
        }).resume()

//        print("connected")
        var tlsSettings: [String:NSObject] = [:]
        tlsSettings.updateValue(server as NSObject, forKey: String(kCFStreamSSLPeerName))
        self.socket.startTLS(tlsSettings)
        login()
    }
    
    
    func socketDidDisconnect(_ sock: GCDAsyncSocket, withError err: Error?) {
        if err != nil {
            DispatchQueue.main.async {
                self.room.disconnected()
            }
        }
//        print("disconnected \(sock.connectedHost)")
//        print("disconnected \(sock.connectedPort)")
        print("disconnected \(String(describing: err?.localizedDescription))")
    }
    func socket(_ sock: GCDAsyncSocket, didRead data: Data, withTag tag: Int) {
//        for byte in data {
//            print("\(byte),", separator: ",", terminator: "")
//        }
        let jsonString = String(bytes: data.subdata(in: (0..<data.count-1)), encoding: .utf8)
//        print("socket read: \(jsonString!)")
        socket.readData(to: separator, withTimeout: -1, tag: 0)
        processEvent(eventString: jsonString!)
    }
    func socket(_ sock: GCDAsyncSocket, didWriteDataWithTag tag: Int) {
        
    }
    func disconnect() {
        socket.disconnect()
    }
    
    func processEvent(eventString: String) {
//        print(eventString)
        let event = convertJSONStringToDictionary(text: eventString)
        if (event?["dsgPingEvent"]) != nil {
            replyPing(pingString: eventString)
        } else if let content = event?["dsgLoginEvent"] {
            room.loginEvent(event: content as! [String:Any])
        } else if let content = event?["dsgJoinMainRoomEvent"] {
            room.joinMainRoomEvent(event: content as! [String:Any])
        } else if let content = event?["dsgUpdatePlayerDataEvent"] {
            room.updatePlayerDataEvent(event: content as! [String:Any])
        } else if (event?["dsgJoinMainRoomErrorEvent"]) != nil {
            reLogin()
        } else if let content = event?["dsgExitMainRoomEvent"] {
            room.exitMainRoomEvent(event: content as! [String:Any])
        } else if let content = event?["dsgJoinTableEvent"] {
            room.joinTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgChangeStateTableEvent"] {
            room.changeTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgExitTableEvent"] {
            room.exitTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgSitTableEvent"] {
            room.sitTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgStandTableEvent"] {
            room.standTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgOwnerTableEvent"] {
            room.ownerTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgTextMainRoomEvent"] {
            room.addRoomText(event: content as! [String:Any])
        } else if let content = event?["dsgTextTableEvent"] {
            room.addTableText(event: content as! [String:Any])
        } else if let content = event?["dsgBootTableEvent"] {
            room.bootFromTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgJoinTableErrorEvent"] {
            room.joinTableErrorEvent(event: content as! [String:Any])
        } else if let content = event?["dsgTimerChangeTableEvent"] {
            room.timerChangeTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgGameStateTableEvent"] {
            room.gameStateTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgMoveTableEvent"] {
            room.moveTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgSystemMessageTableEvent"] {
            room.systemMessageTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgSwapSeatsTableEvent"] {
            room.swapSeatsTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgUndoRequestTableEvent"] {
            room.undoRequestTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgUndoReplyTableEvent"] {
            room.replyUndoRequestTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgCancelRequestTableEvent"] {
            room.cancelRequestTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgCancelReplyTableEvent"] {
            room.cancelRequestReplyTableEvent(event: content as! [String:Any])
//        } else if let content = event?["dsgForceCancelResignTableEvent"] {
//            room.forceCancelResignTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgWaitingPlayerReturnTimeUpTableEvent"] {
            room.waitingPlayerReturnTimeUpTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgInviteTableEvent"] {
            room.inviteTableEvent(event: content as! [String:Any])
        } else if let content = event?["dsgInviteResponseTableEvent"] {
            room.inviteResponseTableEvent(event: content as! [String:Any])
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
        let username = UserDefaults.standard.string(forKey: "username")!
        let password = UserDefaults.standard.string(forKey: "password")!
        let loginStr = "{\"dsgLoginEvent\":{\"player\":\"\(username)\",\"password\":\"\(password)\",\"guest\":false,\"time\":0}}"
        var loginData = loginStr.data(using: .utf8)
        loginData?.append(separator)
        socket.write(loginData!, withTimeout: 5, tag: 1)
    }
    func reLogin() {
        let url = URL(string: "https://\(server)/gameServer/bootMeMobile.jsp")
        let session = URLSession.shared
        _ = session.dataTask(with: url as URL!, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) in
        if error == nil {
            self.login()
        }
        }).resume()
    }
    func sendEvent(eventData: Data) {
        var data = eventData
        data.append(separator)
        socket.write(data, withTimeout: 30, tag: 1)
    }
    func sendEvent(eventString: String) {
        let data = eventString.data(using: .utf8)
        sendEvent(eventData: data!)
    }
    func sendEvent(eventDictionary: [String:Any]) {
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
        socket.write(data!, withTimeout: 30, tag: 1)
    }
}
