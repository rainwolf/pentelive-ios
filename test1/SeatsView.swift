//
//  SeatsView.swift
//  penteLive
//
//  Created by rainwolf on 05/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

class SeatsView: UIView {

    let seat1Label = UILabel()
    let seat2Label = UILabel()
    let seat1TimeLabel = UILabel()
    let seat2TimeLabel = UILabel()
    let ratedTimerLabel = UILabel()
    

    override init(frame: CGRect) {
        super.init(frame: frame)
        var labelFrame = frame
        labelFrame.origin = CGPoint(x: 0, y: 0)
        let labelWidth = frame.width / 3
        labelFrame.size.width = labelWidth
        labelFrame.size.height = frame.size.height/2
        seat1Label.frame = labelFrame
        seat1Label.textAlignment = .center
        seat1Label.tag = 1
        addSubview(seat1Label)
        addSubview(ratedTimerLabel)
        labelFrame.origin.x = 2*labelWidth
        seat2Label.frame = labelFrame
        seat2Label.textAlignment = .center
        seat2Label.tag = 2
        addSubview(seat2Label)
        labelFrame = seat1Label.frame
        labelFrame.size.height = frame.size.height/2
        labelFrame.origin.y = seat1Label.frame.origin.y + seat1Label.frame.size.height
        seat1TimeLabel.frame = labelFrame
        addSubview(seat1TimeLabel)
        labelFrame = seat1TimeLabel.frame
        labelFrame.origin.x = labelWidth*2
        seat2TimeLabel.frame = labelFrame
        addSubview(seat2TimeLabel)
        seat1TimeLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        seat1TimeLabel.textAlignment = .center
        seat2TimeLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        seat2TimeLabel.textAlignment = .center
        labelFrame = CGRect(x: labelWidth, y: 0, width: labelWidth, height: frame.size.height)
        ratedTimerLabel.frame = labelFrame
        ratedTimerLabel.textAlignment = .center
        ratedTimerLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        ratedTimerLabel.numberOfLines = 2
        if #available(iOS 13.0, *) {
            backgroundColor = UIColor.systemBackground
        } else {
            backgroundColor = UIColor.white
        }
        seat1Label.attributedText = NSAttributedString(string: NSLocalizedString("Tap to sit", comment: ""))
        seat2Label.attributedText = NSAttributedString(string: NSLocalizedString("Tap to sit", comment: ""))
        seat1Label.isUserInteractionEnabled = true
        seat2Label.isUserInteractionEnabled = true
        seat1Label.alpha = 0.6
        seat2Label.alpha = 0.6
    }
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }

    func sit(player: NSAttributedString, seat: Int) {
        if seat == 1 {
            seat1Label.attributedText = player
            seat1Label.alpha = 1
        } else if seat == 2 {
            seat2Label.attributedText = player
            seat2Label.alpha = 1
        }
    }
    func stand(seat: Int) {
        if seat == 1 {
            seat1Label.attributedText = NSAttributedString(string: NSLocalizedString("Tap to sit", comment: ""))
            seat1Label.alpha = 0.6
        } else if seat == 2 {
            seat2Label.attributedText = NSAttributedString(string: NSLocalizedString("Tap to sit", comment: ""))
            seat2Label.alpha = 0.6
        }
    }
    func setRatedTimer(rated: Bool, timed: Bool, initialMinutes: Int, incrementalSeconds: Int) {
        var ratedStr = "Rated"
        if !rated {
            ratedStr = "Not rated"
        }
        var timerStr = "Not timed"
        if timed {
            timerStr = NSLocalizedString("Timer: \(initialMinutes)/\(incrementalSeconds)", comment: "")
        }
        ratedTimerLabel.text = NSLocalizedString(ratedStr, comment: "") + "\n" + timerStr
    }
    func getTimerText(timer: [String: Int]) -> String {
        let millis = timer["millis"]!
        let minutes = millis / 60000
        let secs = (millis % 60000) / 1000
        var seconds = "\(secs)"
        if secs < 10 {
            seconds = "0\(secs)"
        }
        if (millis / 1000 < 12) {
            let tenths = ((millis % 60000) / 100) % 10
            return "\(minutes):\(seconds).\(tenths)"
        }
        return "\(minutes):\(seconds)"
    }
    func setTimers(timers: [Int:[String:Int]]) {
        seat1TimeLabel.text = getTimerText(timer: timers[1]!)
        seat2TimeLabel.text = getTimerText(timer: timers[2]!)
    }
    
}
