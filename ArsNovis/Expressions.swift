//
//  FieldTransformers.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/9/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Foundation

@objc(DistanceTransformer) class DistanceTransformer: NSValueTransformer
{
    var inches_RE = RegularExpression(pattern: "([[:digit:]\\.]*)(\")")
    var feet_inches_RE = RegularExpression(pattern: "([[:digit:]\\.]*)'[[:space:]]*([[:digit:]\\.]*)\"?")
    var mm_RE = RegularExpression(pattern: "([[:digit:]\\.]*)mm")
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(value: AnyObject?) -> AnyObject? {
        if let n = value as? NSNumber {
            var v = n.doubleValue
            
            switch measurementUnits {
            case .Inches_dec:
                v /= 100.0
                return NSString(format: "%0.6g\"", v)
            case .Feet_dec:
                v /= 100.0
                let ft = Int(v) / 12
                let inches = v - Double(ft) * 12.0
                if ft > 0 {
                    return NSString(format: "%d'%0.6g\"", ft, inches)
                } else {
                    return NSString(format: "%0.6g\"", inches)
                }
            case .Millimeters:
                v /= 100.0 / 25.4
                return NSString(format: "%0.6gmm", v)
            default:
                return "\(v)pt"
            }
        } else {
            return "-0"
        }
    }
    
    override func reverseTransformedValue(value: AnyObject?) -> AnyObject? {
        if let s = value as? String {
            if feet_inches_RE.matchesWithString(s) {
                var value = 0.0
                if let ftString = feet_inches_RE.match(1) {
                    if let v = Double(ftString) {
                        value = v * 12.0
                    }
                }
                if let inString = feet_inches_RE.match(2) {
                    if let v = Double(inString) {
                        value += v
                    }
                }
                return value * 100
            }
            
            if inches_RE.matchesWithString(s) {
                if let inString = inches_RE.match(1) {
                    if let v = Double(inString) {
                        return v * 100
                    }
                }
            }
            
            if mm_RE.matchesWithString(s) {
                if let mmString = mm_RE.match(1) {
                    if let v = Double(mmString) {
                        return v * 100 / 25.4
                    }
                }
            }
            
            let v = Double(s) ?? 0.0
            
            switch measurementUnits {
            case .Feet_dec, .Inches_dec, .Feet_frac, .Inches_frac:
                return v * 100.0
            case .Millimeters, .Meters:
                return v * 100 / 25.4
            }
        } else {
            return 0
        }
    }
}

@objc(AngleTransformer) class AngleTransformer: NSValueTransformer
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

func distanceFromString(s: String) -> CGFloat {
    let transformer = DistanceTransformer()
    if let num = transformer.reverseTransformedValue(s) {
        return CGFloat(num.doubleValue)
    }
    return 0.0
}

func stringFromDistance(d: CGFloat) -> String {
    let transformer = DistanceTransformer()
    
    if let s = transformer.transformedValue(d) as? String {
        return s
    }
    return "-0"
}

enum ParseToken {
    case Number(CGFloat)
    case ID(String)
    case Operator(String)
    case Error(String)
}

class StringParser
{
    let EOF: Character = "\0"
    var content = ""
    var location: String.Index
    var lastch: Character {
        if location == content.endIndex {
            return EOF
        }
        return content[location]
    }
    
    init(string: String) {
        content = string
        location = content.startIndex
    }
    
    func nextch() {
        if lastch != EOF {
            location = location.successor()
        }
    }
    
    func skipSpace() {
        while lastch == " " || lastch == "\n" || lastch == "\t" {
            nextch()
        }
    }
    
    func isUpperCase(c: Character) -> Bool {
        switch c {
        case "A"..."Z":
            return true
        default:
            return false
        }
    }
    
    func isLowerCase(c: Character) -> Bool {
        switch c {
        case "a"..."z":
            return true
        default:
            return false
        }
    }
    
    func isDigit(c: Character) -> Bool {
        switch c {
        case "0"..."9":
            return true
        default:
            return false
        }
    }
    
    func isAlpha(c: Character) -> Bool { return isUpperCase(c) || isLowerCase(c) }
    func isAlphaNumeric(c: Character) -> Bool { return isAlpha(c) || isDigit(c) }
    
    func nextToken() -> ParseToken {
        skipSpace()
        switch lastch {
        case "A"..."Z", "a"..."Z":
            var s = ""
            while isAlphaNumeric(lastch) {
                s.append(lastch)
                nextch()
            }
            return .ID(s)
        case "0"..."9":
            var s = ""
            while isDigit(lastch) {
                s.append(lastch)
                nextch()
            }
            if lastch == "." {
                s.append(lastch)
                nextch()
                while isDigit(lastch) {
                    s.append(lastch)
                    nextch()
                }
            }
            if lastch == "e" || lastch == "E" {
                s.append(lastch)
                nextch()
                if lastch == "-" {
                    s.append(lastch)
                    nextch()
                }
                while isDigit(lastch) {
                    s.append(lastch)
                    nextch()
                }
            }
            if let v = Double(s) {
                return .Number(CGFloat(v))
            }
            return .Error("bad number")
        case "+", "-", "*", "/", "(", ")", "\"", "'":
            let op = String(lastch)
            nextch()
            return .Operator(op)
        default:
            let char = lastch
            nextch()
            return .Error("bad char '\(char)")
        }
    }
}
