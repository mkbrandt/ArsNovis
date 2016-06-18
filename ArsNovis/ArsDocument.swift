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
        templateChooser.addItems(withTitles: ["ANSI A", "ANSI B", "ANSI C", "ANSI D"])
    }
}

enum MeasurementUnits: Int {
    case inches_dec = 0, inches_frac, feet_dec, feet_frac, millimeters, meters
}

enum GridMode: Int {
    case never = 0, selected = 1, always = 2
}

var measurementUnits: MeasurementUnits = .feet_frac

class ArsDefaults: NSObject
{
    var defaultUnits: MeasurementUnits = .feet_frac
}

class ArsLayer: NSObject, NSCoding
{
    var name: String = "untitled"
    var contents: [Graphic] = []
    var enabled = true
    var layerScale: CGFloat = 1.0
    var majorGrid: CGFloat = 100
    var minorGrid: CGFloat = 10
    var snapToGrid: Bool = false
    var gridMode: GridMode = .selected {
        willSet {
            willChangeValue(forKey: "gridModeNever")
            willChangeValue(forKey: "gridModeSelected")
            willChangeValue(forKey: "gridModeAlways")
        }
        didSet {
            didChangeValue(forKey: "gridModeNever")
            didChangeValue(forKey: "gridModeSelected")
            didChangeValue(forKey: "gridModeAlways")
        }
    }
    
