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
    
    init(page: ArsPage) {
        self.name = page.name
        self.parametricContext = page.parametricContext
        super.init(contents: page.layers.reduce([], combine: { return $0 + $1.contents }))      // all layers of page combined
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
/*
    override var inspectionKeys: [String] {
        return parametricContext.variables.map { $0.0 }
    }
    
    override var defaultInspectionKey: String {
        if let p = parametricContext.variables.first {
            return p.0
        }
        return super.defaultInspectionKey
    }
 */
}

class LibraryManager: NSView
{
}

