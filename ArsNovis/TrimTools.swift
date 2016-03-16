//
//  TrimTools.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/16/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class TrimToTool: GraphicTool
{
    override func selectTool(view: DrawingView) {
        if view.selection.count == 0 {
            view.setDrawingHint("Hold control and select trim barriers")
        } else {
            view.setDrawingHint("Trim to: Click on section to retain")
        }
    }
    
    override func escape(view: DrawingView) {
        view.selection = []
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        if view.controlKeyDown {
            if let g = view.closestGraphicToPoint(location, within: SnapRadius) {
                if view.selection.contains(g) {
                    view.selection = view.selection.filter { return $0 != g }
                } else {
                    view.selection.append(g)
                }
                view.needsDisplay = true
            }
        } else if view.selection.count > 0 {
            if let g = view.closestGraphicToPoint(location, within: SnapRadius) {
                let trimGroup = GroupGraphic(contents: view.selection)
                var intersections = trimGroup.intersectionsWithGraphic(g, extendSelf: false, extendOther: true)
                intersections = intersections.sort { return $0.distanceToPoint(location) < $1.distanceToPoint(location) }
                if intersections.count > 0 {
                    let trimLocation = intersections[0]
                    
                    let gs = g.divideAtPoint(trimLocation).sort { $0.distanceToPoint(location) < $1.distanceToPoint(location) }
                    view.deleteGraphic(g)
                    view.addGraphic(gs[0])
                    view.construction = nil
                    view.needsDisplay = true
                }
            }
        }
    }
    
    override func mouseMoved(location: CGPoint, view: DrawingView) {
        if view.selection.count > 0 {
            if let g = view.closestGraphicToPoint(location, within: SnapRadius) {
                let trimGroup = GroupGraphic(contents: view.selection)
                var intersections = trimGroup.intersectionsWithGraphic(g, extendSelf: false, extendOther: true)
                intersections = intersections.sort { return $0.distanceToPoint(location) < $1.distanceToPoint(location) }
                if intersections.count > 0 {
                    let trimLocation = intersections[0]
                    let visualCue = Graphic(origin: trimLocation)
                    visualCue.fillColor = NSColor.redColor()
                    view.construction = visualCue
                }
            }
        }
    }
}

class TrimFromTool: TrimToTool
{
    override func selectTool(view: DrawingView) {
        if view.selection.count == 0 {
            view.setDrawingHint("Hold control and select trim barriers")
        } else {
            view.setDrawingHint("Trim from: Click on section to delete")
        }
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        if view.controlKeyDown {
            if let g = view.closestGraphicToPoint(location, within: SnapRadius) {
                if view.selection.contains(g) {
                    view.selection = view.selection.filter { return $0 != g }
                } else {
                    view.selection.append(g)
                }
                view.needsDisplay = true
            }
        } else if view.selection.count > 0 {
            if let g = view.closestGraphicToPoint(location, within: SnapRadius) {
                let trimGroup = GroupGraphic(contents: view.selection)
                var intersections = trimGroup.intersectionsWithGraphic(g, extendSelf: false, extendOther: false)
                intersections = intersections.sort { return $0.distanceToPoint(location) < $1.distanceToPoint(location) }
                if intersections.count > 0 {
                    let trimLocation = intersections[0]
                    
                    let gs = g.divideAtPoint(trimLocation).sort { $0.distanceToPoint(location) > $1.distanceToPoint(location) }
                    view.deleteGraphic(g)
                    view.addGraphic(gs[0])
                    view.construction = nil
                    view.needsDisplay = true
                }
            }
        }
    }
}

class BreakAtTool: TrimToTool
{
    override func selectTool(view: DrawingView) {
        if view.selection.count == 0 {
            view.setDrawingHint("Hold control and select trim barriers")
        } else {
            view.setDrawingHint("Trim from: Click on section to divide near barrier")
        }
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        if view.controlKeyDown {
            if let g = view.closestGraphicToPoint(location, within: SnapRadius) {
                if view.selection.contains(g) {
                    view.selection = view.selection.filter { return $0 != g }
                } else {
                    view.selection.append(g)
                }
                view.needsDisplay = true
            }
        } else if view.selection.count > 0 {
            if let g = view.closestGraphicToPoint(location, within: SnapRadius) {
                let trimGroup = GroupGraphic(contents: view.selection)
                var intersections = trimGroup.intersectionsWithGraphic(g, extendSelf: false, extendOther: false)
                intersections = intersections.sort { return $0.distanceToPoint(location) < $1.distanceToPoint(location) }
                if intersections.count > 0 {
                    let trimLocation = intersections[0]
                    
                    let gs = g.divideAtPoint(trimLocation).sort { $0.distanceToPoint(location) > $1.distanceToPoint(location) }
                    view.deleteGraphic(g)
                    view.addGraphics(gs)
                    view.selection = gs
                    view.construction = nil
                    view.needsDisplay = true
                }
            }
        }
    }
}

class JoinTool: GraphicTool
{
    var primary: Graphic?
    var startLoc = CGPoint()
    
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Join Tool: Click and drag between two endpoints to join")
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        primary = view.closestGraphicToPoint(location, within: SnapRadius)
        startLoc = location
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView) {
        if primary != nil {
            view.redrawConstruction()
            let lg = LineGraphic(origin: startLoc, endPoint: location)
            lg.lineWidth = 0
            lg.lineColor = NSColor.redColor()
            view.construction = lg
            view.redrawConstruction()
        }
    }
    
    override func mouseUp(location: CGPoint, view: DrawingView) {
        view.redrawConstruction()
        view.construction = nil
        if let primary = primary {
            if let secondary = view.closestGraphicToPoint(location, within: SnapRadius) {
                let p1 = primary.extendToIntersectionWith(secondary, closeToPoint: startLoc)
                let s1 = secondary.extendToIntersectionWith(primary, closeToPoint: location)
                view.deleteGraphics([primary, secondary])
                view.addGraphics([p1, s1])
                view.needsDisplay = true
            }
        }
    }
}