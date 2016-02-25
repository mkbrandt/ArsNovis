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
    var scale: CGFloat = 1.0
    var minimumScale: CGFloat = 0.1
    var maximumScale: CGFloat = 100.0
    
    var centeredPointInDocView: CGPoint {
        if let clipView = superview as? NSClipView {
            let clipFrame = clipView.documentVisibleRect
            
            return CGPoint(x: clipFrame.origin.x + clipFrame.size.width / 2, y: clipFrame.origin.y + clipFrame.size.height / 2)
        }
        return bounds.origin
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
    
    func zoomByFactor(factor: CGFloat) {
        zoomByFactor(factor, withCenter: centeredPointInDocView)
    }
    
    func zoomToAbsoluteScale(scale: CGFloat) {
        let factor = scale / self.scale
        zoomByFactor(factor)
    }
    
    func zoomToFitRect(rect: CGRect) {
        let sx = rect.size.width / frame.size.width
        let sy = rect.size.height / frame.size.height
        zoomByFactor(min(sx, sy))
    }
    
    func zoomViewToRect(rect: CGRect) {
        if let clipView = superview as? NSClipView {
            let vr = clipView.documentVisibleRect
            
            let sx = vr.size.width / rect.size.width
            let sy = vr.size.height / rect.size.height
            let p = CGPoint(x: rect.origin.x + rect.size.width / 2, y: rect.origin.y + rect.size.height / 2)
            zoomByFactor(min(sx, sy), withCenter: p)
        }
    }
    
    override func scrollWheel(theEvent: NSEvent) {
        let factor: CGFloat = 1.0 - theEvent.deltaY * 0.1
        
        zoomByFactor(factor, withCenter: centeredPointInDocView)
    }
    
    func zoomByFactor(var factor: CGFloat, withCenter center: CGPoint) {
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
            
            if newScale != scale {
                scale = newScale
                let oldSize = frame.size
                
                scaleUnitSquareToSize(CGSize(width: factor, height: factor))
                frame = CGRect(origin: frame.origin, size: CGSize(width: oldSize.width * factor, height: oldSize.height * factor))
                scrollPointToCenter(center)
                setNeedsDisplayInRect(bounds)
                if let cv = superview as? NSClipView {
                    cv.setNeedsDisplayInRect(cv.bounds)
                }
            }
        }
    }
    
    func scrollPointToCenter(center: CGPoint) {
        if let clipView = superview as? NSClipView {
            let fr = clipView.documentVisibleRect
            
            let x = center.x - fr.size.width / 2
            let y = center.y - fr.size.height / 2
            scrollPoint(CGPoint(x: x, y: y))
        }
    }
}
