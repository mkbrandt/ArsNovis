//
//  Dimensions.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/17/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

var DIMENSION_ARROW_WIDTH: CGFloat = 6
var DIMENSION_ARROW_LENGTH: CGFloat = 12
var DIMENSION_TEXT_SIZE: CGFloat = 12
var DIMENSION_TEXT_FONT = NSFont.systemFontOfSize(12)

class LinearDimension: Graphic
{
    var text = "#{dim}"
    var units: String?
    var endPoint: CGPoint
    var verticalOffset: CGFloat = 40
    var horizontalOffset: CGFloat = 0
    var fontSize = DIMENSION_TEXT_SIZE
    var fontDescriptor = DIMENSION_TEXT_FONT.fontDescriptor
    
    var measurement: CGPoint        { return endPoint - origin }
    var leadAngle: CGFloat          { return measurement.angle + PI / 2 }
    var originLeadLine: CGPoint     { return CGPoint(length: verticalOffset, angle: leadAngle) }
    var endPointLeadLine: CGPoint   { return CGPoint(length: verticalOffset, angle: leadAngle) }
    var originLeadPoint: CGPoint    { return origin + originLeadLine }
    var endLeadPoint: CGPoint       { return endPoint + endPointLeadLine }
    
    var measureLine: LineGraphic    { return LineGraphic(origin: origin, endPoint: endPoint) }
    var dimLine: LineGraphic        { return LineGraphic(origin: originLeadPoint, endPoint: endLeadPoint) }
    
    var dimensionText: NSString {
        return stringFromDistance((endPoint - origin).length)
    }
    
    var dimCenter: CGPoint          { return dimLine.center + CGPoint(length: horizontalOffset, angle: dimLine.angle) }
    
    override var points: [CGPoint]  { return [origin, endPoint, dimCenter] }
    override var bounds: CGRect     { return rectContainingPoints([origin, endPoint, originLeadPoint, endLeadPoint]) }
    
    init(origin: CGPoint, endPoint: CGPoint) {
        self.endPoint = endPoint
        super.init(origin: origin)
        lineColor = lineColor.colorWithAlphaComponent(0.3)
    }
    
    required init?(coder decoder: NSCoder) {
        endPoint = decoder.decodePointForKey("endPoint")
        super.init(coder: decoder)
        if let text = decoder.decodeObjectForKey("text") as? String {
            self.text = text
        }
        if let units = decoder.decodeObjectForKey("units") as? String {
            self.units = units
        }
        verticalOffset = CGFloat(decoder.decodeDoubleForKey("vertical"))
        horizontalOffset = CGFloat(decoder.decodeDoubleForKey("horizontal"))
    }

