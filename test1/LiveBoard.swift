//
//  LiveBoard.swift
//  penteLive
//
//  Created by rainwolf on 05/12/2016.
//  Copyright © 2016 Triade. All rights reserved.
//

import UIKit

enum StoneColor: Int {
    case white = 1, black, red
}

class LiveBoard: UIView {
    var table: Table!
    var go = false
    var whiteStone: LiveStone!
    var blackStone: LiveStone!
    var goTerritory: [Int: [Int]]?
    var goDeadStones: [Int: [Int]]?
    let whiteSquare = UIView(), blackSquare = UIView()
    var gridSize = 19

    init(table: Table) {
        self.table = table
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        let h: CGFloat = frame.size.height

        whiteStone = LiveStone(size: h)
        whiteStone.color = StoneColor.white
        whiteStone.alpha = 0.7; whiteStone.isOpaque = false; whiteStone.fill = true; whiteStone.clipsToBounds = true
        blackStone = LiveStone(size: h)
        blackStone.color = StoneColor.black
        blackStone.alpha = 0.7; blackStone.isOpaque = false; blackStone.fill = true; blackStone.clipsToBounds = true

        whiteSquare.alpha = 0.8; blackSquare.alpha = 0.8
        whiteSquare.clipsToBounds = true; blackSquare.clipsToBounds = true
        whiteSquare.isOpaque = false; blackSquare.isOpaque = false
        whiteSquare.backgroundColor = UIColor.white; blackSquare.backgroundColor = UIColor.black
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }

    func clearGoStructures() {
        goTerritory = nil
        goDeadStones = nil
    }

