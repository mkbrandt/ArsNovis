//
//  ArcGraphic.swift
//  ArsNovis
//
//  Created by Matt Brandt on 7/16/14.
//  Copyright (c) 2014 WalkingDog Design. All rights reserved.
//

import Cocoa

enum ArcInspectionMode {
    case threePoint, centerRadius
}

class ArcGraphic: Graphic
{
    var radius: CGFloat         { didSet { cachedPath = nil }}
    var startAngle: CGFloat     { didSet { cachedPath = nil }}
    var endAngle: CGFloat       { didSet { cachedPath = nil }}
    var clockwise: Bool         { didSet { cachedPath = nil }}
    
    var startPoint: CGPoint     {
        get { return origin + CGPoint(length: radius, angle: startAngle) }
        set { startAngle = (newValue - origin).angle }
    }
    
    var endPoint: CGPoint     {
        get { return origin + CGPoint(length: radius, angle: endAngle) }
        set { endAngle = (newValue - origin).angle }
    }
    
    var midPoint: CGPoint       {
        get {
            let p1 = origin + CGPoint(length: radius, angle: (startAngle + endAngle) / 2)
            if pointOnArc(p1) {
                return p1
            }
            return origin - (p1 - origin)
        }
        set { radius = (newValue - origin).length }
    }
    
    override var description: String { return "Arc @ \(origin), \(radius), \(startAngle), \(endAngle)" }
    
    override var points: Array<CGPoint> { return [origin, startPoint, endPoint, midPoint] }
    
    override var bounds: CGRect {
        get {
            if cachedPath == nil {
                recache()
            }
            let b = cachedPath!.bounds
            return NSInsetRect(b, -lineWidth, -lineWidth)
        }
    }
    
    override var inspectionName: String { return "Arc" }
    
    override var inspectionInfo: [InspectionInfo] {
        return super.inspectionInfo + [
            InspectionInfo(label: "Radius", key: "radius", type: .distance),
            InspectionInfo(label: "Starting Angle", key: "startAngle", type: .angle),
            InspectionInfo(label: "Ending Angle", key: "endAngle", type: .angle),
            InspectionInfo(label: "Clockwise", key: "clockwise", type: .bool)
        ]
    }
    
    override var inspectionKeys: [String] {
        return ["x", "y", "radius", "startAngle", "endAngle"]
    }
    
    override var defaultInspectionKey: String {
        return "radius"
    }
    
    override func typeForKey(_ key: String) -> MeasurementType {
        switch key {
        case "startAngle", "endAngle":
            return .angle
        default:
            return .distance
        }
    }
    
    override init(origin: CGPoint) {
        radius = 0.0
        startAngle = 0
        endAngle = 0
        clockwise = false
        super.init(origin: origin)
    }
    
    init(origin: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.clockwise = clockwise
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        radius = CGFloat(decoder.decodeDouble(forKey: "radius"))
        startAngle = CGFloat(decoder.decodeDouble(forKey: "startAngle"))
        endAngle = CGFloat(decoder.decodeDouble(forKey: "endAngle"))
        clockwise = decoder.decodeBool(forKey: "clockwise")
        super.init(coder: decoder)
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(Double(startAngle), forKey: "startAngle")
        coder.encode(Double(endAngle), forKey: "endAngle")
        coder.encode(Double(radius), forKey: "radius")
        coder.encode(clockwise, forKey: "clockwise")
    }
    
    func pointOnArc(_ point: CGPoint) -> Bool {
        if point.distanceToPoint(origin) > radius + 0.001 {
            //print("point \(point) too far: distance = \(point.distanceToPoint(center)), radius = \(radius)")
            return false
        }
        let angle = (point - origin).angle
        if startAngle < endAngle {
            if angle >= startAngle && angle <= endAngle {
                return !clockwise
            } else {
                return clockwise
            }
        } else {
            if angle <= startAngle && angle >= endAngle {
                return clockwise
            } else {
                return !clockwise
            }
        }
    }
    
