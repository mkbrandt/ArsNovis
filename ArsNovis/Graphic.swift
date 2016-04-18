//
//  Graphic.swift
//  ArsNovis
//
//  Created by Matt Brandt on 6/7/14.
//  Copyright (c) 2014 WalkingDog Design. All rights reserved.
//

import Cocoa

let ELGraphicUTI = "graphic.walkingdog.com"

var RawSnapRadius = CGFloat(6.0)
var SnapRadius = CGFloat(6.0)        // scaled by view when drawing

enum SnapType
{
    case EndPoint, On, Center, Horizontal, Vertical, Angle, Align, Intersection, Grid
}

struct SnapResult
{
    var location: CGPoint
    var type: SnapType
    var cursorText: NSString {
        switch type {
        case .EndPoint:
            return "End"
        case .On:
            return "On"
        case .Center:
            return "Center"
        case .Horizontal:
            return "H"
        case .Vertical:
            return "V"
        case .Angle:
            return "45°"
        case .Align:
            return "Align"
        case .Intersection:
            return "Intersect"
        case .Grid:
            return ""
        }
    }
}

private var IDCount = 0

func nextIdentifier() -> Int {
    IDCount += 1
    return IDCount
}

/// Base class for all graphic objects

class Graphic: NSObject, NSCoding, NSPasteboardWriting, NSPasteboardReading
{
    var lineColor = NSColor.blackColor()
    var fillColor: NSColor?
    var cachedPath: NSBezierPath?
    var selected = false             { didSet { cachedPath = nil }}
    var isActive = true
    var identifier: Int
    var ref: [Graphic] = []
    
    var isConstruction: Bool { return false }       // return true when this graphic is a temporary construction line
    
    var origin: CGPoint {
        willSet {
            willChangeValueForKey("x")
            willChangeValueForKey("y")
        }
        didSet {
            cachedPath = nil
            didChangeValueForKey("x")
            didChangeValueForKey("y")
        }
    }
    
    var x: CGFloat  {
        set { origin.x = newValue }
        get { return origin.x }
    }
    
    var y: CGFloat {
        set { origin.y = newValue }
        get { return origin.y }
    }
    
    var lineWidth: CGFloat = 1.0 {
        didSet { cachedPath = nil }
    }
    
    var path: NSBezierPath {
        if cachedPath == nil {
            recache()
        }
        if let p = cachedPath {
            return p
        }
        return NSBezierPath()
    }
    
    var inspector: GraphicInspector?
    
    var nestedGraphics: [Graphic]?
    
    var points: [CGPoint] {
        get { return [origin] }
    }
    
    var bounds: CGRect
        {
        get { return CGRect(origin: origin, size: NSSize(width: 0.0, height: 0.0)) }
    }
    
    override var description: String { return "Graphic @ \(origin)" }
    
    init(origin: CGPoint)
    {
        self.origin = origin
        identifier = nextIdentifier()
        super.init()
    }
    
    required init?(coder decoder: NSCoder)
    {
        lineColor = decoder.decodeObjectForKey("lineColor") as! NSColor
        fillColor = decoder.decodeObjectForKey("fillColor") as? NSColor
        lineWidth = CGFloat(decoder.decodeDoubleForKey("lineWidth"))
        origin = decoder.decodePointForKey("origin")
        identifier = nextIdentifier()
        super.init()
    }
    
    func encodeWithCoder(coder: NSCoder)
    {
        coder.encodeObject(lineColor, forKey: "lineColor")
        if let color = fillColor {
            coder.encodeObject(color, forKey: "fillColor")
        }
        coder.encodeDouble(Double(lineWidth), forKey: "lineWidth")
        coder.encodePoint(origin, forKey: "origin")
    }
    
    /// Override unlink to do anything necessary to remove links to other graphics when deleting this one
    func unlink() {
        ref = []        // delete all references
    }
    
    // Pasteboard
    
