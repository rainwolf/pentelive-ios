//
//  LiveBoard.swift
//  penteLive
//
//  Created by rainwolf on 05/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

class LiveBoard: UIView {
    var table: Table!
    
    init(table:Table) {
        self.table = table
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        context.setLineWidth(1.2)
        context.setStrokeColor(UIColor.black.cgColor)
        let margin = self.bounds.size.width / 38
        // draw the grid
        for i in 0..<19 {
            context.move(to: CGPoint(x: margin, y: margin + CGFloat(i)*margin*2))
            context.addLine(to: CGPoint(x: self.bounds.size.width - margin, y: margin + CGFloat(i)*margin*2))
            context.strokePath()
            context.move(to: CGPoint(x: margin + CGFloat(i)*margin*2, y: margin))
            context.addLine(to: CGPoint(x: margin + CGFloat(i)*margin*2, y: self.bounds.size.width - margin))
            context.strokePath()
        }
        // draw the 5 little special circles
        var circle = CGRect(x: margin + 12*margin - margin/2, y: margin + 12*margin - margin/2, width: margin, height: margin)
        context.addEllipse(in: circle)
        context.strokePath()
        circle.origin.x = self.bounds.size.width - margin - 12*margin - margin/2
        context.addEllipse(in: circle)
        context.strokePath()
        circle.origin.x = self.bounds.size.width - margin - 12*margin - margin/2
        circle.origin.y = self.bounds.size.width - margin - 12*margin - margin/2
        context.addEllipse(in: circle)
        context.strokePath()
        circle.origin.x = margin + 12*margin - margin/2
        circle.origin.y = self.bounds.size.width - margin - 12*margin - margin/2
        context.addEllipse(in: circle);
        context.strokePath();
        circle.origin.x = self.bounds.size.width/2 - margin/2;
        circle.origin.y = self.bounds.size.width/2 - margin/2;
        context.addEllipse(in: circle);
        context.strokePath();
        for i in 0..<19 {
            for j in 0..<19 {
                if table.abstractBoard[i][j] > 0 {
                    circle = CGRect(x: CGFloat(j)*2*margin, y: CGFloat(i)*2*margin, width: 2*margin, height: 2*margin)
                    let centre = CGPoint(x: circle.origin.x + margin - margin/6, y: circle.origin.y + margin - margin/6)
                    
                    context.saveGState()
                    let num_locations: size_t = 2
                    let locations:[CGFloat] = [ 0.0, 1.0 ]
                    var start:CGFloat = 150.0/255.0
                    var end:CGFloat = 0.0
                    if table.abstractBoard[i][j] == 2 {
                    } else {
                        start = 1.0;
                        end = 210.0/255.0;
                    }
                    let components:[CGFloat] = [ start,start,start, 1.0,  // Start color
                        end,end,end, 1.0 ] // End color
                    
                    let myColorspace = CGColorSpaceCreateDeviceRGB()
                    let myGradient = CGGradient (colorSpace: myColorspace, colorComponents: components, locations: locations, count: num_locations);
                    
                    context.addEllipse(in: circle)
                    context.setShadow(offset: CGSize(width: margin/6, height: margin/6), blur: 0)
                    context.fillPath()
                    context.addEllipse(in: circle)
                    context.clip()
                    context.drawRadialGradient(myGradient!, startCenter: centre, startRadius: 0.0, endCenter: centre, endRadius: 5*margin/4, options: CGGradientDrawingOptions(rawValue: 0))
                    context.restoreGState()
                }
            }
        }
        let lastMove = table.lastMove()
        if (lastMove > -1) {
            context.setFillColor(UIColor.red.cgColor)
            let i = lastMove / 19, j = lastMove % 19
            circle = CGRect(x: (CGFloat(j)*2 + 2/3)*margin, y: (CGFloat(i)*2 + 2/3)*margin, width: (CGFloat(2)/3)*margin, height: (CGFloat(2)/3)*margin)
            context.addEllipse(in: circle)
            context.fillPath()
        }

    }
}










class LiveStone: UIView {
    var color = 2
    
    init(size: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: 1.3*size, height: 1.3*size))
        self.backgroundColor = UIColor.clear
    }
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }
    
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        context.setStrokeColor(UIColor.black.cgColor)
        let circleSide: CGFloat = self.bounds.size.width/1.2
        let indent: CGFloat = (self.bounds.size.width - circleSide)/2
        let circle = CGRect(x: indent, y: indent, width: circleSide, height: circleSide)
        let margin: CGFloat = circle.size.width/2
        let centre = CGPoint(x: circle.origin.x + margin - margin/6, y: circle.origin.y + margin - margin/6)

        let num_locations: size_t = 2
        let locations:[CGFloat] = [ 0.0, 1.0 ]
        var start:CGFloat = 150.0/255.0
        var end:CGFloat = 0.0
        if color == 2 {
        } else {
            start = 1.0;
            end = 210.0/255.0;
        }
        let components:[CGFloat] = [ start,start,start, 1.0,  // Start color
            end,end,end, 1.0 ] // End color
        let myColorspace = CGColorSpaceCreateDeviceRGB()
        let myGradient = CGGradient (colorSpace: myColorspace, colorComponents: components, locations: locations, count: num_locations);

        context.addEllipse(in: circle)
        context.setShadow(offset: CGSize(width: margin/6, height: margin/6), blur: 0)
        context.fillPath()
        context.addEllipse(in: circle)
        context.clip()
        context.drawRadialGradient(myGradient!, startCenter: centre, startRadius: 0.0, endCenter: centre, endRadius: 5*margin/4, options: CGGradientDrawingOptions(rawValue: 0))
    }
}



class LiveVerticalLine: UIView {
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(3)
        context.move(to: CGPoint(x: self.bounds.size.width/2, y: 1))
        context.addLine(to: CGPoint(x: self.bounds.size.width/2, y: self.bounds.size.height))
        context.strokePath()
    }
}



class LiveHorizontalLine: UIView {
    override func draw(_ rect: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(3)
        context.move(to: CGPoint(x: 1, y: self.bounds.size.height/2))
        context.addLine(to: CGPoint(x: self.bounds.size.width, y: self.bounds.size.height/2))
        context.strokePath()
    }
}




