    func intersectionsWithLine(_ line: LineGraphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        var points: [CGPoint]
        let p = line.closestPointToPoint(origin, extended: true)
        let dist = p.distanceToPoint(origin)
        
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
    
    func intersectionsWithArc(_ arc: ArcGraphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        let d = origin.distanceToPoint(arc.origin)
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
        if origin.distanceToPoint(arc.origin) == radius + arc.radius {
            var v = arc.origin - origin
            v.length = radius
            intersections = [origin + v]
        } else {
            let radiusSquared = self.radius * self.radius
            let arcRadiusSquared = arc.radius * arc.radius
            let dSquared = d * d
            let a = (radiusSquared - arcRadiusSquared + dSquared) / (d * 2)
            let h = sqrt(radius * radius - a * a)
            var va = arc.origin - origin
            va.length = a
            let vh = CGPoint(length: h, angle: va.angle + PI / 2)
            intersections = [origin + va + vh, origin + va - vh]
        }

        if !extendSelf {
            intersections = intersections.filter { return pointOnArc($0) && arc.pointOnArc($0) }
        }
        return intersections
    }
    
    override func intersectionsWithGraphic(_ g: Graphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        if let arc = g as? ArcGraphic {
            return intersectionsWithArc(arc, extendSelf: extendSelf, extendOther: extendOther)
        } else if let line = g as? LineGraphic {
            return intersectionsWithLine(line, extendSelf: extendSelf, extendOther: extendOther)
        } else if let rect = g as? RectGraphic {
            return rect.sides.reduce([], combine: {$0 + intersectionsWithLine($1, extendSelf: extendSelf, extendOther: extendOther)})
        }
        return []
    }
    
    override func setPoint(_ point: CGPoint, atIndex index: Int)
    {
        switch index {
        case 0:
            origin = point
        case 1:
            startPoint = point
        case 2:
            endPoint = point
        case 3:
            midPoint = point
        default:
            break
        }
    }
    
    func intersectsWithLine(_ line: LineGraphic) -> Bool {
        return intersectionsWithLine(line, extendSelf: false, extendOther: false).count > 0
    }
    
    override func shouldSelectInRect(_ rect: CGRect) -> Bool {
        if rect.contains(origin) || rect.contains(endPoint) {
            return true
        }
        
        let top = LineGraphic(origin: rect.origin, vector: CGPoint(x: rect.size.width, y: 0))
        let left = LineGraphic(origin: rect.origin, vector: CGPoint(x: 0, y: rect.size.height))
        let right = LineGraphic(origin: top.endPoint, vector: CGPoint(x: 0, y: rect.size.height))
        let bottom = LineGraphic(origin: left.endPoint, endPoint: right.endPoint)
        
        return intersectsWithLine(top) || intersectsWithLine(left) || intersectsWithLine(right) || intersectsWithLine(bottom)
    }
    
    override func snapCursor(_ location: CGPoint) -> SnapResult? {
        if origin.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: origin, type: .center)
        }
        if startPoint.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: startPoint, type: .endPoint)
        }
        if endPoint.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: endPoint, type: .endPoint)
        }
        let cp = closestPointToPoint(location)
        if cp.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: cp, type: .on)
        }
        return nil
    }
    
    override func closestPointToPoint(_ point: CGPoint, extended: Bool = false) -> CGPoint {
        let a = (point - origin).angle
        let p = CGPoint(length: radius, angle: a) + origin
        
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
    
    override func distanceToPoint(_ point: CGPoint, extended: Bool) -> CGFloat {
        let d = super.distanceToPoint(point, extended: extended)
        return d
    }
    
    override func recache() {
        cachedPath = NSBezierPath()
        
        if let cachedPath = cachedPath {
            print("origin = \(origin), radius = \(radius), startAngle = \(startAngle), endAngle = \(endAngle), clockwise = \(clockwise)")
            cachedPath.appendArc(withCenter: origin, radius: radius, startAngle: startAngle * 180 / PI, endAngle: endAngle * 180 / PI, clockwise: clockwise)
        }
    }
    
    override func divideAtPoint(_ point: CGPoint) -> [Graphic] {
        let pointVector = point - origin
        let arc1 = ArcGraphic(origin: origin, radius: radius, startAngle: startAngle, endAngle: pointVector.angle, clockwise: clockwise)
        let arc2 = ArcGraphic(origin: origin, radius: radius, startAngle: pointVector.angle, endAngle: endAngle, clockwise: clockwise)
        return [arc1, arc2]
    }
    
    override func extendToIntersectionWith(_ g: Graphic, closeToPoint: CGPoint) -> Graphic {
        let intersections = intersectionsWithGraphic(g, extendSelf: true, extendOther: true).sorted {
            $0.distanceToPoint(closeToPoint) < $1.distanceToPoint(closeToPoint)
        }
        if intersections.count > 0 {
            let intersection = intersections[0]
            let angle = (intersection - origin).angle
            
            if closeToPoint.distanceToPoint(startPoint) < closeToPoint.distanceToPoint(endPoint) {
                return ArcGraphic(origin: origin, radius: radius, startAngle: angle, endAngle: endAngle, clockwise: clockwise)
            } else {
                return ArcGraphic(origin: origin, radius: radius, startAngle: startAngle, endAngle: angle, clockwise: clockwise)
            }
        }
        return self
    }
    
    override func addReshapeSnapConstructionsAtPoint(_ point: CGPoint, toView: DrawingView) {
        let circle = ElipseGraphic(origin: origin - CGPoint(x: radius, y: radius), size: CGSize(width: radius * 2, height: radius * 2))
        circle.lineColor = NSColor.blue().withAlphaComponent(0.5)
        circle.lineWidth = 0.0
        circle.ref = [self]
        toView.addSnapConstructions([circle])
    }
}

