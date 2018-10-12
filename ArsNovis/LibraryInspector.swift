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
    
    @IBAction func openLibrary(_ sender: AnyObject?) {
        let openPanel = NSOpenPanel()
        
        openPanel.allowedFileTypes = ["ars"]
        if let window = window {
            openPanel.beginSheetModal(for: window) { result in
                let fileURLs = openPanel.urls
                for url in fileURLs {
                    if let lib = try? ArsDocument(contentsOf: url, ofType: "ars") {
                        let libname = url.lastPathComponent
                        self.libraries[libname] = lib
                        self.selector.addItem(withTitle: libname)
                        self.table.reloadData()
                    }
                }
            }
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if let lib = selectedLibrary {
            return lib.pages.count
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        if let lib = selectedLibrary {
            if row < lib.pages.count {
                return GraphicSymbol(page: lib.pages[row])
            }
        }
        return nil
    }
    
    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        if let lib = selectedLibrary, row < lib.pages.count {
            return GraphicSymbol(page: lib.pages[row])
        }
        return nil
    }
    
    func tableView(_ tableView: NSTableView, draggingSession session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        
    }
}

