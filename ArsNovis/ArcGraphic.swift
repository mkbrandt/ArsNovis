//
//  ArcGraphic.swift
//  ArsNovis
//
//  Created by Matt Brandt on 7/16/14.
//  Copyright (c) 2014 WalkingDog Design. All rights reserved.
//

import Cocoa

class ArcGraphic: Graphic
{
    var midPoint: CGPoint
    
    var endPoint: CGPoint {
        didSet {
            if midPoint == origin {
                midPoint = CGPoint(x: (origin.x + endPoint.x) / 2, y: (origin.y + endPoint.y) / 2)
                let v = midPoint - origin;
                let r = v.length
                let a = v.angle + PI / 2
                let v2 = CGPoint(length: r, angle: a)
                midPoint = midPoint + v2
            }
        }
    }
    
    var center: CGPoint {
        get {
            let p1 = (midPoint + origin) * 0.5
            let p2 = (midPoint + endPoint) * 0.5
            let a1 = (origin - midPoint).angle + PI / 2
            let a2 = (midPoint - endPoint).angle + PI / 2
            let v1 = CGPoint(length: 100.0, angle: a1)
            let v2 = CGPoint(length: 100.0, angle: a2)
            let l1 = LineGraphic(origin: p1, vector: v1)
            let l2 = LineGraphic(origin: p2, vector: v2)
            
            let p = l1.intersectionWithLine(l2, extended: true)
            if p != nil {
                return p!
            }
            return (origin + endPoint) * 0.5
        }
    }
    
    var radius: CGFloat { return (center - origin).length }
    
    var clockwise: Bool {
        get {
            let a1 = (midPoint - origin).angle
            let a2 = (endPoint - midPoint).angle
            
            var a3 = a1 - a2
            while a3 < -PI {
                a3 += 2 * PI
            }
            while a3 > PI {
                a3 -= 2 * PI
            }
            
            return a3 > 0
        }
    }
    
    override var points: Array<CGPoint> { return [origin, midPoint, endPoint] }
    
    override var bounds: CGRect {
        get {
            let cachedPath = NSBezierPath()
            cachedPath.lineWidth = lineWidth
            
            let r = radius
            let a = (origin - center).angle * 180.0 / PI
            let b = (endPoint - center).angle * 180.0 / PI
            
            cachedPath.moveToPoint(origin)
            cachedPath.appendBezierPathWithArcWithCenter(center, radius: r, startAngle: a, endAngle: b, clockwise: clockwise)
            let bound = cachedPath.bounds
            return NSInsetRect(bound, -lineWidth, -lineWidth)
        }
    }
    
    override init(origin: CGPoint) {
        midPoint = origin
        endPoint = origin
        super.init(origin: origin)
    }
    
    init(origin: CGPoint, midPoint: CGPoint, endPoint: CGPoint) {
        self.midPoint = midPoint
        self.endPoint = endPoint
        super.init(origin: origin)
    }
    
    init(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat) {
        let origin = center + CGPoint(length: radius, angle: startAngle)
        endPoint = center + CGPoint(length: radius, angle: endAngle)
        midPoint = center + CGPoint(length: radius, angle: (startAngle + endAngle) / 2)
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        midPoint = decoder.decodePointForKey("midPoint")
        endPoint = decoder.decodePointForKey("endPoint")
        super.init(coder: decoder)
    }
    
    func pointOnArc(point: CGPoint) -> Bool {
        if point.distanceToPoint(center) > radius + 0.01 {
            //print("point \(point) too far: distance = \(point.distanceToPoint(center)), radius = \(radius)")
            return false
        }
        let arc2 = ArcGraphic(origin: origin, midPoint: point, endPoint: endPoint)
        
        let rv = arc2.clockwise == clockwise
        //print("Point \(point) on arc is \(rv)")
        return rv
    }
    
