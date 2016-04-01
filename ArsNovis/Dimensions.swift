//
//  Dimensions.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/17/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

let ARROW_WIDTH: CGFloat = 8
let ARROW_LENGTH: CGFloat = 16
let DIMENSION_TEXT_SIZE: CGFloat = 16
let DIMENSION_TEXT_FONT = NSFont(name: "Helvetica", size: 16)!

class LinearDimension: Graphic
{
    var text = "#{dim}"
    var units: String?
    var endPoint: CGPoint
    var verticalOffset: CGFloat = 40
    var horizontalOffset: CGFloat = 0
    var fontSize = DIMENSION_TEXT_SIZE
    var fontDescriptor = DIMENSION_TEXT_FONT.fontDescriptor
    
    var measurement: CGPoint    { return endPoint - origin }
    var leadAngle: CGFloat      { return measurement.angle + PI / 2 }
    var leadLine: CGPoint       { return CGPoint(length: verticalOffset, angle: leadAngle) }
    var leadPoint1: CGPoint     { return origin + leadLine }
    var leadPoint2: CGPoint     { return endPoint + leadLine }
    
    var measureLine: LineGraphic    { return LineGraphic(origin: origin, endPoint: endPoint) }
    var dimLine: LineGraphic        { return LineGraphic(origin: origin + leadLine, endPoint: endPoint + leadLine) }
    
    var dimensionText: NSString {
        return stringFromDistance((endPoint - origin).length)
    }
    
    var dimCenter: CGPoint          { return dimLine.center + CGPoint(length: horizontalOffset, angle: dimLine.angle) }
    
    override var points: [CGPoint]  { return [origin, endPoint, dimCenter] }
    override var bounds: CGRect     { return rectContainingPoints([origin, endPoint, leadPoint1, leadPoint2]) }
    
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
    
    override func drawInView(view: DrawingView) {
        let context = view.context
        
        CGContextSaveGState(context)
        CGContextTranslateCTM(context, origin.x, origin.y)
        CGContextRotateCTM(context, measurement.angle)
        lineColor.set()
        CGContextSetLineWidth(context, view.scaleFloatToDrawing(0.5))
       
        let x1 = measurement.length
        let y0 = view.scaleFloat(5) * sign(verticalOffset)
        let y1 = verticalOffset
        let d0 = x1 / 2 + horizontalOffset              // dimension center
        let dim = dimensionText
        var attrib: [String: AnyObject] = [NSForegroundColorAttributeName: lineColor]
        if let font = NSFont(descriptor: fontDescriptor, size: view.scaleFloatToDrawing(fontSize)) {
            attrib[NSFontAttributeName] = font
        }
        let textSize = dim.sizeWithAttributes(attrib)
        let textRect = CGRect(x: d0 - textSize.width / 2, y: y1 - textSize.height / 2, width: textSize.width, height: textSize.height)
        
        // leader lines
        CGContextMoveToPoint(context, 0, y0)
        CGContextAddLineToPoint(context, 0, y1 + y0)
        CGContextMoveToPoint(context, x1, y0)
        CGContextAddLineToPoint(context, x1, y1 + y0)
        
        // dimension line
        CGContextMoveToPoint(context, 0, y1)
        CGContextAddLineToPoint(context, x1, y1)
        CGContextStrokePath(context)
        
        // add arrows
        let arrowLength = view.scaleFloatToDrawing(ARROW_LENGTH)
        let arrowWidth = view.scaleFloatToDrawing(ARROW_WIDTH)
        
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
        let cl = ConstructionLine(origin: measureLine.center, endPoint: measureLine.center + leadLine, reference: [self])
        toView.snapConstructions = [dl, cl]
    }
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
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        switch state {
        case 0:
            let dim = LinearDimension(origin: location, endPoint: location)
            dim.verticalOffset = view.scaleFloatToDrawing(dim.verticalOffset)
            construct = dim
            view.construction = dim
            view.setDrawingHint("Dimension: Select second point")
            state = 1
        case 1:
            if let construct = construct {
                construct.endPoint = location
                let defLead = construct.dimLine
                let defLead2 = LineGraphic(origin: construct.origin - construct.leadLine, endPoint: construct.endPoint - construct.leadLine)
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