    required convenience init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        coder.encodePoint(endPoint, forKey: "endPoint")
        coder.encodeObject(text, forKey: "text")
        if let units = units {
            coder.encodeObject(units, forKey: "units")
        }
        coder.encodeDouble(Double(verticalOffset), forKey: "vertical")
        coder.encodeDouble(Double(horizontalOffset), forKey: "horizontal")
    }
    
    override func recache() {
    }
    
    func drawLeaderLinesInView(view: DrawingView) {
        let context = view.context
        
        CGContextSaveGState(context)
        lineColor.set()
        
        let leadOffset = view.scaleFloat(5)
        let originLeadStart = origin + CGPoint(length: leadOffset, angle: originLeadLine.angle)
        let originLeadEnd = originLeadStart + originLeadLine
        let endPointLeadStart = endPoint + CGPoint(length: leadOffset, angle: endPointLeadLine.angle)
        let endPointLeadEnd = endPointLeadStart + endPointLeadLine
        
        NSBezierPath.setDefaultLineWidth(view.scaleFloat(0.5))
        NSBezierPath.strokeLineFromPoint(originLeadStart, toPoint: originLeadEnd)
        NSBezierPath.strokeLineFromPoint(endPointLeadStart, toPoint: endPointLeadEnd)
        
        CGContextRestoreGState(context)
    }
    
    override func drawInView(view: DrawingView) {
        let context = view.context
        
        CGContextSaveGState(context)
        
        drawLeaderLinesInView(view)
        
        CGContextTranslateCTM(context, origin.x, origin.y)
        CGContextRotateCTM(context, measurement.angle)
        lineColor.set()
        CGContextSetLineWidth(context, view.scaleFloatToDrawing(0.5))
       
        let x1 = measurement.length
        let y1 = verticalOffset
        let d0 = x1 / 2 + horizontalOffset              // dimension center
        let dim = dimensionText
        var attrib: [String: AnyObject] = [NSForegroundColorAttributeName: lineColor]
        if let font = NSFont(descriptor: fontDescriptor, size: view.scaleFloatToDrawing(fontSize)) {
            attrib[NSFontAttributeName] = font
        }
        let textSize = dim.sizeWithAttributes(attrib)
        let textRect = CGRect(x: d0 - textSize.width / 2, y: y1 - textSize.height / 2, width: textSize.width, height: textSize.height)
        
        // dimension line
        CGContextMoveToPoint(context, 0, y1)
        CGContextAddLineToPoint(context, x1, y1)
        CGContextStrokePath(context)
        
        // add arrows
        let arrowLength = view.scaleFloatToDrawing(DIMENSION_ARROW_LENGTH)
        let arrowWidth = view.scaleFloatToDrawing(DIMENSION_ARROW_WIDTH)
        
        CGContextMoveToPoint(context, 0, y1)
        CGContextAddLineToPoint(context, arrowLength, y1 - arrowWidth / 2)
        CGContextAddLineToPoint(context, arrowLength, y1 + arrowWidth / 2)
        CGContextAddLineToPoint(context, 0, y1)
        
        CGContextMoveToPoint(context, x1, y1)
        CGContextAddLineToPoint(context, x1 - arrowLength, y1 - arrowWidth / 2)
        CGContextAddLineToPoint(context, x1 - arrowLength, y1 + arrowWidth / 2)
        CGContextAddLineToPoint(context, x1, y1)
        CGContextFillPath(context)
        
        // add dimension text
        NSColor.whiteColor().set()
        let inset = view.scaleFloat(10)
        CGContextFillRect(context, textRect.insetBy(dx: -inset, dy: 0))
        dim.drawAtPoint(textRect.origin, withAttributes: attrib)
        
        CGContextRestoreGState(context)
        if showHandles {
            drawHandlesInView(view)
        }
    }
    
    override func shouldSelectInRect(rect: CGRect) -> Bool {
        return dimLine.shouldSelectInRect(rect)
    }
    
    override func closestPointToPoint(point: CGPoint, extended: Bool) -> CGPoint {
        var cp = dimLine.closestPointToPoint(point)
        
        for p in points {
            if p.distanceToPoint(point) < cp.distanceToPoint(point) {
                cp = p
            }
        }
        
        return cp
    }
    
    override func setPoint(point: CGPoint, atIndex index: Int) {
        switch index {
        case 0:
            origin = point
        case 1:
            endPoint = point
        case 2:
            let p = measureLine.closestPointToPoint(point)
            let perp = LineGraphic(origin: p, endPoint: point)
            let angleBetween = normalizeAngle(perp.angle - measureLine.angle)
            verticalOffset = sign(angleBetween) * perp.length
            horizontalOffset = measureLine.origin.distanceToPoint(p) - measureLine.length / 2
        default:
            break
        }
    }
    
    override func addReshapeSnapConstructionsAtPoint(point: CGPoint, toView: DrawingView) {
        let dl = dimLine
        dl.lineColor = NSColor.clearColor()
        dl.ref = [self]
        let cl = ConstructionLine(origin: measureLine.center, endPoint: measureLine.center + originLeadLine, reference: [self])
        toView.snapConstructions = [dl, cl]
    }
}

class HorizontalDimension: LinearDimension
{
    override var measurement: CGPoint       { return CGPoint(x: endPoint.x - origin.x, y: 0) }
    override var leadAngle: CGFloat         { return PI / 2 }
    override var measureLine: LineGraphic   { return LineGraphic(origin: origin, endPoint: CGPoint(x: endPoint.x, y: origin.y)) }
    override var dimensionText: NSString    { return stringFromDistance(abs(endPoint.x - origin.x)) }
    override var originLeadLine: CGPoint    { return CGPoint(x: 0, y: verticalOffset) }
    override var endPointLeadLine: CGPoint  { return CGPoint(x: 0, y: verticalOffset - (endPoint.y - origin.y)) }
}

