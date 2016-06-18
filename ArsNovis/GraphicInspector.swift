//
//  GraphicInspector.swift
//  ArsNovis
//
//  Created by Matt Brandt on 1/29/15.
//  Copyright (c) 2015 WalkingDog Design. All rights reserved.
//

import Cocoa

enum InspectionType: Int {
    case distance, angle, string, count, float, bool, literal, point, color
}

struct InspectionInfo
{
    var label: String
    var key: String
    var type: InspectionType
}

class GraphicsInspector: NSView, NSTextFieldDelegate
{
    @IBOutlet var drawingView: DrawingView? {
        willSet {
            drawingView?.removeObserver(self, forKeyPath: "selection")
        }
        didSet {
            drawingView?.addObserver(self, forKeyPath: "selection", options: NSKeyValueObservingOptions.new, context: nil)
        }
    }
    var selection: [Graphic] = [] {
        didSet {
            setupBindings()
        }
    }
    
    var fieldInfo: [(NSControl, Graphic, InspectionInfo)] = []
    var fieldConstraints: [NSLayoutConstraint] = []
    
    override func observeValue(forKeyPath keyPath: String?, of object: AnyObject?, change: [NSKeyValueChangeKey : AnyObject]?, context: UnsafeMutablePointer<Void>?) {
        selection = drawingView?.selection ?? []
    }
    
    @IBAction func fieldChanged(_ sender: AnyObject) {
        NSLog("field changed: \(sender)\n")
        for (field, graphic, info) in fieldInfo {
            if let control = sender as? NSControl where control == field {
                if let pcontext = drawingView?.parametricContext, let oldValue = graphic.value(forKey: info.key) as? NSValue where selection.count == 1 && info.type != .float {
                    let parser = ParametricParser(context: pcontext, string: field.stringValue, defaultValue: oldValue, type: graphic.typeForKey(info.key))
                    if parser.expression.isVariable {
                        pcontext.assign(graphic, property: info.key, expression: parser.expression)
                    }
                    let val = parser.value
                    drawingView?.setNeedsDisplay(graphic.bounds)
                    graphic.setValue(val, forKey: info.key)
                    drawingView?.setNeedsDisplay(graphic.bounds)
                } else {
                    switch info.type {
                    case .bool:
                        graphic.setValue(control.intValue != 0, forKey: info.key)
                    case .distance:
                        let v = DistanceTransformer().reverseTransformedValue(control.stringValue)
                        graphic.setValue(v, forKey: info.key)
                    case .angle:
                        let ang = AngleTransformer().reverseTransformedValue(control.stringValue)
                        graphic.setValue(ang, forKey: info.key)
                    case .float:
                        let v = control.doubleValue
                        graphic.setValue(v, forKey: info.key)
                    default:
                        break
                    }
                }
                break
            }
        }
        drawingView?.needsDisplay = true
    }
    
    @IBAction func colorChanged(_ sender: NSColorWell) {
        for (field, graphic, info) in fieldInfo {
            if sender == field {
                let colorValue = sender.color
                graphic.setValue(colorValue, forKey: info.key)
                break
            }
        }
    }
    
