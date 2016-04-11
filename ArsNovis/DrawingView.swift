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

class DrawingView: ZoomView, ParametricContextDelegate
{
    @IBOutlet var hintField: NSTextField?
    @IBOutlet var inspector: GraphicInspector?      { didSet { inspector?.view = self }}
    @IBOutlet var menuWindow: NSWindow!
    @IBOutlet var menuButton: NSButton!
    
    var document: ArsDocument?
    
    var context: CGContext!

    override var pageRect: CGRect? {
        if let rect = document?.page.pageRect {
            let size = rect.size * (100 / (document?.page.pageScale ?? 1.0))
            return CGRect(origin: rect.origin, size: size)
        } else {
            return nil
        }
    }
    
    var displayList: [Graphic] {
        get { return document?.displayList ?? [] }
        set { document?.displayList = newValue }
    }
    
    var selection: [Graphic] = [] {
        willSet {
            selection.forEach { $0.showHandles = false }
            willChangeValueForKey("parametricContext")
        }
        didSet {
            selection.forEach { $0.showHandles = true }
            if selection.count == 1 {
                inspector?.beginInspection(selection[0])
            } else {
                inspector?.removeAllSubviews()
            }
            didChangeValueForKey("parametricContext")
        }
    }
    
    var parametricContext: ParametricContext? {
        if selection.count == 1 {
            if let symbol = selection[0] as? GraphicSymbol {
                return symbol.parametricContext
            }
        }
        return document?.page.parametricContext
    }
    