class Arc3PtTool: GraphicTool
{
    var state = 0
    var startPoint = CGPoint()
    var endPoint = CGPoint()
    
    func arcFromStartPoint(_ startPoint: CGPoint, endPoint: CGPoint, midPoint: CGPoint) -> Graphic {
        let mp1 = (startPoint + midPoint) / 2
        let mp2 = (endPoint + midPoint) / 2
        let ang1 = (midPoint - startPoint).angle + PI / 2
        let ang2 = (midPoint - endPoint).angle + PI / 2
        let bisector1 = LineGraphic(origin: mp1, vector: CGPoint(length: 100, angle: ang1))
        let bisector2 = LineGraphic(origin: mp2, vector: CGPoint(length: 100, angle: ang2))
        if let origin = bisector1.intersectionWithLine(bisector2, extendSelf: true, extendOther: true) {
            let radius = (startPoint - origin).length
            let startAngle = (startPoint - origin).angle
            let endAngle = (endPoint - origin).angle
            let clockwise = true
            let g = ArcGraphic(origin: origin, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
            g.clockwise = g.pointOnArc(midPoint)
            return g
        }
        return LineGraphic(origin: startPoint, endPoint: endPoint)
    }
    
    override func cursor() -> NSCursor {
        return NSCursor.crosshair()
    }
    
    override func selectTool(_ view: DrawingView) {
        state = 0
        view.setDrawingHint("3 Point Arc: Select start point")
    }
    
    override func mouseDown(_ location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        switch state {
        case 0:
            startPoint = location
        case 1:
            endPoint = location
            view.construction = LineGraphic(origin: startPoint, endPoint: endPoint)
        default:
            view.construction = arcFromStartPoint(startPoint, endPoint: endPoint, midPoint: location)
        }
        view.redrawConstruction()
    }
    
    override func mouseMoved(_ location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        switch state {
        case 0:
            break
        case 1:
            endPoint = location
            view.construction = LineGraphic(origin: startPoint, endPoint: endPoint)
        default:
            view.construction = arcFromStartPoint(startPoint, endPoint: endPoint, midPoint: location)
        }
        view.redrawConstruction()
    }
    
    override func mouseDragged(_ location: CGPoint, view: DrawingView) {
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
    
    override func mouseUp(_ location: CGPoint, view: DrawingView) {
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
    var origin = CGPoint()
    var radius = CGFloat(0)
    var startAngle = CGFloat(0)
    var clockwise = false
    
    override func cursor() -> NSCursor {
        return NSCursor.crosshair()
    }
    
    override func selectTool(_ view: DrawingView) {
        state = 0
        view.setDrawingHint("Arc from center: Drag radius to start point")
    }
    
    override func mouseDown(_ location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        switch state {
        case 0:
            view.construction = LineGraphic(origin: location)
        default:
            break
        }
        view.redrawConstruction()
    }
    
    override func mouseMoved(_ location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        switch state {
        case 0:
            break
        default:
            let endAngle = (location - origin).angle
            let diffAngle = endAngle - startAngle
            
            if 0 < diffAngle && diffAngle < PI / 90 {
                clockwise = false
            } else if 0 > diffAngle && diffAngle > -PI / 90 {
                clockwise = true
            }

            let arc = ArcGraphic(origin: origin, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
            view.construction = arc
        }
        view.redrawConstruction()
    }
    
    override func mouseDragged(_ location: CGPoint, view: DrawingView) {
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
    
    override func mouseUp(_ location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        switch state {
        case 0:
            state = 1
            if let line = view.construction as? LineGraphic {
                origin = line.origin
                radius = line.length
                startAngle = line.angle
                view.construction = ArcGraphic(origin: origin, radius: radius, startAngle: startAngle, endAngle: startAngle, clockwise: clockwise)
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