class VerticalDimension: LinearDimension
{
    override var measurement: CGPoint       { return CGPoint(x: 0, y: endPoint.y - origin.y) }
    override var leadAngle: CGFloat         { return 0 }
    override var measureLine: LineGraphic   { return LineGraphic(origin: origin, endPoint: CGPoint(x: origin.x, y: endPoint.y)) }
    override var dimensionText: NSString    { return stringFromDistance(abs(endPoint.y - origin.y)) }
    override var originLeadLine: CGPoint    { return CGPoint(x: verticalOffset, y: 0) }
    override var endPointLeadLine: CGPoint  { return CGPoint(x: verticalOffset - (endPoint.x - origin.x), y: 0) }
}

class LinearDimensionTool: GraphicTool
{
    var state = 0
    var construct: LinearDimension?
    
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Dimension: Select first point")
        state = 0
    }
    
    override func escape(view: DrawingView) {
        if let construct = construct {
            view.removeSnapConstructionsForReference(construct)
        }
        construct = nil
        state = 0
        view.construction = nil
    }
    
    func makeDimension(origin: CGPoint, endPoint: CGPoint) -> LinearDimension {
        return LinearDimension(origin: origin, endPoint: endPoint)
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        switch state {
        case 0:
            let dim = makeDimension(location, endPoint: location)
            dim.verticalOffset = view.scaleFloatToDrawing(dim.verticalOffset)
            construct = dim
            view.construction = dim
            view.setDrawingHint("Dimension: Select second point")
            state = 1
        case 1:
            if let construct = construct {
                construct.endPoint = location
                let defLead = construct.dimLine
                let defLead2 = LineGraphic(origin: construct.origin - construct.originLeadLine, endPoint: construct.endPoint - construct.endPointLeadLine)
                defLead.lineColor = NSColor.clearColor()
                defLead2.lineColor = NSColor.clearColor()
                defLead.ref = [construct]
                defLead2.ref = [construct]
                view.snapConstructions = [defLead, defLead2]
                view.setDrawingHint("Dimension: Select text location")
            }
            state = 2
        default:
            if let construct = construct {
                let dim = construct.measureLine
                let p = dim.closestPointToPoint(location)
                let perp = LineGraphic(origin: p, endPoint: location)
                let angleBetween = normalizeAngle(perp.angle - dim.angle)
                construct.verticalOffset = sign(angleBetween) * perp.length
                construct.horizontalOffset = dim.origin.distanceToPoint(p) - dim.length / 2
                construct.lineColor = construct.lineColor.colorWithAlphaComponent(1.0)
                view.addConstruction()
                view.removeSnapConstructionsForReference(construct)
                self.construct = nil
            }
            state = 0
            break
        }
    }
    
    override func mouseMoved(location: CGPoint, view: DrawingView) {
        if let construct = construct {
            switch state {
            case 1:
                construct.endPoint = location
            case 2:
                let dim = construct.measureLine
                let p = dim.closestPointToPoint(location, extended: true)
                let perp = LineGraphic(origin: p, endPoint: location)
                let angleBetween = normalizeAngle(perp.angle - dim.angle)
                construct.verticalOffset = sign(angleBetween) * perp.length
                construct.horizontalOffset = dim.origin.distanceToPoint(p) - dim.length / 2
            default:
                break
            }
        }
    }
    
    override func mouseUp(location: CGPoint, view: DrawingView) {
    }
}

class HorizontalDimensionTool: LinearDimensionTool
{
    override func makeDimension(origin: CGPoint, endPoint: CGPoint) -> LinearDimension {
        return HorizontalDimension(origin: origin, endPoint: endPoint)
    }
}

class VerticalDimensionTool: LinearDimensionTool
{
    override func makeDimension(origin: CGPoint, endPoint: CGPoint) -> LinearDimension {
        return VerticalDimension(origin: origin, endPoint: endPoint)
    }
}
