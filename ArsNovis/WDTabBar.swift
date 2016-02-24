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
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        delegate = self
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override var intrinsicContentSize: NSSize
    {
        let text = attributedStringValue
        let size = CGSize(width: text.size().width + 12, height: text.size().height)
        
        return size
    }
    
    override func controlTextDidChange(obj: NSNotification)
    {
        invalidateIntrinsicContentSize()
    }
}

@objc protocol WDTabBarButtonDelegate
{
    func shouldBeginEditingTab(tab: WDTabBarButton) -> Bool
    optional func didBeginEditingTab(tab: WDTabBarButton) -> ()
    optional func didEndEditingTab(tab: WDTabBarButton) -> ()
    func shouldSelectTab(tab: WDTabBarButton) -> Bool
    optional func didSelectTab(tab: WDTabBarButton) -> ()
}

class WDTabBarButton: NSView
{
    var _selected = false
    var label: NSTextField!
    var delegate: WDTabBarButtonDelegate?
    
    var selected: Bool
        {
        get { return _selected }
        set { _selected = newValue; needsDisplay = true }
    }
    
    override init(frame frameRect: CGRect)
    {
        super.init(frame: frameRect)
        let textFrame = NSInsetRect(bounds, 10, 5)
        label = WDResizableTextField(frame: textFrame)
        label.stringValue = "untitled"
        label.editable = false
        label.enabled = true
        label.bordered = false
        label.drawsBackground = false
        label.action = "endEditing:"
        label.target = self
        label.alignment = NSTextAlignment.Center
        label.translatesAutoresizingMaskIntoConstraints = false
        
        translatesAutoresizingMaskIntoConstraints = false
        
        addConstraint(NSLayoutConstraint(item: self, attribute: NSLayoutAttribute.Width, relatedBy: NSLayoutRelation.Equal,
            toItem: label, attribute: NSLayoutAttribute.Width, multiplier: 1, constant: 40))
        addConstraint(NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.CenterX, relatedBy: NSLayoutRelation.Equal,
            toItem: self, attribute: NSLayoutAttribute.CenterX, multiplier: 1, constant: 0))
        addConstraint(NSLayoutConstraint(item: label, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal,
            toItem: self, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0))
        addSubview(label)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    @IBAction func checkSize(sender: NSObject)
    {
        needsUpdateConstraints = true
    }
    
    @IBAction func endEditing(sender: NSObject)
    {
        if label.editable
        {
            label.editable = false
            delegate?.didEndEditingTab?(self)
        }
    }
    
    override var intrinsicContentSize: NSSize
    {
        let text = label.stringValue as NSString
        var size = text.sizeWithAttributes([:])
        
        size.width += 40
        size.height += 20
        return size
    }
    
    override func drawRect(dirtyRect: CGRect)
    {
        super.drawRect(dirtyRect)
        
        let fill = selected ? NSGradient(startingColor: NSColor.whiteColor(), endingColor: NSColor.lightGrayColor())
            : NSGradient(startingColor: NSColor.grayColor(), endingColor: NSColor.lightGrayColor())
        
        if let fill = fill {
            fill.drawInRect(bounds, angle: 90)
            NSColor.blackColor().set()
            NSBezierPath.strokeRect(NSInsetRect(bounds, 1, 1))
        }
    }
    
    override func mouseDown(theEvent: NSEvent)
    {
        if theEvent.clickCount == 2
        {
            if delegate?.shouldBeginEditingTab(self) != nil
            {
                label.editable = true
                label.selectText(self)
                delegate?.didBeginEditingTab?(self)
            }
        }
        else
        {
            if (delegate?.shouldSelectTab(self) != nil)
            {
                selected = true
                delegate?.didSelectTab?(self)
            }
        }
    }
}

@objc protocol WDTabBarDelegate
{
    optional func tabBar(tabBar: WDTabBar, shouldSelectTabAtIndex index: Int) -> Bool
    optional func tabBar(tabBar: WDTabBar, didSelectTabAtIndex index: Int) -> ()
    optional func tabBar(tabBar: WDTabBar, shouldRenameTabAtIndex index: Int) -> Bool
    optional func tabBar(tabBar: WDTabBar, didRenameTabAtIndex index: Int) -> ()
}