    func intersectionsWithLine(line: LineGraphic) -> [CGPoint] {
        var points: [CGPoint]
        let p = line.closestPointToPoint(center, extended: false)
        let dist = p.distanceToPoint(center)
        
        if dist > radius {
            return []
        }
        else if dist == radius {
            points = [p]
        } else {
            let d2 = sqrt(radius * radius - dist * dist)
            let v = CGPoint(length: d2, angle: line.vector.angle)
            points = [p + v, p - v]
        }
        
        var intersections = [] as [CGPoint]
        
        for point in points {
            if line.pointOnLine(point) && pointOnArc(point) {
                intersections.append(point)
            }
        }
        
        return intersections
    }
    
    override func setPoint(point: CGPoint, atIndex index: Int)
    {
        switch index {
        case 0:
            origin = point
        case 1:
            midPoint = point
        case 2:
            endPoint = point
        default:
            break
        }
    }
    
    func intersectsWithLine(line: LineGraphic) -> Bool {
        return intersectionsWithLine(line).count > 0
    }
    
    override func shouldSelectInRect(rect: CGRect) -> Bool {
        if rect.contains(origin) || rect.contains(endPoint) {
            return true
        }
        
        let top = LineGraphic(origin: rect.origin, vector: CGPoint(x: rect.size.width, y: 0))
        let left = LineGraphic(origin: rect.origin, vector: CGPoint(x: 0, y: rect.size.height))
        let right = LineGraphic(origin: top.endPoint, vector: CGPoint(x: 0, y: rect.size.height))
        let bottom = LineGraphic(origin: left.endPoint, endPoint: right.endPoint)
        
        return intersectsWithLine(top) || intersectsWithLine(left) || intersectsWithLine(right) || intersectsWithLine(bottom)
    }
    
    override func snapCursor(location: CGPoint) -> SnapResult? {
        if center.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: center, type: .Center)
        }
        if origin.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: origin, type: .EndPoint)
        }
        if endPoint.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: endPoint, type: .EndPoint)
        }
        let cp = closestPointToPoint(location)
        if cp.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: cp, type: .On)
        }
        return nil
    }
    
    override func closestPointToPoint(point: CGPoint, extended: Bool = false) -> CGPoint
    {
        let a = (point - center).angle
        let p = CGPoint(length: radius, angle: a) + center
        
        if extended || pointOnArc(p) {
            return p
        }
        
        let d0 = (point - origin).length
        let d1 = (point - endPoint).length
        
        if d0 < d1 {
            return origin
        }
        return endPoint
    }
    
    override func distanceToPoint(point: CGPoint, extended: Bool) -> CGFloat
    {
        let d = super.distanceToPoint(point, extended: extended)
        return d
    }
}

class Arc3PtTool: GraphicTool
{
    var state = 0
    
    override func cursor() -> NSCursor {
        return NSCursor.crosshairCursor()
    }
    
    override func selectTool(view: DrawingView)
    {
        state = 0
        view.setDrawingHint("3 Point Arc: Select start point")
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView)
    {
        view.redrawConstruction()
        switch state
        {
        case 0:
            view.construction = ArcGraphic(origin: location)
        case 1:
            if let ag = view.construction as? ArcGraphic {
                ag.endPoint = location
            }
        default:
            if let ag = view.construction as? ArcGraphic {
                ag.midPoint = location
            }
        }
        view.redrawConstruction()
    }
    
    override func mouseMoved(location: CGPoint, view: DrawingView)
    {
        view.redrawConstruction()
        if let ag = view.construction as? ArcGraphic {
            switch state
            {
            case 0:
                break
            case 1:
                ag.endPoint = location
            default:
                ag.midPoint = location
            }
        }
        view.redrawConstruction()
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView)
    {
        view.redrawConstruction()
        
        switch state
        {
        case 0:
            state = 1
            fallthrough
        default:
            mouseMoved(location, view: view)
        }
        
        view.redrawConstruction()
    }
    
    override func mouseUp(location: CGPoint, view: DrawingView)
    {
        view.redrawConstruction()
        switch state
        {
        case 0:
            state = 1
            view.setDrawingHint("3 Point Arc: Select end point")
        case 1:
            state = 2
            view.setDrawingHint("3 Point Arc: Select mid point")
        default:
            state = 0
            view.setDrawingHint("3 Point Arc: Select start point")
            view.addConstruction()
        }
        view.redrawConstruction()
    }
}
