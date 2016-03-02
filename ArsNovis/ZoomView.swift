//
//  ZoomView.swift
//  ArsNovis
//
//  Created by Matt Brandt on 2/24/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class ZoomView: NSView
{
    @IBOutlet var widthConstraint: NSLayoutConstraint!
    @IBOutlet var heightConstraint: NSLayoutConstraint!
    
    var scale: CGFloat = 1.0
    var minimumScale: CGFloat = 0.01
    var maximumScale: CGFloat = 100000.0
    
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
    
    var zoomCenter: CGPoint?
    var lastVisibleRect = CGRect()
    var previousVisibleRect = CGRect()
    
    var centeredPointInDocView: CGPoint {
        return visibleRect.center
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
        zoomToFitRect(contentMarginRect)
    }
    
    func zoomByFactor(factor: CGFloat) {
        zoomByFactor(factor, aroundPoint: centeredPointInDocView)
    }
    
    func zoomToAbsoluteScale(scale: CGFloat) {
        let factor = scale / self.scale
        zoomByFactor(factor)
    }
    
    func zoomToFitRect(rect: CGRect) {
        let sx = visibleRect.size.width / rect.size.width
        let sy = visibleRect.size.height / rect.size.height
        zoomByFactor(min(sx, sy))
        scrollRectToVisible(rect)
    }
    
    override func scrollWheel(theEvent: NSEvent) {
        if theEvent.modifierFlags.contains(.ControlKeyMask) {
            let factor: CGFloat = 1.0 - theEvent.deltaY * 0.1
            var mouseloc = convertPoint(theEvent.locationInWindow, fromView: nil)
            
            if let zc = zoomCenter {
                mouseloc = zc
            }
            
            zoomByFactor(factor, aroundPoint: mouseloc)
        } else {
            super.scrollWheel(theEvent)
        }
    }
    
    func zoomByFactor(var factor: CGFloat, aroundPoint point: CGPoint) {
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
            
            Swift.print("Zoom by \(factor) around \(point)   scale = \(newScale)")
            if newScale != scale {
                let originVector = (point - visibleRect.origin) / factor
                let newVisibleSize = CGSize(width: visibleRect.width / factor, height: visibleRect.height / factor)
                let newVisibleRect = CGRect(origin: point - originVector, size: newVisibleSize)
                Swift.print("  visible = \(newVisibleRect)")
                
                previousVisibleRect = lastVisibleRect
                lastVisibleRect = newVisibleRect
                
                scale = newScale
                var newBounds = contentMarginRect
                newBounds.size.width *= 1.1
                newBounds.size.height *= 1.1
                newBounds = newBounds.union(newVisibleRect)
                Swift.print("  new bounds = \(newBounds)")
                let newFrame = CGRect(x: 0, y: 0, width: newBounds.size.width * scale, height: newBounds.size.height * scale)
                fixedSize = newFrame.size
                invalidateIntrinsicContentSize()
                frame = newFrame
                bounds = newBounds
                scrollRectToVisible(newVisibleRect)
               setNeedsDisplayInRect(bounds)
            }
            Swift.print("  scale is \(scale)\n  bounds is \(bounds)\n  frame is \(frame)")
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
