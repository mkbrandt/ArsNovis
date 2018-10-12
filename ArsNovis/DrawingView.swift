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
    @IBOutlet var parametricItemView: ParametricItemView!
    
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
            selection.forEach { $0.selected = false }
            willChangeValue(forKey: "parametricContext")
            willChangeValue(forKey: "selection")
        }
        didSet {
            selection.forEach { $0.selected = true }
            if selection.count == 0 {
                inspector?.removeAllSubviews()
                NSFontManager.shared().setSelectedFont(applicationDefaults.textFont, isMultiple: false)
            } else if selection.count == 1 {
                inspector?.beginInspection(selection[0])
            } else {
                inspector?.removeAllSubviews()
            }
            didChangeValue(forKey: "parametricContext")
            didChangeValue(forKey: "selection")
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
        register(forDraggedTypes: [ELGraphicUTI])
    }
    
    override func becomeFirstResponder() -> Bool
    {
        return true
    }
    
    override func updateTrackingAreas()
    {
        let options: NSTrackingAreaOptions = [.mouseMoved, .mouseEnteredAndExited, .activeAlways]
        
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
            setNeedsDisplay(construction.bounds.insetBy(dx: -lineWidth, dy: -lineWidth))
        }
    }

    func scaleFloat(_ f: CGFloat) -> CGFloat {
        return f / scale
    }
    
    func scaleFloatToDrawing(_ f: CGFloat) -> CGFloat {
        return f / (document?.page.pageScale ?? 1.0)
    }
    
