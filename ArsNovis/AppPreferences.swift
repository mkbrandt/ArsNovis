//
//  AppPreferences.swift
//  ArsNovis
//
//  Created by Matt Brandt on 4/10/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class ArsToolbarItem: NSToolbarItem
{
    @IBOutlet var toolView: NSView?
}

class AppPreferences: NSPanel
{
    @IBOutlet var defaultToolbarItem: ArsToolbarItem?
    
    override func awakeFromNib() {
        if let item = defaultToolbarItem {
            chooseContents(item)
        }
    }
    
    @IBAction func chooseContents(sender: ArsToolbarItem) {
        if let newContent = sender.toolView, let contentSize = contentView?.frame.size {
            var newFrame = frame
            newFrame.size.height = newFrame.size.height - contentSize.height + newContent.frame.size.height
            newFrame.size.width = newFrame.size.width - contentSize.width + newContent.frame.size.width
            contentView?.removeFromSuperview()
            contentView = NSView(frame: newFrame)
            setFrame(newFrame, display: true, animate: true)
            contentView?.removeFromSuperview()
            contentView = sender.toolView
        }
    }
}

class PreviewDrawing: DrawingView {
    var _displayList: [Graphic] = []
    override var displayList: [Graphic] {
        get {return _displayList }
        set {_displayList = newValue}
    }
    
    override func mouseDown(theEvent: NSEvent) {
    }
    
    override func mouseMoved(theEvent: NSEvent) {
    }
    
    override func mouseUp(theEvent: NSEvent) {
    }
    
    override func mouseDragged(theEvent: NSEvent) {
    }
}


class DimensionPreferenceView: NSView
{
    @IBOutlet var arrowWidthField: NSTextField!
    @IBOutlet var arrowLengthField: NSTextField!
    @IBOutlet var widthStepper: NSStepper!
    @IBOutlet var lengthStepper: NSStepper!
    @IBOutlet var preview: PreviewDrawing!
        
    override func awakeFromNib() {
        let defaults = NSUserDefaults()
        let dimensionFontName = defaults.stringForKey("dimensionFontName") ?? "Helvetica"
        DIMENSION_TEXT_SIZE = CGFloat(defaults.floatForKey("dimensionFontSize"))
        DIMENSION_ARROW_LENGTH = CGFloat(defaults.floatForKey("dimensionArrowLength"))
        DIMENSION_ARROW_WIDTH = CGFloat(defaults.floatForKey("dimensionArrowWidth"))
        
        DIMENSION_TEXT_SIZE = DIMENSION_TEXT_SIZE == 0 ? 12.0 : DIMENSION_TEXT_SIZE
        DIMENSION_ARROW_LENGTH = DIMENSION_ARROW_LENGTH == 0 ? 12.0 : DIMENSION_ARROW_LENGTH
        DIMENSION_ARROW_WIDTH = DIMENSION_ARROW_WIDTH == 0 ? 6.0 : DIMENSION_ARROW_WIDTH
        
        DIMENSION_TEXT_FONT = NSFont(name: dimensionFontName, size: DIMENSION_TEXT_SIZE) ?? NSFont.systemFontOfSize(DIMENSION_TEXT_SIZE)
        
        arrowWidthField.floatValue = Float(DIMENSION_ARROW_WIDTH)
        widthStepper.floatValue = Float(DIMENSION_ARROW_WIDTH)
        arrowLengthField.floatValue = Float(DIMENSION_ARROW_LENGTH)
        lengthStepper.floatValue = Float(DIMENSION_ARROW_LENGTH)
        updatePreview()
    }
    
    func updatePreview() {
        let width = CGFloat(212.5)
        let org = CGFloat(20.0)
        let r = RectGraphic(origin: CGPoint(x: org, y: 10), size: CGSize(width: width, height: 20))
        let dim = LinearDimension(origin: CGPoint(x: org, y: 30), endPoint: CGPoint(x: org + width, y: 30))
        dim.lineColor = dim.lineColor.colorWithAlphaComponent(1.0)
        preview.displayList = [r, dim]
        preview.needsDisplay = true
    }
    
    func updatePreviewAndSave() {
        updatePreview()
        let defaults = NSUserDefaults()
        
        let dimensionFontName = DIMENSION_TEXT_FONT.fontName
        defaults.setValue(dimensionFontName, forKey: "dimensionFontName")
        defaults.setValue(DIMENSION_TEXT_SIZE, forKey: "dimensionFontSize")
        defaults.setValue(DIMENSION_ARROW_WIDTH, forKey: "dimensionArrowWidth")
        defaults.setValue(DIMENSION_ARROW_LENGTH, forKey: "dimensionArrowLength")
    }
    
    @IBAction func showFontPanel(sender: AnyObject?) {
        let fontManager = NSFontManager.sharedFontManager()
        let fontPanel = fontManager.fontPanel(true)
        fontPanel?.orderFront(self)
        fontPanel?.setPanelFont(DIMENSION_TEXT_FONT, isMultiple: false)
        window?.makeFirstResponder(self)
    }
    
    @IBAction override func changeFont(sender: AnyObject?) {
        let fontManager = NSFontManager.sharedFontManager()
        DIMENSION_TEXT_FONT = fontManager.convertFont(DIMENSION_TEXT_FONT)
        DIMENSION_TEXT_SIZE = DIMENSION_TEXT_FONT.pointSize
        updatePreviewAndSave()
    }
    
    @IBAction func lengthChange(sender: NSControl) {
        let value = sender.floatValue
        arrowLengthField.floatValue = value
        lengthStepper.floatValue = value
        DIMENSION_ARROW_LENGTH = CGFloat(value)
        updatePreviewAndSave()
    }
    
    @IBAction func widthChange(sender: NSControl) {
        let value = sender.floatValue
        arrowWidthField.floatValue = value
        widthStepper.floatValue = value
        DIMENSION_ARROW_WIDTH = CGFloat(Float(arrowWidthField.stringValue) ?? 6.0)
        updatePreviewAndSave()
    }
}