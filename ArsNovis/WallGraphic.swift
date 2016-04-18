//
//  WallGraphic.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/21/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class WallOpening: LineGraphic
{
    var nominalWidth: CGFloat = 450
    var attachedWall: WallGraphic? {
        didSet {
            if let wall = attachedWall {
                wall.addOpening(self)
                alignToWall()
            }
        }
    }
    
    override var origin: CGPoint {
        didSet {
        }
    }
    
    var width: CGFloat {
        if let wall = attachedWall {
            return wall.width
        }
        return nominalWidth
    }
    
    var perpendicularAngle: CGFloat {
        return normalizeAngle(angle + PI / 2)
    }
    
    var offsetToWall: CGPoint { return CGPoint(length: width / 2, angle: perpendicularAngle) }
    
    var ends: [LineGraphic] {
        return [LineGraphic(origin: origin - offsetToWall, endPoint: origin + offsetToWall),
                LineGraphic(origin: endPoint - offsetToWall, endPoint: endPoint + offsetToWall)]
    }
    
    var gap: LineGraphic { return LineGraphic(origin: origin, endPoint: endPoint) }
    
    override var bounds: CGRect { return rectContainingPoints([origin + offsetToWall, origin - offsetToWall, endPoint + offsetToWall, endPoint - offsetToWall]) }
    
    override var description: String { return "Opening @ \(origin), \(endPoint)" }
    
    required init?(coder decoder: NSCoder) {
        attachedWall = decoder.decodeObjectForKey("attached") as? WallGraphic
        super.init(coder: decoder)
    }
    
    required init(origin: CGPoint) {
        super.init(origin: origin)
    }
    
    override init(origin: CGPoint, endPoint: CGPoint) {
        super.init(origin: origin, endPoint: endPoint)
    }
    
    required convenience init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        if let wall = attachedWall {
            coder.encodeObject(wall, forKey: "attached")
        }
    }
    
    override func unlink() {
        super.unlink()
        if let wall = attachedWall {
            attachedWall = nil
            wall.removeOpening(self)
        }
    }
    
    override func recache() {
        alignToWall()
        cachedPath = NSBezierPath()
        for line in ends {
            cachedPath?.moveToPoint(line.origin)
            cachedPath?.lineToPoint(line.endPoint)
        }
    }
    
    func alignToWall() {
        if let wall = attachedWall {
            let centerLine = wall.centerLine
            let offset = CGPoint(length: self.length, angle: centerLine.angle)
            var newOrigin = centerLine.closestPointToPoint(origin)
            var newEndPoint = newOrigin + offset
            if !centerLine.pointOnLine(newEndPoint) {
                newEndPoint = centerLine.closestPointToPoint(endPoint)
                newOrigin = newEndPoint - offset
            }
            origin = newOrigin
            endPoint = newEndPoint
        }
    }
    
    override func drawInView(view: DrawingView) {
        if attachedWall == nil {
            // see if we can attach to a wall
            for g in view.displayList {
                if let wall = g as? WallGraphic where g.bounds.intersects(bounds) {
                    let cp1 = wall.centerLine.closestPointToPoint(origin, extended: false)
                    let cp2 = wall.centerLine.closestPointToPoint(endPoint, extended: false)
                    if cp1.distanceToPoint(origin) < SnapRadius && cp2.distanceToPoint(endPoint) < SnapRadius {
                        attachedWall = wall
                    }
                }
            }
        }
        super.drawInView(view)
    }
}

enum IntersectionType {
    case Corner, ThisTeesInto, OtherTeesInto, Crossing
}

struct IntersectionInfo {
    var otherWall: WallGraphic
    var points: [CGPoint]
    
    func containsPoint(point: CGPoint) -> Bool {
        return rectContainingPoints(points).insetBy(dx: -0.00001, dy: -0.00001).contains(point)
    }
}

class WallGraphic: LineGraphic
{
    var width: CGFloat = 450
    var leftOriented = true
    var adjustIntersections = true
    var openings: [WallOpening] = []
    
    var perpendicularAngle: CGFloat {
        return leftOriented ? normalizeAngle(angle + PI / 2) : normalizeAngle(angle - PI / 2)
    }
    
    var secondaryLineOffset: CGPoint    { return CGPoint(length: width, angle: perpendicularAngle) }
    
