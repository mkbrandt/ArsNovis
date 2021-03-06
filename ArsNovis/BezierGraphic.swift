//
//  BezierGraphic.swift
//  ArsNovis
//
//  Created by Matt Brandt on 2/27/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

let ACCURACY = CGFloat(0.0001)

class BezierArcTo: NSObject
{
    var ctrl1: CGPoint
    var ctrl2: CGPoint
    var endPoint: CGPoint
    
    init(endPoint: CGPoint, ctrl1: CGPoint, ctrl2: CGPoint) {
        self.ctrl1 = ctrl1
        self.ctrl2 = ctrl2
        self.endPoint = endPoint
    }

    required init?(coder decoder: NSCoder) {
        endPoint = decoder.decodePoint(forKey: "endpoint")
        ctrl1 = decoder.decodePoint(forKey: "ctrl1")
        ctrl2 = decoder.decodePoint(forKey: "ctrl2")
    }
    
    func encodeWithCoder(_ coder: NSCoder) {
        coder.encode(endPoint, forKey: "endpoint")
        coder.encode(ctrl1, forKey: "ctrl1")
        coder.encode(ctrl2, forKey: "ctrl2")
    }
}

class BezierSegment
{
    var origin: CGPoint
    var arc: BezierArcTo
    
    var points: [CGPoint]  { return [origin, arc.ctrl1, arc.ctrl2, arc.endPoint] }
    
    init(origin: CGPoint, arc: BezierArcTo) {
        self.origin = origin
        self.arc = arc
    }
    
    init(origin: CGPoint, ctrl1: CGPoint, ctrl2: CGPoint, endPoint: CGPoint) {
        self.origin = origin
        self.arc = BezierArcTo(endPoint: endPoint, ctrl1: ctrl1, ctrl2: ctrl2)
    }
    
    var flatnessError: CGFloat {
        let line = LineGraphic(origin: origin, endPoint: arc.endPoint)
        let error = max(line.distanceToPoint(arc.ctrl1), line.distanceToPoint(arc.ctrl2))
        
        return error
    }
    
    var flatness: CGFloat { return flatnessError / origin.distanceToPoint(arc.endPoint) }
    
    var bounds: CGRect { return rectContainingPoints(points) }
    var approximateLine: LineGraphic { return LineGraphic(origin: origin, endPoint: arc.endPoint) }
    
    func subdivideAt(_ t: CGFloat) -> [BezierSegment] {
        let p0 = origin
        let p1 = origin * (1 - t) + arc.ctrl1 * t
        let p2 = arc.ctrl1 * (1 - t) + arc.ctrl2 * t
        let p3 = arc.ctrl2 * (1 - t) + arc.endPoint * t
        let p4 = p1 * (1 - t) + p2 * t
        let p5 = p2 * (1 - t) + p3 * t
        let p6 = p4 * (1 - t) + p5 * t
        let p7 = arc.endPoint
        
        let a = BezierSegment(origin: p0, ctrl1: p1, ctrl2: p4, endPoint: p6)
        let b = BezierSegment(origin: p6, ctrl1: p5, ctrl2: p3, endPoint: p7)
        
        return [a, b]
    }
    
    func closestPointToPoint(_ point: CGPoint) -> CGPoint {
        if flatnessError < ACCURACY {
            return approximateLine.closestPointToPoint(point)
        } else {
            let segs = subdivideAt(0.5)
            
            let p1 = segs[0].closestPointToPoint(point)
            let p2 = segs[1].closestPointToPoint(point)
            if p1.distanceToPoint(point) < p2.distanceToPoint(point) {
                return p1
            } else {
                return p2
            }
        }
    }
    
    func intersectionsWithLine(_ line: LineGraphic) -> [CGPoint] {
        if line.bounds.intersects(bounds) {
            if flatnessError < ACCURACY {
                if let x = approximateLine.intersectionWithLine(line) {
                    return [x]
                } else {
                    return []
                }
            } else {
                let segs = subdivideAt(0.5)
                return segs[0].intersectionsWithLine(line) + segs[1].intersectionsWithLine(line)
            }
        }
        return []
    }
    
    func intersectionsWithBezierSegment(_ seg: BezierSegment) -> [CGPoint] {
        if flatnessError < ACCURACY {
            return seg.intersectionsWithLine(approximateLine)
        } else if seg.flatnessError < ACCURACY {
            return intersectionsWithLine(seg.approximateLine)
        } else if bounds.intersects(seg.bounds) {
            let segs1 = subdivideAt(0.5)
            let segs2 = subdivideAt(0.5)
            return segs1[0].intersectionsWithBezierSegment(segs2[0])
                + segs1[0].intersectionsWithBezierSegment(segs2[1])
                + segs1[1].intersectionsWithBezierSegment(segs2[0])
                + segs1[1].intersectionsWithBezierSegment(segs2[1])
        }
        return []
    }
}

