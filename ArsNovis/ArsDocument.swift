//
//  Document.swift
//  ArsNovis
//
//  Created by Matt Brandt on 1/21/15.
//  Copyright (c) 2015 WalkingDog Design. All rights reserved.
//

import Cocoa

class ArsLayer: NSObject, NSCoding
{
    var name: String = "untitled"
    var contents: [Graphic] = []
    var enabled = true
    
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
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeBool(enabled, forKey: "enabled")
        coder.encodeObject(contents, forKey: "contents")
        coder.encodeObject(name, forKey: "name")
    }
}

class ArsPage: NSObject, NSCoding
{
    var name = "untitled"
    var pageRect: CGRect?
    var layers: [ArsLayer] = [ArsLayer(name: "Main")]
    
    init(name: String) {
        self.name = name
    }
    
    required init?(coder decoder: NSCoder) {
        super.init()
        if let name = decoder.decodeObjectForKey("name") as? String,
            let layers = decoder.decodeObjectForKey("layers") as? [ArsLayer] {
                pageRect = decoder.decodeRectForKey("pageRect")
                self.layers = layers
                self.name = name
        } else {
            return nil
        }
    }

    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(name, forKey: "name")
        coder.encodeObject(layers, forKey: "layers")
        if let rect = pageRect {
            coder.encodeRect(rect, forKey: "pageRect")
        }
    }
}

class ArsWorkspace: NSObject, NSCoding
{
    var pages: [ArsPage] = []

    override init() {
        pages = [ArsPage(name: "Main Workspace")]
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

class ArsDocument: NSDocument
{
    @IBOutlet var drawingView: DrawingView? {
        didSet {
            drawingView?.document = self
            if let windowFrame = savedWindowFrame {
                drawingView?.window?.setFrame(windowFrame, display:  true)
            }
            if let scale = savedScale, let centeredPoint = savedCenterPoint {
                drawingView?.zoomToAbsoluteScale(scale)
                drawingView?.scrollPointToCenter(centeredPoint)
            } else {
                drawingView?.zoomByFactor(10)
                drawingView?.zoomByFactor(0.1)
            }
        }
    }
    
    var workspace: ArsWorkspace = ArsWorkspace()
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
        }
    }
    
    var cachedBackground: [Graphic]?
    
    var backgroundList: [Graphic] {
        if let background = cachedBackground {
            return background
        }
        let page = workspace.pages[currentPage]
        var list: [Graphic] = []
        for i in 0 ..< page.layers.count {
            if i != currentLayer && page.layers[i].enabled {
                list += page.layers[i].contents
            }
        }
        cachedBackground = list
        return list
    }
    
    var currentPage: Int = 0        { didSet { cachedBackground = nil }}
    var currentLayer: Int = 0       { didSet { cachedBackground = nil }}
    
    override init()
    {
        super.init()
        // Add your subclass-specific initialization here.
    }

    override func windowControllerDidLoadNib(aController: NSWindowController)
    {
        super.windowControllerDidLoadNib(aController)        
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
        } else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
    }
    
// MARK: Workspace Maintenance
    
    @IBAction func newPage(sender: AnyObject?) {
        
    }
    
    @IBAction func deletePage(sender: AnyObject?) {
        
    }
    
    @IBAction func newLayer(sender: AnyObject?) {
        
    }
    
    @IBAction func deleteLayer(sender: AnyObject?) {
        
    }
}

