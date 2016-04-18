//
//  TextGraphic.swift
//  ArsNovis
//
//  Created by Matt Brandt on 4/16/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class TextGraphic: Graphic, NSTextFieldDelegate
{
    var angle: CGFloat
    var text: NSString = "Text"
    var fontName: String = applicationDefaults.textFontName
    var fontSize: CGFloat = applicationDefaults.textFontSize

    var renderedBounds: CGRect?
    
    var activeEditor: NSTextField?
    
    var font: NSFont {
        get { return NSFont(name: fontName, size: fontSize) ?? NSFont.systemFontOfSize(fontSize) }
        set { fontName = newValue.fontName; fontSize = newValue.pointSize }
    }
    
    var fontAttributes: [String: AnyObject]     { return [NSFontAttributeName: font, NSFontSizeAttribute: fontSize, NSForegroundColorAttributeName: lineColor] }
    
    override var bounds: CGRect                 { return renderedBounds ?? CGRect(origin: origin, size: CGSize(width: 100, height: 100)) }
    override var selected: Bool {
        didSet {
            NSFontManager.sharedFontManager().setSelectedFont(font, isMultiple: false)
            NSFontManager.sharedFontManager().setSelectedAttributes([NSForegroundColorAttributeName: lineColor], isMultiple: false)
        }
    }
    
    init(origin: CGPoint, text: String, angle: CGFloat = 0) {
        self.text = text
        self.angle = angle
        self.fontName = applicationDefaults.textFontName
        self.fontSize = applicationDefaults.textFontSize
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        angle = CGFloat(decoder.decodeDoubleForKey("angle"))
        fontSize = CGFloat(decoder.decodeDoubleForKey("fontSize"))
        text = decoder.decodeObjectForKey("text") as? String ?? "Text"
        fontName = decoder.decodeObjectForKey("fontName") as? String ?? "Helvetica"
        super.init(coder: decoder)
    }
    
    required convenience init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeDouble(Double(angle), forKey: "angle")
        coder.encodeDouble(Double(fontSize), forKey: "fontSize")
        coder.encodeObject(text, forKey: "text")
        coder.encodeObject(fontName, forKey: "fontName")
        super.encodeWithCoder(coder)
    }
    
    override func recache() {
        cachedPath = nil
    }
    
    override func drawInView(view: DrawingView) {
        let scaledSize = view.scaleFloatToDrawing(fontSize)
        let scaledFont = NSFont(name: fontName, size: scaledSize) ?? NSFont.systemFontOfSize(scaledSize)
        let attributes: [String: AnyObject] = [NSFontAttributeName: scaledFont, NSForegroundColorAttributeName: lineColor]
        if angle == 0.0 {
            text.drawAtPoint(origin, withAttributes: attributes)
            if text == "" {
                text = " "
            }
            renderedBounds = CGRect(origin: origin, size: text.sizeWithAttributes(attributes))
        } else {
            let context = view.context
            CGContextSaveGState(context)
            CGContextTranslateCTM(context, origin.x, origin.y)
            CGContextRotateCTM(context, angle)
            text.drawAtPoint(CGPoint(x: 0, y: 0), withAttributes: attributes)
            let rsize = text.sizeWithAttributes(attributes)
            let gg = GroupGraphic(contents: RectGraphic(origin: origin, size: rsize).sides) // fixme: replace after changing rect to group
            gg.rotateAroundPoint(origin, angle: angle)
            renderedBounds = gg.bounds
            CGContextRestoreGState(context)
       }
        if selected {
            drawHandlesInView(view)
        }
    }
    
    override var inspectionKeys: [String]   { return ["x", "y", "angle"] }
    override func typeForKey(key: String) -> MeasurementType {
        if key == "angle" {
            return .Angle
        }
        return .Distance
    }
    
    override func closestPointToPoint(point: CGPoint, extended: Bool) -> CGPoint {
        if bounds.contains(point) {
            return point
        }
        let r = RectGraphic(origin: origin, size: bounds.size)
        let p = r.closestPointToPoint(point, extended: extended)
        return p
    }
    
    override func editDoubleClick(location: CGPoint, view: DrawingView) {
        let extra: NSString = "_"
        let scaledSize = view.scaleFloatToDrawing(fontSize)
        let scaledFont = NSFont(name: fontName, size: scaledSize) ?? NSFont.systemFontOfSize(scaledSize)
        var size = text.sizeWithAttributes([NSFontAttributeName: scaledFont])
        size.width += extra.sizeWithAttributes([NSFontAttributeName: scaledFont]).width
        let editor = NSTextField(frame: CGRect(origin: origin, size: size))
        editor.font = scaledFont
        editor.delegate = self
        activeEditor = editor
        view.addSubview(editor)
        editor.stringValue = text as String
        editor.selectText(self)
    }
    
    override func controlTextDidChange(obj: NSNotification) {
        if let editor = activeEditor {
            let extra: NSString = "_"
            text = editor.stringValue
            var size = text.sizeWithAttributes([NSFontAttributeName: editor.font!])
            size.width += extra.sizeWithAttributes([NSFontAttributeName: editor.font!]).width
            editor.frame.size = size
            if let view = editor.superview as? DrawingView {
                view.setNeedsDisplayInRect(bounds)
            }
        }
    }
    
    override func controlTextDidEndEditing(obj: NSNotification) {
        if let editor = activeEditor {
            self.text = editor.stringValue
            editor.delegate = nil
            if let view = editor.superview as? DrawingView {
                view.needsDisplay = true
                view.window?.makeFirstResponder(view)
            }
            editor.removeFromSuperview()
        }
        activeEditor = nil
    }
}

class TextTool: GraphicTool
{
    override func cursor() -> NSCursor {
        return NSCursor.IBeamCursor()
    }
    
    override func escape(view: DrawingView) {
        view.construction = nil
        view.window?.makeFirstResponder(view)
    }
    
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Text: Select location to place text")
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
    }
    
    override func mouseMoved(location: CGPoint, view: DrawingView) {
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView) {
    }
    
    override func mouseUp(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        let tg = TextGraphic(origin: location, text: "Text")
        tg.editDoubleClick(location, view: view)
        view.construction = tg
        view.addConstruction()
        view.redrawConstruction()
    }
}

