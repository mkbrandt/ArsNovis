//
//  Dimensions.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/17/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class LinearDimension: Graphic
{
    var text = "#{dim}"
    var units: String?
    var endPoint: CGPoint
    var verticalOffset: CGFloat = 40
    var horizontalOffset: CGFloat = 0
    var fontSize = applicationDefaults.dimensionFontSize
    var fontDescriptor = applicationDefaults.dimensionFont.fontDescriptor
    
    var font: NSFont {
        get { return NSFont(descriptor: fontDescriptor, size: fontSize)! }
        set { fontDescriptor = newValue.fontDescriptor; fontSize = newValue.pointSize }
    }
    
    var fontName: String { return font.fontName }
    
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
    
    override var inspectionName: String              { return "Linear Dimension" }
    override var inspectionInfo: [InspectionInfo] {
        return super.inspectionInfo + [
            InspectionInfo(label: "text", key: "text", type: .string),
            InspectionInfo(label: "Font", key: "fontName", type: .string),
            InspectionInfo(label: "Size", key: "fontSize", type: .float)
        ]
    }
    
    init(origin: CGPoint, endPoint: CGPoint) {
        self.endPoint = endPoint
        super.init(origin: origin)
        lineColor = lineColor.withAlphaComponent(0.3)
    }
    
    required init?(coder decoder: NSCoder) {
        endPoint = decoder.decodePoint(forKey: "endPoint")
        super.init(coder: decoder)
        if let text = decoder.decodeObject(forKey: "text") as? String {
            self.text = text
        }
        if let units = decoder.decodeObject(forKey: "units") as? String {
            self.units = units
        }
        verticalOffset = CGFloat(decoder.decodeDouble(forKey: "vertical"))
        horizontalOffset = CGFloat(decoder.decodeDouble(forKey: "horizontal"))
    }

    required convenience init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(endPoint, forKey: "endPoint")
        coder.encode(text, forKey: "text")
        if let units = units {
            coder.encode(units, forKey: "units")
        }
        coder.encode(Double(verticalOffset), forKey: "vertical")
        coder.encode(Double(horizontalOffset), forKey: "horizontal")
    }
    
    override func recache() {
    }
    
    func drawLeaderLinesInView(_ view: DrawingView) {
        let context = view.context
        
        context?.saveGState()
        lineColor.set()
        
        let leadOffset = view.scaleFloat(5)
        let originLeadStart = origin + CGPoint(length: leadOffset, angle: originLeadLine.angle)
        let originLeadEnd = originLeadStart + originLeadLine
        let endPointLeadStart = endPoint + CGPoint(length: leadOffset, angle: endPointLeadLine.angle)
        let endPointLeadEnd = endPointLeadStart + endPointLeadLine
        
        NSBezierPath.setDefaultLineWidth(view.scaleFloat(0.5))
        NSBezierPath.strokeLine(from: originLeadStart, to: originLeadEnd)
        NSBezierPath.strokeLine(from: endPointLeadStart, to: endPointLeadEnd)
        
        context?.restoreGState()
    }
    
    override func drawInView(_ view: DrawingView) {
        let context = view.context
        
        context?.saveGState()
        
        drawLeaderLinesInView(view)
        
        context?.translate(x: origin.x, y: origin.y)
        context?.rotate(byAngle: measurement.angle)
        lineColor.set()
        context?.setLineWidth(view.scaleFloatToDrawing(0.5))
       
        let x1 = measurement.length
        let y1 = verticalOffset
        let d0 = x1 / 2 + horizontalOffset              // dimension center
        let dim = dimensionText
        var attrib: [String: AnyObject] = [NSForegroundColorAttributeName: lineColor]
        if let font = NSFont(descriptor: fontDescriptor, size: view.scaleFloatToDrawing(fontSize)) {
            attrib[NSFontAttributeName] = font
        }
        let textSize = dim.size(withAttributes: attrib)
        let textRect = CGRect(x: d0 - textSize.width / 2, y: y1 - textSize.height / 2, width: textSize.width, height: textSize.height)
        
        // dimension line
        context?.moveTo(x: 0, y: y1)
        context?.addLineTo(x: x1, y: y1)
        context?.strokePath()
        
        // add arrows
        let arrowLength = view.scaleFloatToDrawing(applicationDefaults.dimensionArrowLength)
        let arrowWidth = view.scaleFloatToDrawing(applicationDefaults.dimensionArrowWidth)
        
        context?.moveTo(x: 0, y: y1)
        context?.addLineTo(x: arrowLength, y: y1 - arrowWidth / 2)
        context?.addLineTo(x: arrowLength, y: y1 + arrowWidth / 2)
        context?.addLineTo(x: 0, y: y1)
        
        context?.moveTo(x: x1, y: y1)
        context?.addLineTo(x: x1 - arrowLength, y: y1 - arrowWidth / 2)
        context?.addLineTo(x: x1 - arrowLength, y: y1 + arrowWidth / 2)
        context?.addLineTo(x: x1, y: y1)
        context?.fillPath()
        
        // add dimension text
        NSColor.white().set()
        let inset = view.scaleFloat(10)
        context?.fill(textRect.insetBy(dx: -inset, dy: 0))
        dim.draw(at: textRect.origin, withAttributes: attrib)
        
        context?.restoreGState()
        if selected {
            drawHandlesInView(view)
        }
    }
    
    override func shouldSelectInRect(_ rect: CGRect) -> Bool {
        return dimLine.shouldSelectInRect(rect)
    }
    
    override func closestPointToPoint(_ point: CGPoint, extended: Bool) -> CGPoint {
        var cp = dimLine.closestPointToPoint(point)
        
        for p in points {
            if p.distanceToPoint(point) < cp.distanceToPoint(point) {
                cp = p
            }
        }
        
        return cp
    }
    
    override func setPoint(_ point: CGPoint, atIndex index: Int) {
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
    
    override func addReshapeSnapConstructionsAtPoint(_ point: CGPoint, toView: DrawingView) {
        let dl = dimLine
        dl.lineColor = NSColor.clear()
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
    
    override func selectTool(_ view: DrawingView) {
        view.setDrawingHint("Dimension: Select first point")
        state = 0
    }
    
    override func escape(_ view: DrawingView) {
        if let construct = construct {
            view.removeSnapConstructionsForReference(construct)
        }
        construct = nil
        state = 0
        view.construction = nil
    }
    
    func makeDimension(_ origin: CGPoint, endPoint: CGPoint) -> LinearDimension {
        return LinearDimension(origin: origin, endPoint: endPoint)
    }
    
    override func mouseDown(_ location: CGPoint, view: DrawingView) {
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
                defLead.lineColor = NSColor.clear()
                defLead2.lineColor = NSColor.clear()
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
                construct.lineColor = construct.lineColor.withAlphaComponent(1.0)
                view.addConstruction()
                view.removeSnapConstructionsForReference(construct)
                self.construct = nil
            }
            state = 0
            break
        }
    }
    
    override func mouseMoved(_ location: CGPoint, view: DrawingView) {
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
    
    override func mouseUp(_ location: CGPoint, view: DrawingView) {
    }
}

class HorizontalDimensionTool: LinearDimensionTool
{
    override func makeDimension(_ origin: CGPoint, endPoint: CGPoint) -> LinearDimension {
        return HorizontalDimension(origin: origin, endPoint: endPoint)
    }
}

class VerticalDimensionTool: LinearDimensionTool
{
    override func makeDimension(_ origin: CGPoint, endPoint: CGPoint) -> LinearDimension {
        return VerticalDimension(origin: origin, endPoint: endPoint)
    }
}
