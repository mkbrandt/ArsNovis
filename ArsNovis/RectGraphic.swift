//
//  RectGraphic.swift
//  Electra
//
//  Created by Matt Brandt on 7/16/14.
//  Copyright (c) 2014 WalkingDog Design. All rights reserved.
//

import Cocoa

class RectGraphic: GroupGraphic
{
    var sides: [LineGraphic]    { return contents as! [LineGraphic] }
    
    override var inspectionName: String { return "Rectangle" }
    
    override var inspectionInfo: [InspectionInfo] {
        return super.inspectionInfo + [
            //InspectionInfo(label: "Width", key: "width", type: .Distance),
            //InspectionInfo(label: "Height", key: "height", type: .Distance)
        ]
    }
    
    override var inspectionKeys: [String] {
        return ["x", "y"]//, "width", "height"]
    }
    
    init(origin: CGPoint, size: CGSize) {
        let top = LineGraphic(origin: origin + CGPoint(x: 0, y: size.height), endPoint: origin + CGPoint(x: size.width, y: size.height))
        let bottom = LineGraphic(origin: origin, endPoint: origin + CGPoint(x: size.width, y: 0))
        let left = LineGraphic(origin: origin, endPoint: top.origin)
        let right = LineGraphic(origin: bottom.endPoint, endPoint: top.endPoint)
        super.init(contents: [top, bottom, left, right])
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
    }

    required convenience init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
}

class ElipseGraphic: Graphic
{
    var size: CGSize
    
    override var bounds: CGRect     { return CGRect(origin: origin, size: size) }
    
    var topLeft: CGPoint            { return origin + CGPoint(x: 0, y: size.height) }
    var topRight: CGPoint           { return origin + CGPoint(x: size.width, y: size.height) }
    var bottomRight: CGPoint        { return origin + CGPoint(x: size.width, y: 0) }
    
    var width: CGFloat { return bounds.width }
    var height: CGFloat { return bounds.height }
    
    override var points: [CGPoint]  { return [origin, topLeft, topRight, bottomRight] }
    
    override var inspectionName: String { return "Elipse" }
    
    override var inspectionInfo: [InspectionInfo] {
        return super.inspectionInfo + [
            InspectionInfo(label: "Width", key: "width", type: .distance),
            InspectionInfo(label: "Height", key: "height", type: .distance)
        ]
    }
    
    init(origin: CGPoint, size: CGSize) {
        self.size = size
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        size = decoder.decodeSize(forKey: "size")
        super.init(coder: decoder)
    }
    
    required convenience init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(size, forKey: "size")
    }
    
    override func setPoint(_ point: CGPoint, atIndex index: Int) {
        switch index {
        case 0:
            let r = rectContainingPoints([point, topRight])
            origin = r.origin
            size = r.size
        case 1:
            let r = rectContainingPoints([point, bottomRight])
            origin = r.origin
            size = r.size
        case 2:
            let r = rectContainingPoints([origin, point])
            origin = r.origin
            size = r.size
        case 3:
            let r = rectContainingPoints([topLeft, point])
            origin = r.origin
            size = r.size
        default:
            break
        }
    }
    
    override func recache()
    {
        cachedPath = NSBezierPath(ovalIn: CGRect(origin: origin, size: size))
    }
    
    override func closestPointToPoint(_ point: CGPoint, extended: Bool) -> CGPoint {
        let cp = points.reduce(origin, { point.distanceToPoint($1) < point.distanceToPoint($0) ? $1 : $0 })
        let cp2 = super.closestPointToPoint(point)
        
        return cp.distanceToPoint(point) < cp2.distanceToPoint(point) ? cp : cp2
    }
    
    override func intersectionsWithGraphic(_ g: Graphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        return simpleIntersectionsWithGraphic(g, extendSelf: extendSelf, extendOther: extendOther)
    }
    
    override func snapCursor(_ location: CGPoint) -> SnapResult? {
        if let bp = BezierGraphic(path: path) {
            return bp.snapCursor(location)
        }
        return nil
    }
}

class RectTool: GraphicTool
{
    var startPoint = CGPoint(x: 0, y: 0)
    
    func construct(origin: CGPoint, size: CGSize) -> Graphic {
        return RectGraphic(origin: origin, size: size)
    }
    
    override func cursor() -> NSCursor {
        return NSCursor.crosshair
    }
    
    override func selectTool(_ view: DrawingView) {
        view.setDrawingHint("Drawing Rectangles")
    }
    
    override func mouseDown(_ location: CGPoint, view: DrawingView) {
        startPoint = location
    }
    
    override func mouseDragged(_ location: CGPoint, view: DrawingView) {
        var location = location
        if view.shiftKeyDown {
            location = constrainTo45Degrees(location, relativeToPoint: startPoint)
        }
        let r = rectContainingPoints([startPoint, location])
        view.redrawConstruction()
        view.construction = construct(origin: r.origin, size: r.size)
        view.redrawConstruction()
    }
}

class CenterRectTool: GraphicTool
{
    var startPoint = CGPoint(x: 0, y: 0)
    
    func construct(origin: CGPoint, size: CGSize) -> Graphic {
        return RectGraphic(origin: origin, size: size)
    }

    override func cursor() -> NSCursor {
        return NSCursor.crosshair
    }
    
    override func selectTool(_ view: DrawingView) {
        view.setDrawingHint("Drawing Rectangles from Center")
    }
    
    override func mouseDown(_ location: CGPoint, view: DrawingView) {
        startPoint = location
        view.construction = construct(origin: location, size: NSSize(width: 0, height: 0))
    }
    
    override func mouseDragged(_ location: CGPoint, view: DrawingView) {
        var location = location
        if view.shiftKeyDown {
            location = constrainTo45Degrees(location, relativeToPoint: startPoint)
        }
        let r = rectContainingPoints([startPoint + startPoint - location, location])
        view.redrawConstruction()
        view.construction = RectGraphic(origin: r.origin, size: r.size)
        view.redrawConstruction()
    }
}

class ElipseTool: RectTool
{
    override func selectTool(_ view: DrawingView) {
        view.setDrawingHint("Drawing Elipses by corner")
    }
    
    override func construct(origin: CGPoint, size: CGSize) -> Graphic {
        return ElipseGraphic(origin: origin, size: size)
    }
}


class CenterElipseTool: CenterRectTool
{
    override func selectTool(_ view: DrawingView) {
        view.setDrawingHint("Drawing Elipse from Center")
    }
    
    override func construct(origin: CGPoint, size: CGSize) -> Graphic {
        return ElipseGraphic(origin: origin, size: size)
    }
}


