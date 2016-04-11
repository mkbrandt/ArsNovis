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
        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints")
    }

    func applicationWillTerminate(aNotification: NSNotification)
    {
    }
}
