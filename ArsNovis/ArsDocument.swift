//
//  Document.swift
//  ArsNovis
//
//  Created by Matt Brandt on 1/21/15.
//  Copyright (c) 2015 WalkingDog Design. All rights reserved.
//

import Cocoa

class ArsPage
{
    var name = "untitled"
    var pageSize = NSSize(width: 17, height: 11)
    var displayList = []
}

class ArsDocument: NSDocument
{
    @IBOutlet var drawingView: DrawingView?
    
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
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    override func readFromData(data: NSData, ofType typeName: String) throws
    {
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
}

