//
//  SelectionTool.swift
//  Electra
//
//  Created by Matt Brandt on 7/25/14.
//  Copyright (c) 2014 WalkingDog Design. All rights reserved.
//

import Cocoa

enum SelectionMode {
    case select, moveSelected, moveHandle
}

extension Array
{
    func contains<T : Equatable>(_ obj: T) -> Bool {
        return self.filter({$0 as? T == obj}).count > 0
    }
}

class SelectTool: GraphicTool
{
    var mode: SelectionMode = SelectionMode.select
    var selectedHandle = 0
    var selectOrigin = CGPoint(x: 0, y: 0)
    var selectedGraphic: Graphic?
    var restoreOnMove = false
    
    override func selectTool(_ view: DrawingView) {
        view.setDrawingHint("Select objects")
    }
    
    override func escape(_ view: DrawingView) {
        view.selection = []
        view.snapConstructions = []
    }
    
    override func mouseDown(_ location: CGPoint, view: DrawingView) {
        if view.mouseClickCount == 2 {
            if view.selection.count == 1 {
                let g = view.selection[0]
                g.editDoubleClick(location, view: view)
                return
            }
        }
        let handleSize = view.scaleFloat(HSIZE)
        mode = SelectionMode.select
        restoreOnMove = false
        selectOrigin = location
        let radius = view.scaleFloat(SELECT_RADIUS)
        if let g = view.closestGraphicToPoint(location, within: radius) {
            mode = SelectionMode.moveSelected
            if view.selection.count == 0 || !view.selection.contains(g) {
                view.selection = [g]
                view.setNeedsDisplay(view.bounds)
            } else if view.selection.count == 1 {
                for i in 0 ..< g.points.count {
                    let p = g.points[i]
                    if p.distanceToPoint(location) < handleSize {
                        selectedGraphic = g
                        selectedHandle = i
                        mode = SelectionMode.moveHandle
                        g.addReshapeSnapConstructionsAtPoint(p, toView: view)
                        break
                    }
                }
            }
            restoreOnMove = true
        }
    }
    
    override func mouseDragged(_ location: CGPoint, view: DrawingView)
    {
        let handleSize = view.scaleFloat(HSIZE)
        
        switch mode {
        case SelectionMode.select:
            view.selectionRect = rectContainingPoints([selectOrigin, location])
            view.selectObjectsInRect(view.selectionRect)
            view.needsDisplay = true
            
        case SelectionMode.moveSelected:
            let delta = location - selectOrigin
            selectOrigin = location
            for g in view.selection {
                view.setNeedsDisplay(NSInsetRect(g.bounds, -handleSize, -handleSize))
                moveGraphic(g, byVector: delta, inView: view)
                view.setNeedsDisplay(NSInsetRect(g.bounds, -handleSize, -handleSize))
            }
            
        case SelectionMode.moveHandle:
            if let graphic = selectedGraphic {
                view.setNeedsDisplay(graphic.bounds.insetBy(dx: -handleSize, dy: -handleSize))
                setPoint(location, atIndex: selectedHandle, forGraphic: graphic, inView: view)
                view.setNeedsDisplay(graphic.bounds.insetBy(dx: -handleSize, dy: -handleSize))
            }
        }
        restoreOnMove = false
    }
    
    override func mouseMoved(_ location: CGPoint, view: DrawingView) {
    }
    
    override func mouseUp(_ location: CGPoint, view: DrawingView) {
        view.removeSnapConstructionsForReference(selectedGraphic)
        if mode == SelectionMode.select {
            view.selectionRect = CGRect(x: 0, y: 0, width: 0, height: 0)
            view.selectObjectsInRect(rectContainingPoints([selectOrigin, location]))
            view.setNeedsDisplay(view.bounds)
        }
    }
    
    func moveGraphic(_ graphic: Graphic, toPoint point: CGPoint, inView view: DrawingView) {
        let handleSize = view.scaleFloat(HSIZE)
        view.setNeedsDisplay(NSInsetRect(graphic.bounds, -handleSize, -handleSize))
        view.undoManager?.prepare(withInvocationTarget: self).moveGraphic(graphic, toPoint: graphic.origin, inView: view)
        graphic.moveOriginTo(point)
        view.setNeedsDisplay(NSInsetRect(graphic.bounds, -handleSize, -handleSize))
    }
    
    func moveGraphic(_ graphic: Graphic, byVector vector: CGPoint, inView view: DrawingView) {
        if restoreOnMove {
            view.undoManager?.prepare(withInvocationTarget: self).moveGraphic(graphic, toPoint: graphic.origin, inView: view)
        }
        graphic.moveOriginBy(vector)
    }
    
    func setPoint(_ point: CGPoint, atIndex index: Int, forGraphic graphic: Graphic, inView view: DrawingView)
    {
        let handleSize = view.scaleFloat(HSIZE)
        if restoreOnMove {
            let oldLocation = graphic.points[index]
            view.undoManager?.prepare(withInvocationTarget: self).setPoint(oldLocation, atIndex: index, forGraphic: graphic, inView: view)
        }
        view.setNeedsDisplay(NSInsetRect(graphic.bounds, -handleSize, -handleSize))
        graphic.setPoint(point, atIndex: index)
        view.setNeedsDisplay(NSInsetRect(graphic.bounds, -handleSize, -handleSize))
    }
}
