//
//  Dialogs.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/4/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class NewPageDialog: NSWindow
{
    @IBOutlet var nameField: NSTextField!
    @IBOutlet var emptyPageButton: NSButton!
    @IBOutlet var referenceLayersButton: NSButton!
    @IBOutlet var copyLayersButton: NSButton!
    @IBOutlet var referencePageControl: NSPopUpButton!
    
    @IBAction func radioSelect(sender: NSButton) {
        for button in [emptyPageButton, referenceLayersButton, copyLayersButton] {
            if button != sender {
                button.state = NSOffState
            }
        }
        sender.state = NSOnState
    }
    
    override var canBecomeKeyWindow: Bool {
        return true
    }
    
    @IBAction func ok(sender: AnyObject?) {
        sheetParent?.endSheet(self, returnCode: NSModalResponseOK)
        orderOut(self)
    }
    
    @IBAction func cancel(sender: AnyObject?) {
        sheetParent?.endSheet(self, returnCode: NSModalResponseCancel)
        orderOut(self)
    }
}
