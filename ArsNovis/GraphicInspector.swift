//
//  GraphicInspector.swift
//  ArsNovis
//
//  Created by Matt Brandt on 1/29/15.
//  Copyright (c) 2015 WalkingDog Design. All rights reserved.
//

import Cocoa

class DistanceTransformer: NSValueTransformer
{
    var defaultUnits = "ft"
    var inches_RE: NSRegularExpression
    var feet_inches_RE: NSRegularExpression
    var mm_RE: NSRegularExpression

    override init()
    {
        inches_RE = try! NSRegularExpression(pattern: "(.*)(\")", options: NSRegularExpressionOptions())
        feet_inches_RE = try! NSRegularExpression(pattern: "(.*)'\\s*(.*)\"?", options: NSRegularExpressionOptions())
        mm_RE = try! NSRegularExpression(pattern: "(.*)mm", options: NSRegularExpressionOptions())
        super.init()
    }
    
    override class func allowsReverseTransformation() -> Bool
    {
        return true
    }
    
    override func transformedValue(value: AnyObject?) -> AnyObject?
    {
        if let n = value as? NSNumber
        {
            var v = n.doubleValue
            
            switch defaultUnits {
                case "in":
                    v /= 100.0
                    return NSString(format: "%0.6g\"", v)
                case "ft":
                    v /= 100.0
                    let ft = Int(v) / 12
                    let inches = v - Double(ft) * 12.0
                    if ft > 0 {
                        return NSString(format: "%d'%0.6g\"", ft, inches)
                    } else {
                        return NSString(format: "%0.6g\"", inches)
                    }
                case "mm":
                    v /= 100.0 / 25.4
                    return NSString(format: "%0.6gmm", v)
                default:
                    return "\(v)pt"
            }
        }
        else
        {
            return "-0"
        }
    }
    
    override func reverseTransformedValue(value: AnyObject?) -> AnyObject?
    {
        if let s = value as? NSString
        {
            let all = NSMakeRange(0, s.length)
            if 0 < feet_inches_RE.numberOfMatchesInString(s as String, options: NSMatchingOptions(), range: all)
            {
                let m = feet_inches_RE.firstMatchInString(s as String, options: NSMatchingOptions(), range: all)
                if let r = m?.rangeAtIndex(1)
                {
                    let sn: NSString = s.substringWithRange(r)
                    let feet = sn.doubleValue
                    let r2 = m!.rangeAtIndex(2)
                    let sn2: NSString = s.substringWithRange(r2)
                    return (feet * 12 + sn2.doubleValue) * 100.0
                }
            }
            if 0 < inches_RE.numberOfMatchesInString(s as String, options: NSMatchingOptions(), range: all)
            {
                let m = inches_RE.firstMatchInString(s as String, options: NSMatchingOptions(), range: all)
                if let r = m?.rangeAtIndex(1)
                {
                    let sn: NSString = s.substringWithRange(r)
                    return sn.doubleValue * 100.0
                }
            }
            if 0 < mm_RE.numberOfMatchesInString(s as String, options: NSMatchingOptions(), range: all)
            {
                let m = mm_RE.firstMatchInString(s as String, options: NSMatchingOptions(), range: all)
                if let r = m?.rangeAtIndex(1)
                {
                    let sn: NSString = s.substringWithRange(r)
                    return sn.doubleValue * 100.0 / 25.4
                }
            }
            
            switch defaultUnits {
                case "ft", "in":
                    return s.doubleValue * 100.0
                case "mm":
                    return s.doubleValue * 100 / 25.4
                default:
                    return s.doubleValue
            }
        }
        else
        {
            return 0
        }
    }
}

class AngleTransformer: NSValueTransformer
{
    override func transformedValue(value: AnyObject?) -> AnyObject? {
        if let n = value as? NSNumber {
            let v = n.doubleValue
            
            return NSString(format: "%0.2f°", v * (180.0 / 3.1415926535))
        }
        return "?"
    }
    
    override func reverseTransformedValue(value: AnyObject?) -> AnyObject? {
        if let s = value as? NSString {
            return s.doubleValue / (180.0 / 3.1415926535)
        }
        return 0
    }
}

class GraphicInspector: NSView
{
    var view: DrawingView?
    var selection: Graphic?
    var info: [String:(NSTextField, NSValueTransformer, NSTextField)] = [:]
    
    override func drawRect(dirtyRect: CGRect)
    {
        NSEraseRect(dirtyRect)
    }
    
    func removeAllSubviews()
    {
        for key in info.keys {
            if let (field, _, label) = info[key] {
                label.removeFromSuperview()
                field.removeFromSuperview()
            }
        }
        info = [:]
    }
    
    @IBAction func fieldChanged(sender: AnyObject)
    {
        NSLog("field changed: \(sender)\n")
        for (key, (field, xfrm, _)) in info {
            if field == sender as! NSTextField {
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
    
    func beginInspection(graphic: Graphic)
    {
        self.selection = graphic
        let keys = graphic.inspectionKeys()
        
        removeAllSubviews()
        
        var location = CGPoint(x: 10, y: 3)
        var lastField: NSTextField? = nil
        
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
            field.action = "fieldChanged:"
            lastField?.nextKeyView = field
            lastField = field
            self.addSubview(field)
            
            let transformer = graphic.transformerForKey(key)

            info[key] = (field, transformer, label)
            
            location.x += 100
            
            field.bind("stringValue", toObject: graphic, withKeyPath: key, options: [NSValueTransformerBindingOption: transformer, NSContinuouslyUpdatesValueBindingOption: true])
            
        }
    }
}
