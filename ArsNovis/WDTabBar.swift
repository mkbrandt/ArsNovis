//
//  WDTabBar.swift
//  Electra
//
//  Created by Matt Brandt on 7/31/14.
//  Copyright (c) 2014 WalkingDog Design. All rights reserved.
//

import Cocoa

class WDResizableTextField: NSTextField, NSTextFieldDelegate
{
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        delegate = self
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override var intrinsicContentSize: NSSize {
        let text = attributedStringValue
        let size = CGSize(width: text.size().width + 12, height: text.size().height)
        
        return size
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        invalidateIntrinsicContentSize()
    }
}

@objc protocol WDTabBarButtonDelegate
{
    func shouldBeginEditingTab(_ tab: WDTabBarButton) -> Bool
    @objc optional func didBeginEditingTab(_ tab: WDTabBarButton) -> ()
    @objc optional func didEndEditingTab(_ tab: WDTabBarButton) -> ()
    func shouldSelectTab(_ tab: WDTabBarButton) -> Bool
    @objc optional func didSelectTab(_ tab: WDTabBarButton) -> ()
}

class WDTabBarButton: NSView
{
    var _selected = false
    var label: NSTextField!
    var delegate: WDTabBarButtonDelegate?
    
    var selected: Bool {
        get { return _selected }
        set { _selected = newValue; needsDisplay = true }
    }
    
    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        let textFrame = NSInsetRect(bounds, 10, 5)
        label = WDResizableTextField(frame: textFrame)
        label.stringValue = "untitled"
        label.isEditable = false
        label.isEnabled = true
        label.isBordered = false
        label.drawsBackground = false
        label.action = #selector(WDTabBarButton.endEditing(_:))
        label.target = self
        label.alignment = NSTextAlignment.center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        translatesAutoresizingMaskIntoConstraints = false
        
        addConstraint(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.width, relatedBy: NSLayoutRelation.equal,
            toItem: label, attribute: NSLayoutAttribute.width, multiplier: 1, constant: 40))
        addConstraint(NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.centerX, relatedBy: NSLayoutRelation.equal,
            toItem: self, attribute: NSLayoutAttribute.centerX, multiplier: 1, constant: 0))
        addConstraint(NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal,
            toItem: self, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0))
        addSubview(label)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @IBAction func checkSize(_ sender: NSObject) {
        needsUpdateConstraints = true
    }
    
    @IBAction func endEditing(_ sender: NSObject) {
        if label.isEditable {
            label.isEditable = false
            delegate?.didEndEditingTab?(self)
        }
    }
    
    override var intrinsicContentSize: NSSize {
        let text = label.stringValue as NSString
        var size = text.size(withAttributes: [:])
        
        size.width += 40
        size.height += 20
        return size
    }
    
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)
        
        let fill = selected ? NSGradient(starting: NSColor.white(), ending: NSColor.lightGray())
            : NSGradient(starting: NSColor.gray(), ending: NSColor.lightGray())
        
        if let fill = fill {
            fill.draw(in: bounds, angle: 90)
            NSColor.black().set()
            NSBezierPath.stroke(NSInsetRect(bounds, 1, 1))
        }
    }
    
    override func mouseDown(_ theEvent: NSEvent)
    {
        if theEvent.clickCount == 2 {
            if delegate?.shouldBeginEditingTab(self) != nil {
                label.isEditable = true
                label.selectText(self)
                delegate?.didBeginEditingTab?(self)
            }
        } else {
            if (delegate?.shouldSelectTab(self) != nil) {
                selected = true
                delegate?.didSelectTab?(self)
            }
        }
    }
}

@objc protocol WDTabBarDelegate
{
    @objc optional func tabBar(_ tabBar: WDTabBar, shouldSelectTabAtIndex index: Int) -> Bool
    @objc optional func tabBar(_ tabBar: WDTabBar, didSelectTabAtIndex index: Int) -> ()
    @objc optional func tabBar(_ tabBar: WDTabBar, shouldRenameTabAtIndex index: Int) -> Bool
    @objc optional func tabBar(_ tabBar: WDTabBar, didRenameTabAtIndex index: Int) -> ()
}

class WDTabBar: NSView, WDTabBarButtonDelegate
{
    var tabs: [WDTabBarButton] = []
    var buttonLayouts: [NSLayoutConstraint] = []
    var delegate: WDTabBarDelegate?
    
    override init(frame: CGRect) {
        tabs = []
        buttonLayouts = []
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func draw(_ dirtyRect: CGRect) {
        super.draw(dirtyRect)
        
        NSColor.gray().set()
        NSRectFill(bounds)
    }
    
    func rejiggerConstraints() {
        removeConstraints(buttonLayouts)
        buttonLayouts = []
        if tabs.count > 0 {
            let tab = tabs[0]
            
            let leftAlign = NSLayoutConstraint(item: tab, attribute: NSLayoutAttribute.left, relatedBy: NSLayoutRelation.equal,
                toItem: self, attribute: NSLayoutAttribute.left, multiplier: 1, constant: 0)
            
            addConstraint(leftAlign)
            buttonLayouts.append(leftAlign)
            
            let centers = NSLayoutConstraint(item: tab, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal,
                toItem: self, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0)
            
            addConstraint(centers)
            buttonLayouts.append(centers)
        }
        
        for i in 1 ..< tabs.count {
            let tab = tabs[i]
            let prev = tabs[i - 1]
            
            let leftAlign = NSLayoutConstraint(item: tab, attribute: NSLayoutAttribute.left, relatedBy: NSLayoutRelation.equal,
                toItem: prev, attribute: NSLayoutAttribute.right, multiplier: 1, constant: -1)
            
            addConstraint(leftAlign)
            buttonLayouts.append(leftAlign)
            
            let centers = NSLayoutConstraint(item: tab, attribute: NSLayoutAttribute.centerY, relatedBy: NSLayoutRelation.equal,
                toItem: self, attribute: NSLayoutAttribute.centerY, multiplier: 1, constant: 0)
            
            addConstraint(centers)
            buttonLayouts.append(centers)
        }
    }
    
    func addTabWithName(_ name: String) {
        let tab = WDTabBarButton(frame: CGRect(x: 0, y: 0, width: 80, height: 30))
        
        tab.label.stringValue = name
        tab.delegate = self
        tabs.append(tab)
        addSubview(tab)
        rejiggerConstraints()
    }
    
    func selectLastTab() {
        tabs[tabs.count - 1].selected = true
    }
    
    func didSelectTab(_ aTab: WDTabBarButton) {
        for tab in tabs {
            if tab != aTab {
                tab.selected = false
            }
        }
    }
    
    func indexOfTab(_ tab: WDTabBarButton) -> Int? {
        for i in 0 ..< tabs.count {
            if tabs[i] == tab {
                return i
            }
        }
        return nil
    }
    
    func shouldBeginEditingTab(_ tab: WDTabBarButton) -> Bool {
        if let index = indexOfTab(tab) {
            if let rv = delegate?.tabBar?(self, shouldRenameTabAtIndex: index) {
                return rv
            }
        }
        return false
    }
    
    func didBeginEditingTab(_ tab: WDTabBarButton) {
    }
    
    func didEndEditingTab(_ tab: WDTabBarButton) {
        if let index = indexOfTab(tab) {
            delegate?.tabBar?(self, didRenameTabAtIndex: index)
        }
    }
    
    func shouldSelectTab(_ tab: WDTabBarButton) -> Bool {
        if let index = indexOfTab(tab) {
            if let rv = delegate?.tabBar?(self, shouldSelectTabAtIndex: index) {
                return rv
            }
        }
        return false
    }
}