// MARK: Drawing
    
    func massiveChange() {
        selection = []
        snapConstructions = []
        needsDisplay = true
    }
    
    func drawBorder(_ dirtyRect: CGRect) {
        if let pageRect = pageRect, let page = document?.page {
            let borderWidth = page.borderWidth / page.pageScale
            var outsideBorderRect = pageRect.insetBy(dx: (page.borderInset + page.leftBorderOffset / 2) / page.pageScale, dy: page.borderInset / page.pageScale)
            outsideBorderRect.origin.x += page.leftBorderOffset / 2 / page.pageScale
            let insideBorderRect = outsideBorderRect.insetBy(dx: page.borderWidth / page.pageScale, dy: page.borderWidth / page.pageScale)
            NSBezierPath.setDefaultLineWidth(2.0 / page.pageScale)
            NSBezierPath.stroke(insideBorderRect)
            NSBezierPath.setDefaultLineWidth(0.5 / page.pageScale)
            NSBezierPath.stroke(outsideBorderRect)
            NSBezierPath.strokeLine(from: insideBorderRect.topLeft, to: outsideBorderRect.topLeft)
            NSBezierPath.strokeLine(from: insideBorderRect.bottomLeft, to: outsideBorderRect.bottomLeft)
            NSBezierPath.strokeLine(from: insideBorderRect.topRight, to: outsideBorderRect.topRight)
            NSBezierPath.strokeLine(from: insideBorderRect.bottomRight, to: outsideBorderRect.bottomRight)
            let horizontalDivisions = Int(insideBorderRect.size.width / (page.gridSize / page.pageScale))
            let verticalDivisions = Int(insideBorderRect.size.height / (page.gridSize / page.pageScale))
            let horizontalGridSize = insideBorderRect.size.width / CGFloat(horizontalDivisions)
            let verticalGridSize = insideBorderRect.size.height / CGFloat(verticalDivisions)
            
            for i in 1 ..< horizontalDivisions {
                let x = CGFloat(i) * horizontalGridSize + insideBorderRect.left
                NSBezierPath.strokeLine(from: CGPoint(x: x, y: insideBorderRect.top), to: CGPoint(x: x, y: outsideBorderRect.top))
                NSBezierPath.strokeLine(from: CGPoint(x: x, y: insideBorderRect.bottom), to: CGPoint(x: x, y: outsideBorderRect.bottom))
            }
            
            let font = NSFont.systemFont(ofSize: borderWidth * 0.8)
            let attributes = [NSFontAttributeName: font]

            for i in 0 ..< horizontalDivisions {
                let label = "\(i)" as NSString
                let labelWidth = label.size(withAttributes: attributes).width
                let x = CGFloat(i) * horizontalGridSize + insideBorderRect.left + horizontalGridSize / 2 - labelWidth / 2
                label.draw(at: CGPoint(x: x, y: insideBorderRect.top + borderWidth * 0.1), withAttributes: attributes)
                label.draw(at: CGPoint(x: x, y: outsideBorderRect.bottom + borderWidth * 0.1), withAttributes: attributes)
            }
            
            for i in 1 ..< verticalDivisions {
                let y = CGFloat(i) * verticalGridSize + insideBorderRect.bottom
                NSBezierPath.strokeLine(from: CGPoint(x: outsideBorderRect.left, y: y), to: CGPoint(x: insideBorderRect.left, y: y))
                NSBezierPath.strokeLine(from: CGPoint(x: outsideBorderRect.right, y: y), to: CGPoint(x: insideBorderRect.right, y: y))
            }
            
            let charLabels: [NSString] = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
            for i in 0 ..< verticalDivisions {
                let labelIndex = verticalDivisions - i - 1
                if labelIndex < charLabels.count {
                    let label = charLabels[labelIndex]
                    let labelSize = label.size(withAttributes: attributes)
                    let y = CGFloat(i) * verticalGridSize + insideBorderRect.bottom + verticalGridSize / 2 - labelSize.height / 2
                    label.draw(at: CGPoint(x: outsideBorderRect.left + borderWidth / 2 - labelSize.width / 2, y: y), withAttributes: attributes)
                    label.draw(at: CGPoint(x: insideBorderRect.right + borderWidth / 2 - labelSize.width / 2, y: y), withAttributes: attributes)
                }
            }
        }
    }
        
    func drawGridInRect(_ dirtyRect: CGRect, layer: ArsLayer)
    {
        if let document = document where NSGraphicsContext.currentContextDrawingToScreen() {
            let gridSize = layer.minorGrid / document.page.pageScale
            let majorGridSize = layer.majorGrid / document.page.pageScale
            let drawMinor = gridSize * scale > 4
            let drawMajor = majorGridSize * scale > 4
            let divsPerMajor = round(layer.majorGrid / document.layer.minorGrid)
            let xs = floor((dirtyRect.origin.x - gridSize) / gridSize) * gridSize
            let ys = floor((dirtyRect.origin.y - gridSize) / gridSize) * gridSize
            let top = dirtyRect.origin.y + dirtyRect.size.height + gridSize
            let bottom = dirtyRect.origin.y - gridSize
            let left = dirtyRect.origin.x - gridSize
            let right = dirtyRect.origin.x + dirtyRect.size.width + gridSize
            
            NSColor.blue().withAlphaComponent(0.5).set()
            var x = xs
            while x <= right {
                let isMajor = fmod((x / gridSize), divsPerMajor) == 0
                let linewidth = CGFloat(isMajor ? 0.25 : 0.1)
                if drawMajor && isMajor || drawMinor {
                    NSBezierPath.setDefaultLineWidth(scaleFloat(linewidth))
                    NSBezierPath.strokeLine(from: CGPoint(x: x, y: top), to: CGPoint(x: x, y: bottom))
                }
                x += gridSize
            }
            
            var y = ys
            while y <= top {
                let isMajor = fmod((y / gridSize), divsPerMajor) == 0
                let linewidth = CGFloat(isMajor ? 0.25 : 0.1)
                if drawMajor && isMajor || drawMinor {
                    NSBezierPath.setDefaultLineWidth(scaleFloat(linewidth))
                    NSBezierPath.strokeLine(from: CGPoint(x: left, y: y), to: CGPoint(x: right, y: y))
                }
                y += gridSize
            }
        }
    }
    
    func drawArsLayer(_ layer: ArsLayer) {
        if layer.enabled {
            context.saveGState()
            context.scale(x: layer.layerScale, y: layer.layerScale)
            for g in layer.contents {
                if needsToDraw(g.bounds) {
                    g.drawInView(self)
                }
            }
            context.restoreGState()
        }
    }
    
    override func draw(_ dirtyRect: CGRect)
    {
        context = NSGraphicsContext.current()?.cgContext
        
        NSEraseRect(dirtyRect)
        drawBorder(dirtyRect)
        if let document = document {
            if document.layer.gridMode != .never {
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
            if needsToDraw(g.bounds)
            {
                g.drawInView(self)
            }
        }
        
        for g in snapConstructions {
            if needsToDraw(g.bounds)
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
            NSColor.darkGray().set()
            path.stroke()
        }
        
        drawSnappedCursor()
        //super.drawRect(dirtyRect)
    }
    
    func parametricContextDidUpdate(_ parametricContext: ParametricContext) {
        needsDisplay = true
    }
    
    func setDrawingHint(_ hint: String)
    {
        hintField?.stringValue = hint
    }
    
    func closestGraphicToPoint(_ point: CGPoint, within distance: CGFloat) -> Graphic?
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
    
    func selectObjectsInRect(_ rect: CGRect)
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
            let textSize = snap.cursorText.size(withAttributes: nil)
            let textRect = CGRect(origin: tp, size: convert(textSize, from: nil))
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
            
            path.move(to: p + xx + yy)
            path.line(to: p + 3 * (xx + yy))
            path.move(to: p + xx - yy)
            path.line(to: p + 3 * (xx - yy))
            path.move(to: p - (xx + yy))
            path.line(to: p - 3 * (xx + yy))
            path.move(to: p - (xx - yy))
            path.line(to: p - 3 * (xx - yy))
            NSColor.black.set()
            path.lineWidth = scaleFloat(1)
            path.stroke()
            let fsize = scaleFloat(12)
            let textFont = NSFont.systemFont(ofSize: fsize)
            snap.cursorText.draw(at: p + xx + yy, withAttributes: [NSAttributedStringKey.font: textFont])
        }
    }
    
    func snapToGrid(_ point: CGPoint) -> SnapResult?
    {
        var point = point
        let grid = document?.layer.minorGrid ?? 0.1
        
        if gridSnap {
            point.x = round(point.x / grid) * grid
            point.y = round(point.y / grid) * grid
        
            return SnapResult(location: point, type: .grid)
        }
        return nil
    }
    
    func snapToObjects(_ p: CGPoint, snapSelected: Bool = false) -> SnapResult? {
        if optionKeyDown {
            return nil
        }
        SnapRadius = scaleFloat(RawSnapRadius)
        var snappedObjects: [Graphic] = []
        var result: SnapResult?
        
        for g in snapConstructions {
            if g.isActive {
                setNeedsDisplay(g.bounds)
            }
            g.isActive = false
        }
        
        for g in snapConstructions {
            if let snap = g.snapCursor(p) {
                g.isActive = true
                setNeedsDisplay(g.bounds)
                result = snap
                snappedObjects.append(g)
            }
        }
        
        for g in displayList {
            if snapSelected || !selection.contains(g) {
                if let snap = g.snapCursor(p) {
                    if snap.type == .endPoint || snap.type == .center {
                        addSnapConstructionsForPoint(snap.location, reference: [g])
                    }
                    result = snap
                    snappedObjects.append(g)
                }
            }
        }
        
        if let snap = result, snap.type == .on || snap.type == .align {
            for i in 0 ..< snappedObjects.count {
                let a = snappedObjects.remove(at: i)
                for b in snappedObjects {
                    if let cp = a.closestIntersectionWithGraphic(b, toPoint: p) {
                        if cp.distanceToPoint(p) < SnapRadius {
                            if !a.isConstruction && !b.isConstruction {
                                addSnapConstructionsForPoint(cp, reference: [a, b])
                            }
                            result = SnapResult(location: cp, type: .intersection)
                            break
                        }
                    }
                }
                snappedObjects.insert(a, at: i)
            }
        }
        
        return result
    }
    
    func addSnapConstructionsForPoint(_ p: CGPoint, reference: [Graphic], includeAngles: Bool = false) {
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
    
    func addSnapConstructions(_ snaps: [Graphic]) {
        snapConstructions.insert(contentsOf: snaps, at: 0)

        while snapConstructions.count > 10 {
            let old = snapConstructions.removeLast()
            if old.isActive {
                setNeedsDisplay(old.bounds)
            }
        }
    }
    
    func removeSnapConstructionsForReference(_ ref: Graphic?) {
        if let ref = ref {
            snapConstructions = snapConstructions.filter { return !$0.ref.contains(ref) }
        }
    }

// MARK: Mouse Handling
    
    var mouseClickCount = 0
    
    override func mouseDown(with theEvent: NSEvent)
    {
        var p = convert(theEvent.locationInWindow, from: nil)
        
        mouseClickCount = theEvent.clickCount
        
        snappedCursor = snapToObjects(p) ?? snapToGrid(p)
        if let snap = snappedCursor {
            p = snap.location
        }
        tool.mouseDown(p, view: self)
    }
    
    override func mouseDragged(with theEvent: NSEvent)
    {
        var p = convert(theEvent.locationInWindow, from: nil)
        
        setNeedsDisplay(cursorSnapRect)
        snappedCursor = snapToObjects(p) ?? snapToGrid(p)
        if let snap = snappedCursor {
            p = snap.location
        }
        setNeedsDisplay(cursorSnapRect)
        tool.mouseDragged(p, view: self)
    }
    
    override func mouseMoved(with theEvent: NSEvent)
    {
        var p = convert(theEvent.locationInWindow, from: nil)
        
        setNeedsDisplay(cursorSnapRect)
        snappedCursor = snapToObjects(p) ?? snapToGrid(p)
        if let snap = snappedCursor {
            p = snap.location
        }
        zoomCenter = p
        setNeedsDisplay(cursorSnapRect)
        tool.mouseMoved(p, view: self)
        self.needsDisplay = true
    }
    
    override func mouseUp(with theEvent: NSEvent)
    {
        var p = convert(theEvent.locationInWindow, from: nil)
        
        setNeedsDisplay(cursorSnapRect)
        snappedCursor = snapToObjects(p) ?? snapToGrid(p) ?? snapToObjects(p, snapSelected: true)
        if let snap = snappedCursor {
            p = snap.location
        }
        setNeedsDisplay(cursorSnapRect)
        tool.mouseUp(p, view: self)
    }
    
    override func mouseEntered(with theEvent: NSEvent)
    {
        window!.makeFirstResponder(self)
    }
    
    override func mouseExited(with theEvent: NSEvent)
    {
        //tool.cursor().pop()
    }
    
    override func rightMouseDown(with theEvent: NSEvent) {
        let p = convert(theEvent.locationInWindow, from: nil)
        let fr = window?.convertToScreen(CGRect(origin: theEvent.locationInWindow, size: CGSize(width: 200, height: 200)))
        
        if let g = closestGraphicToPoint(p, within: SnapRadius) {
            parametricItemView.graphic = g
            parametricItemView.window?.setFrameOrigin(fr!.origin)
            if let window = parametricItemView.window {
                window.backgroundColor = NSColor.clear
                window.isOpaque = false
                window.styleMask = NSBorderlessWindowMask
                window.setFrameOrigin(fr!.origin)
                window.orderFront(self)
            }
        }
    }
    
// MARK: Drag and Drop
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.enumerateDraggingItems(.clearNonenumeratedImages, for: self, classes: [Graphic.self], searchOptions: [:]) { (item, n, stop) in
            if let graphic = item.item as? Graphic {
                let fr = item.draggingFrame
                let image = NSImage(size: CGSize(width: 1, height: 1))
                item.setDraggingFrame(fr, contents: image)
                self.construction = graphic
                let windowLocation = sender.draggingLocation()
                let location = self.convert(windowLocation, from: nil)
                self.construction?.moveOriginTo(location)
                self.needsDisplay = true
            }
        }
        return NSDragOperation.copy
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let windowLocation = sender.draggingLocation()
        let location = self.convert(windowLocation, from: nil)
        construction?.moveOriginTo(location)
        needsDisplay = true
       return NSDragOperation.copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        self.construction = nil
        needsDisplay = true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if construction != nil {
            addConstruction()
        }
        return true
    }

