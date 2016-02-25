//
//  DrawingView.swift
//  Electra
//
//  Created by Matt Brandt on 6/8/14.
//  Copyright (c) 2014 WalkingDog Design. All rights reserved.
//

import Cocoa

let HSIZE: CGFloat = 6.0
let SELECT_RADIUS: CGFloat = 3.0

class DrawingView: ZoomView
{
    @IBOutlet var hintField: NSTextField?
    @IBOutlet var inspector: GraphicInspector?      { didSet { inspector?.view = self }}
    
    var context: CGContext!
    
    var displayList: [Graphic] = []
    
    var selection: [Graphic] = [] {
        didSet {
            if selection.count == 1 {
                inspector?.beginInspection(selection[0])
            }
        }
    }
    
    var selectionRect = CGRect(x: 0, y: 0, width: 0, height: 0)

    var construction: Graphic? {
        didSet {
            if let g = construction {
                inspector?.beginInspection(g)
            }
        }
    }
    
    var tool: GraphicTool = LineTool() {
        didSet { selection = [] }
    }
    var gridSnap = false
    var cursorNote = ""
    var snappedCursor: SnapResult?
    
    var _trackingArea: NSTrackingArea?
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func awakeFromNib()
    {
        window?.acceptsMouseMovedEvents = true
        tool.selectTool(self)
        updateTrackingAreas()
    }
    
    override func becomeFirstResponder() -> Bool
    {
        return true
    }
    
    override func updateTrackingAreas()
    {
        let options: NSTrackingAreaOptions = [.MouseMoved, .MouseEnteredAndExited, .ActiveAlways]
        
        if _trackingArea != nil {
            removeTrackingArea(_trackingArea!)
        }
        _trackingArea = NSTrackingArea(rect: visibleRect, options: options, owner: self, userInfo: nil)
        addTrackingArea(_trackingArea!)
    }
    
    func resetBounds() {
        var b = CGRect()
        for g in displayList {
            b = b.union(g.bounds)
        }
        if b.isEmpty {
            bounds = CGRect(x: 0, y: 0, width: 90 * 18, height: 90 * 12)
        }
        b.size.width *= 1.1
        b.size.height *= 1.1
        let maxbound = max(b.size.width * 2, b.size.height * 3)
        b.size.width = maxbound / 2
        b.size.height = maxbound / 3
        Swift.print("Frame set to \(b)")
        frame = b
    }
    
    override var intrinsicContentSize: CGSize {
        return CGSize(width: 90 * 18, height: 90 * 12)
    }
    
    override func resetCursorRects()
    {
        addCursorRect(bounds, cursor: tool.cursor())
    }
    
    func redrawConstruction() {
        if let construction = construction {
            setNeedsDisplayInRect(construction.bounds)
        }
    }
    
    func drawGridInRect(var dirtyRect: CGRect)
    {
        dirtyRect.standardizeInPlace()
        
        let left = dirtyRect.origin.x - 10
        let right = left + dirtyRect.size.width + 10
        let bottom = dirtyRect.origin.y - 10
        let top = bottom + dirtyRect.size.height + 10
        
        NSColor.lightGrayColor().set()
        NSBezierPath.setDefaultLineWidth(0.1)
        for var gx = floor(left / 10); gx * 10 <= right; ++gx {
            let major = fmod(gx, 10) == 0
            if major {
                NSBezierPath.setDefaultLineWidth(0.25)
            }
            NSBezierPath.strokeLineFromPoint(CGPoint(x: gx * 10, y: bottom), toPoint: CGPoint(x: gx * 10, y: top))
            if major {
                NSBezierPath.setDefaultLineWidth(0.1)
            }
        }
        
        for var gy = floor(bottom / 10); gy * 10 <= top; ++gy {
            let major = fmod(gy, 10) == 0
            if major {
                NSBezierPath.setDefaultLineWidth(0.25)
            }
            NSBezierPath.strokeLineFromPoint(CGPoint(x: left, y: gy * 10), toPoint: CGPoint(x: right, y: gy * 10))
            if major {
                NSBezierPath.setDefaultLineWidth(0.1)
            }
        }
    }
    
