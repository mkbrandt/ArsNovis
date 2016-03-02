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
    
    var document: ArsDocument!
    
    var context: CGContext!
    
    var displayList: [Graphic] {
        get { return document.displayList }
        set { document.displayList = newValue }
    }
    
    var selection: [Graphic] = [] {
        didSet {
            if selection.count == 1 {
                inspector?.beginInspection(selection[0])
            } else {
                inspector?.removeAllSubviews()
            }
        }
    }
    
    override var contentRect: CGRect {
        var r = CGRect()
        if displayList.count == 0 {
            return CGRect(x: 0, y: 0, width: 90 * 17, height: 90 * 11)
        } else {
            r = displayList[0].bounds
        }
        
        for g in displayList {
            r = r.union(g.bounds)
        }
        return r
    }
    
    var selectionRect = CGRect(x: 0, y: 0, width: 0, height: 0)

    var construction: Graphic? {
        didSet {
            if let g = construction {
                inspector?.beginInspection(g)
            }
        }
    }
    
    var snapConstructions: [ConstructionLine] = []
    
    var tool: GraphicTool = LineTool() {
        didSet { selection = [] }
    }
    var gridSnap = false
    var cursorNote = ""
    var snappedCursor: SnapResult?
    
    var controlKeyDown = false
    var shiftKeyDown = false
    var commandKeyDown = false
    var optionKeyDown = false
    
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

    override var intrinsicContentSize: CGSize {
        return super.intrinsicContentSize
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

    func scaleFloat(f: CGFloat) -> CGFloat {
        return convertSize(CGSize(width: f, height: f), fromView: nil).width
    }
    
// MARK: Drawing
        
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
                g.drawInView(self)
            }
        }
        
        for g in snapConstructions {
            if needsToDrawRect(g.bounds)
            {
                g.drawInView(self)
            }
        }
        
        for g in selection
        {
            if needsToDrawRect(NSInsetRect(g.bounds, -HSIZE / 2.0, -HSIZE / 2.0))
            {
                drawHandlesForGraphic(g)
            }
        }
        
        construction?.drawInView(self)
        
        if !selectionRect.isEmpty
        {
            let path = NSBezierPath(rect: selectionRect)
            let dashPattern: [CGFloat] = [scaleFloat(3.0), scaleFloat(5.0)]
            
            path.setLineDash(dashPattern, count: 2, phase: 0)
            path.lineWidth = scaleFloat(1.0)
            NSColor.darkGrayColor().set()
            path.stroke()
        }
        
        drawSnappedCursor()
        //super.drawRect(dirtyRect)
    }
    
    func drawHandleAtPoint(point: CGPoint)
    {
        let hsize = scaleFloat(HSIZE)
        let x = point.x - hsize / 2
        let y = point.y - hsize / 2
        let handleSize = CGSize(width: hsize, height: hsize)
        let handleRect = CGRect(origin: CGPoint(x: x, y: y), size: handleSize)
        NSColor.blackColor().set()
        NSRectFill(handleRect)
    }
    
    func drawHandlesForGraphic(graphic: Graphic)
    {
        graphic.drawHandlesInView(self)
    }
    
    func setDrawingHint(hint: String)
    {
        hintField?.stringValue = hint
    }
    
    func closestGraphicToPoint(point: CGPoint, within distance: CGFloat) -> Graphic?
    {
        var dist = CGFloat.infinity
        var found: Graphic?
        
        for g in selection
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
    
// MARK: Cursor Snap
    
    var cursorSnapRect: CGRect {
        if let snap = snappedCursor {
            let p = snap.location
            let tp = p + CGPoint(x: scaleFloat(6), y: scaleFloat(6))
            let textSize = snap.cursorText.sizeWithAttributes(nil)
            let textRect = CGRect(origin: tp, size: convertSize(textSize, fromView: nil))
            let crossRect = CGRect(x: p.x - scaleFloat(RawSnapRadius * 2), y: p.y - scaleFloat(RawSnapRadius * 2), width: scaleFloat(RawSnapRadius * 2), height: scaleFloat(RawSnapRadius * 2))
            let rect = textRect.union(crossRect)
            return rect
        } else {
            return CGRect()
        }
    }
    
    func drawSnappedCursor()
    {
        if let snap = snappedCursor {
            let p = snap.location
            
            let path = NSBezierPath()
            let xx = CGPoint(x: scaleFloat(2), y: 0)
            let yy = CGPoint(x: 0, y: scaleFloat(2))
            
            path.moveToPoint(p + xx + yy)
            path.lineToPoint(p + 3 * (xx + yy))
            path.moveToPoint(p + xx - yy)
            path.lineToPoint(p + 3 * (xx - yy))
            path.moveToPoint(p - (xx + yy))
            path.lineToPoint(p - 3 * (xx + yy))
            path.moveToPoint(p - (xx - yy))
            path.lineToPoint(p - 3 * (xx - yy))
            NSColor.blackColor().set()
            path.lineWidth = scaleFloat(1)
            path.stroke()
            let fsize = scaleFloat(12)
            let textFont = NSFont.systemFontOfSize(fsize)
            snap.cursorText.drawAtPoint(p + xx + yy, withAttributes: [NSFontAttributeName: textFont])
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
    
    func snapToObjects(p: CGPoint, snapSelected: Bool = false) -> SnapResult? {
        if optionKeyDown {
            return nil
        }
        SnapRadius = scaleFloat(RawSnapRadius)
        var snappedObjects: [Graphic] = []
        var result: SnapResult?
        
        for g in snapConstructions {
            if g.isActive {
                setNeedsDisplayInRect(g.bounds)
            }
            g.isActive = false
        }
        
        for g in snapConstructions {
            if let snap = g.snapCursor(p) {
                g.isActive = true
                setNeedsDisplayInRect(g.bounds)
                result = snap
                snappedObjects.append(g)
            }
        }
        
        for g in displayList {
            if snapSelected || !selection.contains(g) {
                if let snap = g.snapCursor(p) {
                    if snap.type == .EndPoint || snap.type == .Center {
                        addSnapConstructionsForPoint(snap.location)
                    }
                    result = snap
                    snappedObjects.append(g)
                }
            }
        }
        
        if let snap = result where snap.type == .On || snap.type == .Align {
            for i in 0 ..< snappedObjects.count {
                let a = snappedObjects.removeAtIndex(i)
                for b in snappedObjects {
                    if let cp = a.closestIntersectionWithGraphic(b, toPoint: p) {
                        if cp.distanceToPoint(p) < SnapRadius {
                            if !a.isConstruction && !b.isConstruction {
                                addSnapConstructionsForPoint(cp)
                            }
                            result = SnapResult(location: cp, type: .Intersection)
                            break
                        }
                    }
                }
                snappedObjects.insert(a, atIndex: i)
            }
        }
        
        SnapRadius = RawSnapRadius
        return result
    }
    
    func addSnapConstructionsForPoint(p: CGPoint) {
        snapConstructions = snapConstructions.filter { $0.origin != p }
        
        for i in 0 ..< 2 {
            let line = ConstructionLine(origin: p)
            line.angle = CGFloat(i) * PI / 2
            snapConstructions = snapConstructions.filter { !$0.isColinearWith(line) }
            snapConstructions.append(line)
        }
        
        while snapConstructions.count > 20 {
            let old = snapConstructions.removeFirst()
            if old.isActive {
                setNeedsDisplayInRect(old.bounds)
            }
        }
    }

// MARK: Mouse Handling
    
    var mouseClickCount = 0
    
    override func mouseDown(theEvent: NSEvent)
    {
        var p = convertPoint(theEvent.locationInWindow, fromView: nil)
        
        mouseClickCount = theEvent.clickCount
        
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
        zoomCenter = p
        setNeedsDisplayInRect(cursorSnapRect)
        tool.mouseMoved(p, view: self)
        self.needsDisplay = true
    }
    
    override func mouseUp(theEvent: NSEvent)
    {
        var p = convertPoint(theEvent.locationInWindow, fromView: nil)
        
        setNeedsDisplayInRect(cursorSnapRect)
        snappedCursor = snapToObjects(p) ?? snapToGrid(p) ?? snapToObjects(p, snapSelected: true)
        if let snap = snappedCursor {
            p = snap.location
        }
        setNeedsDisplayInRect(cursorSnapRect)
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

// MARK: Keyboard Handling
    
    override func keyDown(theEvent: NSEvent)
    {
        let key = theEvent.characters!
        Swift.print("Key down: \(theEvent)")
        
        switch key
        {
        case "\t":
            inspector?.beginEditing()
        case "b":
            tool = BezierTool()
        case "e":
            tool = ElipseTool()
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
            super.keyDown(theEvent)
        }
        window?.invalidateCursorRectsForView(self)
    }
    
    override func flagsChanged(theEvent: NSEvent) {
        let flags = theEvent.modifierFlags
        
        controlKeyDown = flags.contains(.ControlKeyMask)
        shiftKeyDown = flags.contains(.ShiftKeyMask)
        optionKeyDown = flags.contains(.AlternateKeyMask)
        commandKeyDown = flags.contains(.CommandKeyMask)
        super.flagsChanged(theEvent)
    }
    
// MARK: IB Actions
    
    @IBAction func setLineTool(sender: AnyObject?) {
        tool = LineTool()
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setRectTool(sender: AnyObject?) {
        tool = RectTool()
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setArc3Tool(sender: AnyObject?) {
        tool = Arc3PtTool()
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setBezierTool(sender: AnyObject?) {
        tool = BezierTool()
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setElipseTool(sender: AnyObject?) {
        tool = ElipseTool()
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setSelectTool(sender: AnyObject?) {
        tool = SelectTool()
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func cut(sender: AnyObject?) {
        copy(sender)
        delete(sender)
    }
    
    @IBAction func copy(sender: AnyObject?) {
        let pasteBoard = NSPasteboard.generalPasteboard()
        
        pasteBoard.clearContents()
        pasteBoard.writeObjects(selection)
        snapConstructions = []
    }
    
    @IBAction func paste(sender: AnyObject?) {
        let pasteBoard = NSPasteboard.generalPasteboard()
        let classes = [Graphic.self]
        if pasteBoard.canReadObjectForClasses(classes, options: [:]) {
            if let graphics = pasteBoard.readObjectsForClasses([Graphic.self], options:[:]) as? [Graphic] {
                addGraphics(graphics)
                selection = graphics
            }
        }
        snapConstructions = []
    }
    
    @IBAction override func selectAll(sender: AnyObject?) {
        selection = displayList
    }
    
    @IBAction func delete(sender: AnyObject?) {
        deleteSelection()
        snapConstructions = []
    }
    
// MARK: Display List Maintenance
    
    func addGraphic(graphic: Graphic)
    {
        displayList.append(graphic)
        undoManager?.prepareWithInvocationTarget(self).deleteGraphic(graphic)
        inspector?.beginInspection(graphic)
        needsDisplay = true
    }
    
    func addGraphics(graphics: [Graphic])
    {
        for g in graphics {
            displayList.append(g)
        }
        undoManager?.prepareWithInvocationTarget(self).deleteGraphics(graphics)
        needsDisplay = true
    }
    
    func deleteGraphics(graphics: [Graphic])
    {
        displayList = displayList.filter { !graphics.contains($0) }
        undoManager?.prepareWithInvocationTarget(self).addGraphics(graphics)
        needsDisplay = true
    }
    
    func deleteGraphic(graphic: Graphic)
    {
        displayList = displayList.filter { $0 != graphic }
        undoManager?.prepareWithInvocationTarget(self).addGraphic(graphic)
        needsDisplay = true
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
