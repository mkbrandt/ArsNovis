//
//  ArcGraphic.swift
//  ArsNovis
//
//  Created by Matt Brandt on 7/16/14.
//  Copyright (c) 2014 WalkingDog Design. All rights reserved.
//

import Cocoa

enum ArcInspectionMode {
    case ThreePoint, CenterRadius
}

class ArcGraphic: Graphic
{
    var midPoint: CGPoint {
        didSet { cachedPath = nil }
    }
    
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
            cachedPath = nil
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
            
            let p = l1.intersectionWithLine(l2, extendSelf: true, extendOther: true)
            if p != nil {
                return p!
            }
            return (origin + endPoint) * 0.5
        }
    }
    
    var radius: CGFloat {
        get { return (center - origin).length }
    }
    
    var startAngle: CGFloat {
        get { return (origin - center).angle }
        set {
            origin = center + CGPoint(length: radius, angle: newValue)
            midPoint = center + CGPoint(length: radius, angle: (newValue + endAngle) / 2.0)
        }
    }
    
    var endAngle: CGFloat {
        get { return (endPoint - center).angle }
        set {
            endPoint = center + CGPoint(length: radius, angle: newValue)
            midPoint = center + CGPoint(length: radius, angle: (newValue + startAngle) / 2.0)
        }
    }
    
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
    
    override var description: String { return "Arc @ \(center), \(radius)" }
    
    override var points: Array<CGPoint> { return [origin, midPoint, endPoint] }
    
    override var bounds: CGRect {
        get {
            if cachedPath == nil {
                recache()
            }
            let b = cachedPath!.bounds
            return NSInsetRect(b, -lineWidth, -lineWidth)
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
    
    override func encodeWithCoder(aCoder: NSCoder) {
        super.encodeWithCoder(aCoder)
        aCoder.encodePoint(midPoint, forKey: "midPoint")
        aCoder.encodePoint(endPoint, forKey: "endPoint")
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
    
    func intersectionsWithLine(line: LineGraphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        var points: [CGPoint]
        let p = line.closestPointToPoint(center, extended: true)
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
        
        var intersections: [CGPoint] = []
        
        for point in points {
            if (extendOther || line.pointOnLine(point)) && (extendSelf || pointOnArc(point)) {
                intersections.append(point)
            }
        }
        
        return intersections
    }
    
    func intersectionsWithArc(arc: ArcGraphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        let d = center.distanceToPoint(arc.center)
        if d == 0 {
            return []
        }
        if d > radius + arc.radius {
            return []
        }
        if d < abs(radius - arc.radius) {
            return []
        }
        
        var intersections: [CGPoint] = []
        if center.distanceToPoint(arc.center) == radius + arc.radius {
            var v = arc.center - center
            v.length = radius
            intersections = [center + v]
        } else {
            let a = (radius * radius - arc.radius * arc.radius + d * d) / (d * 2)
            let h = sqrt(radius * radius - a * a)
            var va = arc.center - center
            va.length = a
            let vh = CGPoint(length: h, angle: va.angle + PI / 2)
            intersections = [center + va + vh, center + va - vh]
        }

        if !extendSelf {
            intersections = intersections.filter { return pointOnArc($0) && arc.pointOnArc($0) }
        }
        return intersections
    }
    
    override func intersectionsWithGraphic(g: Graphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        if let arc = g as? ArcGraphic {
            return intersectionsWithArc(arc, extendSelf: extendSelf, extendOther: extendOther)
        } else if let line = g as? LineGraphic {
            return intersectionsWithLine(line, extendSelf: extendSelf, extendOther: extendOther)
        } else if let rect = g as? RectGraphic {
            return rect.sides.reduce([], combine: {$0 + intersectionsWithLine($1, extendSelf: extendSelf, extendOther: extendOther)})
        }
        return []
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
        return intersectionsWithLine(line, extendSelf: false, extendOther: false).count > 0
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
    
    override func closestPointToPoint(point: CGPoint, extended: Bool = false) -> CGPoint {
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
    
    override func distanceToPoint(point: CGPoint, extended: Bool) -> CGFloat {
        let d = super.distanceToPoint(point, extended: extended)
        return d
    }
    
    override func recache() {
        cachedPath = NSBezierPath()
        
        let r = radius
        let a = (origin - center).angle * 180.0 / PI
        let b = (endPoint - center).angle * 180.0 / PI
        
        if let cachedPath = cachedPath {
            cachedPath.moveToPoint(origin)
            cachedPath.appendBezierPathWithArcWithCenter(center, radius: r, startAngle: a, endAngle: b, clockwise: clockwise)
        }
    }
}

class Arc3PtTool: GraphicTool
{
    var state = 0
    
    override func cursor() -> NSCursor {
        return NSCursor.crosshairCursor()
    }
    
    override func selectTool(view: DrawingView) {
        state = 0
        view.setDrawingHint("3 Point Arc: Select start point")
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        switch state {
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
    
    override func mouseMoved(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        if let ag = view.construction as? ArcGraphic {
            switch state {
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
    
    override func mouseDragged(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        
        switch state {
        case 0:
            state = 1
            fallthrough
        default:
            mouseMoved(location, view: view)
        }
        
        view.redrawConstruction()
    }
    
    override func mouseUp(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        switch state {
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

class ArcCenterTool: GraphicTool
{
    var state = 0
    var center = CGPoint()
    var radius = CGFloat(0)
    var startAngle = CGFloat(0)
    var lastMidPoint = CGPoint()
    
    override func cursor() -> NSCursor {
        return NSCursor.crosshairCursor()
    }
    
    override func selectTool(view: DrawingView) {
        state = 0
        view.setDrawingHint("Arc from center: Drag radius to start point")
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        switch state {
        case 0:
            view.construction = LineGraphic(origin: location)
        default:
            break
        }
        view.redrawConstruction()
    }
    
    override func mouseMoved(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        switch state {
        case 0:
            break
        default:
            var endAngle = (location - center).angle
            var midAngle = (lastMidPoint - center).angle
            
            if startAngle > PI / 2 && endAngle < 0 {
                endAngle += 2 * PI
            } else if startAngle < -PI / 2 && endAngle > 0 {
                endAngle -= 2 * PI
            }
            
            if startAngle > PI / 2 && midAngle < 0 {
                midAngle += 2 * PI
            } else if startAngle < -PI / 2 && midAngle > 0 {
                midAngle -= 2 * PI
            }
            
            let arc = ArcGraphic(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle)
            if (midAngle - startAngle > PI / 4 && endAngle - startAngle < 0 || midAngle - startAngle < -PI / 4 && endAngle - startAngle > 0) {
                    arc.midPoint = lastMidPoint
            } else {
                lastMidPoint = arc.midPoint
            }
            view.construction = arc
        }
        view.redrawConstruction()
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        switch state {
        case 0:
            if let line = view.construction as? LineGraphic {
                line.endPoint = location
            }
        default:
            mouseMoved(location, view: view)
        }
        view.redrawConstruction()
    }
    
    override func mouseUp(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        switch state {
        case 0:
            state = 1
            if let line = view.construction as? LineGraphic {
                center = line.origin
                radius = line.length
                startAngle = line.angle
                lastMidPoint = location
                view.construction = ArcGraphic(center: center, radius: radius, startAngle: startAngle, endAngle: startAngle)
                print("construction = \(view.construction)")
            }
            view.setDrawingHint("Arc from center: Set end angle")
        default:
            state = 0
            view.addConstruction()
            view.setDrawingHint("Arc from center: Drag radius")
        }
        view.redrawConstruction()
    }
}
