//
//  SelectionTool.swift
//  Electra
//
//  Created by Matt Brandt on 7/25/14.
//  Copyright (c) 2014 WalkingDog Design. All rights reserved.
//

import Cocoa

enum SelectionMode {
    case Select, MoveSelected, MoveHandle
}

extension Array
{
    func contains<T : Equatable>(obj: T) -> Bool {
        return self.filter({$0 as? T == obj}).count > 0
    }
}

class SelectTool: GraphicTool
{
    var mode: SelectionMode = SelectionMode.Select
    var selectedHandle = 0
    var selectOrigin = CGPoint(x: 0, y: 0)
    var selectedGraphic: Graphic?
    var restoreOnMove = false
    
    override func selectTool(view: DrawingView) {
        view.setDrawingHint("Select objects")
    }
    
    override func mouseDown(location: CGPoint, view: DrawingView) {
        mode = SelectionMode.Select
        restoreOnMove = false
        selectOrigin = location
        if let g = view.closestGraphicToPoint(location, within: SELECT_RADIUS) {
            mode = SelectionMode.MoveSelected
            if view.selection.count == 0 || !view.selection.contains(g) {
                view.selection = [g]
                view.setNeedsDisplayInRect(view.bounds)
            } else if view.selection.count == 1 {
                for var i = 0; i < g.points.count; ++i {
                    let p = g.points[i]
                    if p.distanceToPoint(location) < HSIZE {
                        selectedGraphic = g
                        selectedHandle = i
                        mode = SelectionMode.MoveHandle
                        break
                    }
                }
            }
            restoreOnMove = true
        }
    }
    
    override func mouseDragged(location: CGPoint, view: DrawingView)
    {
        let delta = location - selectOrigin
        selectOrigin = location
        
        switch mode {
        case SelectionMode.Select:
            view.selectionRect = rectContainingPoints([selectOrigin, location])
            view.selectObjectsInRect(view.selectionRect)
            view.setNeedsDisplayInRect(view.bounds)
            
        case SelectionMode.MoveSelected:
            for g in view.selection {
                view.setNeedsDisplayInRect(NSInsetRect(g.bounds, -HSIZE, -HSIZE))
                moveGraphic(g, byVector: delta, inView: view)
                view.setNeedsDisplayInRect(NSInsetRect(g.bounds, -HSIZE, -HSIZE))
            }
            
        case SelectionMode.MoveHandle:
            view.setNeedsDisplayInRect(NSInsetRect(selectedGraphic!.bounds, -HSIZE, -HSIZE))
            setPoint(location, atIndex: selectedHandle, forGraphic: selectedGraphic!, inView: view)
            view.setNeedsDisplayInRect(NSInsetRect(selectedGraphic!.bounds, -HSIZE, -HSIZE))
        }
        restoreOnMove = false
    }
    
    override func mouseMoved(location: CGPoint, view: DrawingView) {
    }
    
    override func mouseUp(location: CGPoint, view: DrawingView) {
        if mode == SelectionMode.Select {
            view.selectionRect = CGRect(x: 0, y: 0, width: 0, height: 0)
            view.selectObjectsInRect(rectContainingPoints([selectOrigin, location]))
            view.setNeedsDisplayInRect(view.bounds)
        } else {
            mouseDragged(location, view: view)
        }
    }
    
    func moveGraphic(graphic: Graphic, toPoint point: CGPoint, inView view: DrawingView) {
        view.setNeedsDisplayInRect(NSInsetRect(graphic.bounds, -HSIZE, -HSIZE))
        view.undoManager?.prepareWithInvocationTarget(self).moveGraphic(graphic, toPoint: graphic.origin, inView: view)
        graphic.moveOriginTo(point)
        view.setNeedsDisplayInRect(NSInsetRect(graphic.bounds, -HSIZE, -HSIZE))
    }
    
    func moveGraphic(graphic: Graphic, byVector vector: CGPoint, inView view: DrawingView) {
        if restoreOnMove {
            view.undoManager?.prepareWithInvocationTarget(self).moveGraphic(graphic, toPoint: graphic.origin, inView: view)
        }
        graphic.moveOriginBy(vector)
    }
    
    func setPoint(point: CGPoint, atIndex index: Int, forGraphic graphic: Graphic, inView view: DrawingView)
    {
        if restoreOnMove {
            let oldLocation = graphic.points[index]
            view.undoManager?.prepareWithInvocationTarget(self).setPoint(oldLocation, atIndex: index, forGraphic: graphic, inView: view)
        }
        view.setNeedsDisplayInRect(NSInsetRect(graphic.bounds, -HSIZE, -HSIZE))
        graphic.setPoint(point, atIndex: index)
        view.setNeedsDisplayInRect(NSInsetRect(graphic.bounds, -HSIZE, -HSIZE))
    }
}
