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

let appDefaults: [String: AnyObject] = [
    "defaultUnits": MeasurementUnits.Feet_frac.rawValue,
    "dimensionFontName": "Helvetica",
    "dimensionFontSize": 12.0,
    "dimensionArrowWidth": 6.0,
    "dimensionArrowLength": 12.0,
    "textFontSize": 12.0,
    "textFontName": "Helvetica"
]

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

class ArsUserDefaults: NSObject
{
    var userDefaults = NSUserDefaults.standardUserDefaults()
    
    var defaultUnits: MeasurementUnits {
        get { return MeasurementUnits(rawValue: userDefaults.integerForKey("defaultUnits")) ?? .Feet_frac }
        set { userDefaults.setInteger(newValue.rawValue, forKey: "defaultUnits") }
    }
    
    var dimensionFontName: String {
        get { return userDefaults.stringForKey("dimensionFontName") ?? "Helvetica" }
        set { userDefaults.setValue(newValue, forKey: "dimensionFontName") }
    }
    
    var dimensionFontSize: CGFloat {
        get { return CGFloat(userDefaults.doubleForKey("dimensionFontSize") ?? 12) }
        set { userDefaults.setDouble(Double(newValue), forKey: "dimensionFontSize") }
    }
    
    var dimensionArrowWidth: CGFloat {
        get { return CGFloat(userDefaults.doubleForKey("dimensionArrowWidth") ?? 12) }
        set { userDefaults.setDouble(Double(newValue), forKey: "dimensionArrowWidth") }
    }
    
    var dimensionArrowLength: CGFloat {
        get { return CGFloat(userDefaults.doubleForKey("dimensionArrowLength") ?? 12) }
        set { userDefaults.setDouble(Double(newValue), forKey: "dimensionArrowLength") }
    }
    
    var textFontName: String {
        get { return userDefaults.stringForKey("textFontName") ?? "Helvetica" }
        set { userDefaults.setValue(newValue, forKey: "textFontName") }
    }

    var textFontSize: CGFloat {
        get { return CGFloat(userDefaults.doubleForKey("textFontSize") ?? 12) }
        set { userDefaults.setDouble(Double(newValue), forKey: "textFontSize") }
    }
    
    var pageSize: CGSize? {
        get {
            if let width = userDefaults.valueForKey("pageWidth"), let height = userDefaults.valueForKey("pageHeight") {
                return CGSize(width: CGFloat(width.doubleValue), height: CGFloat(height.doubleValue))
            }
            return nil
        }
        set {
            if let size = newValue {
                userDefaults.setValue(size.height, forKey: "pageHeight")
                userDefaults.setValue(size.width, forKey: "pageWidth")
            } else {
                userDefaults.removeObjectForKey("pageHeight")
                userDefaults.removeObjectForKey("pageWidth")
            }
        }
    }
    
    var pageScale: CGFloat {
        get { return CGFloat(userDefaults.doubleForKey("pageScale") ?? 1.0) }
        set { userDefaults.setDouble(Double(newValue), forKey: "pageScale") }
    }
    
    var dimensionFont: NSFont {
        get {
            if let font = NSFont(name: dimensionFontName, size: dimensionFontSize) {
                return font
            }
            return NSFont.systemFontOfSize(dimensionFontSize)
        }
        set {
            dimensionFontName = newValue.fontName
            dimensionFontSize = newValue.pointSize
        }
    }
    
    var textFont: NSFont {
        get {
            if let font = NSFont(name: textFontName, size: textFontSize) {
                return font
            }
            return NSFont.systemFontOfSize(textFontSize)
        }
        set {
            textFontName = newValue.fontName
            textFontSize = newValue.pointSize
        }
    }
}

var applicationDefaults = ArsUserDefaults()

// MARK: Dimensions

class DimensionPreferenceView: NSView
{
    @IBOutlet var arrowWidthField: NSTextField!
    @IBOutlet var arrowLengthField: NSTextField!
    @IBOutlet var widthStepper: NSStepper!
    @IBOutlet var lengthStepper: NSStepper!
    @IBOutlet var preview: PreviewDrawing!
        
