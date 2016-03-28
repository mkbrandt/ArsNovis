//
//  ZoomView.swift
//  ArsNovis
//
//  Created by Matt Brandt on 2/24/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

struct ZoomState {
    var scale: CGFloat
    var centerPoint: CGPoint
}

class ZoomView: NSView
{
    @IBOutlet var widthConstraint: NSLayoutConstraint!
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    
    var pageRect: CGRect?       { return nil }                // force view bounds to this size if present
    var scale: CGFloat = 1.0
    var minimumScale: CGFloat = 0.0001
    var maximumScale: CGFloat = 100000.0
    var constrainViewToSuperview = true                         // set to false when printing
    
    var contentRect: CGRect { return CGRect(x: 0, y: 0, width: 0, height: 0) }      // override to always enclose content
    var contentMarginRect: CGRect {
        var rect = contentRect
        let margin = max(rect.size.width, rect.size.height) * 0.1
        rect.origin.x -= margin
        rect.origin.y -= margin
        rect.size.width += 2 * margin
        rect.size.height += 2 * margin
        return rect
    }
    
    var fixedSize: CGSize = CGSize(width: 1280, height: 1024)
    
    var fullVisibleRect: CGRect {
        if let superview = superview {
            return convertRect(superview.bounds, fromView: superview)
        }
        return visibleRect
    }
    
    var zoomCenter: CGPoint?
    var lastVisibleRect = CGRect()
    var previousVisibleRect = CGRect()
    
    var centeredPointInDocView: CGPoint {
        return visibleRect.center
    }
    
    var zoomState: ZoomState {
        get { return ZoomState(scale: scale, centerPoint: centeredPointInDocView) }
        set {
            zoomToAbsoluteScale(newValue.scale)
            scrollPointToCenter(newValue.centerPoint)
        }
    }
    
    override var intrinsicContentSize: CGSize {
        return fixedSize
    }
    
    @IBAction func zoomIn(sender: NSObject) {
        zoomByFactor(2.0)
    }
    
    @IBAction func zoomOut(sender: NSObject) {
        zoomByFactor(0.5)
    }
    
    @IBAction func zoomActualSize(sender: NSObject) {
        zoomToAbsoluteScale(1.0)
    }
    
    @IBAction func zoomToFit(sender: NSObject) {
        if let pageRect = pageRect {
            zoomToFitRect(pageRect)
        } else {
            zoomToFitRect(contentMarginRect)
        }
    }
    
    func zoomByFactor(factor: CGFloat) {
        zoomByFactor(factor, aroundPoint: centeredPointInDocView)
    }
    
    func zoomToAbsoluteScale(scale: CGFloat) {
        let factor = scale / self.scale
        zoomByFactor(factor)
    }
    
    func zoomToFitRect(rect: CGRect) {
        let sx = fullVisibleRect.size.width / rect.size.width
        let sy = fullVisibleRect.size.height / rect.size.height
        zoomByFactor(min(sx, sy))
        scrollRectToVisible(rect)
    }
    
    override func scrollWheel(theEvent: NSEvent) {
        if theEvent.modifierFlags.contains(.ControlKeyMask) {
            let factor: CGFloat = 1.0 - theEvent.deltaY * 0.04
            var mouseloc = convertPoint(theEvent.locationInWindow, fromView: nil)
            
            if let zc = zoomCenter {
                mouseloc = zc
            }
            
            zoomByFactor(factor, aroundPoint: mouseloc)
        } else {
            super.scrollWheel(theEvent)
        }
    }
    
    func checkViewBoundries() {
        zoomByFactor(2)
        zoomByFactor(0.5)
    }
    
    func zoomByFactor(factor: CGFloat, aroundPoint point: CGPoint) {
        var factor = factor
        if factor != 1.0 {
            var newScale = factor * scale
            
            if newScale < minimumScale {
                newScale = minimumScale
                factor = newScale / scale
            }
            
            if newScale > maximumScale {
                newScale = maximumScale
                factor = newScale / scale
            }
            
            //Swift.print("Zoom by \(factor) around \(point)   scale = \(newScale)")
            if newScale != scale {
                let originVector = (point - fullVisibleRect.origin) / factor
                let newVisibleSize = CGSize(width: fullVisibleRect.width / factor, height: fullVisibleRect.height / factor)
                let newVisibleRect = CGRect(origin: point - originVector, size: newVisibleSize)
                //Swift.print("  visible = \(newVisibleRect)")
                
                previousVisibleRect = lastVisibleRect
                lastVisibleRect = newVisibleRect
                
                scale = newScale
                var newBounds = contentMarginRect
                newBounds = newBounds.union(newVisibleRect)
                if let rect = pageRect {
                    newBounds = rect
                }
                //Swift.print("  new bounds = \(newBounds)")
                var newFrame = CGRect(x: 0, y: 0, width: newBounds.size.width * scale, height: newBounds.size.height * scale)
                if let superview = superview where constrainViewToSuperview {
                    var sy: CGFloat = 1.0
                    var sx: CGFloat = 1.0
                    if newFrame.size.height < superview.bounds.size.height {
                        sy = superview.bounds.size.height / newFrame.size.height
                    }
                    if newFrame.size.width < superview.bounds.size.width {
                        sx = superview.bounds.size.width / newFrame.size.width
                    }
                    if sx > 1 && sy > 1 {
                        let sf = min(sx, sy)
                        newFrame.size = newFrame.size * sf
                        scale = newFrame.size.width / newBounds.size.width
                        Swift.print("scale sticks at \(scale)")
                    }
                }
                fixedSize = newFrame.size
                invalidateIntrinsicContentSize()
                frame = newFrame
                bounds = newBounds
                scrollRectToVisible(newVisibleRect)
               setNeedsDisplayInRect(bounds)
            }
           // Swift.print("  scale is \(scale)\n  bounds is \(bounds)\n  frame is \(frame)")
        }
    }
    
    override func viewDidEndLiveResize() {
        zoomByFactor(10)
        zoomByFactor(0.1)
    }
    
    func scrollPointToCenter(center: CGPoint) {
        var rect = visibleRect
        rect.origin = CGPoint(x: center.x - rect.size.width / 2, y: center.y - rect.size.height / 2)
        scrollRectToVisible(rect)
    }
    
    override func drawRect(dirtyRect: NSRect) {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextSaveGState(context)
        CGContextSetLineWidth(context, 8.0)
        NSColor.redColor().set()
        CGContextStrokeRect(context, lastVisibleRect)
        NSColor.blueColor().set()
        CGContextStrokeRect(context, previousVisibleRect)
        CGContextRestoreGState(context)
    }
}
