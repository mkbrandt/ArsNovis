//
//  Document.swift
//  ArsNovis
//
//  Created by Matt Brandt on 1/21/15.
//  Copyright (c) 2015 WalkingDog Design. All rights reserved.
//

import Cocoa

class ArsPageLayoutController: NSViewController
{
    @IBOutlet var templateChooser: NSPopUpButton!
    
    override func awakeFromNib() {
        templateChooser.removeAllItems()
        templateChooser.addItemsWithTitles(["ANSI A", "ANSI B", "ANSI C", "ANSI D"])
    }
}

enum MeasurementUnits: Int {
    case Inches_dec = 0, Inches_frac, Feet_dec, Feet_frac, Millimeters, Meters
}

enum GridMode: Int {
    case Never = 0, Selected = 1, Always = 2
}

var measurementUnits: MeasurementUnits = .Feet_frac

class ArsLayer: NSObject, NSCoding
{
    var name: String = "untitled"
    var contents: [Graphic] = []
    var enabled = true
    var layerScale: CGFloat = 1.0
    var majorGrid: CGFloat = 100
    var minorGrid: CGFloat = 10
    var snapToGrid: Bool = false
    var gridMode: GridMode = .Selected {
        willSet {
            willChangeValueForKey("gridModeNever")
            willChangeValueForKey("gridModeSelected")
            willChangeValueForKey("gridModeAlways")
        }
        didSet {
            didChangeValueForKey("gridModeNever")
            didChangeValueForKey("gridModeSelected")
            didChangeValueForKey("gridModeAlways")
        }
    }
    
    var gridModeNever: Bool {
        get { return gridMode == .Never }
        set { if newValue { gridMode = .Never } }
    }
    var gridModeSelected: Bool {
        get { return gridMode == .Selected }
        set { if newValue { gridMode = .Selected } }
    }
    var gridModeAlways: Bool {
        get { return gridMode == .Always }
        set { if newValue { gridMode = .Always } }
    }
    
    var bounds: CGRect {
        return contents.reduce(CGRect(), combine: { return $0 + $1.bounds} )
    }
    
    init(name: String) {
        super.init()
        self.name = name
    }
    
    required init?(coder decoder: NSCoder) {
        super.init()
        if let name = decoder.decodeObjectForKey("name") as? String,
            let contents = decoder.decodeObjectForKey("contents") as? [Graphic] {
                enabled = decoder.decodeBoolForKey("enabled")
                self.contents = contents
                self.name = name
        } else {
            return nil
        }
    }
    
    init(copyLayer: ArsLayer) {
        name = copyLayer.name
        contents = copyLayer.contents
        enabled = copyLayer.enabled
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeBool(enabled, forKey: "enabled")
        coder.encodeObject(contents, forKey: "contents")
        coder.encodeObject(name, forKey: "name")
    }
}

class ArsPage: NSObject, NSCoding
{
    var name = "untitled"
    var parametricContext = ParametricContext()
    var pageRect: CGRect?
    var pageScale: CGFloat = 1.0
    var layers: [ArsLayer] = [ArsLayer(name: "Main")]
    var leftBorderOffset: CGFloat = 0
    var borderInset: CGFloat = 10
    var borderWidth: CGFloat = 20
    var gridSize: CGFloat = 200
    var units: MeasurementUnits = .Feet_frac {
        willSet {
            willChangeValueForKey("unitsFeetFrac")
            willChangeValueForKey("unitsFeetDec")
            willChangeValueForKey("unitsInchFrac")
            willChangeValueForKey("unitsInchDec")
            willChangeValueForKey("unitsMillimeters")
            willChangeValueForKey("unitsMeters")
        }
        didSet {
            didChangeValueForKey("unitsFeetFrac")
            didChangeValueForKey("unitsFeetDec")
            didChangeValueForKey("unitsInchFrac")
            didChangeValueForKey("unitsInchDec")
            didChangeValueForKey("unitsMillimeters")
            didChangeValueForKey("unitsMeters")
            measurementUnits = units
        }
    }
    
    var unitsFeetDec: Bool {
        get { return units == .Feet_dec }
        set { if newValue { units = .Feet_dec } }
    }
    var unitsFeetFrac: Bool {
        get { return units == .Feet_frac }
        set { if newValue { units = .Feet_frac } }
    }
    var unitsInchFrac: Bool {
        get { return units == .Inches_frac }
        set { if newValue { units = .Inches_frac } }
    }
    var unitsInchDec: Bool {
        get { return units == .Inches_dec }
        set { if newValue { units = .Inches_dec } }
    }
    var unitsMillimeters: Bool {
        get { return units == .Millimeters }
        set { if newValue { units = .Millimeters } }
    }
    var unitsMeters: Bool {
        get { return units == .Meters }
        set { if newValue { units = .Meters } }
    }
    
