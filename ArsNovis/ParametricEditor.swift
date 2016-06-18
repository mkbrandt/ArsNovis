//
//  ParametricEditor.swift
//  ArsNovis
//
//  Created by Matt Brandt on 4/21/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

let ParametricItemUTI = "com.walkingdog.arsnovis.parametric"

class ParametricEquationEditor: NSView, NSDraggingSource
{
    var context: ParametricContext?
    var equation: ParametricOperation? { didSet { invalidateIntrinsicContentSize(); needsDisplay = true }}
    let LineHeight = CGFloat(18)
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        register(forDraggedTypes: [ParametricItemUTI])
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        register(forDraggedTypes: [ParametricItemUTI])
    }
    
    var drawnSize: NSSize?
    override var intrinsicContentSize: NSSize {
        let width = bounds.size.width
        var lines: CGFloat = 0
        
        if let equation = equation {
            let count = equation.count
            var x: CGFloat = 0
            
            for index in 0 ..< count {
                let item = equation.itemAtIndex(index)
                let image = item.image
                if x + image.size.width > width {
                    x = image.size.width
                    lines += 1
                }
            }
        }
        return CGSize(width: width, height: lines * LineHeight)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        var cursor = CGPoint(x: bounds.origin.x, y: bounds.origin.y + bounds.size.height - LineHeight)
        if let equation = equation {
            let numObjects = equation.count
            
            for index in 0 ..< numObjects {
                let item = equation.itemAtIndex(index)
                Swift.print("display \(item.targetString)")
                let image = item.image
                if image.size.width + cursor.x > bounds.origin.x + bounds.size.width {
                    cursor.x = bounds.origin.x
                    cursor.y -= LineHeight
                }
                if image.size.width > 2 {
                    item.origin = cursor
                    image.draw(in: CGRect(origin: cursor, size: image.size))
                    cursor.x += image.size.width + 4
                }
            }
        }
    }
    
// Dragging Source

    var originalEquation: ParametricOperation?
    var draggedParameter: ParametricNode?
    var shouldDeleteOnDrag: Bool { return true }
    
    func itemAtLocation(_ point: CGPoint) -> ParametricNode? {
        return equation?.itemAtPoint(point)
    }
    
    override func mouseDown(_ theEvent: NSEvent) {
        let location = convert(theEvent.locationInWindow, from: nil)
        
        if let item = equation?.itemAtPoint(location) {
            draggedParameter = item
            originalEquation = equation
            if shouldDeleteOnDrag {
                equation = equation?.removeItem(item) as? ParametricOperation
            }
            let draggingItem = NSDraggingItem(pasteboardWriter: item)
            let oldImage = item.image
            item.createImage()
            draggingItem.setDraggingFrame(item.frame, contents: item.image)
            item.image = oldImage
            let session = beginDraggingSession(with: [draggingItem], event: theEvent, source: self)
            session.animatesToStartingPositionsOnCancelOrFail = true
        }
    }
    
    override func mouseMoved(_ theEvent: NSEvent) {
    }
    
    override func mouseDragged(_ theEvent: NSEvent) {
    }

    override func mouseUp(_ theEvent: NSEvent) {
    }
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .move
    }
    
    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
    }
    
    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        if operation == NSDragOperation() {
            equation = originalEquation
        }
        originalEquation = nil
    }
    
// Dragging Destination
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return [.move, .copy]
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return false
    }
}

class ParametricEditorTableCellView: NSTableCellView
{
    @IBOutlet var editor: ParametricEquationEditor!
    
    override var objectValue: AnyObject? {
        didSet {
            editor.equation = objectValue as? ParametricOperation
        }
    }
}

class ParametricItemView: ParametricEquationEditor
{
    var items: [ParametricValue] = []
    var maxWidth: CGFloat = 0
    
    var graphic: Graphic? {
        didSet {
            if let graphic = graphic {
                equation = nil
                maxWidth = 0
                items = []
                for p in graphic.parametricInfo {
                    let item = ParametricValue(target: graphic, name: p.key, type: p.type, context: context)
                    if item.image.size.width > maxWidth {
                        maxWidth = item.image.size.width
                    }
                    items.append(item)
                }
                maxWidth += 20
                for item in items {
                    item.createImage(maxWidth)
                    equation = ParametricOperation(op: "", left: equation, right: item, context: context)
                }
            }
            let height = LineHeight * CGFloat(items.count) + LineHeight * 1.2
            let origin = window?.frame.origin ?? CGPoint()
            window?.setFrame(CGRect(origin: origin, size: CGSize(width: maxWidth, height: height)), display: true, animate: true)
        }
    }
    