    override func awakeFromNib() {
        arrowWidthField.floatValue = Float(applicationDefaults.dimensionArrowWidth)
        widthStepper.floatValue = Float(applicationDefaults.dimensionArrowWidth)
        arrowLengthField.floatValue = Float(applicationDefaults.dimensionArrowLength)
        lengthStepper.floatValue = Float(applicationDefaults.dimensionArrowLength)
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
    
    @IBAction func showFontPanel(sender: AnyObject?) {
        let fontManager = NSFontManager.sharedFontManager()
        let fontPanel = fontManager.fontPanel(true)
        fontPanel?.orderFront(self)
        fontPanel?.setPanelFont(applicationDefaults.dimensionFont, isMultiple: false)
        window?.makeFirstResponder(self)
    }
    
    @IBAction override func changeFont(sender: AnyObject?) {
        let fontManager = NSFontManager.sharedFontManager()
        let newFont = fontManager.convertFont(applicationDefaults.dimensionFont)
        applicationDefaults.dimensionFontSize = newFont.pointSize
        applicationDefaults.dimensionFontName = newFont.fontName
        updatePreview()
    }
    
    @IBAction func lengthChange(sender: NSControl) {
        let value = sender.floatValue
        arrowLengthField.floatValue = value
        lengthStepper.floatValue = value
        applicationDefaults.dimensionArrowLength = CGFloat(value)
        updatePreview()
    }
    
    @IBAction func widthChange(sender: NSControl) {
        let value = sender.floatValue
        arrowWidthField.floatValue = value
        widthStepper.floatValue = value
        applicationDefaults.dimensionArrowWidth = CGFloat(Float(arrowWidthField.stringValue) ?? 6.0)
        updatePreview()
    }
}

// MARK: Units

class UnitsPreferences: NSView
{
    var defaultUnits: MeasurementUnits = .Feet_frac {
        willSet {
            willChangeValueForKey("unitsInchesDecimal")
            willChangeValueForKey("unitsInchesFractional")
            willChangeValueForKey("unitsFeetDecimal")
            willChangeValueForKey("unitsFeetFractional")
            willChangeValueForKey("unitsMeters")
            willChangeValueForKey("unitsMillimeters")
        }
        didSet {
            didChangeValueForKey("unitsInchesDecimal")
            didChangeValueForKey("unitsInchesFractional")
            didChangeValueForKey("unitsFeetDecimal")
            didChangeValueForKey("unitsFeetFractional")
            didChangeValueForKey("unitsMeters")
            didChangeValueForKey("unitsMillimeters")
            NSUserDefaults.standardUserDefaults().setInteger(defaultUnits.rawValue, forKey: "defaultUnits")
        }
    }
    
    var unitsInchesDecimal: Bool {
        get { return defaultUnits == .Inches_dec }
        set { if newValue { defaultUnits = .Inches_dec } }
    }
    var unitsInchesFractional: Bool {
        get { return defaultUnits == .Inches_frac }
        set { if newValue { defaultUnits = .Inches_frac } }
    }
    var unitsFeetDecimal: Bool {
        get { return defaultUnits == .Feet_dec }
        set { if newValue { defaultUnits = .Feet_dec } }
    }
    var unitsFeetFractional: Bool {
        get { return defaultUnits == .Feet_frac }
        set { if newValue { defaultUnits = .Feet_frac } }
    }
    var unitsMeters: Bool {
        get { return defaultUnits == .Meters }
        set { if newValue { defaultUnits = .Meters } }
    }
    var unitsMillimeters: Bool {
        get { return defaultUnits == .Millimeters }
        set { if newValue { defaultUnits = .Millimeters } }
    }
    
