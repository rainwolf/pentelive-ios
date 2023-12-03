//
//  PenteWebViewController.swift
//  penteLive
//
//  Created by rainwolf on 21/02/2017.
//  Copyright © 2017 Triade. All rights reserved.
//

import UIKit
import WebKit

class PenteWebViewController: AFWebViewController, WKNavigationDelegate {
    
    let digits = CharacterSet(charactersIn: "0123456789")
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
//    override init(urlRequest request: URLRequest, configuration: WKWebViewConfiguration?) {
////        config = nil
//        super.init(urlRequest: request, configuration: nil)
//    }
    
    init(address: String) {
        print("init ")
        super.init(urlRequest: URLRequest(url: URL(string: address)!), configuration: nil)
    }


    
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping ((WKNavigationActionPolicy) -> Void)) {

//        print(navigationAction.request.url)
                var urlStr = navigationAction.request.url?.absoluteString
//        print(urlStr)
                if (navigationAction.navigationType == .linkActivated || navigationAction.navigationType == .other) && ((urlStr?.contains("?mobile&g="))! || (urlStr?.contains("gameServer/tb/game?gid="))!) {
                    if (urlStr?.contains("?mobile&g="))! {
                        while !(urlStr?.hasPrefix("?mobile&g="))! {
                            let startIdx = (urlStr?.startIndex)!
                            urlStr?.remove(at: startIdx)
                        }
                        urlStr = urlStr?.replacingOccurrences(of: "?mobile&g=", with: "")
                    }
                    if (urlStr?.contains("gameServer/tb/game?gid="))! {
                        while !(urlStr?.hasPrefix("gameServer/tb/game?gid="))! {
                            let startIdx = (urlStr?.startIndex)!
                            urlStr?.remove(at: startIdx)
                        }
                        urlStr = urlStr?.replacingOccurrences(of: "gameServer/tb/game?gid=", with: "")
                    }
                    var gid = ""
                    for c in (urlStr?.unicodeScalars)! {
        //                print("kitten \(c) \(gid)")
                        if digits.contains(c) {
                            gid = gid + "\(c)"
                        } else {
                            break
                        }
                    }
        
                    let game = Game()
                    game.gameID = gid
                    game.remainingTime = "0 days"
        
                    let storyboard = UIStoryboard(name: "MainStoryboard", bundle: nil)
                    let boardVC = storyboard.instantiateViewController(withIdentifier: "boardViewController") as! BoardViewController
        //            let boardFrame = boardVC.view.frame;
        //            boardVC.view.frame = CGRect(x: boardFrame.origin.x, y: boardFrame.origin.y, width: boardFrame.size.width, height: boardFrame.size.height - 444)
        //            boardVC.viewDidLoad()
                    boardVC.activeGame = false
                    boardVC.game = game
                    boardVC.boardTapRecognizer.isEnabled = false
                    boardVC.replayGame()
        
                    self.navigationController?.pushViewController(boardVC, animated: true)
        
                    decisionHandler(.cancel)
                    return
                }
        decisionHandler(.allow)

    }
 
}
