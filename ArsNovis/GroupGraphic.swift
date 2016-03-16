//
//  GroupGraphic.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/16/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class GroupGraphic: RectGraphic
{
    var contents: [Graphic] = []
    
    override var origin: CGPoint {
        get { return bounds.origin }
        set { moveOriginTo(newValue) }
    }
    
    override var size: NSSize {
        set {
            willChangeValueForKey("width")
            willChangeValueForKey("height")
            scaleFromRect(bounds, toRect: CGRect(origin: bounds.origin, size: newValue))
            cachedPath = nil
            didChangeValueForKey("width")
            didChangeValueForKey("height")
        }
        get {
            return bounds.size
        }
    }
    
    override var bounds: CGRect {
        var b = CGRect()
        
        for g in contents {
            b = b + g.bounds
        }
        
        return b
    }
    
    init(contents: [Graphic]) {
        super.init(origin: CGPoint(x: 0, y: 0))
        self.contents = contents
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(origin: CGPoint(x: 0, y: 0))
        if let contents = decoder.decodeObjectForKey("contents") as? [Graphic] {
            self.contents = contents
        }
    }

    required convenience init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(contents, forKey: "contents")
    }
    
    override func moveOriginBy(vector: CGPoint) {
        for g in contents {
            g.moveOriginBy(vector)
        }
    }
    
    override func drawInView(view: DrawingView) {
        for g in contents {
            g.drawInView(view)
        }
        if showHandles {
            drawHandlesInView(view)
        }
    }
    
    override func snapCursor(location: CGPoint) -> SnapResult? {
        for g in contents {
            if let snap = g.snapCursor(location) {
                return snap
            }
        }
        return nil
    }
    
    override func closestPointToPoint(point: CGPoint, extended: Bool) -> CGPoint {
        var cp = origin
        for p in points {
            if p.distanceToPoint(point) < cp.distanceToPoint(point) {
                cp = p
            }
        }
        
        for g in contents {
            let cp2 = g.closestPointToPoint(point, extended: extended)
            if cp2.distanceToPoint(point) < cp.distanceToPoint(point) {
                cp = cp2
            }
        }
        return cp
    }
    
    override func closestIntersectionWithGraphic(g: Graphic, toPoint p: CGPoint) -> CGPoint? {
        var cp: CGPoint? = nil
        for g2 in contents {
            if let cp2 = g2.closestIntersectionWithGraphic(g, toPoint: p) {
                if let cpx = cp {
                    if cp2.distanceToPoint(p) < cpx.distanceToPoint(p) {
                        cp = cp2
                    }
                } else {
                    cp = cp2
                }
            }
        }
        return cp
    }
    
    override func scaleFromRect(fromRect: CGRect, toRect: CGRect) {
        for g in contents {
            g.scaleFromRect(fromRect, toRect: toRect)
        }
    }
    
    override func intersectionsWithGraphic(g: Graphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        return contents.flatMap { $0.intersectionsWithGraphic(g, extendSelf: extendSelf, extendOther: extendOther) }
    }
    
    override var description: String { return "Group with contents \(contents)" }
}