class WDTabBar: NSView, WDTabBarButtonDelegate
{
    var tabs: [WDTabBarButton] = []
    var buttonLayouts: [NSLayoutConstraint] = []
    var delegate: WDTabBarDelegate?
    
    override init(frame: CGRect)
    {
        tabs = []
        buttonLayouts = []
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
    }
    
    required init?(coder: NSCoder)
    {
        super.init(coder: coder)
    }
    
    override func drawRect(dirtyRect: CGRect)
    {
        super.drawRect(dirtyRect)
        
        NSColor.grayColor().set()
        NSRectFill(bounds)
    }
    
    func rejiggerConstraints()
    {
        removeConstraints(buttonLayouts)
        buttonLayouts = []
        if tabs.count > 0
        {
            let tab = tabs[0]
            
            let leftAlign = NSLayoutConstraint(item: tab, attribute: NSLayoutAttribute.Left, relatedBy: NSLayoutRelation.Equal,
                toItem: self, attribute: NSLayoutAttribute.Left, multiplier: 1, constant: 0)
            
            addConstraint(leftAlign)
            buttonLayouts.append(leftAlign)
            
            let centers = NSLayoutConstraint(item: tab, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal,
                toItem: self, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0)
            
            addConstraint(centers)
            buttonLayouts.append(centers)
        }
        
        for var i = 1; i < tabs.count; ++i
        {
            let tab = tabs[i]
            let prev = tabs[i - 1]
            
            let leftAlign = NSLayoutConstraint(item: tab, attribute: NSLayoutAttribute.Left, relatedBy: NSLayoutRelation.Equal,
                toItem: prev, attribute: NSLayoutAttribute.Right, multiplier: 1, constant: -1)
            
            addConstraint(leftAlign)
            buttonLayouts.append(leftAlign)
            
            let centers = NSLayoutConstraint(item: tab, attribute: NSLayoutAttribute.CenterY, relatedBy: NSLayoutRelation.Equal,
                toItem: self, attribute: NSLayoutAttribute.CenterY, multiplier: 1, constant: 0)
            
            addConstraint(centers)
            buttonLayouts.append(centers)
        }
    }
    
    func addTabWithName(name: String)
    {
        let tab = WDTabBarButton(frame: CGRect(x: 0, y: 0, width: 80, height: 30))
        
        tab.label.stringValue = name
        tab.delegate = self
        tabs.append(tab)
        addSubview(tab)
        rejiggerConstraints()
    }
    
    func selectLastTab()
    {
        tabs[tabs.count - 1].selected = true
    }
    
    func didSelectTab(aTab: WDTabBarButton)
    {
        for tab in tabs
        {
            if tab != aTab {
                tab.selected = false
            }
        }
    }
    
    func indexOfTab(tab: WDTabBarButton) -> Int?
    {
        for var i = 0; i < tabs.count; ++i
        {
            if tabs[i] == tab {
                return i
            }
        }
        return nil
    }
    
    func shouldBeginEditingTab(tab: WDTabBarButton) -> Bool
    {
        if let index = indexOfTab(tab)
        {
            if let rv = delegate?.tabBar?(self, shouldRenameTabAtIndex: index) {
                return rv
            }
        }
        return false
    }
    
    func didBeginEditingTab(tab: WDTabBarButton)
    {
    }
    
    func didEndEditingTab(tab: WDTabBarButton)
    {
        if let index = indexOfTab(tab) {
            delegate?.tabBar?(self, didRenameTabAtIndex: index)
        }
    }
    
    func shouldSelectTab(tab: WDTabBarButton) -> Bool
    {
        if let index = indexOfTab(tab) {
            if let rv = delegate?.tabBar?(self, shouldSelectTabAtIndex: index) {
                return rv
            }
        }
        return false
    }
}