    var primaryLine: LineGraphic        { return LineGraphic(origin: origin, endPoint: endPoint) }
    var secondaryLine: LineGraphic      { return LineGraphic(origin: origin + secondaryLineOffset, endPoint: endPoint + secondaryLineOffset) }
    var centerLine: LineGraphic         { return LineGraphic(origin: origin + secondaryLineOffset / 2, endPoint: endPoint + secondaryLineOffset / 2) }
    
    var outerLines: [LineGraphic]       { return [primaryLine, secondaryLine] }
    var drawnLines: [LineGraphic] = []
    var extendedLines: [LineGraphic] = []
    
    var boundsLines: [LineGraphic] {
        if extendedLines.count == 0 {
            return outerLines
        }
        return extendedLines
    }
    
    override var description: String { return "Wall @ \(origin), \(endPoint), width = \(width)" }
    
    override func recache() {
        cachedPath = nil
    }
    
    override var bounds: CGRect {
        return rectContainingPoints(boundsLines.reduce([], combine: { return $0 + $1.points })).insetBy(dx: -lineWidth, dy: -lineWidth)
    }
    
    required init?(coder decoder: NSCoder) {
        width = CGFloat(decoder.decodeDoubleForKey("width"))
        openings = decoder.decodeObjectForKey("openings") as? [WallOpening] ?? []
        super.init(coder: decoder)
    }
    
    required init(origin: CGPoint) {
        super.init(origin: origin)
    }
    
    override init(origin: CGPoint, endPoint: CGPoint) {
        super.init(origin: origin, endPoint: endPoint)
    }
    
