//
//  WallGraphic.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/21/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class WallGraphic: LineGraphic
{
    var width: CGFloat = 450
    
    var perpendicularAngle: CGFloat {
        return normalizeAngle(angle + PI / 2)
    }
    
    var outerLines: [LineGraphic] {
        let extendedOrigin = origin - CGPoint(length: width / 2, angle: angle)
        let extendedVector = vector + CGPoint(length: width, angle: angle)
        let lineOffset = CGPoint(length: width / 2, angle: perpendicularAngle)
        let origin1 = extendedOrigin + lineOffset
        let origin2 = extendedOrigin - lineOffset
        return [LineGraphic(origin: origin1, vector: extendedVector), LineGraphic(origin: origin2, vector: extendedVector)]
    }
    
    override var bounds: CGRect {
        return rectContainingPoints(Array(outerLines.map({ return $0.points }).flatten()))
    }
    
    func intersectionWithWall(wg: WallGraphic) -> CGPoint? {
        if let intersection = super.intersectionWithLine(wg) {
            return intersection
        }
        return nil
    }
    
    func wallIntersectionsInView(view: DrawingView) -> [(WallGraphic, CGPoint)] {
        var graphics = view.displayList
        if let construction = view.construction {
            graphics.append(construction)
        }
        
        var intersections: [(WallGraphic, CGPoint)] = []
        for g in graphics {
            if let wg = g as? WallGraphic where wg != self {
                if let intersection = intersectionWithWall(wg) {
                    intersections.append((wg, intersection))
                }
            }
        }
        return intersections.sort { origin.distanceToPoint($0.1) < origin.distanceToPoint($1.1) }
    }
    
    override func recache() {
        cachedPath = nil
    }
    
    func intersectionGaps(intersection: CGPoint, otherWall: WallGraphic) -> [LineGraphic] {
        var result: [LineGraphic] = []
        
        for line in outerLines {
            let points = otherWall.outerLines.flatMap { return line.intersectionWithLine($0) }
            if points.count == 2 {
                let l = LineGraphic(origin: points[0], endPoint: points[1])
                if l.intersectionWithLine(otherWall) != nil {
                    result.append(l)
                }
            }
        }
        
        return result
    }
    
    func gapForIntersectionWithLine(line: LineGraphic) -> LineGraphic? {
        var points = outerLines.flatMap { $0.intersectionWithLine(line, extendSelf: true, extendOther: true) }
        if points.count == 2 {
            let farPoint = line.origin - CGPoint(length: width * 2, angle: line.angle)
            points.sortInPlace { farPoint.distanceToPoint($0) < farPoint.distanceToPoint($1) }
            let lg = LineGraphic(origin: points[0], endPoint: points[1])
            if intersectionWithLine(lg) != nil {
                return lg
            }
        }
        return nil
    }
    
    func outerIntersectionsWithLine(line: LineGraphic) -> [CGPoint] {
        var points = outerLines.flatMap { $0.intersectionWithLine(line, extendSelf: true, extendOther: true) }
        let farPoint = line.origin - CGPoint(length: width * 2, angle: line.angle)
        points.sortInPlace { farPoint.distanceToPoint($0) < farPoint.distanceToPoint($1) }
        return points
    }
    
    override func drawInView(view: DrawingView) {
        let path = NSBezierPath()
        lineColor.set()

        let intersections = wallIntersectionsInView(view)
        var lines = outerLines
        
        // origin endcap
        if intersections.count == 0 || intersections[0].1 != origin {
            path.moveToPoint(lines[0].origin)
            path.lineToPoint(lines[1].origin)
        }
        
        // endpoint endcap
        if intersections.count == 0 || intersections[intersections.count - 1].1 != endPoint {
            path.moveToPoint(lines[0].endPoint)
            path.lineToPoint(lines[1].endPoint)
        }

        for line in lines {
            for intersect in intersections {
                let otherWall = intersect.0
                let ip = intersect.1
                if let gap = otherWall.gapForIntersectionWithLine(line) {
                    if ip != origin {
                        path.moveToPoint(line.origin)
                        path.lineToPoint(gap.origin)
                    }
                    if ip == endPoint {
                        line.endPoint = gap.endPoint
                    }
                    let ep = line.endPoint
                    line.origin = gap.endPoint
                    line.endPoint = ep
                } else if ip == origin {
                    let points = otherWall.outerIntersectionsWithLine(line)
                    if let p = points.first {
                        let ep = line.endPoint
                        line.origin = p
                        line.endPoint = ep
                    }
                } else if ip == endPoint {
                    let points = otherWall.outerIntersectionsWithLine(line)
                    if let p = points.last {
                        line.endPoint = p
                    }
                }
            }
            if line.origin != line.endPoint {
                path.moveToPoint(line.origin)
                path.lineToPoint(line.endPoint)
            }
        }
        
        path.lineWidth = view.scaleFloat(lineWidth)
        path.stroke()
        if showHandles {
            drawHandlesInView(view)
        }
    }

    override func divideAtPoint(point: CGPoint) -> [Graphic] {
        let lines = [WallGraphic(origin: origin, endPoint: point), WallGraphic(origin: point, endPoint: endPoint)]
        
        return lines
    }
    
    override func extendToIntersectionWith(g: Graphic, closeToPoint: CGPoint) -> Graphic {
        var intersections = intersectionsWithGraphic(g, extendSelf: true, extendOther: true)
        intersections = intersections.sort { $0.distanceToPoint(closeToPoint) < $1.distanceToPoint(closeToPoint) }
        if intersections.count > 0 {
            let intersection = intersections[0]
            if intersection.distanceToPoint(origin) < intersection.distanceToPoint(endPoint) {
                return WallGraphic(origin: intersection, endPoint: endPoint)
            } else {
                return WallGraphic(origin: origin, endPoint: intersection)
            }
        }
        return self
    }
    
}

class WallTool: GraphicTool
{
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Click and drag to draw wall")
    }
    
    override func escape(view: DrawingView) {
        view.construction = nil
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        let wall = WallGraphic(origin: location, endPoint: location)
        view.construction = wall
        view.addSnapConstructionsForPoint(location, reference: [wall], includeAngles: true)
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        if let wall = view.construction as? WallGraphic {
            wall.endPoint = location
        }
        view.redrawConstruction()
    }
    
    override func mouseUp(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        view.removeSnapConstructionsForReference(view.construction)
        view.addConstruction()
    }
}

