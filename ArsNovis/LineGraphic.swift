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
    var vector: CGPoint {
        didSet {
            willChangeValueForKey("endPoint")
            willChangeValueForKey("length")
            willChangeValueForKey("angle")
            cachedPath = nil
            didChangeValueForKey("endPoint")
            didChangeValueForKey("length")
            didChangeValueForKey("angle")
        }
    }
    
    var endPoint: CGPoint {
        get { return origin + vector }
        set { vector = newValue - origin; cachedPath = nil }
    }
    
    var length: CGFloat {
        get { return vector.length }
        set { vector = CGPoint(length: newValue, angle: vector.angle) }
    }
    
    var angle: CGFloat {
        get { return vector.angle }
        set { vector = CGPoint(length: vector.length, angle: newValue) }
    }
    
    override var points: Array<CGPoint> {
        get { return [origin, endPoint] }
    }
    
    override var bounds: CGRect {
        get{ return NSInsetRect(rectContainingPoints([origin, origin + vector]), -lineWidth, -lineWidth) }
    }
    
    required override init(origin: CGPoint)
    {
        vector = CGPoint(x: 1, y: 1)
        super.init(origin: origin)
    }
    
    init(origin: CGPoint, vector: CGPoint)
    {
        self.vector = vector
        super.init(origin: origin)
    }
    
    init(origin: CGPoint, endPoint: CGPoint)
    {
        vector = endPoint - origin
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        vector = decoder.decodePointForKey("vector")
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        coder.encodePoint(vector, forKey: "vector")
    }
    
    override func setPoint(point: CGPoint, atIndex index: Int) {
        switch index {
        case 0:
            let ep = endPoint
            origin = point
            endPoint = ep
        case 1:
            endPoint = point
        default:
            break
        }
    }
    
    override func recache() {
        cachedPath = NSBezierPath()
        cachedPath!.lineWidth = lineWidth
        cachedPath!.moveToPoint(origin)
        cachedPath!.lineToPoint(origin + vector)
    }
    
    override var description: String {
        get { return "LineGraphic(\(origin),\(vector))" }
    }
    
    func pointOnLine(point: CGPoint) -> Bool {
        let v = point - origin
        
        return v.length <= vector.length && v.angle == vector.angle
    }
    
    func intersectionWithLine(line: LineGraphic, extended: Bool = false) -> CGPoint? {
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
        
        if !extended && (t < 0 || t > 1.0 || u < 0 || u > 1.0) {
            return nil
        }
        
        return p + t * r
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
        let center = (origin + endPoint) / 2.0
        if center.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: center, type: .Center)
        }
        let p = closestPointToPoint(location)
        if p.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: p, type: .On)
        }
        return nil
    }
    
    override func closestPointToPoint(point: CGPoint, extended: Bool = false) -> CGPoint
    {
        let v2 = point - origin;
        
        let len = dotProduct(vector, v2) / vector.length
        let plen = vector.length
        if( len > plen )
        {
            return origin + vector
        }
        else if( plen < 0 )
        {
            return origin;
        }
        
        let angle = vector.angle;
        let v = CGPoint(length: len, angle: angle)
        
        return origin + v;
    }
    
    override func distanceToPoint(p: CGPoint, extended: Bool = false) -> CGFloat
    {
        let v = closestPointToPoint(p, extended: extended)
        
        return (p - v).length
    }
    
    override func inspectionKeys() -> [String]
    {
        var keys = super.inspectionKeys()
        
        keys += ["length", "angle"]
        return keys
    }
    
    override func transformerForKey(key: String) -> NSValueTransformer
    {
        if key == "angle" {
            return AngleTransformer()
        }
        return super.transformerForKey(key)
    }
}

class LineTool: GraphicTool
{
    override func cursor() -> NSCursor {
        return NSCursor.crosshairCursor()
    }
    
    override func selectTool(view: DrawingView)
    {
        view.setDrawingHint("Drawing Lines")
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView)
    {
        view.construction = LineGraphic(origin: location, vector: CGPoint(x: 0, y: 0))
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView)
    {
        if let lg = view.construction as? LineGraphic {
            view.redrawConstruction()
            
            lg.vector = location - lg.origin
            
            view.redrawConstruction()
        }
    }
}