    override func drawRect(dirtyRect: CGRect)
    {
        context = NSGraphicsContext.currentContext()?.CGContext
        
        NSEraseRect(dirtyRect)
        drawGridInRect(dirtyRect)
        
        CGContextSetLineWidth(context, 0.0)
        
        for g in displayList
        {
            if needsToDrawRect(g.bounds)
            {
                g.draw()
            }
        }
        
        for g in selection
        {
            if needsToDrawRect(NSInsetRect(g.bounds, -HSIZE / 2.0, -HSIZE / 2.0))
            {
                drawHandlesForGraphic(g)
            }
        }
        
        construction?.draw()
        
        if !selectionRect.isEmpty
        {
            let path = NSBezierPath(rect: selectionRect)
            let dashPattern: [CGFloat] = [3.0, 5.0]
            
            path.setLineDash(dashPattern, count: 2, phase: 0)
            path.lineWidth = 1.0
            NSColor.darkGrayColor().set()
            path.stroke()
        }
        
        drawSnappedCursor()
    }
    
    func drawHandleAtPoint(point: CGPoint)
    {
        let x = point.x - HSIZE / 2.0
        let y = point.y - HSIZE / 2.0
        let handleRect = CGRect(origin: CGPoint(x: x, y: y), size: NSSize(width: HSIZE, height: HSIZE))
        NSColor.blackColor().set()
        NSRectFill(handleRect)
    }
    
    func drawHandlesForGraphic(graphic: Graphic)
    {
        let handles = graphic.points
        
        for handle in handles
        {
            drawHandleAtPoint(handle)
        }
    }
    
    func setDrawingHint(hint: String)
    {
        hintField?.stringValue = hint
    }
    
    func closestGraphicToPoint(point: CGPoint, within distance: CGFloat) -> Graphic?
    {
        var dist = CGFloat.infinity
        var found: Graphic?
        
        for g in displayList
        {
            let r = g.bounds.insetBy(dx: -distance, dy: -distance)
            if r.contains(point)
            {
                let d = g.distanceToPoint(point)
                
                if d < distance && d < dist
                {
                    dist = d
                    found = g
                }
            }
        }
        return found
    }
    
    func selectObjectsInRect(rect: CGRect)
    {
        selection = []
        for g in displayList
        {
            if g.shouldSelectInRect(rect)
            {
                selection.append(g)
            }
        }
    }
    
    var cursorSnapRect: CGRect {
        if let snap = snappedCursor {
            let p = snap.location
            let tp = p + CGPoint(x: 6, y: 6)
            let textRect = CGRect(origin: tp, size: snap.cursorText.sizeWithAttributes(nil))
            let crossRect = CGRect(x: p.x - SnapRadius * 2, y: (p.y - SnapRadius * 2), width: SnapRadius * 2, height: SnapRadius * 2)
            return textRect.union(crossRect)
        } else {
            return CGRect()
        }
    }
    
    func drawSnappedCursor()
    {
        if let snap = snappedCursor {
            let p = snap.location
            
            let path = NSBezierPath()
            let xx = CGPoint(x: 2, y: 0)
            let yy = CGPoint(x: 0, y: 2)
            
            path.moveToPoint(p + xx + yy)
            path.lineToPoint(p + 3 * (xx + yy))
            path.moveToPoint(p + xx - yy)
            path.lineToPoint(p + 3 * (xx - yy))
            path.moveToPoint(p - (xx + yy))
            path.lineToPoint(p - 3 * (xx + yy))
            path.moveToPoint(p - (xx - yy))
            path.lineToPoint(p - 3 * (xx - yy))
            NSColor.blackColor().set()
            path.lineWidth = 1.0
            path.stroke()
            snap.cursorText.drawAtPoint(p + xx + yy, withAttributes: nil)
        }
    }
    
