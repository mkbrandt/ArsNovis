//
//  RectGraphic.swift
//  Electra
//
//  Created by Matt Brandt on 7/16/14.
//  Copyright (c) 2014 WalkingDog Design. All rights reserved.
//

import Cocoa

class RectGraphic: Graphic
{
    var size: NSSize
    
    override var points: [CGPoint] {
        get {
            let p1 = CGPoint(x: origin.x + size.width, y: origin.y)
            let p2 = CGPoint(x: origin.x + size.width, y: origin.y + size.height)
            let p3 = CGPoint(x: origin.x, y: origin.y + size.height)
            return [origin, p1, p2, p3]
        }
    }
    
    override var bounds: CGRect { return NSInsetRect(CGRect(origin: origin, size: size), -lineWidth, -lineWidth) }
    
    required override init(origin: CGPoint) {
        size = NSSize(width: 0, height: 0)
        super.init(origin: origin)
    }
    
    init(origin: CGPoint, size: NSSize) {
        self.size = size
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        size = decoder.decodeSizeForKey("size")
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        coder.encodeSize(size, forKey: "size")
    }
    
    override func setPoint(point: CGPoint, atIndex index: Int) {
        switch index {
        case 0:
            size.width -= point.x - origin.x
            size.height -= point.y - origin.y
            origin = point;
        case 1:
            size.width = point.x - origin.x
            size.height -= point.y - origin.y
            origin = CGPoint(x: origin.x, y: point.y)
        case 2:
            size = NSSize(width: point.x - origin.x, height: point.y - origin.y)
        case 3:
            size.height = point.y - origin.y
            size.width -= point.x - origin.x
            origin = CGPoint(x: point.x, y: origin.y)
        default:
            break
        }
    }
    
    override func recache()
    {
        cachedPath = NSBezierPath()
        cachedPath!.lineWidth = lineWidth
        cachedPath!.appendBezierPathWithRect(CGRect(origin: origin, size: size))
    }
   
    override func snapCursor(location: CGPoint) -> SnapResult? {
        let top = LineGraphic(origin: origin, vector: CGPoint(x: size.width, y: 0))
        let left = LineGraphic(origin: origin, vector: CGPoint(x: 0, y: size.height))
        let right = LineGraphic(origin: top.endPoint, vector: CGPoint(x: 0, y: size.height))
        let bottom = LineGraphic(origin: left.endPoint, endPoint: right.endPoint)
        
        return top.snapCursor(location) ?? left.snapCursor(location) ?? bottom.snapCursor(location) ?? right.snapCursor(location)
    }
    
    override func closestPointToPoint(point: CGPoint, extended: Bool = false) -> CGPoint {
        let top = LineGraphic(origin: origin, vector: CGPoint(x: size.width, y: 0))
        let left = LineGraphic(origin: origin, vector: CGPoint(x: 0, y: size.height))
        let right = LineGraphic(origin: top.endPoint, vector: CGPoint(x: 0, y: size.height))
        let bottom = LineGraphic(origin: left.endPoint, endPoint: right.endPoint)
        
        let tp = top.closestPointToPoint(point)
        let lp = left.closestPointToPoint(point)
        let rp = right.closestPointToPoint(point)
        let bp = bottom.closestPointToPoint(point)
        
        var closest = tp
        for p in [lp, rp, bp] {
            if (p - point).length < (closest - point).length {
                closest = p
            }
        }
        return closest
    }
    
    override var description: String {
        get { return "RectGraphic(\(origin),\(size))" }
    }
}

class RectTool: GraphicTool
{
    var startPoint = CGPoint(x: 0, y: 0)
    
    override func cursor() -> NSCursor {
        return NSCursor.crosshairCursor()
    }
    
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Drawing Rectangles")
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        startPoint = location
        view.construction = RectGraphic(origin: location, size: NSSize(width: 0, height: 0))
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView) {
        let r = rectContainingPoints([startPoint, location])
        if let rg = view.construction as? RectGraphic {
            view.redrawConstruction()
            
            rg.origin = r.origin
            rg.size = r.size
            
            view.redrawConstruction()
        }
    }
}

