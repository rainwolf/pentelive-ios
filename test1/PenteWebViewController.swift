//
//  PenteWebViewController.swift
//  penteLive
//
//  Created by rainwolf on 21/02/2017.
//  Copyright © 2017 Triade. All rights reserved.
//

import UIKit

class PenteWebViewController: SVWebViewController, UIWebViewDelegate {
    
    let digits = CharacterSet(charactersIn: "0123456789")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        var urlStr = request.url?.absoluteString
        if (navigationType == .linkClicked || navigationType == .other) && ((urlStr?.contains("?mobile&g="))! || (urlStr?.contains("gameServer/tb/game?gid="))!) {
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
            boardVC.activeGame = false
            boardVC.game = game
            boardVC.showAds = (self.navigationController as! PenteNavigationViewController).player.showAds
            boardVC.boardTapRecognizer.isEnabled = false
            boardVC.replayGame()
            
            self.navigationController?.pushViewController(boardVC, animated: true)

            return false
        }
        return true
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
