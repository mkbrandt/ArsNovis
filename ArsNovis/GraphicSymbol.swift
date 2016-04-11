//
//  GraphicSymbol.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/19/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class GraphicSymbol: GroupGraphic
{
    var name: String = "Symbol"
    var parametricContext = ParametricContext()
    
    var previewImage: NSImage { return SymbolImager(symbol: self).image(NSSize(width: 128, height: 128)) }
    
    override var description: String { return "Symbol \(name) with contents \(contents)" }
    
    init(page: ArsPage) {
        self.name = page.name
        self.parametricContext = page.parametricContext
        super.init(contents: page.layers.reduce([], combine: { return $0 + $1.contents }))      // all layers of page combined
        moveOriginTo(CGPoint(x: 0, y: 0))
    }

    required convenience init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }

    required init?(coder decoder: NSCoder) {
        if let name = decoder.decodeObjectForKey("name") as? String {
            self.name = name
        }
        if let parametrics = decoder.decodeObjectForKey("parametrics") as? ParametricContext {
            self.parametricContext = parametrics
        }
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        coder.encodeObject(name, forKey: "name")
        coder.encodeObject(parametricContext, forKey: "parametrics")
    }

    override var inspectionKeys: [String] {
        return parametricContext.variables.map { $0.name }
    }
    
    override var defaultInspectionKey: String {
        if let p = parametricContext.variables.first {
            return p.name
        }
        return super.defaultInspectionKey
    }
    
    override func valueForUndefinedKey(key: String) -> AnyObject? {
        return parametricContext.valueForUndefinedKey(key)
    }
    
    override func setValue(value: AnyObject?, forUndefinedKey key: String) {
        parametricContext.setValue(value, forUndefinedKey: key)
    }
    
    override func unlink() {
        super.unlink()
        parametricContext.suspendObservation()
    }

    override func rotateAroundPoint(center: CGPoint, angle: CGFloat) {
        parametricContext.suspendObservation()
        super.rotateAroundPoint(center, angle: angle)
        parametricContext.resumeObservation()
    }
    
    override func flipVerticalAroundPoint(center: CGPoint) {
        parametricContext.suspendObservation()
        super.flipVerticalAroundPoint(center)
        parametricContext.resumeObservation()
    }
    
    override func flipHorizontalAroundPoint(center: CGPoint) {
        parametricContext.suspendObservation()
        super.flipHorizontalAroundPoint(center)
        parametricContext.resumeObservation()
    }
    
}

class SymbolImager: DrawingView
{
    var symbol: GraphicSymbol
    
    init(symbol: GraphicSymbol) {
        self.symbol = symbol
        super.init(frame: CGRect(x: 0, y: 0, width: 128, height: 128))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func drawRect(dirtyRect: CGRect) {
        NSColor.whiteColor().set()
        NSRectFill(dirtyRect)
        context = NSGraphicsContext.currentContext()?.CGContext
        scale = 1.0 / max(symbol.bounds.width / bounds.width, symbol.bounds.height / bounds.height)
        
        CGContextSaveGState(context)
        CGContextScaleCTM(context, scale, scale)
        symbol.drawInView(self)
        CGContextRestoreGState(context)
    }
    
    func image(size: NSSize) -> NSImage {
        let width = Int(size.width)
        let height = Int(size.height)
        if let imageRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: NSDeviceRGBColorSpace,
                                           bitmapFormat: NSBitmapFormat(), bytesPerRow: 0, bitsPerPixel: 0) {
            cacheDisplayInRect(bounds, toBitmapImageRep: imageRep)
            return NSImage(CGImage: imageRep.CGImage!, size: size)
        }
        return NSImage(size: size)
    }
}

