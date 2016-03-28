//
//  AppDelegate.swift
//  ArsNovis
//
//  Created by Matt Brandt on 1/21/15.
//  Copyright (c) 2015 WalkingDog Design. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{
    func applicationDidFinishLaunching(aNotification: NSNotification)
    {
        expressionTest()
    }

    func applicationWillTerminate(aNotification: NSNotification)
    {
    }


}

func expressionTest() {
    let line = LineGraphic(origin: CGPoint(x: 100, y: 100), endPoint: CGPoint(x: 200, y: 100))
    
    let pcontext = ParametricContext()
    
    var expr1 = try! ParametricParser(context: pcontext, string: "2' + Width").expression()
    var expr2 = try! ParametricParser(context: pcontext, string: "Height + 30 3/4 in").expression()
    pcontext.assign(line, property: "length", expression: expr1)
    pcontext.assign(line, property: "x", expression: expr2)
    pcontext.setValue(CGFloat(1700), forUndefinedKey: "Width")
    pcontext.setValue(CGFloat(1000), forUndefinedKey: "Height")
    pcontext.resolve()
    print("expr1 = \(expr1.value)")
    print("expr2 = \(expr2.value)")
}