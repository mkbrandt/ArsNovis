//
//  ArsGraphic.swift
//  ArsNovis
//
//  Created by Matt Brandt on 1/21/15.
//  Copyright (c) 2015 WalkingDog Design. All rights reserved.
//

import Cocoa

class LineGraphic: Graphic
{
    var endPoint: CGPoint {
        willSet {
            willChangeValueForKey("vector")
            willChangeValueForKey("length")
            willChangeValueForKey("angle")
        }
        didSet {
            cachedPath = nil
            didChangeValueForKey("vector")
            didChangeValueForKey("length")
            didChangeValueForKey("angle")
        }
    }
    
    var vector: CGPoint {
        get { return endPoint - origin }
        set { endPoint = origin + newValue }
    }
    
    var length: CGFloat {
        get { return vector.length }
        set { vector = CGPoint(length: newValue, angle: vector.angle) }
    }
    
    var angle: CGFloat {
        get { return vector.angle }
        set { vector = CGPoint(length: vector.length, angle: newValue) }
    }
    
    var center: CGPoint { return (origin + endPoint) / 2.0 }
    
    override var points: [CGPoint] { return [origin, endPoint] }
    
    override var bounds: CGRect { return NSInsetRect(rectContainingPoints([origin, origin + vector]), -lineWidth, -lineWidth) }
    
    required override init(origin: CGPoint) {
        endPoint = origin + CGPoint(x: 1, y: 1)
        super.init(origin: origin)
    }
    
    init(origin: CGPoint, vector: CGPoint) {
        endPoint = origin + vector
        super.init(origin: origin)
    }
    
    init(origin: CGPoint, endPoint: CGPoint) {
        self.endPoint = endPoint
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        endPoint = decoder.decodePointForKey("endPoint")
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        coder.encodePoint(endPoint, forKey: "endPoint")
    }
    
    override func setPoint(point: CGPoint, atIndex index: Int) {
        switch index {
        case 0:
            origin = point
        case 1:
            endPoint = point
        default:
            break
        }
    }
    
    override func recache() {
        cachedPath = NSBezierPath()
        if let cachedPath = cachedPath {
            cachedPath.moveToPoint(origin)
            cachedPath.lineToPoint(origin + vector)
        }
    }
    
    override var description: String { return "LineGraphic @ \(origin),\(endPoint)"}
    
    func pointOnLine(point: CGPoint) -> Bool {
        return distanceToPoint(point) < IOTA 
    }
    
    func isParallelWith(line: LineGraphic) -> Bool {
        return abs(line.angle - angle) < 0.00001
            || abs(line.angle + angle) < 0.00001
    }
    
    func isColinearWith(line: LineGraphic) -> Bool {
        return isParallelWith(line) && line.distanceToPoint(origin, extended: true) < 0.00001
    }
    
    func intersectionWithLine(line: LineGraphic, extendSelf: Bool, extendOther: Bool) -> CGPoint? {
        if isParallelWith(line) {
            return nil
        }
        
        let p = origin
        let q = line.origin
        let r = vector
        let s = line.vector
        let rxs = crossProduct(r, s)
        if rxs == 0 {
            return nil
        }
        let t = crossProduct((q - p), s) / rxs
        let u = crossProduct((q - p), r) / rxs
        
        if !extendSelf && (t < 0 || t > 1.0) || !extendOther && (u < 0 || u > 1.0) {
            return nil
        }
        
        return p + t * r
    }
    
    override func intersectsWithGraphic(g: Graphic) -> Bool {
        if let g = g as? LineGraphic {
            return intersectionWithLine(g, extendSelf: false, extendOther: false) != nil
        } else {
            return g.intersectsWithGraphic(self)
        }
    }
    
    override func intersectionsWithGraphic(g: Graphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        if let g = g as? LineGraphic {
            if let p = intersectionWithLine(g, extendSelf: extendSelf, extendOther: extendOther) {
                return [p]
            }
        } else {
            return g.intersectionsWithGraphic(self, extendSelf: extendOther, extendOther: extendSelf)
        }
        return []
    }
    
    func intersectionWithLine(g: LineGraphic) -> CGPoint? {
        return intersectionWithLine(g, extendSelf: false, extendOther: false)
    }
    
    override func shouldSelectInRect(rect: CGRect) -> Bool {
        if rect.contains(origin) || rect.contains(endPoint)
        {
            return true
        }
        
        let top = LineGraphic(origin: rect.origin, vector: CGPoint(x: rect.size.width, y: 0))
        let left = LineGraphic(origin: rect.origin, vector: CGPoint(x: 0, y: rect.size.height))
        let right = LineGraphic(origin: top.endPoint, vector: CGPoint(x: 0, y: rect.size.height))
        let bottom = LineGraphic(origin: left.endPoint, endPoint: right.endPoint)
        
        return intersectionWithLine(top) != nil || intersectionWithLine(left) != nil || intersectionWithLine(right) != nil || intersectionWithLine(bottom) != nil
    }
    
