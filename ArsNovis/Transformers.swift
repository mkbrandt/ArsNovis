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
    var frac_RE = RegularExpression(pattern: "([[:digit:]]*)[[:space:]]*/[[:space:]]*([[:digit:]]*)")
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    func fractionString(f: Double) -> NSString {
        let oneSixtyFourth = 1.0 / 64.0
        var numerator = Int(round(f / oneSixtyFourth))
        if numerator == 0 {
            return ""
        }
        var denominator = 64
        while numerator % 2 == 0 {
            numerator /= 2
            denominator /= 2
        }
        return NSString(format: "%d/%d", numerator, denominator)
    }
    
    override func transformedValue(value: AnyObject?) -> AnyObject? {
        if let n = value as? NSNumber {
            var v = n.doubleValue
            
            switch measurementUnits {
            case .Inches_frac:
                v /= 100.0
                let whole = Int(v)
                let frac = v - Double(whole)
                let fracStr = fractionString(frac)
                return NSString(format: "%d %s\"", whole, fracStr)
            case .Feet_frac:
                v /= 100.0
                let ft = Int(v) / 12
                let inches = Int(v - Double(ft) * 12.0)
                let frac = v - Double(ft * 12 + inches)
                if ft > 0 {
                    return NSString(format: "%d'%d %@\"", ft, inches, fractionString(frac))
                } else {
                    return NSString(format: "%d %@\"", inches, fractionString(frac))
                }
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
                if frac_RE.matchesWithString(feet_inches_RE.suffix) {
                    if let num_s = frac_RE.match(1), let denom_s = frac_RE.match(2),
                        let numerator = Double(num_s), let denominator = Double(denom_s) {
                            value += numerator / denominator
                    }
                }
                return value * 100
            }
            
            if inches_RE.matchesWithString(s) {
                var value = 0.0
                if let inString = inches_RE.match(1) {
                    if let v = Double(inString) {
                        value = v * 100
                    }
                }
                if frac_RE.matchesWithString(inches_RE.suffix) {
                    if let num_s = frac_RE.match(1), let denom_s = frac_RE.match(2),
                        let numerator = Double(num_s), let denominator = Double(denom_s) {
                            value += numerator / denominator
                    }
                }
                return value
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