    required convenience init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        return nil
    }
    
    func writableTypesForPasteboard(pasteboard: NSPasteboard) -> [String]
    {
        return [ELGraphicUTI]
    }
    
    class func readableTypesForPasteboard(pasteboard: NSPasteboard) -> [String]
    {
        return [ELGraphicUTI]
    }
    
    class func readingOptionsForType(type: String, pasteboard: NSPasteboard) -> NSPasteboardReadingOptions {
        return NSPasteboardReadingOptions.AsKeyedArchive
    }
    
    func pasteboardPropertyListForType(type: String) -> AnyObject?
    {
        let data = NSKeyedArchiver.archivedDataWithRootObject(self)
        return data
    }
    
    // Inspection
    
    var inspectionKeys: [String] {
        return ["x", "y"]
    }
    
    var defaultInspectionKey: String {
        return "x"
    }
    
    func typeForKey(key: String) -> MeasurementType {
        return .Distance
    }
    
    func transformerForKey(key: String) -> NSValueTransformer {
        switch typeForKey(key) {
        case .Angle:
            return AngleTransformer()
        case .Distance:
            return DistanceTransformer()
        }
    }
    
    /// Override to allow editing in the drawing view
    
    func editDoubleClick(location: CGPoint, view: DrawingView) {
    }
    
    // Graphic
    
    func setPoint(point: CGPoint, atIndex index: Int)
    {
        if index == 0 {
            origin = point
        }
    }
    
    func moveOriginBy(vector: CGPoint)
    {
        let op = points
        
        for i in 0 ..< op.count
        {
            setPoint(op[i] + vector, atIndex: i)
        }
    }
    
    func moveOriginTo(point: CGPoint)
    {
        let vector = point - origin
        moveOriginBy(vector)
    }
    
    func centerOfPoints() -> CGPoint {
        var center = origin
        for i in 1 ..< points.count {
            center = center + points[i]
        }
        return center / CGFloat(points.count)
    }
    
    func rotateAroundPoint(center: CGPoint, angle: CGFloat) {
        var newPoints: [CGPoint] = []
        for i in 0 ..< points.count {
            var offset = points[i] - center
            offset.angle += angle
            newPoints.append(center + offset)
        }
        
        for i in 0 ..< points.count {
            setPoint(newPoints[i], atIndex: i)
        }
    }
    
    func flipHorizontalAroundPoint(center: CGPoint) {
        var newPoints: [CGPoint] = []
        for i in 0 ..< points.count {
            let offset = points[i].x - center.x
            newPoints.append(CGPoint(x: center.x - offset, y: points[i].y))
        }
        
        for i in 0 ..< points.count {
            setPoint(newPoints[i], atIndex: i)
        }
    }
    
    func flipVerticalAroundPoint(center: CGPoint) {
        var newPoints: [CGPoint] = []
        for i in 0 ..< points.count {
            let offset = points[i].y - center.y
            newPoints.append(CGPoint(x: points[i].x, y: center.y - offset))
        }
        
        for i in 0 ..< points.count {
            setPoint(newPoints[i], atIndex: i)
        }
    }
    
    /// Recreate the cached path.
    ///
    /// This is the correct routine to override when you want to change the drawing
    /// behavior.
    func recache()
    {
        cachedPath = NSBezierPath()
        cachedPath!.lineWidth = lineWidth
        cachedPath!.appendBezierPathWithOvalInRect(CGRect(x: origin.x - SELECT_RADIUS / 2, y: origin.y - SELECT_RADIUS, width: SELECT_RADIUS, height: SELECT_RADIUS))
    }
    
    /// Utility function to draw a filled point as a 4 pixel rect.
    func drawPoint(point: CGPoint, size: CGFloat)
    {
        NSRectFill(CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size))
    }
    
    func addObserverPoints(points: [CGPoint], color: NSColor?) {
        if nestedGraphics == nil {
            nestedGraphics = []
        }
        nestedGraphics? += points.map { let g = Graphic(origin: $0); g.fillColor = color; return g }
    }
    
    func drawHandlesInView(view: DrawingView) {
        let size = view.scaleFloat(HSIZE)
        
        for p in points {
            drawPoint(p, size: size)
        }
    }
    
    /// Draw the graphic
    ///
    /// Draws the currently cached path.
    /// The default implementation should normally be sufficient. Override recache instead of drawing directly.
    func drawInView(view: DrawingView)
    {
        if cachedPath == nil
        {
            recache()
        }
        
        if let fillColor = fillColor
        {
            fillColor.set()
            cachedPath?.fill()
        }
        lineColor.set()
        cachedPath?.lineWidth = view.scaleFloat(lineWidth)
        cachedPath?.stroke()
        
        if let nested = nestedGraphics
        {
            for g in nested {
                g.drawInView(view)
            }
        }
        
        if selected {
            drawHandlesInView(view)
        }
    }
    
    /// Test whether a graphic lies within a rectangle.
    ///
    /// - parameter rect: the selection rectangle
    /// - returns: true if any part of the graphic is within the rect
    func shouldSelectInRect(rect: CGRect) -> Bool
    {
        return NSIntersectsRect(rect, bounds)
    }
    
    /// Get the closest point to a given location on or within the graphic
    ///
    /// - parameter point: the reference location
    /// - parameter extended: true if the graphic should be extended beyond its bounds. This means that a line
    ///    would be extended infinitely, an arc would be treated as a complete circle, etc.
    /// - returns: the closest point on the graphic to the reference point
    func closestPointToPoint(point: CGPoint, extended: Bool = false) -> CGPoint
    {
        if let bp = BezierGraphic(path: path) {
            return bp.closestPointToPoint(point, extended: extended)
        }
        return origin
    }
    
    /// Get the distance to from the graphic to a reference point
    ///
    /// - parameter point: the reference location
    /// - parameter extended: true if the graphic should be extended beyond its bounds. This means that a line
    ///    would be extended infinitely, an arc would be treated as a complete circle, etc.
    /// - returns: the distance from the closest point on the graphic to the reference point
    func distanceToPoint(point: CGPoint, extended: Bool = false) -> CGFloat
    {
        let p = closestPointToPoint(point, extended: extended)
        return p.distanceToPoint(point)
    }
    
    func intersectsWithGraphic(g: Graphic) -> Bool {
        return intersectionsWithGraphic(g, extendSelf: false, extendOther: false).count > 0
    }
    
    func simpleIntersectionsWithGraphic(g: Graphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        if let bp = BezierGraphic(path: path) {
            return bp.intersectionsWithGraphic(g, extendSelf: extendSelf, extendOther: extendOther)
        }
        return []
    }
    
    func intersectionsWithGraphic(g: Graphic, extendSelf: Bool, extendOther: Bool) -> [CGPoint] {
        return simpleIntersectionsWithGraphic(g, extendSelf: extendSelf, extendOther: extendOther)
    }
    
    func closestIntersectionWithGraphic(g: Graphic, toPoint p: CGPoint) -> CGPoint? {
        let points = intersectionsWithGraphic(g, extendSelf: false, extendOther: false)
        
        if points.count == 0 {
            return nil
        } else {
            return points.sort({ $0.distanceToPoint(p) < $1.distanceToPoint(p) })[0]
        }
    }
    
    /// Snap the cursor to the graphic if within the SnapRadius
    
    func snapCursor(location: CGPoint) -> SnapResult? {
        for point in points {
            if point.distanceToPoint(location) < SnapRadius {
                return SnapResult(location: point, type: .EndPoint)
            }
        }
        return nil
    }
    
    /// Scale the graphic
    
    func scalePoint(point: CGPoint, fromRect: CGRect, toRect: CGRect) -> CGPoint {
        let hscale = toRect.size.width / fromRect.size.width
        let vscale = toRect.size.height / fromRect.size.height
        let offset = point - fromRect.origin
        let scaledOffset = CGPoint(x: offset.x * hscale, y: offset.y * vscale)
        
        return toRect.origin + scaledOffset
    }
    
    func scaleFromRect(fromRect: CGRect, toRect: CGRect) {
        for i in 0 ..< points.count {
            let p = scalePoint(points[i], fromRect: fromRect, toRect: toRect)
            
            setPoint(p, atIndex: i)
        }
    }
    
    /// trim help
    
    func divideAtPoint(point: CGPoint) -> [Graphic] {
        return [self]
    }
    
    func extendToIntersectionWith(g: Graphic, closeToPoint: CGPoint) -> Graphic {
        return self
    }
    
    /// resize snaps
    
    func addReshapeSnapConstructionsAtPoint(point: CGPoint, toView: DrawingView) {
    }
}