    var gridModeNever: Bool {
        get { return gridMode == .never }
        set { if newValue { gridMode = .never } }
    }
    var gridModeSelected: Bool {
        get { return gridMode == .selected }
        set { if newValue { gridMode = .selected } }
    }
    var gridModeAlways: Bool {
        get { return gridMode == .always }
        set { if newValue { gridMode = .always } }
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
        if let name = decoder.decodeObject(forKey: "name") as? String,
            let contents = decoder.decodeObject(forKey: "contents") as? [Graphic] {
                enabled = decoder.decodeBool(forKey: "enabled")
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
    
    func encode(with coder: NSCoder) {
        coder.encode(enabled, forKey: "enabled")
        coder.encode(contents, forKey: "contents")
        coder.encode(name, forKey: "name")
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
    var units: MeasurementUnits = .feet_frac {
        willSet {
            willChangeValue(forKey: "unitsFeetFrac")
            willChangeValue(forKey: "unitsFeetDec")
            willChangeValue(forKey: "unitsInchFrac")
            willChangeValue(forKey: "unitsInchDec")
            willChangeValue(forKey: "unitsMillimeters")
            willChangeValue(forKey: "unitsMeters")
        }
        didSet {
            didChangeValue(forKey: "unitsFeetFrac")
            didChangeValue(forKey: "unitsFeetDec")
            didChangeValue(forKey: "unitsInchFrac")
            didChangeValue(forKey: "unitsInchDec")
            didChangeValue(forKey: "unitsMillimeters")
            didChangeValue(forKey: "unitsMeters")
            measurementUnits = units
        }
    }
    
    var unitsFeetDec: Bool {
        get { return units == .feet_dec }
        set { if newValue { units = .feet_dec } }
    }
    var unitsFeetFrac: Bool {
        get { return units == .feet_frac }
        set { if newValue { units = .feet_frac } }
    }
    var unitsInchFrac: Bool {
        get { return units == .inches_frac }
        set { if newValue { units = .inches_frac } }
    }
    var unitsInchDec: Bool {
        get { return units == .inches_dec }
        set { if newValue { units = .inches_dec } }
    }
    var unitsMillimeters: Bool {
        get { return units == .millimeters }
        set { if newValue { units = .millimeters } }
    }
    var unitsMeters: Bool {
        get { return units == .meters }
        set { if newValue { units = .meters } }
    }
    
    var printingRect: CGRect {
        if let pageRect = pageRect {
            return pageRect
        } else {
            return layers.reduce(CGRect(), combine: { return $0 + $1.bounds })
        }
    }
    
    override init() {
        super.init()
        pageScale = applicationDefaults.pageScale
        if let pageSize = applicationDefaults.pageSize {
            pageRect = CGRect(origin: CGPoint(x: 0, y: 0), size: pageSize)
        }
    }
    
    init(name: String, printInfo: NSPrintInfo?) {
        super.init()
        self.name = name
        pageScale = applicationDefaults.pageScale
        if let pageSize = applicationDefaults.pageSize {
            pageRect = CGRect(origin: CGPoint(x: 0, y: 0), size: pageSize)
        }
        if let printInfo = printInfo {
            let sizeDiff = printInfo.paperSize - printInfo.imageablePageBounds.size
            borderInset = max(sizeDiff.width, sizeDiff.height) / 2
        }
    }
    
    required init?(coder decoder: NSCoder) {
        super.init()
        if let name = decoder.decodeObject(forKey: "name") as? String,
            let layers = decoder.decodeObject(forKey: "layers") as? [ArsLayer] {
                let rect = decoder.decodeRect(forKey: "pageRect")
                if !rect.isEmpty {
                    pageRect = rect
                }
                let dscale = decoder.decodeDouble(forKey: "pageScale")
                pageScale = dscale == 0 ? 1 : CGFloat(dscale)
                if let parametricContext = decoder.decodeObject(forKey: "parametrics") as? ParametricContext {
                    self.parametricContext = parametricContext
                }
                self.layers = layers
                self.name = name
        } else {
            return nil
        }
    }

    func encode(with coder: NSCoder) {
        coder.encode(name, forKey: "name")
        coder.encode(layers, forKey: "layers")
        coder.encode(parametricContext, forKey: "parametrics")
        coder.encode(Double(pageScale), forKey: "pageScale")
        if let rect = pageRect {
            coder.encode(rect, forKey: "pageRect")
        }
    }
}

class ArsWorkspace: NSObject, NSCoding
{
    var pages: [ArsPage] = []
    var defaults: ArsDefaults = ArsDefaults()
    
    override init() {
        super.init()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init()
        if let pages = decoder.decodeObject(forKey: "pages") as? [ArsPage] {
                self.pages = pages
        } else {
            return nil
        }
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(pages, forKey: "pages")
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
        if let workspace = decoder.decodeObject(forKey: "workspace") as? ArsWorkspace {
            self.workspace = workspace
        } else {
            return nil
        }
        windowFrame = decoder.decodeRect(forKey: "windowFrame")
        scale = CGFloat(decoder.decodeDouble(forKey: "scale"))
        centeredPoint = decoder.decodePoint(forKey: "centeredPoint")
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(workspace, forKey: "workspace")
        if let windowFrame = windowFrame,
            let scale = scale,
            let centeredPoint = centeredPoint {
                coder.encode(windowFrame, forKey: "windowFrame")
                coder.encode(Double(scale), forKey: "scale")
                coder.encode(centeredPoint, forKey: "centeredPoint")
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
                if page.pageRect != nil {
                    drawingView?.zoomToFit(self)
                } else {
                    drawingView?.zoomByFactor(page.pageScale)
                }
            }
        }
    }
    
    var workspace: ArsWorkspace = ArsWorkspace() {
        willSet {
            willChangeValue(forKey: "page")
            willChangeValue(forKey: "pages")
            willChangeValue(forKey: "layer")
            willChangeValue(forKey: "layers")
            willChangeValue(forKey: "state")
        }
        didSet {
            didChangeValue(forKey: "page")
            didChangeValue(forKey: "pages")
            didChangeValue(forKey: "layer")
            didChangeValue(forKey: "layers")
            didChangeValue(forKey: "state")
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
            willChangeValue(forKey: "layers")
            willChangeValue(forKey: "page")
        }
        didSet {
            didChangeValue(forKey: "layers")
            didChangeValue(forKey: "page")
            measurementUnits = page.units
            page.parametricContext.delegate = drawingView
            drawingView?.massiveChange()
        }
    }
    
    var currentLayer: Int = 0 {
        willSet {
            willChangeValue(forKey: "layer")
        }
        didSet {
            didChangeValue(forKey: "layer")
            drawingView?.massiveChange()
        }
    }
    
    var pageSelection: IndexSet {
        get {
            return IndexSet(integer: currentPage)
        }
        set {
            let index = newValue.first
            if let index = index where index < pages.count {
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
    
    var parametricEquations: [ParametricBinding] {
        return parametricContext.parametrics
    }
    
    class func keyPathsForValuesAffectingParametricVariables() -> Set<String> {
        return ["layer", "page", "drawingView.parametricContext"]
    }
    
    class func keyPathsForValuesAffectingParametricEquations() -> Set<String> {
        return ["layer", "page", "drawingView.parametricContext"]
    }
    
    override init()
    {
        super.init()
        workspace.pages.append(ArsPage(name: "Page 1", printInfo: printInfo))
    }

    override func windowControllerDidLoadNib(_ aController: NSWindowController)
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

    override func data(ofType typeName: String) throws -> Data
    {
        let data = NSKeyedArchiver.archivedData(withRootObject: state)
        
        return data
    }

    override func read(from data: Data, ofType typeName: String) throws
    {
        if let state = NSKeyedUnarchiver.unarchiveObject(with: data) as? ArsState {
            self.state = state
            currentPage = 0
        } else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
    }
    
// MARK: Window Delegate
    
    func windowDidResize(_ notification: Notification) {
        drawingView?.zoomByFactor(2)
        drawingView?.zoomByFactor(0.5)
    }
    
// MARK: Printing
    
    override func preparePageLayout(_ pageLayout: NSPageLayout) -> Bool {
        pageLayout.addAccessoryController(pageLayoutAccessory)
        return true
    }
    
    enum PrinterError: ErrorProtocol {
        case noViewError
    }
    
    var printSaveZoomState = ZoomState(scale: 1, centerPoint: CGPoint())
    
    override func printOperation(withSettings printSettings: [String : AnyObject]) throws -> NSPrintOperation {
        if let drawingView = drawingView {
            let operation = NSPrintOperation(view: drawingView, printInfo: printInfo)
            return operation
        } else {
            throw PrinterError.noViewError
        }
    }
    
    func document(_ document: NSDocument, didPrintSuccessfully: Bool,  contextInfo: UnsafeMutablePointer<Void>) {
        drawingView?.zoomState = printSaveZoomState
        drawingView?.constrainViewToSuperview = true
        drawingView?.needsDisplay = true
    }
    
    override func print(_ sender: AnyObject?) {
        if let drawingView = drawingView {
            drawingView.constrainViewToSuperview = false        // allow random zooming
            printSaveZoomState = drawingView.zoomState
            drawingView.zoomToAbsoluteScale(0.72 * page.pageScale * printInfo.scalingFactor)
            print(withSettings: [:], showPrintPanel: true, delegate: self, didPrint: #selector(ArsDocument.document(_:didPrintSuccessfully:contextInfo:)), contextInfo: nil)
        }
    }
    
// MARK: Workspace Maintenance
    
    @IBAction func pageSelectionChanged(_ sender: NSTableView) {
        currentPage = sender.selectedRow
    }
    
    @IBAction func layerSelectionChanged(_ sender: NSTableView) {
        currentLayer = sender.selectedRow
    }
    
    @IBAction func layerEnableChanged(_ sender: AnyObject?) {
        willChangeValue(forKey: "layer")
        drawingView?.massiveChange()
        didChangeValue(forKey: "layer")
    }
    
    @IBAction func newPage(_ sender: AnyObject?) {
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
                
                DispatchQueue.main.async {
                    self.willChangeValue(forKey: "pages")
                    self.workspace.pages.append(newPage)
                    self.didChangeValue(forKey: "pages")
                }
            }
        }
    }
    
    @IBAction func deletePage(_ sender: AnyObject?) {
        if pages.count > 1 {
            let alert = NSAlert()
            alert.messageText = "Are you sure? This will delete all of the page content in \(layer.name)."
            alert.alertStyle = NSAlertStyle.warning
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Delete")
            if let window = drawingView?.window {
                alert.beginSheetModal(for: window) { (response) -> Void in
                    if response == NSAlertSecondButtonReturn {
                        let index = self.currentPage
                        self.willChangeValue(forKey: "page")
                        self.willChangeValue(forKey: "layer")
                        self.workspace.pages.append(self.workspace.pages.remove(at: index))
                        self.didChangeValue(forKey: "page")
                        self.didChangeValue(forKey: "layer")
                        self.currentPage = 0
                        self.willChangeValue(forKey: "pages")
                        self.workspace.pages.remove(at: self.pages.count - 1)
                        self.didChangeValue(forKey: "pages")
                    }
                }
            }
        }
    }
    
    @IBAction func newLayer(_ sender: AnyObject?) {
        willChangeValue(forKey: "layers")
        workspace.pages[currentPage].layers.append(ArsLayer(name: "Unnamed"))
        didChangeValue(forKey: "layers")
    }
    
    @IBAction func deleteLayer(_ sender: AnyObject?) {
        if layers.count > 1 {
            if layer.contents.count > 0 {
                let alert = NSAlert()
                alert.messageText = "Are you sure? This will delete all of the layer content in \(layer.name)."
                alert.alertStyle = NSAlertStyle.warning
                alert.addButton(withTitle: "Cancel")
                alert.addButton(withTitle: "Delete")
                if let window = drawingView?.window {
                    alert.beginSheetModal(for: window) { (response) -> Void in
                        if response == NSAlertSecondButtonReturn {
                            self.willChangeValue(forKey: "layers")
                            self.workspace.pages[self.currentPage].layers.remove(at: self.currentLayer)
                            self.currentLayer = 0
                            self.didChangeValue(forKey: "layers")
                        }
                    }
                }
            }
        }
    }    
}