    func setupBindings() {
        for subview in subviews {
            subview.removeFromSuperview()
        }
        removeConstraints(fieldConstraints)
        fieldInfo = []
        
        var selected: Graphic
        if selection.count == 0 {
            return
        }
        
        if selection.count == 1 {
            selected = selection[0]
        } else {
            selected = GroupGraphic(contents: selection)
        }
        
        let firstLabel = NSTextField(frame: CGRect(x: 10, y: 10, width: 30, height: 10))
        firstLabel.stringValue = selected.inspectionName
        firstLabel.isBordered = false
        firstLabel.isEditable = false
        firstLabel.isSelectable = false
        firstLabel.translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(firstLabel)
        
        let firstLabelHConstraint = NSLayoutConstraint(item: firstLabel, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 10)
        let firstLabelVConstraint = NSLayoutConstraint(item: firstLabel, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1.0, constant: 10)
        
        fieldConstraints = [firstLabelHConstraint, firstLabelVConstraint]
        addConstraints(fieldConstraints)
        
        var lastLabel = firstLabel
        var firstField: NSTextField?
        var lastField: NSTextField?
        
        for info in selected.inspectionInfo {
            let label = NSTextField(frame: CGRect(x: 10, y: 10, width: 30, height: 10))
            label.stringValue = info.label + ":"
            label.isEnabled = true
            label.isEditable = false
            label.isSelectable = false
            label.isBordered = false
            label.translatesAutoresizingMaskIntoConstraints = false
            
            addSubview(label)
            
            let labelHConstraint = NSLayoutConstraint(item: label, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1.0, constant: 10)
            let labelVConstraint = NSLayoutConstraint(item: label, attribute: .top, relatedBy: .equal, toItem: lastLabel, attribute: .bottom, multiplier: 1.0, constant: 10)
            addConstraints([labelHConstraint, labelVConstraint])
            fieldConstraints += [labelHConstraint, labelVConstraint]
            if lastLabel != firstLabel {
                let labelWidthConstraint = NSLayoutConstraint(item: label, attribute: .width, relatedBy: .equal, toItem: lastLabel, attribute: .width, multiplier: 1.0, constant: 0)
                addConstraint(labelWidthConstraint)
                fieldConstraints.append(labelWidthConstraint)
            }
            lastLabel = label
            var additionalConstraints: [NSLayoutConstraint] = []
            
            var field: NSControl?
            switch info.type {
            case .bool:
                let button = NSButton(frame: CGRect(x: 10, y: 10, width: 30, height: 10))
                button.setButtonType(.switchButton)
                button.title = ""
                button.isEnabled = true
                button.bind("intValue", to: selected, withKeyPath: info.key, options: [NSContinuouslyUpdatesValueBindingOption: true])
                field = button
            case .color:
                let colorWell = NSColorWell(frame: CGRect(x: 10, y: 10, width: 30, height: 30))
                colorWell.isEnabled = true
                colorWell.bind("color", to: selected, withKeyPath: info.key, options: [NSContinuouslyUpdatesValueBindingOption: true])
                colorWell.target = self
                colorWell.action = #selector(colorChanged)
                colorWell.isContinuous = true
                let widthConstraint = NSLayoutConstraint(item: colorWell, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 24)
                let heightConstraint = NSLayoutConstraint(item: colorWell, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 24)
                additionalConstraints = [widthConstraint, heightConstraint]
                field = colorWell
            case .angle:
                let textField = NSTextField(frame: CGRect(x: 10, y: 10, width: 30, height: 10))
                textField.bind("stringValue", to: selected, withKeyPath: info.key, options: [NSValueTransformerBindingOption: AngleTransformer(), NSContinuouslyUpdatesValueBindingOption: true])
                field = textField
            case .count:
                let textField = NSTextField(frame: CGRect(x: 10, y: 10, width: 30, height: 10))
                textField.bind("integerValue", to: selected, withKeyPath: info.key, options: [NSContinuouslyUpdatesValueBindingOption: true])
                field = textField
           case .distance:
                let textField = NSTextField(frame: CGRect(x: 10, y: 10, width: 30, height: 10))
                textField.bind("stringValue", to: selected, withKeyPath: info.key, options: [NSValueTransformerBindingOption: DistanceTransformer(), NSContinuouslyUpdatesValueBindingOption: true])
                field = textField
            case .float:
                let textField = NSTextField(frame: CGRect(x: 10, y: 10, width: 30, height: 10))
                textField.bind("doubleValue", to: selected, withKeyPath: info.key, options: [NSContinuouslyUpdatesValueBindingOption: true])
                field = textField
           case .string:
                let textField = NSTextField(frame: CGRect(x: 10, y: 10, width: 30, height: 10))
                textField.bind("stringValue", to: selected, withKeyPath: info.key, options: [NSContinuouslyUpdatesValueBindingOption: true])
                field = textField
            case .literal, .point:
                field = nil
            }
            
            if let field = field {
                fieldInfo.append((field, selected, info))
                field.translatesAutoresizingMaskIntoConstraints = false
                addSubview(field)
                let vConstraint = NSLayoutConstraint(item: field, attribute: .lastBaseline, relatedBy: .equal, toItem: lastLabel, attribute: .lastBaseline, multiplier: 1.0, constant: 0.0)
                let hConstraint = NSLayoutConstraint(item: field, attribute: .left, relatedBy: .equal, toItem: lastLabel, attribute: .right, multiplier: 1.0, constant: 10.0)
                addConstraints([hConstraint, vConstraint] + additionalConstraints)
                fieldConstraints += [hConstraint, vConstraint] + additionalConstraints
            }
            
            if let field = field as? NSTextField {
                firstField = firstField ?? field
                lastField?.nextKeyView = field
                lastField = field
                field.isEditable = info.type != .count
                field.isSelectable = true
                field.isEnabled = true
                field.isBordered = info.type != .count
                let rConstraint = NSLayoutConstraint(item: field, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1.0, constant: -10.0)
                addConstraint(rConstraint)
                fieldConstraints.append(rConstraint)
                field.target = self
                field.action = #selector(fieldChanged)
            }
        }
        lastField?.nextKeyView = firstField
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let context = NSGraphicsContext.current()?.cgContext
        
        NSColor.white().set()
        context?.fill(dirtyRect)
    }

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        fieldChanged(control)
        return true
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            window?.makeFirstResponder(drawingView)
            return true
        }
        return false
    }
}