    override func awakeFromNib() {
        let units = NSUserDefaults.standardUserDefaults().integerForKey("defaultUnits")
        if let defaultUnits = MeasurementUnits(rawValue: units) {
            self.defaultUnits = defaultUnits
        }
    }
}

class DrawingPreferenceView: NSView
{
    @IBOutlet var drawingView: DrawingView!
    @IBOutlet var pageSizePopup: NSPopUpButton!
    @IBOutlet var pageWidth: NSTextField!
    @IBOutlet var pageHeight: NSTextField!
    @IBOutlet var pageOrientation: NSSegmentedControl!
    @IBOutlet var pageScalePopup: NSPopUpButton!
    @IBOutlet var scaleNumerator: NSTextField!
    @IBOutlet var scaleDenominator: NSTextField!
    
    
    override func awakeFromNib() {
        pageSizePopup.removeAllItems()
        pageSizePopup.addItemsWithTitles(drawingSizes.map { $0.name })
        pageScalePopup.removeAllItems()
        pageScalePopup.addItemsWithTitles(drawingScales.map { $0.name })
        showScale()
        showPageInfo()
    }
    
    func showScale() {
        let pageScale = applicationDefaults.pageScale
        var (numerator, denominator) = ("\(pageScale)" , "1")
        var scaleTitle = "Custom"
        if pageScale < 1.0 {
            let invScale = 1.0 / pageScale
            switch invScale {
            case 96:
                (numerator, denominator) = ("1\"", "8'")
                scaleTitle = "Eighth Scale"
            case 48:
                (numerator, denominator) = ("1\"", "4'")
                scaleTitle = "Quarter Scale"
            case 24:
                (numerator, denominator) = ("1\"", "2'")
                scaleTitle = "Half Scale"
            case 12:
                (numerator, denominator) = ("1\"", "1'")
            default:
                (numerator, denominator) = ("1", "\(invScale)")
            }
        }
        pageScalePopup.selectItemWithTitle(scaleTitle)
        scaleNumerator.stringValue = numerator
        scaleDenominator.stringValue = denominator
    }
    
    func showPageInfo() {
        if let pageSize = applicationDefaults.pageSize {
            pageWidth.stringValue = "\(pageSize.width)"
            pageHeight.stringValue = "\(pageSize.height)"
            pageOrientation.selectedSegment = pageSize.width > pageSize.height ? 1 : 0

            for dwgSize in drawingSizes {
                if dwgSize.size.width == pageSize.width && dwgSize.size.height == pageSize.height {
                    pageSizePopup.selectItemWithTitle(dwgSize.name)
                    pageOrientation.selectedSegment = 0
                    return
                } else if dwgSize.size.width == pageSize.height && dwgSize.size.height == pageSize.width {
                    pageSizePopup.selectItemWithTitle(dwgSize.name)
                    pageOrientation.selectedSegment = 1
                    return
                }
            }
            pageSizePopup.selectItemAtIndex(0)
        }
    }
    
    @IBAction func pageSettingsChanged(sender: AnyObject?) {
        let index = pageSizePopup.indexOfSelectedItem
        if index == 0 {
            applicationDefaults.pageSize = nil
            return
        }
        let info = drawingSizes[index]
        let portrait = pageOrientation.selectedSegment == 0
        if portrait {
            applicationDefaults.pageSize = CGSize(width: info.size.width, height: info.size.height)
        } else {
            applicationDefaults.pageSize = CGSize(width: info.size.height, height: info.size.width)
        }
        showPageInfo()
    }
    
    @IBAction func scaleSettingsChanged(sender: AnyObject?) {
        let index = pageScalePopup.indexOfSelectedItem
        if let _ = sender as? NSPopUpButton {
            if index == 0 {
                let num = distanceFromString(scaleNumerator.stringValue)
                let denom = distanceFromString(scaleDenominator.stringValue)
                let scale = num / denom
                
                applicationDefaults.pageScale = scale
            } else {
                let scaleSetting = drawingScales[index]
                
                scaleNumerator.stringValue = scaleSetting.numerator
                scaleDenominator.stringValue = scaleSetting.denominator
                applicationDefaults.pageScale = scaleSetting.scale
            }
        } else {
            let num = distanceFromString(scaleNumerator.stringValue)
            let denom = distanceFromString(scaleDenominator.stringValue)
            let scale = num / denom
            
            applicationDefaults.pageScale = scale
        }
        showScale()
    }

}