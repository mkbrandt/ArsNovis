//
//  GroupGraphic.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/16/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class GroupGraphic: Graphic
{
    var contents: [Graphic] = []
    
    override var origin: CGPoint {
        get { return bounds.origin }
        set { moveOriginTo(newValue) }
    }
    
    var size: NSSize {
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
    
    override var points: [CGPoint] {
        let topLeft = origin + CGPoint(x: 0, y: size.height)
        let topRight = origin + CGPoint(x: size.width, y: size.height)
        let bottomRight = origin + CGPoint(x: size.width, y: 0)
        
        return [origin, topLeft, topRight, bottomRight]
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
        willChangeValueForKey("origin")
        willChangeValueForKey("x")
        willChangeValueForKey("y")
        for g in contents {
            g.moveOriginBy(vector)
        }
        didChangeValueForKey("origin")
        didChangeValueForKey("x")
        didChangeValueForKey("y")
    }
    
    override func setPoint(point: CGPoint, atIndex index: Int) {
        switch index {
        case 0:
            let sizeDiff = point - origin
            moveOriginTo(point)
            size = CGSize(width: size.width - sizeDiff.x, height: size.height - sizeDiff.y)
        case 1:
            let sizeDiff = point - points[1]
            moveOriginTo(CGPoint(x: point.x, y: origin.y))
            size = CGSize(width: size.width - sizeDiff.x, height: size.height + sizeDiff.y)
        case 2:
            let sizeDiff = point - points[2]
            size = CGSize(width: size.width + sizeDiff.x, height: size.height + sizeDiff.y)
        case 3:
            let sizeDiff = point - points[3]
            moveOriginTo(CGPoint(x: origin.x, y: point.y))
            size = CGSize(width: size.width + sizeDiff.x, height: size.height - sizeDiff.y)
        default:
            break
        }
    }
    
    override func unlink() {
        super.unlink()
        for g in contents {
            g.unlink()
        }
    }
    
    override func rotateAroundPoint(center: CGPoint, angle: CGFloat) {
        for g in contents {
            g.rotateAroundPoint(center, angle: angle)
        }
    }
    
    override func flipVerticalAroundPoint(center: CGPoint) {
        for g in contents {
            g.flipVerticalAroundPoint(center)
        }
    }
    
    override func flipHorizontalAroundPoint(center: CGPoint) {
        for g in contents {
            g.flipHorizontalAroundPoint(center)
        }
    }
    
    override func drawInView(view: DrawingView) {
        for g in contents {
            g.drawInView(view)
        }
        if selected {
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
