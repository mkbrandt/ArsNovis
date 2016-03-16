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
    var size: NSSize {
        willSet {
            willChangeValueForKey("width")
            willChangeValueForKey("height")
        }
        didSet {
            cachedPath = nil
            didChangeValueForKey("width")
            didChangeValueForKey("height")
        }
    }
    
    var width: CGFloat {
        get { return size.width }
        set {
            let newSize = CGSize(width: newValue, height: size.height)
            size = newSize
        }
    }
    
    var height: CGFloat {
        get { return size.height }
        set {
            let newSize = CGSize(width: size.width, height: newValue)
            size = newSize
        }
    }
    
    override var points: [CGPoint] {
        get {
            let p1 = CGPoint(x: origin.x + size.width, y: origin.y)
            let p2 = CGPoint(x: origin.x + size.width, y: origin.y + size.height)
            let p3 = CGPoint(x: origin.x, y: origin.y + size.height)
            return [origin, p1, p2, p3]
        }
    }
    
    override var bounds: CGRect { return NSInsetRect(CGRect(origin: origin, size: size), -lineWidth, -lineWidth) }
    
    override init(origin: CGPoint) {
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
            let newSize = CGSize(width: size.width - (point.x - origin.x), height: size.height - (point.y - origin.y))
            size = newSize
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
        if let cachedPath = cachedPath {
            cachedPath.appendBezierPathWithRect(CGRect(origin: origin, size: size))
        }
    }
    
    var sides: [LineGraphic] {
        let top = LineGraphic(origin: origin, vector: CGPoint(x: size.width, y: 0))
        let left = LineGraphic(origin: origin, vector: CGPoint(x: 0, y: size.height))
        let right = LineGraphic(origin: top.endPoint, vector: CGPoint(x: 0, y: size.height))
        let bottom = LineGraphic(origin: left.endPoint, endPoint: right.endPoint)

        return [top, left, bottom, right]
    }
    
    override func intersectsWithGraphic(g: Graphic) -> Bool {
        return sides.reduce(false, combine: { return $0 || $1.intersectsWithGraphic(g) })
    }
    
    override func intersectionsWithGraphic(g: Graphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        
        return Array(sides.map({ $0.intersectionsWithGraphic(g, extendSelf: extendSelf, extendOther: extendOther) }).flatten())
    }
   
    override func snapCursor(location: CGPoint) -> SnapResult? {
        return sides.reduce(nil, combine: { return $0 ?? $1.snapCursor(location) })
    }
    
    override func closestPointToPoint(point: CGPoint, extended: Bool = false) -> CGPoint {
        let points = sides.map { $0.closestPointToPoint(point) }
        
        var distance = CGFloat.infinity
        var closest = CGPoint()
        for p in points {
            let dist = p.distanceToPoint(point)
            if dist < distance {
                closest = p
                distance = dist
            }
        }
        return closest
    }
    
    override var description: String { return "RectGraphic(\(origin),\(size))" }

    override var inspectionKeys: [String] {
        var keys = super.inspectionKeys
        
        keys += ["width", "height"]
        return keys
    }
    
    override var defaultInspectionKey: String {
        return "width"
    }
}

class ElipseGraphic: RectGraphic
{
    override func recache()
    {
        cachedPath = NSBezierPath(ovalInRect: CGRect(origin: origin, size: size))
    }
    
    override func intersectionsWithGraphic(g: Graphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        return simpleIntersectionsWithGraphic(g, extendSelf: extendSelf, extendOther: extendOther)
    }
    
    override func snapCursor(location: CGPoint) -> SnapResult? {
        if let bp = BezierGraphic(path: path) {
            return bp.snapCursor(location)
        }
        return nil
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
    
    override func mouseDragged(var location: CGPoint, view: DrawingView) {
        if view.shiftKeyDown {
            location = constrainTo45Degrees(location, relativeToPoint: startPoint)
        }
        let r = rectContainingPoints([startPoint, location])
        if let rg = view.construction as? RectGraphic {
            view.redrawConstruction()
            
            rg.origin = r.origin
            rg.size = r.size
            
            view.redrawConstruction()
        }
    }
}

class CenterRectTool: GraphicTool
{
    var startPoint = CGPoint(x: 0, y: 0)
    
    override func cursor() -> NSCursor {
        return NSCursor.crosshairCursor()
    }
    
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Drawing Rectangles from Center")
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        startPoint = location
        view.construction = RectGraphic(origin: location, size: NSSize(width: 0, height: 0))
    }
    
    override func mouseDragged(var location: CGPoint, view: DrawingView) {
        if view.shiftKeyDown {
            location = constrainTo45Degrees(location, relativeToPoint: startPoint)
        }
        let r = rectContainingPoints([startPoint + startPoint - location, location])
        if let rg = view.construction as? RectGraphic {
            view.redrawConstruction()
            
            rg.origin = r.origin
            rg.size = r.size
            
            view.redrawConstruction()
        }
    }
}

class ElipseTool: RectTool
{
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Drawing Elipses by corner")
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        startPoint = location
        view.construction = ElipseGraphic(origin: location, size: NSSize(width: 0, height: 0))
    }
}


class CenterElipseTool: CenterRectTool
{
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Drawing Elipse from Center")
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        startPoint = location
        view.construction = ElipseGraphic(origin: location, size: NSSize(width: 0, height: 0))
    }
}


