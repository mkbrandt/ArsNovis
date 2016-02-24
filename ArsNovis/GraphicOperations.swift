//
//  GraphicOperations.swift
//  ArsNovis
//
//  Created by Matt Brandt on 1/21/15.
//  Copyright (c) 2015 WalkingDog Design. All rights reserved.
//

import Foundation

let iota = 0.000000001
let PI: CGFloat = 3.14159265357

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

extension CGPoint
{
    init(length: CGFloat, angle: CGFloat) {
        let x0 = length * cos(angle)
        let y0 = length * sin(angle)
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
            x = len * cos(newValue)
            y = len * sin(newValue)
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
