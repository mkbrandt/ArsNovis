//
//  CircleGraphic.swift
//  ArsNovis
//
//  Created by Matt Brandt on 4/15/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class CircleGraphic: Graphic
{
    var radius: CGFloat     { didSet { cachedPath = nil }}
    
    override var points: [CGPoint]  { return [origin, origin + CGPoint(x: 0, y: radius)] }
    override var description: String    { return "Circle @ \(origin), radius = \(radius)" }
    
    override var bounds: CGRect         { return CGRect(origin: origin - CGPoint(x: radius, y: radius), size: CGSize(width: radius * 2, height: radius * 2)) }
    
    var asArc: ArcGraphic   { return ArcGraphic(origin: origin, radius: radius, startAngle: 0, endAngle: 2 * PI, clockwise: false) }
    
    init(origin: CGPoint, radius: CGFloat) {
        self.radius = radius
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        radius = CGFloat(decoder.decodeDoubleForKey("radius"))
        super.init(coder: decoder)
    }
    
    required convenience init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        coder.encodeDouble(Double(radius), forKey: "radius")
    }
    
    override func recache() {
        cachedPath = NSBezierPath()
        cachedPath?.lineWidth = lineWidth
        cachedPath?.appendBezierPathWithOvalInRect(bounds)
    }
    
    override func setPoint(point: CGPoint, atIndex index: Int) {
        switch index {
        case 0:
            origin = point
        case 1:
            radius = origin.distanceToPoint(point)
        default:
            break
        }
    }
    
    override func intersectionsWithGraphic(g: Graphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        if let circle = g as? CircleGraphic {
            return asArc.intersectionsWithGraphic(circle.asArc, extendSelf: true, extendOther: true)
        } else {
            return asArc.intersectionsWithGraphic(g, extendSelf: true, extendOther: extendOther)
        }
    }
    
    override func closestPointToPoint(point: CGPoint, extended: Bool) -> CGPoint {
        let angle = (point - origin).angle
        let possible = origin + CGPoint(length: radius, angle: angle)
        if origin.distanceToPoint(point) < possible.distanceToPoint(point) {
            return origin
        } else {
            return possible
        }
    }
    
    override func shouldSelectInRect(rect: CGRect) -> Bool {
        if rect.contains(origin) {
            return true
        }
        return asArc.shouldSelectInRect(rect)
    }
    
    override func snapCursor(location: CGPoint) -> SnapResult? {
        let cp = closestPointToPoint(location, extended: true)
        if origin.distanceToPoint(cp) < SnapRadius {
            return SnapResult(location: origin, type: .Center)
        } else if abs(origin.distanceToPoint(location) - radius) < SnapRadius {
            return SnapResult(location: cp, type: .On)
        }
        return nil
    }
    
    override func divideAtPoint(point: CGPoint) -> [Graphic] {
        return asArc.divideAtPoint(point)
    }
}

class RadiusCircleTool: GraphicTool
{
    var start = CGPoint()
    
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Circle: draw radius")
    }
    
    override func escape(view: DrawingView) {
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        start = location
    }
    
    override func mouseMoved(location: CGPoint, view: DrawingView) {
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        view.construction = CircleGraphic(origin: start, radius: start.distanceToPoint(location))
        view.redrawConstruction()
    }
    
    override func mouseUp(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        view.addConstruction()
        view.redrawConstruction()
    }
}

class DiameterCircleTool: RadiusCircleTool
{
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Circle: draw diameter")
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        let origin = (start + location) / 2
        view.construction = CircleGraphic(origin: origin, radius: origin.distanceToPoint(location))
        view.redrawConstruction()
    }
    
}