    var printingRect: CGRect {
        if let pageRect = pageRect {
            return pageRect
        } else {
            return layers.reduce(CGRect(), combine: { return $0 + $1.bounds })
        }
    }
    
    init(name: String, printInfo: NSPrintInfo?) {
        super.init()
        self.name = name
        if let printInfo = printInfo {
            let sizeDiff = printInfo.paperSize - printInfo.imageablePageBounds.size
            borderInset = max(sizeDiff.width, sizeDiff.height) / 2
        }
        parametricContext.setValue(CGFloat(120), forUndefinedKey: "test1")
        parametricContext.setValue(CGFloat(200), forUndefinedKey: "test2")
    }
    
    required init?(coder decoder: NSCoder) {
        super.init()
        if let name = decoder.decodeObjectForKey("name") as? String,
            let layers = decoder.decodeObjectForKey("layers") as? [ArsLayer] {
                let rect = decoder.decodeRectForKey("pageRect")
                if !rect.isEmpty {
                    pageRect = rect
                }
                let dscale = decoder.decodeDoubleForKey("pageScale")
                pageScale = dscale == 0 ? 1 : CGFloat(dscale)
                if let parametricContext = decoder.decodeObjectForKey("parametrics") as? ParametricContext {
                    self.parametricContext = parametricContext
                }
                self.layers = layers
                self.name = name
        } else {
            return nil
        }
    }

    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(name, forKey: "name")
        coder.encodeObject(layers, forKey: "layers")
        coder.encodeObject(parametricContext, forKey: "parametrics")
        coder.encodeDouble(Double(pageScale), forKey: "pageScale")
        if let rect = pageRect {
            coder.encodeRect(rect, forKey: "pageRect")
        }
    }
}

class ArsWorkspace: NSObject, NSCoding
{
    var pages: [ArsPage] = []
    
    override init() {
        super.init()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init()
        if let pages = decoder.decodeObjectForKey("pages") as? [ArsPage] {
                self.pages = pages
        } else {
            return nil
        }
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(pages, forKey: "pages")
    }
}

class ArsState: NSObject, NSCoding
{
    var workspace: ArsWorkspace = ArsWorkspace()
    var windowFrame: CGRect?
    var scale: CGFloat?
    var centeredPoint: CGPoint?
    
    init(workspace: ArsWorkspace, windowFrame: CGRect?, scale: CGFloat?, centeredPoint: CGPoint?) {
        self.workspace = workspace
        self.windowFrame = windowFrame
        self.scale = scale
        self.centeredPoint = centeredPoint
    }
    
    required init?(coder decoder: NSCoder) {
        super.init()
        if let workspace = decoder.decodeObjectForKey("workspace") as? ArsWorkspace {
            self.workspace = workspace
        } else {
            return nil
        }
        windowFrame = decoder.decodeRectForKey("windowFrame")
        scale = CGFloat(decoder.decodeDoubleForKey("scale"))
        centeredPoint = decoder.decodePointForKey("centeredPoint")
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(workspace, forKey: "workspace")
        if let windowFrame = windowFrame,
            let scale = scale,
            let centeredPoint = centeredPoint {
                coder.encodeRect(windowFrame, forKey: "windowFrame")
                coder.encodeDouble(Double(scale), forKey: "scale")
                coder.encodePoint(centeredPoint, forKey: "centeredPoint")
        }
    }
}

// MARK: Document

class ArsDocument: NSDocument
{
    @IBOutlet var newPageDialog: NewPageDialog!
    @IBOutlet var pageLayoutAccessory: ArsPageLayoutController!
    @IBOutlet var drawingSizePopup: NSPopUpButton!
    
    @IBOutlet var drawingView: DrawingView? {
        didSet {
            drawingView?.document = self
            page.parametricContext.delegate = drawingView
            if let windowFrame = savedWindowFrame {
                drawingView?.window?.setFrame(windowFrame, display:  true)
            }
            if let scale = savedScale, let centeredPoint = savedCenterPoint {
                drawingView?.zoomToFit(self)
                drawingView?.zoomByFactor(100)
                drawingView?.zoomByFactor(0.01)
                drawingView?.zoomToAbsoluteScale(scale)
                drawingView?.scrollPointToCenter(centeredPoint)
            } else {
                drawingView?.zoomByFactor(100)
                drawingView?.zoomByFactor(0.01)
            }
        }
    }
    
