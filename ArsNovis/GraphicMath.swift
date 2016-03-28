//
//  GraphicOperations.swift
//  ArsNovis
//
//  Created by Matt Brandt on 1/21/15.
//  Copyright (c) 2015 WalkingDog Design. All rights reserved.
//

import Foundation

let IOTA: CGFloat = 0.000000001
let PI: CGFloat = CGFloat(M_PI)

// MARK: Point Math

func +(a: CGPoint, b: CGPoint) -> CGPoint {
    return CGPoint(x: a.x + b.x, y: a.y + b.y)
}

func -(a: CGPoint, b: CGPoint) -> CGPoint {
    return CGPoint(x: a.x - b.x, y: a.y - b.y)
}

func *(b: CGFloat, a: CGPoint) -> CGPoint {
    return CGPoint(x: a.x * b, y: a.y * b)
}

func *(a: CGPoint, b: CGFloat) -> CGPoint {
    return CGPoint(x: a.x * b, y: a.y * b)
}

func /(a: CGPoint, b: CGFloat) -> CGPoint {
    return CGPoint(x: a.x / b, y: a.y / b)
}

func crossProduct(a: CGPoint, _ b: CGPoint) -> CGFloat {
    return a.x * b.y - a.y * b.x
}

func dotProduct(a: CGPoint, _ b: CGPoint) -> CGFloat {
    return a.x * b.x + a.y * b.y
}

// MARK: Rect and Size manipulation

func +(a: CGRect, b: CGRect) -> CGRect {
    if a.isEmpty {
        return b
    } else if b.isEmpty {
        return a
    }
    return a.union(b)
}

func +(a: CGSize, b: CGSize) -> CGSize {
    return CGSize(width: a.width + b.width, height: a.height + b.height)
}

func -(a: CGSize, b: CGSize) -> CGSize {
    return CGSize(width: a.width - b.width, height: a.height - b.height)
}

func *(a: CGSize, b: CGFloat) -> CGSize {
    return CGSize(width: a.width * b, height: a.height * b)
}

func /(a: CGSize, b: CGFloat) -> CGSize {
    return CGSize(width: a.width / b, height: a.height / b)
}

func rectContainingPoints(array: [CGPoint]) -> CGRect {
    var x_min = CGFloat.infinity
    var x_max = -CGFloat.infinity
    var y_min = CGFloat.infinity
    var y_max = -CGFloat.infinity
    
    for p in array
    {
        if( p.x < x_min ) { x_min = p.x }
        if( p.x > x_max ) { x_max = p.x }
        if( p.y < y_min ) { y_min = p.y }
        if( p.y > y_max ) { y_max = p.y }
    }
    if x_min == x_max { x_min -= 0.001; x_max += 0.001 }
    if y_min == y_max { y_min -= 0.001; y_max += 0.001 }
    
    return CGRect(x: x_min, y: y_min, width: x_max - x_min, height: y_max - y_min)
}

// MARK: utilities

func constrainTo45Degrees(location: CGPoint, relativeToPoint startPoint: CGPoint) -> CGPoint {
    let delta = location - startPoint
    let maxoffset = max(abs(delta.x), abs(delta.y))
    return startPoint + CGPoint(x: sign(delta.x) * maxoffset, y: sign(delta.y) * maxoffset)
}

func sign(f: CGFloat) -> CGFloat {
    if f < 0 {
        return -1
    }
    return 1
}

func normalizeAngle(angle: CGFloat) -> CGFloat {
    var angle = angle
    while angle > PI {
        angle -= 2 * PI
    }
    while angle < -PI {
        angle += 2 * PI
    }
    return angle
}

// MARK: Class Extensions

extension CGPoint
{
    init(length: CGFloat, angle: CGFloat) {
        var cosa = cos(angle)
        if abs(cosa) < 1e-15 {
            cosa = 0
        }
        var sina = sin(angle)
        if abs(sina) < 1e-15 {
            sina = 0
        }
        let x0 = length * cosa
        let y0 = length * sina
        self.init(x: x0, y: y0)
    }
    
    var length: CGFloat {
        get { return sqrt(x * x + y * y) }
        set {
            let ratio = newValue / length
            x *= ratio
            y *= ratio
        }
    }
    
    var angle: CGFloat {
        get { return atan2(y, x) }
        set {
            let len = length
            var cosa = cos(newValue)            // cos(acos(0)) is not zero!
            if abs(cosa) < 1e-15 {
                cosa = 0
            }
            var sina = sin(newValue)
            if abs(sina) < 1e-15 {
                sina = 0
            }
            x = len * cosa
            y = len * sina
        }
    }
    
    func distanceToPoint(point: CGPoint) -> CGFloat {
        return (point - self).length
    }
    
    mutating func scale(s: CGFloat) {
        x *= s
        y *= s
    }
}

extension CGRect
{
    var center: CGPoint         { return CGPoint(x: origin.x + size.width / 2, y: origin.y + size.height / 2) }
    var top: CGFloat            { return origin.y + size.height }
    var left: CGFloat           { return origin.x }
    var bottom: CGFloat         { return origin.y }
    var right: CGFloat          { return origin.x + size.width }
    var topLeft: CGPoint        { return CGPoint(x: left, y: top) }
    var bottomLeft: CGPoint     { return CGPoint(x: left, y: bottom) }
    var topRight: CGPoint       { return CGPoint(x: right, y: top) }
    var bottomRight: CGPoint    { return CGPoint(x: right, y: bottom) }
}
