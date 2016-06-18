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
    func applicationDidFinishLaunching(_ aNotification: Notification)
    {
        UserDefaults.standard().register(appDefaults)
        UserDefaults.standard().set(true, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraints")
    }

    func applicationWillTerminate(_ aNotification: Notification)
    {
    }
}