    var workspace: ArsWorkspace = ArsWorkspace() {
        willSet {
            willChangeValueForKey("page")
            willChangeValueForKey("pages")
            willChangeValueForKey("layer")
            willChangeValueForKey("layers")
            willChangeValueForKey("state")
        }
        didSet {
            didChangeValueForKey("page")
            didChangeValueForKey("pages")
            didChangeValueForKey("layer")
            didChangeValueForKey("layers")
            didChangeValueForKey("state")
        }
    }
    
    var displayList: [Graphic] {
        get {
            return workspace.pages[currentPage].layers[currentLayer].contents
        }
        set {
            workspace.pages[currentPage].layers[currentLayer].contents = newValue
        }
    }
    
    var savedWindowFrame: CGRect?
    var savedScale: CGFloat?
    var savedCenterPoint: CGPoint?
    
    var state: ArsState {
        get {
            let windowFrame = drawingView?.window?.frame
            let scale = drawingView?.scale
            let centeredPoint = drawingView?.centeredPointInDocView
                
            return ArsState(workspace: workspace, windowFrame: windowFrame, scale: scale, centeredPoint: centeredPoint)
        }
        set {
            workspace = newValue.workspace
            savedWindowFrame = newValue.windowFrame
            savedScale = newValue.scale
            savedCenterPoint = newValue.centeredPoint
            currentPage = 0
            currentLayer = 0
        }
    }
    
    var pages: [ArsPage]        { return workspace.pages }
    var page: ArsPage           { return pages[currentPage < pages.count ? currentPage : 0] }
    var layers: [ArsLayer]      { return page.layers }
    var layer: ArsLayer         { return layers[currentLayer] }
    
    var currentPage: Int = 0 {
        willSet {
            willChangeValueForKey("layers")
            willChangeValueForKey("page")
        }
        didSet {
            didChangeValueForKey("layers")
            didChangeValueForKey("page")
            measurementUnits = page.units
            page.parametricContext.delegate = drawingView
            drawingView?.massiveChange()
        }
    }
    
    var currentLayer: Int = 0 {
        willSet {
            willChangeValueForKey("layer")
        }
        didSet {
            didChangeValueForKey("layer")
            drawingView?.massiveChange()
        }
    }
    
    var pageSelection: NSIndexSet {
        get {
            return NSIndexSet(index: currentPage)
        }
        set {
            let index = newValue.firstIndex
            if index < pages.count && index != NSNotFound {
                currentPage = index
            }
        }
    }
    
    var parametricContext: ParametricContext {
        if let pcontext = drawingView?.parametricContext {
            return pcontext
        }
        return page.parametricContext
    }
    
    var parametricVariables: [ParametricVariable] {
        return parametricContext.variables
    }
    
    class func keyPathsForValuesAffectingParametricVariables() -> Set<String> {
        return ["layer", "page", "drawingView.parametricContext"]
    }
    
    override init()
    {
        super.init()
        workspace.pages.append(ArsPage(name: "Page 1", printInfo: printInfo))
    }

    override func windowControllerDidLoadNib(aController: NSWindowController)
    {
        super.windowControllerDidLoadNib(aController)
        //aController.window?.titleVisibility = NSWindowTitleVisibility.Hidden
    }

    override class func autosavesInPlace() -> Bool
    {
        return true
    }

    override var windowNibName: String?
    {
        return "ArsDocument"
    }

    override func dataOfType(typeName: String) throws -> NSData
    {
        let data = NSKeyedArchiver.archivedDataWithRootObject(state)
        
        return data
    }

    override func readFromData(data: NSData, ofType typeName: String) throws
    {
        if let state = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? ArsState {
            self.state = state
            currentPage = 0
        } else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
    }
    
// MARK: Printing
    
    override func preparePageLayout(pageLayout: NSPageLayout) -> Bool {
        pageLayout.addAccessoryController(pageLayoutAccessory)
        return true
    }
    
    enum PrinterError: ErrorType {
        case NoViewError
    }
    
    var printSaveZoomState = ZoomState(scale: 1, centerPoint: CGPoint())
    
    override func printOperationWithSettings(printSettings: [String : AnyObject]) throws -> NSPrintOperation {
        if let drawingView = drawingView {
            let operation = NSPrintOperation(view: drawingView, printInfo: printInfo)
            return operation
        } else {
            throw PrinterError.NoViewError
        }
    }
    