    override func draw(_: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        context.setLineWidth(1.2)
        context.setStrokeColor(UIColor.black.cgColor)
        let margin = bounds.size.width / (2 * CGFloat(gridSize))
        // draw the grid
        for i in 0 ..< gridSize {
            context.move(to: CGPoint(x: margin, y: margin + CGFloat(i) * margin * 2))
            context.addLine(to: CGPoint(x: bounds.size.width - margin, y: margin + CGFloat(i) * margin * 2))
            context.strokePath()
            context.move(to: CGPoint(x: margin + CGFloat(i) * margin * 2, y: margin))
            context.addLine(to: CGPoint(x: margin + CGFloat(i) * margin * 2, y: bounds.size.width - margin))
            context.strokePath()
        }
        var circle: CGRect
        if !go {
            // draw the 5 little special circles
            circle = CGRect(x: margin + 12 * margin - margin / 2, y: margin + 12 * margin - margin / 2, width: margin, height: margin)
            context.addEllipse(in: circle)
            context.strokePath()
            circle.origin.x = bounds.size.width - margin - 12 * margin - margin / 2
            context.addEllipse(in: circle)
            context.strokePath()
            circle.origin.x = bounds.size.width - margin - 12 * margin - margin / 2
            circle.origin.y = bounds.size.width - margin - 12 * margin - margin / 2
            context.addEllipse(in: circle)
            context.strokePath()
            circle.origin.x = margin + 12 * margin - margin / 2
            circle.origin.y = bounds.size.width - margin - 12 * margin - margin / 2
            context.addEllipse(in: circle)
            context.strokePath()
            circle.origin.x = bounds.size.width / 2 - margin / 2
            circle.origin.y = bounds.size.width / 2 - margin / 2
            context.addEllipse(in: circle)
            context.strokePath()
        } else {
            let c = floor(CGFloat(gridSize / 2))
            let gridSizeFloat = CGFloat(gridSize)
            var l: CGFloat = 3
            if gridSize == 9 {
                l = 2
            }
            circle = CGRect(x: margin + 2 * l * margin - margin / 4, y: margin + 2 * l * margin - margin / 4, width: margin / 2, height: margin / 2)
            context.addEllipse(in: circle)
            context.fillPath()
            circle = CGRect(x: margin + 2 * l * margin - margin / 4, y: margin + 2 * (gridSizeFloat - l - 1) * margin - margin / 4, width: margin / 2, height: margin / 2)
            context.addEllipse(in: circle)
            context.fillPath()
            circle = CGRect(x: margin + 2 * c * margin - margin / 4, y: margin + 2 * c * margin - margin / 4, width: margin / 2, height: margin / 2)
            context.addEllipse(in: circle)
            context.fillPath()
            circle = CGRect(x: margin + 2 * (gridSizeFloat - l - 1) * margin - margin / 4, y: margin + 2 * l * margin - margin / 4, width: margin / 2, height: margin / 2)
            context.addEllipse(in: circle)
            context.fillPath()
            circle = CGRect(x: margin + 2 * (gridSizeFloat - l - 1) * margin - margin / 4, y: margin + 2 * (gridSizeFloat - l - 1) * margin - margin / 4, width: margin / 2, height: margin / 2)
            context.addEllipse(in: circle)
            context.fillPath()

            if gridSize != 9 {
                circle = CGRect(x: margin + 2 * l * margin - margin / 4, y: margin + 2 * c * margin - margin / 4, width: margin / 2, height: margin / 2)
                context.addEllipse(in: circle)
                context.fillPath()
                circle = CGRect(x: margin + 2 * (gridSizeFloat - l - 1) * margin - margin / 4, y: margin + 2 * c * margin - margin / 4, width: margin / 2, height: margin / 2)
                context.addEllipse(in: circle)
                context.fillPath()
                circle = CGRect(x: margin + 2 * c * margin - margin / 4, y: margin + 2 * (gridSizeFloat - l - 1) * margin - margin / 4, width: margin / 2, height: margin / 2)
                context.addEllipse(in: circle)
                context.fillPath()
                circle = CGRect(x: margin + 2 * c * margin - margin / 4, y: margin + 2 * l * margin - margin / 4, width: margin / 2, height: margin / 2)
                context.addEllipse(in: circle)
                context.fillPath()
            }
        }
        for i in 0 ..< gridSize {
            for j in 0 ..< gridSize {
                if table.abstractBoard[i][j] > 0 {
                    circle = CGRect(x: CGFloat(j) * 2 * margin, y: CGFloat(i) * 2 * margin, width: 2 * margin, height: 2 * margin)
                    let centre = CGPoint(x: circle.origin.x + margin - margin / 6, y: circle.origin.y + margin - margin / 6)

                    context.saveGState()
                    let num_locations: size_t = 2
                    let locations: [CGFloat] = [0.0, 1.0]
                    var start: CGFloat = 150.0 / 255.0
                    var end: CGFloat = 0.0
                    if table.abstractBoard[i][j] == StoneColor.white.rawValue {
                        start = 1.0
                        end = 210.0 / 255.0
                    }
                    let components: [CGFloat] = [start, start, start, 1.0, // Start color
                                                 end, end, end, 1.0] // End color

                    let myColorspace = CGColorSpaceCreateDeviceRGB()
                    let myGradient = CGGradient(colorSpace: myColorspace, colorComponents: components, locations: locations, count: num_locations)

                    context.addEllipse(in: circle)
                    context.setShadow(offset: CGSize(width: margin / 6, height: margin / 6), blur: 0)
                    context.fillPath()
                    context.addEllipse(in: circle)
                    context.clip()
                    context.drawRadialGradient(myGradient!, startCenter: centre, startRadius: 0.0, endCenter: centre, endRadius: 5 * margin / 4, options: CGGradientDrawingOptions(rawValue: 0))
                    context.restoreGState()
                }
            }
        }

        if goDeadStones != nil {
            for stone in goDeadStones![2]! {
                let i = stone / gridSize, j = stone % gridSize
                circle = CGRect(x: CGFloat(j) * 2 * margin, y: CGFloat(i) * 2 * margin, width: 2 * margin, height: 2 * margin)
                context.saveGState()
                context.translateBy(x: circle.origin.x, y: circle.origin.y)
                whiteStone.frame = circle
                whiteStone.layer.cornerRadius = margin
                whiteStone.layer.render(in: context)
                context.restoreGState()
            }
            for stone in goDeadStones![1]! {
                let i = stone / gridSize, j = stone % gridSize
                circle = CGRect(x: CGFloat(j) * 2 * margin, y: CGFloat(i) * 2 * margin, width: 2 * margin, height: 2 * margin)
                context.saveGState()
                context.translateBy(x: circle.origin.x, y: circle.origin.y)
                blackStone.frame = circle
                blackStone.layer.cornerRadius = margin
                blackStone.layer.render(in: context)
                context.restoreGState()
            }
        }
        if goTerritory != nil {
            for stone in goTerritory![2]! {
                let i = stone / gridSize, j = stone % gridSize
                circle = CGRect(x: CGFloat(j) * 2 * margin + margin * 2 / 3, y: CGFloat(i) * 2 * margin + margin * 2 / 3, width: 2 * margin / 3, height: 2 * margin / 3)
                context.saveGState()
                context.translateBy(x: circle.origin.x, y: circle.origin.y)
                whiteSquare.frame = circle
                whiteSquare.layer.render(in: context)
                context.restoreGState()
            }
            for stone in goTerritory![1]! {
                let i = stone / gridSize, j = stone % gridSize
                circle = CGRect(x: CGFloat(j) * 2 * margin + margin * 2 / 3, y: CGFloat(i) * 2 * margin + margin * 2 / 3, width: 2 * margin / 3, height: 2 * margin / 3)
                context.saveGState()
                context.translateBy(x: circle.origin.x, y: circle.origin.y)
                blackSquare.frame = circle
                blackSquare.layer.render(in: context)
                context.restoreGState()
            }
        }

        let lastMove = table.lastMove()
        if lastMove > -1 {
            context.setFillColor(UIColor.red.cgColor)
            let i = lastMove / gridSize, j = lastMove % gridSize
            circle = CGRect(x: (CGFloat(j) * 2 + 2 / 3) * margin, y: (CGFloat(i) * 2 + 2 / 3) * margin, width: (CGFloat(2) / 3) * margin, height: (CGFloat(2) / 3) * margin)
            context.addEllipse(in: circle)
            context.fillPath()
        }
    }
}