    required convenience init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        coder.encodeObject(openings, forKey: "openings")
        coder.encodeDouble(Double(width), forKey: "width")
    }
    
    func intersectionsWithLine(line: LineGraphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        return outerLines.flatMap { $0.intersectionWithLine(line, extendSelf: extendSelf, extendOther: extendOther) }
    }
    
    func intersectionsWithWall(wg: WallGraphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        return outerLines.reduce([], combine: { return $0 + wg.intersectionsWithLine($1, extendSelf: extendSelf, extendOther: extendOther)})
    }
    
    override func intersectionsWithGraphic(g: Graphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        if let otherWall = g as? WallGraphic {
            return intersectionsWithWall(otherWall, extendSelf: extendSelf, extendOther: extendOther)
        }
        return outerLines.reduce([], combine: { $0 + $1.intersectionsWithGraphic(g, extendSelf: extendSelf, extendOther: extendOther)})
    }
    
    func addOpening(opening: WallOpening) {
        if !openings.contains(opening) {
            openings.append(opening)
        }
    }
    
    func removeOpening(opening: WallOpening) {
        openings = openings.filter { $0 != opening }
    }
    
    override func unlink() {
        super.unlink()
        let oldOpenings = openings
        openings = []
        for opening in oldOpenings {
            opening.unlink()
        }
    }
    
    func wallIntersectionsInView(view: DrawingView) -> [IntersectionInfo] {
        var graphics = view.displayList
        if let construction = view.construction {
            graphics.append(construction)
        }
        
        var intersections: [IntersectionInfo] = []
        for g in graphics {
            if let wg = g as? WallGraphic where wg != self {
                if intersectionsWithWall(wg, extendSelf: false, extendOther: false).count > 0 {
                    let intersects = intersectionsWithWall(wg, extendSelf: true, extendOther: true)
                    let info = IntersectionInfo(otherWall: wg, points: intersects)
                    intersections.append(info)
                    if let centerIntersection = centerLine.intersectionWithLine(wg.centerLine, extendSelf: true, extendOther: true) {
                        if info.containsPoint(centerLine.origin) {
                            origin = origin + centerIntersection - centerLine.origin
                        } else if info.containsPoint(centerLine.endPoint) {
                            endPoint = endPoint + centerIntersection - centerLine.endPoint
                        }
                    }
                }
            }
        }
        return intersections.sort { origin.distanceToPoint($0.points[0]) < origin.distanceToPoint($1.points[0]) }
    }
    
    func isCloseToEnd(line: LineGraphic, intersectionInfo: IntersectionInfo) -> Bool {
        return intersectionInfo.containsPoint(line.origin) || intersectionInfo.containsPoint(line.endPoint)
    }
    
    func isEndIntersection(intersectionInfo: IntersectionInfo) -> Bool {
        return isCloseToEnd(primaryLine, intersectionInfo: intersectionInfo) || isCloseToEnd(secondaryLine, intersectionInfo: intersectionInfo)
    }
    
    func intersectionType(intersectionInfo: IntersectionInfo) -> IntersectionType {
        let otherWall = intersectionInfo.otherWall
        let otherInfo = IntersectionInfo(otherWall: self, points: intersectionInfo.points)
        switch (isEndIntersection(intersectionInfo), otherWall.isEndIntersection(otherInfo)) {
        case (true, true): return .Corner
        case (false, true): return .OtherTeesInto
        case (true, false): return .ThisTeesInto
        case(false, false): return .Crossing
        }
    }
    
    func intersectionGaps(intersection: CGPoint, otherWall: WallGraphic) -> [LineGraphic] {
        var result: [LineGraphic] = []
        
        for line in outerLines {
            let points = otherWall.outerLines.flatMap { return line.intersectionWithLine($0) }
            if points.count == 2 {
                let l = LineGraphic(origin: points[0], endPoint: points[1])
                if l.intersectionWithLine(otherWall.centerLine) != nil {
                    result.append(l)
                }
            }
        }
        
        return result
    }
    
    func gapForIntersectionWithLine(line: LineGraphic) -> LineGraphic? {
        var points = outerLines.flatMap { $0.intersectionWithLine(line, extendSelf: true, extendOther: true) }
        if points.count == 2 {
            let farPoint = line.origin - line.vector
            points.sortInPlace { farPoint.distanceToPoint($0) < farPoint.distanceToPoint($1) }
            let lg = LineGraphic(origin: points[0], endPoint: points[1])
            if centerLine.intersectionWithLine(lg) != nil {
                return lg
            }
        }
        return nil
    }
    
    func segmentLine(line: LineGraphic, gaps: [LineGraphic]) -> [LineGraphic] {
        var line = line
        var segments: [LineGraphic] = []
        let farpoint = line.origin - line.vector
        let gaps = gaps.sort { farpoint.distanceToPoint($0.origin) < farpoint.distanceToPoint($1.origin) }
        
        for gap in gaps {
            let op = line.closestPointToPoint(gap.origin)
            let ep = line.closestPointToPoint(gap.endPoint)
            
            if op != ep {
                if op == line.origin {
                    line = LineGraphic(origin: ep, endPoint: line.endPoint)
                } else if ep == line.endPoint {
                    line = LineGraphic(origin: line.origin, endPoint: op)
                } else {
                    segments.append(LineGraphic(origin: line.origin, endPoint: op))
                    line = LineGraphic(origin: ep, endPoint: line.endPoint)
                }
            }
        }
        segments.append(line)
        
        return segments
    }
    
    func getExtendedLinesForIntersection(wg: WallGraphic) {
        let info = IntersectionInfo(otherWall: wg, points: intersectionsWithWall(wg, extendSelf: true, extendOther: true))
        let type = intersectionType(info)
        let xlines = extendedLines
        if type != .Crossing && type != .OtherTeesInto {    // need to trim any lines beyond intersection
            for line in xlines {
                for point in info.points.filter({ line.pointOnLine($0) }) {
                    if line.origin.distanceToPoint(point) < line.endPoint.distanceToPoint(point) {
                        line.origin = point
                    } else {
                        line.endPoint = point
                    }
                }
            }
        }
        
        for line in xlines {
            for otherLine in wg.outerLines {
                if let intersect = line.intersectionWithLine(otherLine, extendSelf: true, extendOther: true) {
                    if line.origin.distanceToPoint(intersect) < line.endPoint.distanceToPoint(intersect) {
                        if !line.pointOnLine(intersect) {
                            line.origin = intersect
                        }
                    } else {
                        if !line.pointOnLine(intersect) {
                            line.endPoint = intersect
                        }
                    }
                }
            }
        }
    }
    
    func segmentLineForGaps(line: LineGraphic, intersections: [IntersectionInfo], openings: [WallOpening]) -> [LineGraphic] {
        var gaps = intersections.flatMap { $0.otherWall.gapForIntersectionWithLine(line) }
        
        gaps += openings.map { LineGraphic(origin: line.closestPointToPoint($0.origin), endPoint: line.closestPointToPoint($0.endPoint)) }
        
        let segments = segmentLine(line, gaps: gaps)
        return segments
    }
    
    override func drawInView(view: DrawingView) {
        let path = NSBezierPath()
        ref = []

        drawnLines = []
        extendedLines = outerLines
        let intersections = wallIntersectionsInView(view)
        
        for intersection in intersections {
            getExtendedLinesForIntersection(intersection.otherWall)
        }
        
        lineColor.set()
        // origin endcap
        if !intersections.reduce(false, combine: { return $0 || $1.containsPoint(origin) || $1.containsPoint(secondaryLine.origin)}) {
            path.moveToPoint(primaryLine.origin)
            path.lineToPoint(secondaryLine.origin)
        }
        
        // endpoint endcap
        if !intersections.reduce(false, combine: { return $0 || $1.containsPoint(endPoint) || $1.containsPoint(secondaryLine.endPoint)}) {
            path.moveToPoint(primaryLine.endPoint)
            path.lineToPoint(secondaryLine.endPoint)
        }

        for line in extendedLines {
            let segments = segmentLineForGaps(line, intersections: intersections, openings: openings)
            drawnLines += segments
            
            for seg in segments {
                path.moveToPoint(seg.origin)
                path.lineToPoint(seg.endPoint)
            }
        }
        
        path.lineWidth = view.scaleFloat(lineWidth)
        path.stroke()
        if selected {
            drawHandlesInView(view)
        }
        for g in ref {
            g.drawInView(view)
        }
    }
    
    override func snapCursor(location: CGPoint) -> SnapResult? {
        for line in drawnLines {
            if let snap = line.snapCursor(location) {
                return snap
            }
        }
        return nil
    }
    
    override func shouldSelectInRect(rect: CGRect) -> Bool {
        for line in outerLines {
            if line.shouldSelectInRect(rect) {
                return true
            }
        }
        return false
    }
    
    override func closestPointToPoint(point: CGPoint, extended: Bool) -> CGPoint {
        var cp: CGPoint = center
        for line in drawnLines {
            let p = line.closestPointToPoint(point, extended: false)
            if p.distanceToPoint(point) < cp.distanceToPoint(point) {
                cp = p
            }
        }
        return cp
    }

    override func divideAtPoint(point: CGPoint) -> [Graphic] {
        let lines = [WallGraphic(origin: origin, endPoint: point), WallGraphic(origin: point, endPoint: endPoint)]
        
        return lines
    }
    
    override func extendToIntersectionWith(g: Graphic, closeToPoint: CGPoint) -> Graphic {
        var intersections = intersectionsWithGraphic(g, extendSelf: true, extendOther: true)
        intersections = intersections.sort { $0.distanceToPoint(closeToPoint) < $1.distanceToPoint(closeToPoint) }
        if intersections.count > 0 {
            let intersection = intersections[0]
            if intersection.distanceToPoint(origin) < intersection.distanceToPoint(endPoint) {
                return WallGraphic(origin: intersection, endPoint: endPoint)
            } else {
                return WallGraphic(origin: origin, endPoint: intersection)
            }
        }
        return self
    }
    
}

