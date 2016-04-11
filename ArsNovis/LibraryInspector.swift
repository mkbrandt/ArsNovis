//
//  LibraryInspector.swift
//  ArsNovis
//
//  Created by Matt Brandt on 4/3/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class LibraryInspector: NSView, NSTableViewDataSource
{
    @IBOutlet var table: NSTableView!
    @IBOutlet var selector: NSPopUpButton!
    
    var libraries: [String: ArsDocument] = [:]
    
    var selectedLibrary: ArsDocument?   {
        if let selection = selector.titleOfSelectedItem {
            return libraries[selection]
        }
        return nil
    }
    
    override func awakeFromNib() {
        selector.removeAllItems()
    }
    
    @IBAction func openLibrary(sender: AnyObject?) {
        let openPanel = NSOpenPanel()
        
        openPanel.allowedFileTypes = ["ars"]
        if let window = window {
            openPanel.beginSheetModalForWindow(window) { result in
                let fileURLs = openPanel.URLs
                for url in fileURLs {
                    if let lib = try? ArsDocument(contentsOfURL: url, ofType: "ars"), let libname = url.lastPathComponent {
                        self.libraries[libname] = lib
                        self.selector.addItemWithTitle(libname)
                        self.table.reloadData()
                    }
                }
            }
        }
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if let lib = selectedLibrary {
            return lib.pages.count
        }
        return 0
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        if let lib = selectedLibrary {
            if row < lib.pages.count {
                return GraphicSymbol(page: lib.pages[row])
            }
        }
        return nil
    }
    
    func tableView(tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        if let lib = selectedLibrary where row < lib.pages.count {
            return GraphicSymbol(page: lib.pages[row])
        }
        return nil
    }
    
    func tableView(tableView: NSTableView, draggingSession session: NSDraggingSession, endedAtPoint screenPoint: NSPoint, operation: NSDragOperation) {
        
    }
}

