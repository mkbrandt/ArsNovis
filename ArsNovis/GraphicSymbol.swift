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
    
    override var inspectionName: String              { return "Symbol - \(name)" }
    override var inspectionInfo: [InspectionInfo] {
        let info = super.inspectionInfo + [InspectionInfo(label: "Parametrics", key: "", type: .literal)]
        let pinfo = parametricContext.variables.map {
            return InspectionInfo(label: $0.name, key: $0.name, type: $0.measurementType == .angle ? .angle : .distance)
        }
        return info + pinfo
    }
    
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
        if let name = decoder.decodeObject(forKey: "name") as? String {
            self.name = name
        }
        if let parametrics = decoder.decodeObject(forKey: "parametrics") as? ParametricContext {
            self.parametricContext = parametrics
        }
        super.init(coder: decoder)
    }
    
    override func encode(with coder: NSCoder) {
        super.encode(with: coder)
        coder.encode(name, forKey: "name")
        coder.encode(parametricContext, forKey: "parametrics")
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
    
    override func value(forUndefinedKey key: String) -> AnyObject? {
        return parametricContext.value(forUndefinedKey: key)
    }
    
    override func setValue(_ value: AnyObject?, forUndefinedKey key: String) {
        parametricContext.setValue(value, forUndefinedKey: key)
    }
    
    override func unlink() {
        super.unlink()
        parametricContext.suspendObservation()
    }

    override func rotateAroundPoint(_ center: CGPoint, angle: CGFloat) {
        parametricContext.suspendObservation()
        super.rotateAroundPoint(center, angle: angle)
        parametricContext.resumeObservation()
    }
    
    override func flipVerticalAroundPoint(_ center: CGPoint) {
        parametricContext.suspendObservation()
        super.flipVerticalAroundPoint(center)
        parametricContext.resumeObservation()
    }
    
    override func flipHorizontalAroundPoint(_ center: CGPoint) {
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
    
    override func draw(_ dirtyRect: CGRect) {
        NSColor.white().set()
        NSRectFill(dirtyRect)
        context = NSGraphicsContext.current()?.cgContext
        scale = 1.0 / max(symbol.bounds.width / bounds.width, symbol.bounds.height / bounds.height)
        
        context.saveGState()
        context.scale(x: scale, y: scale)
        symbol.drawInView(self)
        context.restoreGState()
    }
    
    func image(_ size: NSSize) -> NSImage {
        let width = Int(size.width)
        let height = Int(size.height)
        if let imageRep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: NSDeviceRGBColorSpace,
                                           bitmapFormat: NSBitmapFormat(), bytesPerRow: 0, bitsPerPixel: 0) {
            cacheDisplay(in: bounds, to: imageRep)
            return NSImage(cgImage: imageRep.cgImage!, size: size)
        }
        return NSImage(size: size)
    }
}