class LiveStone: UIView {
    var color = StoneColor.black
    var fill = false

    init(size: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: 1.3 * size, height: 1.3 * size))
        backgroundColor = UIColor.clear
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)!
    }

    func resize(size: CGFloat) {
        frame = CGRect(x: 0, y: 0, width: 1.3 * size, height: 1.3 * size)
    }

    override func draw(_: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        context.setStrokeColor(UIColor.black.cgColor)
        var circleSide: CGFloat
        if fill {
            circleSide = bounds.size.width
        } else {
            circleSide = bounds.size.width / 1.2
        }
        let indent: CGFloat = (bounds.size.width - circleSide) / 2
        let circle = CGRect(x: indent, y: indent, width: circleSide, height: circleSide)
        let margin: CGFloat = circle.size.width / 2
        let centre = CGPoint(x: circle.origin.x + margin - margin / 6, y: circle.origin.y + margin - margin / 6)

        let num_locations: size_t = 2
        let locations: [CGFloat] = [0.0, 1.0]
        var start: CGFloat = 150.0 / 255.0
        var end: CGFloat = 0.0
        if color == StoneColor.white {
            start = 1.0
            end = 210.0 / 255.0
        }
        var components: [CGFloat] = [start, start, start, 1.0, // Start color
                                     end, end, end, 1.0] // End color
        if color == StoneColor.red {
            start = 1.0; end = 210.0 / 255.0; components[0] = start; components[1] = end; components[2] = end
            components[4] = start; components[5] = 0; components[6] = 0
        }

        let myColorspace = CGColorSpaceCreateDeviceRGB()
        let myGradient = CGGradient(colorSpace: myColorspace, colorComponents: components, locations: locations, count: num_locations)

        context.addEllipse(in: circle)
        context.setShadow(offset: CGSize(width: margin / 6, height: margin / 6), blur: 0)
        context.fillPath()
        context.addEllipse(in: circle)
        context.clip()
        context.drawRadialGradient(myGradient!, startCenter: centre, startRadius: 0.0, endCenter: centre, endRadius: 5 * margin / 4, options: CGGradientDrawingOptions(rawValue: 0))
    }
}

class LiveVerticalLine: UIView {
    override func draw(_: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(3)
        context.move(to: CGPoint(x: bounds.size.width / 2, y: 1))
        context.addLine(to: CGPoint(x: bounds.size.width / 2, y: bounds.size.height))
        context.strokePath()
    }
}

class LiveHorizontalLine: UIView {
    override func draw(_: CGRect) {
        let context = UIGraphicsGetCurrentContext()!
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(3)
        context.move(to: CGPoint(x: 1, y: bounds.size.height / 2))
        context.addLine(to: CGPoint(x: bounds.size.width, y: bounds.size.height / 2))
        context.strokePath()
    }
}