class BezierGraphic: Graphic
{
    var arcs: [BezierArcTo] = []    { didSet { cachedPath = nil }}
    
    override var points: [CGPoint] {
        var pts = [origin]
        for arc in arcs {
            pts += [arc.endPoint, arc.ctrl1, arc.ctrl2]
        }
        return pts
    }
    
    override var bounds: CGRect {
        if selected {
            return rectContainingPoints(points).insetBy(dx: -lineWidth, dy: -lineWidth)
        } else {
            return path.bounds
        }
    }
    
    var width: CGFloat {
        get { return bounds.width }
        set { }
    }
    
    var height: CGFloat {
        get { return bounds.height }
        set { }
    }
    
    var segments: [BezierSegment] {
        var segs: [BezierSegment] = []
        var start = origin
        for arc in arcs {
            let seg = BezierSegment(origin: start, arc: BezierArcTo(endPoint: arc.endPoint, ctrl1: arc.ctrl1, ctrl2: arc.ctrl2))
            start = arc.endPoint
            segs.append(seg)
        }
        return segs
    }
    
    override var inspectionName: String              { return "Bezier Curve" }
    override var inspectionInfo: [InspectionInfo] {
        return super.inspectionInfo + [
            InspectionInfo(label: "Width", key: "width", type: .distance),
            InspectionInfo(label: "Height", key: "height", type: .distance)
        ]
    }
    
    required override init(origin: CGPoint) {
        super.init(origin: origin)
    }
    
   init(origin: CGPoint, endPoint: CGPoint, ctrl1: CGPoint, ctrl2: CGPoint) {
        arcs = [BezierArcTo(endPoint: endPoint, ctrl1: ctrl1, ctrl2: ctrl2)]
        super.init(origin: origin)
    }
    
    init?(path: NSBezierPath) {
        super.init(origin: CGPoint(x: 0, y: 0))
        if path.elementCount < 2 {
            return nil
        }
        var points: [CGPoint] = [CGPoint(), CGPoint(), CGPoint()]
        for i in 0 ..< path.elementCount {
            let e = path.element(at: i, associatedPoints: &points)
            switch e {
            case .moveToBezierPathElement:
                origin = points[0]
            case .curveToBezierPathElement:
                let arc = BezierArcTo(endPoint: points[2], ctrl1: points[0], ctrl2: points[1])
                arcs.append(arc)
            case .lineToBezierPathElement:
                let arc = BezierArcTo(endPoint: points[0], ctrl1: points[0], ctrl2: points[0])
                arcs.append(arc)
            case .closePathBezierPathElement:
                let arc = BezierArcTo(endPoint: origin, ctrl1: origin, ctrl2: origin)
                arcs.append(arc)
            }
        }
    }

    required init?(coder decoder: NSCoder) {
        if let arcs = decoder.decodeObject(forKey: "curves") as? [BezierArcTo] {
            self.arcs = arcs
        }
        super.init(coder: decoder)
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(arcs, forKey: "curves")
    }
    
    override func recache() {
        let path = NSBezierPath()
        
        path.lineWidth = lineWidth
        path.move(to: origin)
        for arc in arcs {
            path.curve(to: arc.endPoint, controlPoint1: arc.ctrl1, controlPoint2: arc.ctrl2)
        }
        cachedPath = path
    }
    