    override var contentRect: CGRect {
        if displayList.count == 0 {
            return CGRect(x: 0, y: 0, width: 90 * 17, height: 90 * 11)
        } else {
            return displayList.reduce(CGRect(), combine: { return $0 + $1.bounds })
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
    
    var snapConstructions: [Graphic] = []
    
    var tool: GraphicTool = SelectTool() {
        didSet {
            tool.selectTool(self)
            selection = []
        }
    }
    
    var gridSnap: Bool      {
        get { return document?.layer.snapToGrid ?? false }
        set { document?.layer.snapToGrid = newValue }
    }
    
    var defaultSnapAngles = [
        CGPoint(length: 1.0, angle: PI / 6),
        CGPoint(length: 1.0, angle: PI / 4),
        CGPoint(length: 1.0, angle: PI / 3),
        CGPoint(length: 1.0, angle: 2 * PI / 3),
        CGPoint(length: 1.0, angle: 3 * PI / 4),
        CGPoint(length: 1.0, angle: 5 * PI / 6)
    ]
    
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
        registerForDraggedTypes([ELGraphicUTI])
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
        addCursorRect(visibleRect, cursor: tool.cursor())
    }
    
    func redrawConstruction() {
        if let construction = construction {
            let lineWidth = scaleFloat(construction.lineWidth)
            setNeedsDisplayInRect(construction.bounds.insetBy(dx: -lineWidth, dy: -lineWidth))
        }
    }

    func scaleFloat(f: CGFloat) -> CGFloat {
        return f / scale
    }
    
    func scaleFloatToDrawing(f: CGFloat) -> CGFloat {
        return f / (document?.page.pageScale ?? 1.0)
    }
    
// MARK: Drawing
    
    func massiveChange() {
        selection = []
        snapConstructions = []
        needsDisplay = true
    }
    
    func drawBorder(dirtyRect: CGRect) {
        if let pageRect = pageRect, let page = document?.page {
            let borderWidth = page.borderWidth / page.pageScale
            var outsideBorderRect = pageRect.insetBy(dx: (page.borderInset + page.leftBorderOffset / 2) / page.pageScale, dy: page.borderInset / page.pageScale)
            outsideBorderRect.origin.x += page.leftBorderOffset / 2 / page.pageScale
            let insideBorderRect = outsideBorderRect.insetBy(dx: page.borderWidth / page.pageScale, dy: page.borderWidth / page.pageScale)
            NSBezierPath.setDefaultLineWidth(2.0 / page.pageScale)
            NSBezierPath.strokeRect(insideBorderRect)
            NSBezierPath.setDefaultLineWidth(0.5 / page.pageScale)
            NSBezierPath.strokeRect(outsideBorderRect)
            NSBezierPath.strokeLineFromPoint(insideBorderRect.topLeft, toPoint: outsideBorderRect.topLeft)
            NSBezierPath.strokeLineFromPoint(insideBorderRect.bottomLeft, toPoint: outsideBorderRect.bottomLeft)
            NSBezierPath.strokeLineFromPoint(insideBorderRect.topRight, toPoint: outsideBorderRect.topRight)
            NSBezierPath.strokeLineFromPoint(insideBorderRect.bottomRight, toPoint: outsideBorderRect.bottomRight)
            let horizontalDivisions = Int(insideBorderRect.size.width / (page.gridSize / page.pageScale))
            let verticalDivisions = Int(insideBorderRect.size.height / (page.gridSize / page.pageScale))
            let horizontalGridSize = insideBorderRect.size.width / CGFloat(horizontalDivisions)
            let verticalGridSize = insideBorderRect.size.height / CGFloat(verticalDivisions)
            
            for i in 1 ..< horizontalDivisions {
                let x = CGFloat(i) * horizontalGridSize + insideBorderRect.left
                NSBezierPath.strokeLineFromPoint(CGPoint(x: x, y: insideBorderRect.top), toPoint: CGPoint(x: x, y: outsideBorderRect.top))
                NSBezierPath.strokeLineFromPoint(CGPoint(x: x, y: insideBorderRect.bottom), toPoint: CGPoint(x: x, y: outsideBorderRect.bottom))
            }
            
            let font = NSFont.systemFontOfSize(borderWidth * 0.8)
            let attributes = [NSFontAttributeName: font]

            for i in 0 ..< horizontalDivisions {
                let label = "\(i)" as NSString
                let labelWidth = label.sizeWithAttributes(attributes).width
                let x = CGFloat(i) * horizontalGridSize + insideBorderRect.left + horizontalGridSize / 2 - labelWidth / 2
                label.drawAtPoint(CGPoint(x: x, y: insideBorderRect.top + borderWidth * 0.1), withAttributes: attributes)
                label.drawAtPoint(CGPoint(x: x, y: outsideBorderRect.bottom + borderWidth * 0.1), withAttributes: attributes)
            }
            
            for i in 1 ..< verticalDivisions {
                let y = CGFloat(i) * verticalGridSize + insideBorderRect.bottom
                NSBezierPath.strokeLineFromPoint(CGPoint(x: outsideBorderRect.left, y: y), toPoint: CGPoint(x: insideBorderRect.left, y: y))
                NSBezierPath.strokeLineFromPoint(CGPoint(x: outsideBorderRect.right, y: y), toPoint: CGPoint(x: insideBorderRect.right, y: y))
            }
            
            let charLabels: [NSString] = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
            for i in 0 ..< verticalDivisions {
                let labelIndex = verticalDivisions - i - 1
                if labelIndex < charLabels.count {
                    let label = charLabels[labelIndex]
                    let labelSize = label.sizeWithAttributes(attributes)
                    let y = CGFloat(i) * verticalGridSize + insideBorderRect.bottom + verticalGridSize / 2 - labelSize.height / 2
                    label.drawAtPoint(CGPoint(x: outsideBorderRect.left + borderWidth / 2 - labelSize.width / 2, y: y), withAttributes: attributes)
                    label.drawAtPoint(CGPoint(x: insideBorderRect.right + borderWidth / 2 - labelSize.width / 2, y: y), withAttributes: attributes)
                }
            }
        }
    }
        
    func drawGridInRect(dirtyRect: CGRect, layer: ArsLayer)
    {
        if let document = document where NSGraphicsContext.currentContextDrawingToScreen() {
            let gridSize = layer.minorGrid / document.page.pageScale
            let divsPerMajor = round(layer.majorGrid / document.layer.minorGrid)
            let xs = floor((dirtyRect.origin.x - gridSize) / gridSize) * gridSize
            let ys = floor((dirtyRect.origin.y - gridSize) / gridSize) * gridSize
            let top = dirtyRect.origin.y + dirtyRect.size.height + gridSize
            let bottom = dirtyRect.origin.y - gridSize
            let left = dirtyRect.origin.x - gridSize
            let right = dirtyRect.origin.x + dirtyRect.size.width + gridSize
            
            NSColor.blueColor().colorWithAlphaComponent(0.5).set()
            var x = xs
            while x <= right {
                let linewidth = CGFloat(fmod((x / gridSize), divsPerMajor) == 0 ? 0.25 : 0.1)
                NSBezierPath.setDefaultLineWidth(scaleFloat(linewidth))
                NSBezierPath.strokeLineFromPoint(CGPoint(x: x, y: top), toPoint: CGPoint(x: x, y: bottom))
                x += gridSize
            }
            
            var y = ys
            while y <= top {
                let linewidth = CGFloat(fmod((y / gridSize), divsPerMajor) == 0 ? 0.25 : 0.1)
                NSBezierPath.setDefaultLineWidth(scaleFloat(linewidth))
                NSBezierPath.strokeLineFromPoint(CGPoint(x: left, y: y), toPoint: CGPoint(x: right, y: y))
                y += gridSize
            }
        }
    }
    
    func drawArsLayer(layer: ArsLayer) {
        if layer.enabled {
            CGContextSaveGState(context)
            CGContextScaleCTM(context, layer.layerScale, layer.layerScale)
            for g in layer.contents {
                if needsToDrawRect(g.bounds) {
                    g.drawInView(self)
                }
            }
            CGContextRestoreGState(context)
        }
    }
    
    override func drawRect(dirtyRect: CGRect)
    {
        context = NSGraphicsContext.currentContext()?.CGContext
        
        NSEraseRect(dirtyRect)
        drawBorder(dirtyRect)
        if let document = document {
            if document.layer.gridMode != .Never {
                drawGridInRect(dirtyRect, layer: document.layer)
            }
            
            for layerIndex in 0 ..< document.layers.count {
                if layerIndex != document.currentLayer {
                    let layer = document.layers[layerIndex]
                    
                    if layer.gridModeAlways {
                        drawGridInRect(dirtyRect, layer: layer)
                    }
                    drawArsLayer(document.layers[layerIndex])
                }
            }
        }
        
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
    
    func parametricContextDidUpdate(parametricContext: ParametricContext) {
        needsDisplay = true
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
        
        if found != nil {           // prefer already selected objects
            return found
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
    
    func snapToGrid(point: CGPoint) -> SnapResult?
    {
        var point = point
        let grid = document?.layer.minorGrid ?? 0.1
        
        if gridSnap {
            point.x = round(point.x / grid) * grid
            point.y = round(point.y / grid) * grid
        
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
                        addSnapConstructionsForPoint(snap.location, reference: [g])
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
                                addSnapConstructionsForPoint(cp, reference: [a, b])
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
    
    func addSnapConstructionsForPoint(p: CGPoint, reference: [Graphic], includeAngles: Bool = false) {
        let smallDistance = scaleFloat(10)
        let horizontal = ConstructionLine(origin: p, vector: CGPoint(x: 1, y: 0), reference: reference)
        let vertical = ConstructionLine(origin: p, vector: CGPoint(x: 0, y: 1), reference: reference)
        
        snapConstructions = snapConstructions.filter {
            if let line = $0 as? ConstructionLine {
                if line.angle == PI / 2 && abs(line.origin.x - p.x) < smallDistance
                    || line.angle == 0 && abs(line.origin.y - p.y) < smallDistance
                    || line.ref == reference && line.origin.distanceToPoint(p) < smallDistance {
                        return false
                }
            }
            return true
        }
        
        var snaps = [horizontal, vertical]
        
        if includeAngles {
            snaps += defaultSnapAngles.map { return ConstructionLine(origin: p, vector: $0) }
        }
        addSnapConstructions(snaps)
    }
    
    func addSnapConstructions(snaps: [Graphic]) {
        snapConstructions.insertContentsOf(snaps, at: 0)

        while snapConstructions.count > 10 {
            let old = snapConstructions.removeLast()
            if old.isActive {
                setNeedsDisplayInRect(old.bounds)
            }
        }
    }
    
    func removeSnapConstructionsForReference(ref: Graphic?) {
        if let ref = ref {
            snapConstructions = snapConstructions.filter { return !$0.ref.contains(ref) }
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
        //tool.cursor().pop()
    }
    
// MARK: Drag and Drop
    
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        sender.enumerateDraggingItemsWithOptions(.ClearNonenumeratedImages, forView: self, classes: [Graphic.self], searchOptions: [:]) { (item, n, stop) in
            if let graphic = item.item as? Graphic {
                let fr = item.draggingFrame
                let image = NSImage(size: CGSize(width: 1, height: 1))
                item.setDraggingFrame(fr, contents: image)
                self.construction = graphic
                let windowLocation = sender.draggingLocation()
                let location = self.convertPoint(windowLocation, fromView: nil)
                self.construction?.moveOriginTo(location)
                self.needsDisplay = true
            }
        }
        return NSDragOperation.Copy
    }
    
    override func draggingUpdated(sender: NSDraggingInfo) -> NSDragOperation {
        let windowLocation = sender.draggingLocation()
        let location = self.convertPoint(windowLocation, fromView: nil)
        construction?.moveOriginTo(location)
        needsDisplay = true
       return NSDragOperation.Copy
    }
    
    override func draggingExited(sender: NSDraggingInfo?) {
        self.construction = nil
        needsDisplay = true
    }
    
    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        if construction != nil {
            addConstruction()
        }
        return true
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
        case "\u{1b}":
            if construction != nil || selection.count > 0 {
                tool.escape(self)
            } else {
                setSelectTool(self)
            }
            needsDisplay = true
        case "b":
            setBezierTool(self)
        case "e":
            setElipseTool(self)
        case "g":
            gridSnap = !gridSnap
        case "l":
            setLineTool(self)
        case "r":
            setRectTool(self)
        case "a":
            setArc3Tool(self)
        case "s":
            setSelectTool(self)
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
    
    @IBAction func menuButtonPushed(sender: NSView) {
        menuWindow.backgroundColor = NSColor.clearColor()
        menuWindow.opaque = false
        menuWindow.styleMask = NSBorderlessWindowMask
        let menuWindowFrame = sender.convertRect(sender.bounds, toView: nil)
        if let window = window {
            let menuFrame = window.convertRectToScreen(menuWindowFrame)
            let menuOrigin = CGPoint(x: menuFrame.origin.x, y: menuFrame.origin.y - menuWindow.frame.size.height)
            menuWindow.setFrameOrigin(menuOrigin)
        }
        menuWindow.orderFront(sender)
    }
    
    @IBAction func setLineTool(sender: AnyObject?) {
        tool = LineTool()
        menuButton.image = NSImage(named: "LineTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setWallTool(sender: AnyObject?) {
        tool = WallTool()
        menuButton.image = NSImage(named: "WallTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setOpeningTool(sender: AnyObject?) {
        tool = OpeningTool()
        menuButton.image = NSImage(named: "OpeningTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setRectTool(sender: AnyObject?) {
        tool = RectTool()
        menuButton.image = NSImage(named: "RectTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setArc3Tool(sender: AnyObject?) {
        tool = Arc3PtTool()
        menuButton.image = NSImage(named: "Arc3Point")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setArcCenterTool(sender: AnyObject?) {
        tool = ArcCenterTool()
        menuButton.image = NSImage(named: "ArcFromCenter")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setBezierTool(sender: AnyObject?) {
        tool = BezierTool()
        menuButton.image = NSImage(named: "BezierTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setElipseTool(sender: AnyObject?) {
        tool = ElipseTool()
        menuButton.image = NSImage(named: "CornerCircleTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setCenterElipseTool(sender: AnyObject?) {
        tool = CenterElipseTool()
        menuButton.image = NSImage(named: "CenterCircleTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setTrimToTool(sender: AnyObject?) {
        tool = TrimToTool()
        menuButton.image = NSImage(named: "TrimTo")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setTrimFromTool(sender: AnyObject?) {
        tool = TrimFromTool()
        menuButton.image = NSImage(named: "TrimFrom")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setBreakTool(sender: AnyObject?) {
        tool = BreakAtTool()
        menuButton.image = NSImage(named: "BreakAt")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setJoinTool(sender: AnyObject?) {
        tool = JoinTool()
        menuButton.image = NSImage(named: "CornerTrim")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setLinearDimensionTool(sender: AnyObject?) {
        tool = LinearDimensionTool()
        menuButton.image = NSImage(named: "LinearDim")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setHorizontalDimensionTool(sender: AnyObject?) {
        tool = HorizontalDimensionTool()
        menuButton.image = NSImage(named: "HorizontalDim")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setVerticalDimensionTool(sender: AnyObject?) {
        tool = VerticalDimensionTool()
        menuButton.image = NSImage(named: "VerticalDim")
        menuWindow.orderOut(self)
        window?.invalidateCursorRectsForView(self)
    }
    
    @IBAction func setSelectTool(sender: AnyObject?) {
        tool = SelectTool()
        menuButton.image = NSImage(named: "SelectTool")
        menuWindow.orderOut(self)
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
    
    @IBAction func group(sender: AnyObject?) {
        if selection.count > 1 {
            let newGroup = GroupGraphic(contents: selection)
            deleteSelection()
            addGraphic(newGroup)
            selection = [newGroup]
        }
    }
    
    @IBAction func unGroup(sender: AnyObject?) {
        var newSelection: [Graphic] = []
        
        for g in selection {
            if let g = g as? GroupGraphic {
                deleteGraphic(g)
                g.unlink()
                addGraphics(g.contents)
                newSelection.appendContentsOf(g.contents)
            } else {
                newSelection.append(g)
            }
        }
        selection = newSelection
    }
    
    @IBAction func rotateSelected(sender: AnyObject?) {
        if selection.count > 0 {
            let g = GroupGraphic(contents: selection)
            let center = g.centerOfPoints()
            g.rotateAroundPoint(center, angle: PI / 2)
        }
        needsDisplay = true
    }
    
    @IBAction func flipSelectedHorizontal(sender: AnyObject?) {
        if selection.count > 0 {
            let g = GroupGraphic(contents: selection)
            let center = g.centerOfPoints()
            g.flipHorizontalAroundPoint(center)
        }
        needsDisplay = true
    }
    
    @IBAction func flipSelectedVertical(sender: AnyObject?) {
        if selection.count > 0 {
            let g = GroupGraphic(contents: selection)
            let center = g.centerOfPoints()
            g.flipVerticalAroundPoint(center)
        }
        needsDisplay = true
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
        graphics.forEach { $0.unlink() }
        needsDisplay = true
    }
    
    func deleteGraphic(graphic: Graphic)
    {
        displayList = displayList.filter { $0 != graphic }
        undoManager?.prepareWithInvocationTarget(self).addGraphic(graphic)
        graphic.unlink()
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
    
// MARK: Printing Support
    
    var perPageSize: CGSize {
        if let document = document {
            var size = document.printInfo.paperSize
            size = size * (1.0 / 72.0)          // convert to inches
            size = size * (100.0 / document.page.pageScale)
            return size
        } else {
            return CGSize(width: 100, height: 100)
        }
    }
    
    func getPages() -> (Int, Int) {
        if let pageRect = pageRect {
            var horizontalPages = Int(pageRect.size.width / perPageSize.width)
            if CGFloat(horizontalPages) * perPageSize.width < pageRect.size.width {
                horizontalPages += 1
            }
            var verticalPages = Int(pageRect.size.height / perPageSize.height)
            if CGFloat(verticalPages) * perPageSize.height < pageRect.size.height {
                verticalPages += 1
            }
            return (horizontalPages, verticalPages)
        }
        return (1, 1)
    }
    
    override func knowsPageRange(range: NSRangePointer) -> Bool {
        let (h, v) = getPages()
        range.memory.location = 1
        range.memory.length = h * v
        return true
    }
    
    override func rectForPage(page: Int) -> CGRect {
        let pp = page - 1
        let (hm, _) = getPages()
        let v = pp / hm
        let h = pp - v * hm
        let thisPageOrigin = bounds.origin + CGPoint(x: CGFloat(h) * perPageSize.width, y: CGFloat(v) * perPageSize.height)
        let thisPageRect = CGRect(origin: thisPageOrigin, size: perPageSize)
        
        return thisPageRect
    }
}