    override func snapCursor(location: CGPoint) -> SnapResult? {
        if let snap = super.snapCursor(location) {
            return snap
        }
        if center.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: center, type: .Center)
        }
        let p = closestPointToPoint(location)
        if p.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: p, type: .On)
        }
        return nil
    }
    
    override func closestPointToPoint(point: CGPoint, extended: Bool = false) -> CGPoint {
        let v2 = point - origin;
        
        let len = dotProduct(vector, v2) / vector.length
        let plen = vector.length
        if( !extended && len > plen )
        {
            return origin + vector
        }
        else if( !extended && len < 0 )
        {
            return origin;
        }
        
        let angle = vector.angle;
        var v = CGPoint(length: len, angle: angle)
        
        if vector.x == 0 {              // force vertical
            v.x = 0
        } else if vector.y == 0 {       // force horizontal
            v.y = 0
        }
        return origin + v;
    }
    
    override func distanceToPoint(p: CGPoint, extended: Bool = false) -> CGFloat {
        let v = closestPointToPoint(p, extended: extended)
        
        return (p - v).length
    }
    
    override func divideAtPoint(point: CGPoint) -> [Graphic] {
        let lines = [LineGraphic(origin: origin, endPoint: point), LineGraphic(origin: point, endPoint: endPoint)]
        
        return lines
    }
    
    override func extendToIntersectionWith(g: Graphic, closeToPoint: CGPoint) -> Graphic {
        var intersections = intersectionsWithGraphic(g, extendSelf: true, extendOther: true)
        intersections = intersections.sort { $0.distanceToPoint(closeToPoint) < $1.distanceToPoint(closeToPoint) }
        if intersections.count > 0 {
            let intersection = intersections[0]
            if intersection.distanceToPoint(origin) < intersection.distanceToPoint(endPoint) {
                return LineGraphic(origin: intersection, endPoint: endPoint)
            } else {
                return LineGraphic(origin: origin, endPoint: intersection)
            }
        }
        return self
    }
    
    func insetBy(distance: CGFloat) -> LineGraphic {
        let insetVector = CGPoint(length: distance, angle: angle)
        return LineGraphic(origin: origin + insetVector, vector: vector - insetVector)
    }
    
    override func addReshapeSnapConstructionsAtPoint(point: CGPoint, toView view: DrawingView) {
        let line = ConstructionLine(origin: center, vector: CGPoint(length: 1, angle: vector.angle), reference: [self])
        view.addSnapConstructions([line])
    }
    
    override var inspectionKeys: [String] {
        var keys = super.inspectionKeys
        
        keys += ["length", "angle"]
        return keys
    }
    
    override var defaultInspectionKey: String {
        return "length"
    }
    
    override func typeForKey(key: String) -> MeasurementType {
        if key == "angle" {
            return .Angle
        }
        return super.typeForKey(key)
    }
}

class ConstructionLine: LineGraphic
{
    override var isConstruction: Bool { return true }
    override var points: [CGPoint] { return [] }
    var constrainedAngle: CGFloat = 0

    override var angle: CGFloat {
        get { return constrainedAngle }
        set {  }
    }

    override var description: String { return "Construction @ \(origin), \(endPoint)" }
    
    override var isActive: Bool {
        didSet {
            if isActive {
                lineColor = NSColor.blueColor().colorWithAlphaComponent(0.5)
            } else {
                lineColor = NSColor.clearColor()
            }
        }
    }
    
    var snapOverride: SnapType = SnapType.Align
    
    convenience init(origin: CGPoint, endPoint: CGPoint, reference: [Graphic]) {
        self.init(origin: origin, endPoint: endPoint)
        ref = reference
        constrainedAngle = super.angle
        isActive = false
    }
    
    convenience init(origin: CGPoint, vector: CGPoint, reference: [Graphic]) {
        self.init(origin: origin, vector: vector)
        ref = reference
        constrainedAngle = super.angle
        isActive = false
    }

    override func intersectionWithLine(line: LineGraphic, extendSelf: Bool, extendOther: Bool) -> CGPoint? {
        if let line = line as? ConstructionLine {
            if line.origin == origin {
                return nil
            }
        } else if line.origin == origin || line.endPoint == origin || line.center == origin {
            return nil
        }
        return super.intersectionWithLine(line, extendSelf: true, extendOther: extendOther)
    }

    override func distanceToPoint(p: CGPoint, extended: Bool = true) -> CGFloat {
        return super.distanceToPoint(p, extended: extended)
    }

    override func snapCursor(location: CGPoint) -> SnapResult? {
        length = 1
        super.angle = constrainedAngle
        let p = closestPointToPoint(location, extended: true)
        if p.distanceToPoint(location) < SnapRadius {
            endPoint = p
            return SnapResult(location: p, type: snapOverride)
        }
        return nil
    }
}

class LineTool: GraphicTool
{
    func snapPoint(p1: CGPoint, relativeToPoint p2: CGPoint) -> SnapResult? {
        let offset = p1 - p2
        if abs(offset.y) < SnapRadius {
            return SnapResult(location: CGPoint(x: p1.x, y: p2.y), type: .Horizontal)
        }
        if abs(offset.x) < SnapRadius {
            return SnapResult(location: CGPoint(x: p2.x, y: p1.y), type: .Vertical)
        }
        return nil
    }
    
    override func cursor() -> NSCursor {
        return NSCursor.crosshairCursor()
    }
    
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Drawing Lines")
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        let line = LineGraphic(origin: location, vector: CGPoint(x: 0, y: 0))
        view.construction = line
        view.addSnapConstructionsForPoint(location, reference: [line], includeAngles: true)
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView) {
        if let lg = view.construction as? LineGraphic {
            var location = location
            view.redrawConstruction()
            
            if view.shiftKeyDown {
                location = constrainTo45Degrees(location, relativeToPoint: lg.origin)
            }

            lg.endPoint = location
            
            view.redrawConstruction()
            view.addSnapConstructionsForPoint(lg.origin, reference: [lg], includeAngles: true)
        }
    }
    
    override func mouseUp(location: CGPoint, view: DrawingView) {
        if let line = view.construction as? LineGraphic {
            view.removeSnapConstructionsForReference(line)
            view.addSnapConstructionsForPoint(line.origin, reference: [line])
            view.addSnapConstructionsForPoint(line.endPoint, reference: [line])
            view.addConstruction()
        }
    }
}