/// A graphic factory using mouse events

class GraphicTool: NSObject
{
    // return the cursor that represents this tool
    func cursor() -> NSCursor
    {
        return NSCursor.arrowCursor()
    }
    
    /// called when the tool is made the current tool
    func selectTool(view: DrawingView)
    {
    }
    
    // escape pressed - end any creation
    func escape(view: DrawingView)
    {
        view.selection = []
        view.snapConstructions = []
        view.construction = nil
        view.setSelectTool(self)
    }
    
    /// called when a mouseDown event happens
    ///
    /// - parameter location: location within the drawing view
    /// - parameter view: the drawing view
    func mouseDown(location: CGPoint, view: DrawingView)
    {
    }
    
    /// called when a mouseDragged event happens
    ///
    /// - parameter location: location within the drawing view
    /// - parameter view: the drawing view
    func mouseDragged(location: CGPoint, view: DrawingView)
    {
    }
    
    /// called when a mouseMoved event happens
    ///
    /// - parameter location: location within the drawing view
    /// - parameter view: the drawing view
    func mouseMoved(location: CGPoint, view: DrawingView)
    {
    }
    
    /// called when a mouseUp event happens
    ///
    /// The default implementation treats mouseUp as a final drag and then adds the current
    /// construction in the view.
    ///
    /// - parameter location: location within the drawing view
    /// - parameter view: the drawing view
    func mouseUp(location: CGPoint, view: DrawingView)
    {
        mouseDragged(location, view: view)
        view.addConstruction()
    }
}