class WallTool: GraphicTool
{
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Click and drag to draw wall")
    }
    
    override func escape(view: DrawingView) {
        view.construction = nil
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        let wall = WallGraphic(origin: location, endPoint: location)
        view.construction = wall
        view.addSnapConstructionsForPoint(location, reference: [wall], includeAngles: true)
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        if let wall = view.construction as? WallGraphic {
            wall.endPoint = location
        }
        view.redrawConstruction()
    }
    
    override func mouseUp(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        view.removeSnapConstructionsForReference(view.construction)
        view.addConstruction()
    }
}

class OpeningTool: GraphicTool
{
    var lastOpeningSize = CGFloat(3200)
    
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Click a wall to place opening")
    }
    
    override func escape(view: DrawingView) {
        view.construction = nil
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
    }
    
    override func mouseMoved(location: CGPoint, view: DrawingView) {
        if let opening = view.construction as? WallOpening {
            opening.unlink()
        }
        for g in view.displayList {
            if let wg = g as? WallGraphic where wg.bounds.contains(location) {
                let center = wg.centerLine.closestPointToPoint(location)
                let offset = CGPoint(length: lastOpeningSize / 2, angle: wg.centerLine.angle)
                let origin = center - offset
                let endPoint = center + offset
                let opening = WallOpening(origin: origin, endPoint: endPoint)
                opening.attachedWall = wg
                view.construction = opening
                return
            }
        }
        view.construction = nil
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView) {
    }
    
    override func mouseUp(location: CGPoint, view: DrawingView) {
        if let _ = view.construction {
            view.addConstruction()
        }
    }
}