    func handleRect(_ point: CGPoint, size: CGFloat) -> CGRect {
        return CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)
    }
    
    func drawHandle(_ point: CGPoint, color: NSColor, view: DrawingView) {
        let handleSize = view.scaleFloat(HSIZE)
        let r = handleRect(point, size: handleSize)
        let path = NSBezierPath(ovalIn: r)
        color.set()
        path.fill()
    }
    
    override func drawHandlesInView(_ view: DrawingView) {
        let blue = NSColor.blue
        let red = NSColor.red
        let path = NSBezierPath()
        
        drawHandle(origin, color: blue, view: view)
        path.move(to: origin)
        for arc in arcs {
            drawHandle(arc.endPoint, color: blue, view: view)
            drawHandle(arc.ctrl1, color: red, view: view)
            drawHandle(arc.ctrl2, color: red, view: view)
            path.line(to: arc.ctrl1)
            path.move(to: arc.ctrl2)
            path.line(to: arc.endPoint)
        }
        path.lineWidth = view.scaleFloat(0.5)
        NSColor.black.set()
        path.stroke()
    }
    
    override func setPoint(_ point: CGPoint, atIndex index: Int) {
        if index == 0 {
            let delta = point - origin
            origin = point
            if arcs.count > 0 {
                arcs[0].ctrl1 = arcs[0].ctrl1 + delta
            }
        } else {
            let arcIndex = (index - 1) / 3
            let subIndex = (index - 1) % 3
            if arcIndex < arcs.count {
                switch subIndex {
                case 0:
                    let delta = point - arcs[arcIndex].endPoint
                    arcs[arcIndex].endPoint = point
                    arcs[arcIndex].ctrl2 = delta + arcs[arcIndex].ctrl2
                    if arcs.count > arcIndex + 1 {
                        arcs[arcIndex + 1].ctrl1 = delta + arcs[arcIndex + 1].ctrl1
                    }
                case 1:
                    arcs[arcIndex].ctrl1 = point
                case 2:
                    arcs[arcIndex].ctrl2 = point
                default:
                    break
                }
            }
        }
        cachedPath = nil
    }

    override func closestPointToPoint(_ point: CGPoint, extended: Bool = false) -> CGPoint {
        var points = segments.map { return $0.closestPointToPoint(point) }
        
        if selected {
            points = self.points + points
        }
        
        return points.sorted(by: { return $0.distanceToPoint(point) < $1.distanceToPoint(point) })[0]
    }
    
    override func intersectionsWithGraphic(_ g: Graphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        var graphic: BezierGraphic
        if let g = g as? BezierGraphic {
            graphic = g
        } else if let g = BezierGraphic(path: g.path) {
            graphic = g
        } else {
            return []
        }
        
        var intersections: [CGPoint] = []
        for seg in segments {
            for gseg in graphic.segments {
                intersections += seg.intersectionsWithBezierSegment(gseg)
            }
        }
        return intersections
    }
    
    override func snapCursor(_ location: CGPoint) -> SnapResult? {
        if origin.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: origin, type: .endPoint)
        } else if let ep = arcs.last?.endPoint, ep.distanceToPoint(location) < SnapRadius {
            return SnapResult(location: ep, type: .endPoint)
        } else {
            let p = closestPointToPoint(location)
            if p.distanceToPoint(location) < SnapRadius {
                return SnapResult(location: p, type: .on)
            }
        }
        return nil
    }
    
    override func shouldSelectInRect(_ rect: CGRect) -> Bool {
        if bounds.intersection(rect) == bounds {                   // if completely inside
            return true
        }
        return intersectionsWithGraphic(RectGraphic(origin: rect.origin, size: rect.size), extendSelf: false, extendOther: false).count > 0
    }
}

enum BezierToolState {
    case startArc, endArc
}

class BezierTool: GraphicTool
{
    var firstArc = true
    var firstDrag = true
    
    override func cursor() -> NSCursor {
        return NSCursor.crosshair
    }
    
    override func selectTool(_ view: DrawingView) {
        view.construction = nil
        view.setDrawingHint("Drawing Bezier Paths")
    }
    
    override func escape(_ view: DrawingView) {
        if let construct = view.construction as? BezierGraphic {
            if construct.arcs.count > 1 {
                construct.arcs.removeLast()
                construct.selected = false
                view.addConstruction()
            } else {
                view.construction = nil
            }
            view.needsDisplay = true
        }
    }
    
    override func mouseDown(_ location: CGPoint, view: DrawingView) {
        if let construct = view.construction as? BezierGraphic {
            if view.mouseClickCount >= 2 {
                if construct.arcs.count > 1 {
                    construct.arcs.removeLast()
                }
                if construct.arcs.count > 1 {
                    construct.arcs.removeLast()
                }
                construct.selected = false
                view.addConstruction()
                view.needsDisplay = true
            } else {
                construct.arcs.last?.endPoint = location
                construct.arcs.last?.ctrl2 = location
            }
        } else {
            let g = BezierGraphic(origin: location)
            g.selected = true
            view.construction = g
            firstDrag = true
            firstArc = true
        }
        view.redrawConstruction()
   }
    
    override func mouseMoved(_ location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        if let construct = view.construction as? BezierGraphic {
            construct.arcs.last?.endPoint = location
            construct.arcs.last?.ctrl2 = location
            construct.recache()
        }
        view.redrawConstruction()
    }
    
    override func mouseDragged(_ location: CGPoint, view: DrawingView) {
        if let construct = view.construction as? BezierGraphic {
            if firstDrag {
                let arc = BezierArcTo(endPoint: location, ctrl1: location, ctrl2: location)
                construct.arcs.append(arc)
                firstDrag = false
                firstArc = true
            } else if firstArc {
                construct.arcs[0].ctrl1 = location
                construct.arcs[0].ctrl2 = location
                construct.arcs[0].endPoint = location
            } else {
                construct.arcs.last?.endPoint = location
            }
            construct.recache()
        }
        view.redrawConstruction()
    }
    
    override func mouseUp(_ location: CGPoint, view: DrawingView) {
        mouseDragged(location, view: view)
        if let construct = view.construction as? BezierGraphic {
            if !firstDrag && !firstArc {
                if let lastArc = construct.arcs.last {
                    let v = lastArc.endPoint - lastArc.ctrl2
                    let arc = BezierArcTo(endPoint: location, ctrl1: location + v, ctrl2: location + v)
                    construct.arcs.append(arc)
                }
            }
        }
        firstArc = false
        firstDrag = false
        view.redrawConstruction()
   }
}