    override var mouseDownCanMoveWindow: Bool { return false }
    override var shouldDeleteOnDrag: Bool { return false }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let RADIUS: CGFloat = 8.0
        NSColor.black().withAlphaComponent(0.4).set()
        let path = NSBezierPath()
        path.move(to: CGPoint(x: bounds.origin.x, y: bounds.origin.y + RADIUS))
        path.line(to: CGPoint(x: bounds.origin.x, y: bounds.origin.y + bounds.size.height))
        path.line(to: CGPoint(x: bounds.origin.x + bounds.size.width, y: bounds.origin.y + bounds.size.height))
        path.line(to: CGPoint(x: bounds.origin.x + bounds.size.width, y: bounds.origin.y + RADIUS))
        path.appendArc(withCenter: CGPoint(x: bounds.origin.x + bounds.size.width - RADIUS, y: bounds.origin.y + RADIUS), radius: RADIUS, startAngle: 0, endAngle: -90, clockwise: true)
        path.line(to: CGPoint(x: bounds.origin.x + RADIUS, y: bounds.origin.y))
        path.appendArc(withCenter: CGPoint(x: bounds.origin.x + RADIUS, y: bounds.origin.y + RADIUS), radius: RADIUS, startAngle: -90, endAngle: -180, clockwise: true)
        path.fill()
        super.draw(dirtyRect)
    }
    
    override func viewDidMoveToWindow() {
        let oldGraphic = graphic
        graphic = nil
        graphic = oldGraphic
    }
}

class TitleBarView: NSView
{
    override var mouseDownCanMoveWindow: Bool  { return true }
    
    var buttonRect = CGRect()
    
    override func draw(_ dirtyRect: NSRect) {
        let context = NSGraphicsContext.current()?.cgContext
        context?.saveGState()
        
        let TITLE_HEIGHT: CGFloat = 20
        let RADIUS: CGFloat = 8
        let top = bounds.origin + CGPoint(x: 0, y: bounds.size.height - TITLE_HEIGHT)
        NSColor.black().withAlphaComponent(0.6).set()
        var path = NSBezierPath()
        path.move(to: top)
        path.line(to: CGPoint(x: top.x, y: top.y + TITLE_HEIGHT - RADIUS))
        path.appendArc(withCenter: CGPoint(x: top.x + RADIUS, y: top.y + TITLE_HEIGHT - RADIUS), radius: RADIUS, startAngle: 180, endAngle: 90, clockwise: true)
        path.line(to: CGPoint(x: top.x + bounds.size.width - RADIUS, y: top.y + TITLE_HEIGHT))
        path.appendArc(withCenter: CGPoint(x: top.x + bounds.size.width - RADIUS, y: top.y + TITLE_HEIGHT - RADIUS), radius: RADIUS, startAngle: 90, endAngle: 0, clockwise: true)
        path.line(to: CGPoint(x: top.x + bounds.size.width, y: top.y))
        path.line(to: top)
        path.fill()
        NSColor.black().withAlphaComponent(0.8).set()
        path.lineWidth = 0.5
        path.stroke()
        
        buttonRect = CGRect(origin: top + CGPoint(x: 5, y: 3), size: CGSize(width: 12, height: 12))
        path = NSBezierPath(ovalIn: buttonRect)
        path.lineWidth = 0.5
        path.stroke()
        let title = AttributedString(string: "Parametrics", attributes: [NSForegroundColorAttributeName: NSColor.white().withAlphaComponent(0.5)])
        let w = title.size().width
        title.draw(at: top + CGPoint(x: (bounds.size.width - w) / 2, y: 3))
        NSColor.white().withAlphaComponent(0.5).set()
        path.setClip()
        NSBezierPath.setDefaultLineWidth(0.5)
        NSBezierPath.strokeLine(from: buttonRect.origin, to: buttonRect.topRight)
        NSBezierPath.strokeLine(from: buttonRect.topLeft, to: buttonRect.bottomRight)
        
        context?.restoreGState()
    }
    
    override func mouseDown(_ theEvent: NSEvent) {
        let location = convert(theEvent.locationInWindow, from: nil)

        if buttonRect.contains(location) {
            window?.orderOut(self)
        }
    }
}