// MARK: Keyboard Handling
    
    override func keyDown(_ theEvent: NSEvent)
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
        window?.invalidateCursorRects(for: self)
    }
    
    override func flagsChanged(_ theEvent: NSEvent) {
        let flags = theEvent.modifierFlags
        
        controlKeyDown = flags.contains(.control)
        shiftKeyDown = flags.contains(.shift)
        optionKeyDown = flags.contains(.option)
        commandKeyDown = flags.contains(.command)
        super.flagsChanged(theEvent)
    }
    
// MARK: IB Actions
    
    @IBAction func menuButtonPushed(_ sender: NSView) {
        menuWindow.backgroundColor = NSColor.clear()
        menuWindow.isOpaque = false
        menuWindow.styleMask = NSBorderlessWindowMask
        let menuWindowFrame = sender.convert(sender.bounds, to: nil)
        if let window = window {
            let menuFrame = window.convertToScreen(menuWindowFrame)
            let menuOrigin = CGPoint(x: menuFrame.origin.x, y: menuFrame.origin.y - menuWindow.frame.size.height)
            menuWindow.setFrameOrigin(menuOrigin)
        }
        menuWindow.orderFront(sender)
    }
    
    @IBAction func setLineTool(_ sender: AnyObject?) {
        tool = LineTool()
        menuButton.image = NSImage(named: "LineTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setWallTool(_ sender: AnyObject?) {
        tool = WallTool()
        menuButton.image = NSImage(named: "WallTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setOpeningTool(_ sender: AnyObject?) {
        tool = OpeningTool()
        menuButton.image = NSImage(named: "OpeningTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setRectTool(_ sender: AnyObject?) {
        tool = RectTool()
        menuButton.image = NSImage(named: "RectTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setCenterRectTool(_ sender: AnyObject?) {
        tool = CenterRectTool()
        menuButton.image = NSImage(named: "CenterRectTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setArc3Tool(_ sender: AnyObject?) {
        tool = Arc3PtTool()
        menuButton.image = NSImage(named: "Arc3Point")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setArcCenterTool(_ sender: AnyObject?) {
        tool = ArcCenterTool()
        menuButton.image = NSImage(named: "ArcFromCenter")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setBezierTool(_ sender: AnyObject?) {
        tool = BezierTool()
        menuButton.image = NSImage(named: "BezierTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setElipseTool(_ sender: AnyObject?) {
        tool = ElipseTool()
        menuButton.image = NSImage(named: "ElipseTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setCenterElipseTool(_ sender: AnyObject?) {
        tool = CenterElipseTool()
        menuButton.image = NSImage(named: "CenterElipseTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setRadiusCircleTool(_ sender: AnyObject?) {
        tool = RadiusCircleTool()
        menuButton.image = NSImage(named: "CenterCircleTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setDiameterCircleTool(_ sender: AnyObject?) {
        tool = DiameterCircleTool()
        menuButton.image = NSImage(named: "CornerCircleTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setTrimToTool(_ sender: AnyObject?) {
        tool = TrimToTool()
        menuButton.image = NSImage(named: "TrimTo")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setTrimFromTool(_ sender: AnyObject?) {
        tool = TrimFromTool()
        menuButton.image = NSImage(named: "TrimFrom")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setBreakTool(_ sender: AnyObject?) {
        tool = BreakAtTool()
        menuButton.image = NSImage(named: "BreakAt")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setJoinTool(_ sender: AnyObject?) {
        tool = JoinTool()
        menuButton.image = NSImage(named: "CornerTrim")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setLinearDimensionTool(_ sender: AnyObject?) {
        tool = LinearDimensionTool()
        menuButton.image = NSImage(named: "LinearDim")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setHorizontalDimensionTool(_ sender: AnyObject?) {
        tool = HorizontalDimensionTool()
        menuButton.image = NSImage(named: "HorizontalDim")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setVerticalDimensionTool(_ sender: AnyObject?) {
        tool = VerticalDimensionTool()
        menuButton.image = NSImage(named: "VerticalDim")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setTextTool(_ sender: AnyObject?) {
        tool = TextTool()
        menuButton.image = NSImage(named: "TextTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func setSelectTool(_ sender: AnyObject?) {
        tool = SelectTool()
        menuButton.image = NSImage(named: "SelectTool")
        menuWindow.orderOut(self)
        window?.invalidateCursorRects(for: self)
    }
    
    @IBAction func cut(_ sender: AnyObject?) {
        copy(sender)
        delete(sender)
    }
    
    @IBAction func copy(_ sender: AnyObject?) {
        let pasteBoard = NSPasteboard.general()
        
        pasteBoard.clearContents()
        pasteBoard.writeObjects(selection)
        snapConstructions = []
    }
    
    @IBAction func paste(_ sender: AnyObject?) {
        let pasteBoard = NSPasteboard.general()
        let classes = [Graphic.self]
        if pasteBoard.canReadObject(forClasses: classes, options: [:]) {
            if let graphics = pasteBoard.readObjects(forClasses: [Graphic.self], options:[:]) as? [Graphic] {
                addGraphics(graphics)
                selection = graphics
            }
        }
        snapConstructions = []
    }
    
    @IBAction override func selectAll(_ sender: AnyObject?) {
        selection = displayList
    }
    
    @IBAction func delete(_ sender: AnyObject?) {
        deleteSelection()
        snapConstructions = []
    }
    
    @IBAction func group(_ sender: AnyObject?) {
        if selection.count > 1 {
            let newGroup = GroupGraphic(contents: selection)
            deleteSelection()
            addGraphic(newGroup)
            selection = [newGroup]
        }
    }
    
    @IBAction func unGroup(_ sender: AnyObject?) {
        var newSelection: [Graphic] = []
        
        for g in selection {
            if let g = g as? GroupGraphic {
                deleteGraphic(g)
                g.unlink()
                addGraphics(g.contents)
                newSelection.append(contentsOf: g.contents)
            } else {
                newSelection.append(g)
            }
        }
        selection = newSelection
    }
    
    @IBAction func rotateSelected(_ sender: AnyObject?) {
        if selection.count > 0 {
            let g = GroupGraphic(contents: selection)
            let center = g.centerOfPoints()
            g.rotateAroundPoint(center, angle: PI / 2)
        }
        needsDisplay = true
    }
    
    @IBAction func flipSelectedHorizontal(_ sender: AnyObject?) {
        if selection.count > 0 {
            let g = GroupGraphic(contents: selection)
            let center = g.centerOfPoints()
            g.flipHorizontalAroundPoint(center)
        }
        needsDisplay = true
    }
    
    @IBAction func flipSelectedVertical(_ sender: AnyObject?) {
        if selection.count > 0 {
            let g = GroupGraphic(contents: selection)
            let center = g.centerOfPoints()
            g.flipVerticalAroundPoint(center)
        }
        needsDisplay = true
    }
    
    override func changeFont(_ sender: AnyObject?) {
        let fontManager = NSFontManager.shared()
        if selection.count == 0 {
            applicationDefaults.textFont = fontManager.convert(applicationDefaults.textFont)
        }
        selection.forEach {
            if let tg = $0 as? TextGraphic {
                tg.font = fontManager.convert(tg.font)
            } else if let dg = $0 as? LinearDimension {
                dg.font = fontManager.convert(dg.font)
            }
        }
        needsDisplay = true
    }
    
    func changeAttributes(_ sender: AnyObject?) {
        let fontManager = NSFontManager.shared()
        selection.forEach { g in
            let attr = fontManager.convertAttributes([NSForegroundColorAttributeName: g.lineColor])
            g.lineColor = attr[NSForegroundColorAttributeName] as? NSColor ?? g.lineColor
        }
        needsDisplay = true
    }
    
// MARK: Display List Maintenance
    
    func addGraphic(_ graphic: Graphic)
    {
        displayList.append(graphic)
        undoManager?.prepare(withInvocationTarget: self).deleteGraphic(graphic)
        inspector?.beginInspection(graphic)
        needsDisplay = true
    }
    
    func addGraphics(_ graphics: [Graphic])
    {
        for g in graphics {
            displayList.append(g)
        }
        undoManager?.prepare(withInvocationTarget: self).deleteGraphics(graphics)
        needsDisplay = true
    }
    
    func deleteGraphics(_ graphics: [Graphic])
    {
        displayList = displayList.filter { !graphics.contains($0) }
        undoManager?.prepare(withInvocationTarget: self).addGraphics(graphics)
        graphics.forEach { $0.unlink() }
        needsDisplay = true
    }
    
    func deleteGraphic(_ graphic: Graphic)
    {
        displayList = displayList.filter { $0 != graphic }
        undoManager?.prepare(withInvocationTarget: self).addGraphic(graphic)
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
    
    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        let (h, v) = getPages()
        range.pointee.location = 1
        range.pointee.length = h * v
        return true
    }
    
    
    override func rectForPage(_ page: Int) -> CGRect {
        let pp = page - 1
        let (hm, _) = getPages()
        let v = pp / hm
        let h = pp - v * hm
        let thisPageOrigin = bounds.origin + CGPoint(x: CGFloat(h) * perPageSize.width, y: CGFloat(v) * perPageSize.height)
        let thisPageRect = CGRect(origin: thisPageOrigin, size: perPageSize)
        
        return thisPageRect
    }
}
