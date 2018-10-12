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
    
    @IBAction func radioSelect(_ sender: NSButton) {
        for button in [emptyPageButton, referenceLayersButton, copyLayersButton] {
            if button != sender {
                button?.state = NSOffState
            }
        }
        sender.state = NSOnState
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    @IBAction func ok(_ sender: AnyObject?) {
        sheetParent?.endSheet(self, returnCode: NSApplication.ModalResponse.OK)
        orderOut(self)
    }
    
    @IBAction func cancel(_ sender: AnyObject?) {
        sheetParent?.endSheet(self, returnCode: NSApplication.ModalResponse.cancel)
        orderOut(self)
    }
}
