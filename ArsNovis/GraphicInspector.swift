//
//  GraphicInspector.swift
//  ArsNovis
//
//  Created by Matt Brandt on 1/29/15.
//  Copyright (c) 2015 WalkingDog Design. All rights reserved.
//

import Cocoa

class GraphicInspector: NSView, NSTextFieldDelegate
{
    var view: DrawingView?
    var selection: Graphic?
    var info: [String:(NSTextField, NSValueTransformer, NSTextField)] = [:]
    var defaultField: NSTextField?
    
    override func drawRect(dirtyRect: CGRect) {
        NSEraseRect(dirtyRect)
    }
    
    func removeAllSubviews() {
        for key in info.keys {
            if let (field, _, label) = info[key] {
                label.removeFromSuperview()
                field.removeFromSuperview()
            }
        }
        info = [:]
    }
    
    @IBAction func fieldChanged(sender: AnyObject) {
        NSLog("field changed: \(sender)\n")
        for (key, (field, xfrm, _)) in info {
            if let textfield = sender as? NSTextField {
                if field == textfield {
                    if let val = xfrm.reverseTransformedValue(field.stringValue) as? NSNumber {
                        if let g = selection {
                            view?.setNeedsDisplayInRect(g.bounds)
                            g.setValue(val, forKey: key)
                            view?.setNeedsDisplayInRect(g.bounds)
                        }
                    }
                }
            }
        }
    }
    
    func beginEditing() {
        defaultField?.selectText(self)
    }
    
    func beginInspection(graphic: Graphic) {
        self.selection = graphic
        let keys = graphic.inspectionKeys
        let defaultKey = graphic.defaultInspectionKey
        
        removeAllSubviews()
        
        var location = CGPoint(x: 10, y: 3)
        var lastField: NSTextField? = nil
        var firstField: NSTextField? = nil
        
        for key in keys {
            let aKey = NSAttributedString(string: key)
            var labelSize = aKey.size()
            labelSize.width += 10
            let label = NSTextField(frame: CGRect(origin: location, size: labelSize))
            label.stringValue = key + ":"
            label.editable = false
            label.selectable = false
            label.bordered = false
            self.addSubview(label)
            
            location.x += labelSize.width + 5
            let field = NSTextField(frame: CGRect(origin: location, size: NSSize(width: 80, height: 16)))
            field.bordered = true
            field.editable = true
            field.target = self
            field.delegate = self
            field.action = "fieldChanged:"
            lastField?.nextKeyView = field
            lastField = field
            if firstField == nil {
                firstField = field
            }
            self.addSubview(field)
            
            let transformer = graphic.transformerForKey(key)

            info[key] = (field, transformer, label)
            
            location.x += 100
            
            field.bind("stringValue", toObject: graphic, withKeyPath: key, options: [NSValueTransformerBindingOption: transformer, NSContinuouslyUpdatesValueBindingOption: true])
            if key == defaultKey {
                defaultField = field
            }
        }
        lastField?.nextKeyView = firstField
    }

    func control(control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        fieldChanged(control)
        return true
    }
    
    func control(control: NSControl, textView: NSTextView, doCommandBySelector commandSelector: Selector) -> Bool {
        if commandSelector == "insertNewline:" {
            fieldChanged(control)
            window?.makeFirstResponder(view)
            return true
        }
        return false
    }
}