    func document(document: NSDocument, didPrintSuccessfully: Bool,  contextInfo: UnsafeMutablePointer<Void>) {
        drawingView?.zoomState = printSaveZoomState
        drawingView?.constrainViewToSuperview = true
        drawingView?.needsDisplay = true
    }
    
    override func printDocument(sender: AnyObject?) {
        if let drawingView = drawingView {
            drawingView.constrainViewToSuperview = false        // allow random zooming
            printSaveZoomState = drawingView.zoomState
            drawingView.zoomToAbsoluteScale(0.72 * page.pageScale * printInfo.scalingFactor)
            printDocumentWithSettings([:], showPrintPanel: true, delegate: self, didPrintSelector: #selector(ArsDocument.document(_:didPrintSuccessfully:contextInfo:)), contextInfo: nil)
        }
    }
    
// MARK: Workspace Maintenance
    
    @IBAction func pageSelectionChanged(sender: NSTableView) {
        currentPage = sender.selectedRow
    }
    
    @IBAction func layerSelectionChanged(sender: NSTableView) {
        currentLayer = sender.selectedRow
    }
    
    @IBAction func layerEnableChanged(sender: AnyObject?) {
        willChangeValueForKey("layer")
        drawingView?.massiveChange()
        didChangeValueForKey("layer")
    }
    
    @IBAction func newPage(sender: AnyObject?) {
        if let window = drawingView?.window {
            newPageDialog.nameField.stringValue = "Page \(pages.count)"
            window.beginSheet(newPageDialog) { response in
                if response == NSModalResponseCancel {
                    return
                }
                let refIndex = self.newPageDialog.referencePageControl.indexOfSelectedItem
                let refPage = self.pages[refIndex]
                let name = self.newPageDialog.nameField.stringValue
                let doCopy = self.newPageDialog.copyLayersButton.intValue != 0
                let doRef = self.newPageDialog.referenceLayersButton.intValue != 0
                let newPage = ArsPage(name: name, printInfo: self.printInfo)
                
                newPage.pageRect = refPage.pageRect
                
                if doCopy {
                    newPage.layers = refPage.layers.map { return ArsLayer(copyLayer: $0) }
                } else if doRef {
                    newPage.layers = refPage.layers
                }
                
                dispatch_async(dispatch_get_main_queue()) {
                    self.willChangeValueForKey("pages")
                    self.workspace.pages.append(newPage)
                    self.didChangeValueForKey("pages")
                }
            }
        }
    }
    
    @IBAction func deletePage(sender: AnyObject?) {
        if pages.count > 1 {
            let alert = NSAlert()
            alert.messageText = "Are you sure? This will delete all of the page content in \(layer.name)."
            alert.alertStyle = NSAlertStyle.WarningAlertStyle
            alert.addButtonWithTitle("Cancel")
            alert.addButtonWithTitle("Delete")
            if let window = drawingView?.window {
                alert.beginSheetModalForWindow(window) { (response) -> Void in
                    if response == NSAlertSecondButtonReturn {
                        let index = self.currentPage
                        self.willChangeValueForKey("page")
                        self.willChangeValueForKey("layer")
                        self.workspace.pages.append(self.workspace.pages.removeAtIndex(index))
                        self.didChangeValueForKey("page")
                        self.didChangeValueForKey("layer")
                        self.currentPage = 0
                        self.willChangeValueForKey("pages")
                        self.workspace.pages.removeAtIndex(self.pages.count - 1)
                        self.didChangeValueForKey("pages")
                    }
                }
            }
        }
    }
    
    @IBAction func newLayer(sender: AnyObject?) {
        willChangeValueForKey("layers")
        workspace.pages[currentPage].layers.append(ArsLayer(name: "Unnamed"))
        didChangeValueForKey("layers")
    }
    
    @IBAction func deleteLayer(sender: AnyObject?) {
        if layers.count > 1 {
            if layer.contents.count > 0 {
                let alert = NSAlert()
                alert.messageText = "Are you sure? This will delete all of the layer content in \(layer.name)."
                alert.alertStyle = NSAlertStyle.WarningAlertStyle
                alert.addButtonWithTitle("Cancel")
                alert.addButtonWithTitle("Delete")
                if let window = drawingView?.window {
                    alert.beginSheetModalForWindow(window) { (response) -> Void in
                        if response == NSAlertSecondButtonReturn {
                            self.willChangeValueForKey("layers")
                            self.workspace.pages[self.currentPage].layers.removeAtIndex(self.currentLayer)
                            self.currentLayer = 0
                            self.didChangeValueForKey("layers")
                        }
                    }
                }
            }
        }
    }
}