    func snapToGrid(var point: CGPoint) -> SnapResult?
    {
        if gridSnap {
            point.x = round(point.x / 10) * 10
            point.y = round(point.y / 10) * 10
        
            return SnapResult(location: point, type: .Grid)
        }
        return nil
    }
    
    func snapToObjects(p: CGPoint) -> SnapResult? {
        for g in displayList {
            if !selection.contains(g) {
                if let snap = g.snapCursor(p) {
                    return snap
                }
            }
        }
        return nil
    }
    
    override func mouseDown(theEvent: NSEvent)
    {
        var p = convertPoint(theEvent.locationInWindow, fromView: nil)
        
        snappedCursor = snapToObjects(p) ?? snapToGrid(p)
        if let snap = snappedCursor {
            p = snap.location
        }
        tool.mouseDown(p, view: self)
    }
    
    override func mouseDragged(theEvent: NSEvent)
    {
        var p = convertPoint(theEvent.locationInWindow, fromView: nil)
        
        setNeedsDisplayInRect(cursorSnapRect)
        snappedCursor = snapToObjects(p) ?? snapToGrid(p)
        if let snap = snappedCursor {
            p = snap.location
        }
        setNeedsDisplayInRect(cursorSnapRect)
        tool.mouseDragged(p, view: self)
    }
    
    override func mouseMoved(theEvent: NSEvent)
    {
        var p = convertPoint(theEvent.locationInWindow, fromView: nil)
        
        setNeedsDisplayInRect(cursorSnapRect)
        snappedCursor = snapToObjects(p) ?? snapToGrid(p)
        if let snap = snappedCursor {
            p = snap.location
        }
        setNeedsDisplayInRect(cursorSnapRect)
        tool.mouseMoved(p, view: self)
    }
    
    override func mouseUp(theEvent: NSEvent)
    {
        var p = convertPoint(theEvent.locationInWindow, fromView: nil)
        
        snappedCursor = snapToObjects(p) ?? snapToGrid(p)
        if let snap = snappedCursor {
            p = snap.location
        }
        tool.mouseUp(p, view: self)
    }
    
    override func mouseEntered(theEvent: NSEvent)
    {
        window!.makeFirstResponder(self)
    }
    
    override func mouseExited(theEvent: NSEvent)
    {
        tool.cursor().pop()
    }
    
    override func keyDown(theEvent: NSEvent)
    {
        let key = theEvent.characters!
        
        switch key
        {
        case "g":
            gridSnap = !gridSnap
        case "l":
            tool = LineTool()
        case "r":
            tool = RectTool()
        case "a":
            tool = Arc3PtTool()
        case "s":
            tool = SelectTool()
        default:
            break
        }
        window?.invalidateCursorRectsForView(self)
    }
    
    func addGraphic(graphic: Graphic)
    {
        displayList.append(graphic)
        undoManager?.prepareWithInvocationTarget(self).deleteGraphic(graphic)
        inspector?.beginInspection(graphic)
    }
    
    func addGraphics(graphics: [Graphic])
    {
        for g in graphics {
            displayList.append(g)
        }
        undoManager?.prepareWithInvocationTarget(self).deleteGraphics(graphics)
    }
    
    func deleteGraphics(graphics: [Graphic])
    {
        displayList = displayList.filter { !graphics.contains($0) }
        undoManager?.prepareWithInvocationTarget(self).addGraphics(graphics)
    }
    
    func deleteGraphic(graphic: Graphic)
    {
        displayList = displayList.filter { $0 != graphic }
        undoManager?.prepareWithInvocationTarget(self).addGraphic(graphic)
    }
    
    func addConstruction()
    {
        if construction != nil
        {
            addGraphic(construction!)
            construction = nil
        }
    }
    
    func deleteSelection()
    {
        deleteGraphics(selection)
        selection = []
    }
    
}
