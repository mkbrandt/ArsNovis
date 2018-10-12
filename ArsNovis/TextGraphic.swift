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
    var text: String = "Text"
    var fontName: String = applicationDefaults.textFontName
    var fontSize: CGFloat = applicationDefaults.textFontSize

    var renderedBounds: CGRect?
    
    var activeEditor: NSTextField?
    
    var font: NSFont {
        get { return NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize) }
        set { fontName = newValue.fontName; fontSize = newValue.pointSize }
    }
    
    var fontAttributes: [NSAttributedStringKey: Any] {
        return [NSAttributedStringKey.font: font, NSAttributedStringKey(rawValue: kCTFontSizeAttribute as String as String): fontSize, NSAttributedStringKey.foregroundColor: lineColor]
    }
    
    override var bounds: CGRect                 { return renderedBounds ?? CGRect(origin: origin, size: CGSize(width: 100, height: 100)) }
    override var selected: Bool {
        didSet {
            NSFontManager.shared.setSelectedFont(font, isMultiple: false)
            NSFontManager.shared.setSelectedAttributes([kCTForegroundColorAttributeName as String: lineColor], isMultiple: false)
        }
    }

    override var inspectionName: String              { return "Text" }
    override var inspectionInfo: [InspectionInfo] {
        return super.inspectionInfo + [
            InspectionInfo(label: "text", key: "text", type: .string),
            InspectionInfo(label: "Font", key: "fontName", type: .string),
            InspectionInfo(label: "Size", key: "fontSize", type: .float)
        ]
    }
    
    init(origin: CGPoint, text: String, angle: CGFloat = 0) {
        self.text = text
        self.angle = angle
        self.fontName = applicationDefaults.textFontName
        self.fontSize = applicationDefaults.textFontSize
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        angle = CGFloat(decoder.decodeDouble(forKey: "angle"))
        fontSize = CGFloat(decoder.decodeDouble(forKey: "fontSize"))
        text = decoder.decodeObject(forKey: "text") as? String ?? "Text"
        fontName = decoder.decodeObject(forKey: "fontName") as? String ?? "Helvetica"
        super.init(coder: decoder)
    }
    
    required convenience init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(Double(angle), forKey: "angle")
        coder.encode(Double(fontSize), forKey: "fontSize")
        coder.encode(text, forKey: "text")
        coder.encode(fontName, forKey: "fontName")
        super.encode(with: coder)
    }
    
    override func recache() {
        cachedPath = nil
    }
    
    override func drawInView(_ view: DrawingView) {
        let scaledSize = view.scaleFloatToDrawing(fontSize)
        let scaledFont = NSFont(name: fontName, size: scaledSize) ?? NSFont.systemFont(ofSize: scaledSize)
        let attributes: [String: AnyObject] = [NSFontAttributeName: scaledFont, NSForegroundColorAttributeName: lineColor]
        if angle == 0.0 {
            text.draw(at: origin, withAttributes: attributes)
            if text == "" {
                text = " "
            }
            renderedBounds = CGRect(origin: origin, size: text.size(withAttributes: attributes))
        } else {
            let context = view.context
            context?.saveGState()
            context?.translate(x: origin.x, y: origin.y)
            context?.rotate(byAngle: angle)
            text.draw(at: CGPoint(x: 0, y: 0), withAttributes: attributes)
            let rsize = text.size(withAttributes: attributes)
            let gg = GroupGraphic(contents: RectGraphic(origin: origin, size: rsize).sides) // fixme: replace after changing rect to group
            gg.rotateAroundPoint(origin, angle: angle)
            renderedBounds = gg.bounds
            context?.restoreGState()
       }
        if selected {
            drawHandlesInView(view)
        }
    }
    
    override var inspectionKeys: [String]   { return ["x", "y", "angle"] }
    override func typeForKey(_ key: String) -> MeasurementType {
        if key == "angle" {
            return .angle
        }
        return .distance
    }
    
    override func closestPointToPoint(_ point: CGPoint, extended: Bool) -> CGPoint {
        if bounds.contains(point) {
            return point
        }
        let r = RectGraphic(origin: origin, size: bounds.size)
        let p = r.closestPointToPoint(point, extended: extended)
        return p
    }
    
    override func rotateAroundPoint(_ center: CGPoint, angle: CGFloat) {
        var offset = origin - center
        offset.angle += angle
        self.angle += angle
        self.angle = normalizeAngle(self.angle)
        origin = center + offset
    }
    
    override func editDoubleClick(_ location: CGPoint, view: DrawingView) {
        let extra: NSString = "_"
        let scaledSize = view.scaleFloatToDrawing(fontSize)
        let scaledFont = NSFont(name: fontName, size: scaledSize) ?? NSFont.systemFont(ofSize: scaledSize)
        var size = text.size(withAttributes: [NSFontAttributeName: scaledFont])
        size.width += extra.size(withAttributes: [NSFontAttributeName: scaledFont]).width
        let editor = NSTextField(frame: CGRect(origin: origin, size: size))
        editor.font = scaledFont
        editor.delegate = self
        activeEditor = editor
        view.addSubview(editor)
        editor.stringValue = text as String
        editor.selectText(self)
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        if let editor = activeEditor {
            let extra: NSString = "_"
            text = editor.stringValue
            var size = text.size(withAttributes: [NSFontAttributeName: editor.font!])
            size.width += extra.size(withAttributes: [NSFontAttributeName: editor.font!]).width
            editor.frame.size = size
            if let view = editor.superview as? DrawingView {
                view.setNeedsDisplay(bounds)
            }
        }
    }
    
    override func controlTextDidEndEditing(_ obj: Notification) {
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
        return NSCursor.iBeam()
    }
    
    override func escape(_ view: DrawingView) {
        view.construction = nil
        view.window?.makeFirstResponder(view)
    }
    
    override func selectTool(_ view: DrawingView) {
        view.setDrawingHint("Text: Select location to place text")
    }
    
    override func mouseDown(_ location: CGPoint, view: DrawingView) {
    }
    
    override func mouseMoved(_ location: CGPoint, view: DrawingView) {
    }
    
    override func mouseDragged(_ location: CGPoint, view: DrawingView) {
    }
    
    override func mouseUp(_ location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        let tg = TextGraphic(origin: location, text: "Text")
        tg.editDoubleClick(location, view: view)
        view.construction = tg
        view.addConstruction()
        view.redrawConstruction()
    }
}