class GraphicInspector: NSView, NSTextFieldDelegate
{
    var view: DrawingView?
    var selection: Graphic?
    var info: [String:(NSTextField, ValueTransformer, NSTextField)] = [:]
    var defaultField: NSTextField?
    
    override func draw(_ dirtyRect: CGRect) {
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
    
    @IBAction func fieldChanged(_ sender: AnyObject) {
        NSLog("field changed: \(sender)\n")
        for (key, (field, xfrm, _)) in info {
            if let textfield = sender as? NSTextField {
                if field == textfield {
                    if let pcontext = view?.parametricContext, let g = selection, let oldValue = g.value(forKey: key) as? NSValue {
                        let parser = ParametricParser(context: pcontext, string: field.stringValue, defaultValue: oldValue, type: g.typeForKey(key))
                        if parser.expression.isVariable {
                            pcontext.assign(g, property: key, expression: parser.expression)
                        }
                        let val = parser.value
                        view?.setNeedsDisplay(g.bounds)
                        g.setValue(val, forKey: key)
                        view?.setNeedsDisplay(g.bounds)
                    } else if let val = xfrm.reverseTransformedValue(field.stringValue) as? NSNumber {
                        if let g = selection {
                            view?.setNeedsDisplay(g.bounds)
                            g.setValue(val, forKey: key)
                            view?.setNeedsDisplay(g.bounds)
                        }
                    }
                }
            }
        }
    }
    
    func beginEditing() {
        defaultField?.selectText(self)
    }
    
    func beginInspection(_ graphic: Graphic) {
        self.selection = graphic
        let keys = graphic.inspectionKeys
        let defaultKey = graphic.defaultInspectionKey
        
        removeAllSubviews()
        
        var location = CGPoint(x: 10, y: 3)
        var lastField: NSTextField? = nil
        var firstField: NSTextField? = nil
        
        for key in keys {
            let aKey = AttributedString(string: key)
            var labelSize = aKey.size()
            labelSize.width += 10
            let label = NSTextField(frame: CGRect(origin: location, size: labelSize))
            label.stringValue = key + ":"
            label.isEditable = false
            label.isSelectable = false
            label.isBordered = false
            self.addSubview(label)
            
            location.x += labelSize.width + 5
            let field = NSTextField(frame: CGRect(origin: location, size: NSSize(width: 80, height: 16)))
            field.isBordered = true
            field.isEditable = true
            field.target = self
            field.delegate = self
            field.action = #selector(GraphicInspector.fieldChanged(_:))
            lastField?.nextKeyView = field
            lastField = field
            if firstField == nil {
                firstField = field
            }
            self.addSubview(field)
            
            let transformer = graphic.transformerForKey(key)

            info[key] = (field, transformer, label)
            
            location.x += 100
            
            field.bind("stringValue", to: graphic, withKeyPath: key, options: [NSValueTransformerBindingOption: transformer, NSContinuouslyUpdatesValueBindingOption: true])
            if key == defaultKey {
                defaultField = field
            }
        }
        lastField?.nextKeyView = firstField
    }

    func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
        fieldChanged(control)
        return true
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            //fieldChanged(control)
            window?.makeFirstResponder(view)
            return true
        }
        return false
    }
}
