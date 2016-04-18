//
//  DocumentInspectorView.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/2/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

class InspectorButton: NSButton
{
    @IBOutlet var inspector: NSView?    
}

class DocInspectorView: NSView
{
    @IBOutlet var widthConstraint: NSLayoutConstraint!
    @IBOutlet var inspectorView: NSView!
    @IBOutlet var drawingView: DrawingView!
    
    var inspectorConstraints: [NSLayoutConstraint] = []
    
    var currentInspector: NSView?
    
    @IBAction func setInspectorFrom(sender: InspectorButton) {
        if let inspector = currentInspector {
            removeConstraints(inspectorConstraints)
            inspector.removeFromSuperview()
        }
        if let inspector = sender.inspector {
            inspectorConstraints = []
            inspector.translatesAutoresizingMaskIntoConstraints = false
            inspectorView.addSubview(inspector)
            inspectorConstraints.append(NSLayoutConstraint(item: inspector, attribute: .Left, relatedBy: .Equal, toItem: inspectorView, attribute: .Left, multiplier: 1, constant: 0))
            inspectorConstraints.append(NSLayoutConstraint(item: inspector, attribute: .Right, relatedBy: .Equal, toItem: inspectorView, attribute: .Right, multiplier: 1, constant: 0))
            inspectorConstraints.append(NSLayoutConstraint(item: inspector, attribute: .Top, relatedBy: .Equal, toItem: inspectorView, attribute: .Top, multiplier: 1, constant: 0))
            inspectorConstraints.append(NSLayoutConstraint(item: inspector, attribute: .Bottom, relatedBy: .Equal, toItem: inspectorView, attribute: .Bottom, multiplier: 1, constant: 0))
            addConstraints(inspectorConstraints)
            currentInspector = inspector
        }
    }
    
    @IBAction func toggleVisibility(sender: AnyObject?) {
        if widthConstraint.constant == 0 {
            widthConstraint.constant = 200
        } else {
            widthConstraint.constant = 0
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1000000), dispatch_get_main_queue()) {
            self.drawingView.zoomByFactor(2.0)
            self.drawingView.zoomByFactor(0.5)
        }
    }
    
    override func drawRect(dirtyRect: NSRect) {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        NSColor(white: 0.95, alpha: 1.0).set()
        CGContextFillRect(context, bounds)
        NSColor.lightGrayColor().set()
        NSBezierPath.setDefaultLineWidth(1.0)
        NSBezierPath.strokeRect(bounds.insetBy(dx: 0.5, dy: 0.5))
    }
}

// MARK: Drawing Sizes

struct DrawingSizeInfo {
    var name: String
    var size: NSSize                // drawing page size in points
}

var drawingSizes: [DrawingSizeInfo] = [
    DrawingSizeInfo(name: "Undefined", size: NSSize()),
    DrawingSizeInfo(name: "Custom", size: NSSize()),
    DrawingSizeInfo(name: "ARCH A", size: NSSize(width: 9, height: 12)),
    DrawingSizeInfo(name: "ARCH B", size: NSSize(width: 12, height: 18)),
    DrawingSizeInfo(name: "ARCH C", size: NSSize(width: 18, height: 24)),
    DrawingSizeInfo(name: "ARCH D", size: NSSize(width: 24, height: 36)),
    DrawingSizeInfo(name: "ARCH E", size: NSSize(width: 36, height: 48)),
    DrawingSizeInfo(name: "ANSI A", size: NSSize(width: 8.5, height: 11)),
    DrawingSizeInfo(name: "ANSI B", size: NSSize(width: 11, height: 17)),
    DrawingSizeInfo(name: "ANSI C", size: NSSize(width: 17, height: 22)),
    DrawingSizeInfo(name: "ANSI D", size: NSSize(width: 22, height: 34)),
    DrawingSizeInfo(name: "ANSI E", size: NSSize(width: 34, height: 44)),
]

struct DrawingScaleInfo {
    var name: String
    var scale: CGFloat
    var numerator: String
    var denominator: String
}

var drawingScales: [DrawingScaleInfo] = [
    DrawingScaleInfo(name: "Custom", scale: 0, numerator: "", denominator: ""),
    DrawingScaleInfo(name: "ThreeQuarter Scale", scale: 1/9, numerator: "3\"", denominator: "4'"),
    DrawingScaleInfo(name: "Half Scale", scale: 1/24, numerator: "1\"", denominator: "2'"),
    DrawingScaleInfo(name: "Quarter Scale", scale: 1/48, numerator: "1\"", denominator: "4'"),
    DrawingScaleInfo(name: "Eighth Scale", scale: 1/96, numerator: "1\"", denominator: "8'")
]

class PageInspectorView: NSView
{
    @IBOutlet var drawingView: DrawingView!
    @IBOutlet var pageSizePopup: NSPopUpButton!
    @IBOutlet var pageWidth: NSTextField!
    @IBOutlet var pageHeight: NSTextField!
    @IBOutlet var pageOrientation: NSSegmentedControl!
    @IBOutlet var pageScalePopup: NSPopUpButton!
    @IBOutlet var scaleNumerator: NSTextField!
    @IBOutlet var scaleDenominator: NSTextField!
    
    var page: ArsPage? {
        didSet {
            if let page = page {
                showScaleForPage(page)
                if let rect = page.pageRect {
                    pageWidth.doubleValue = Double(rect.size.width)
                    pageHeight.doubleValue = Double(rect.size.height)
                    pageOrientation.selectedSegment = rect.size.width > rect.size.height ? 1 : 0
                } else {
                    pageOrientation.selectedSegment = 0
                    pageWidth.stringValue = "infinite"
                    pageHeight.stringValue = "infinite"
                    pageSizePopup.selectItemAtIndex(0)
                    return
                }
                
                for dwgSize in drawingSizes {
                    if dwgSize.size.width == page.pageRect?.width && dwgSize.size.height == page.pageRect?.height {
                        pageSizePopup.selectItemWithTitle(dwgSize.name)
                        pageOrientation.selectedSegment = 0
                        return
                    } else if dwgSize.size.width == page.pageRect?.height && dwgSize.size.height == page.pageRect?.width {
                        pageSizePopup.selectItemWithTitle(dwgSize.name)
                        pageOrientation.selectedSegment = 1
                        return
                    }
                }
                pageSizePopup.selectItemAtIndex(1)
            }
        }
    }
    
    override func awakeFromNib() {
        pageSizePopup.removeAllItems()
        pageSizePopup.addItemsWithTitles(drawingSizes.map { $0.name })
        pageScalePopup.removeAllItems()
        pageScalePopup.addItemsWithTitles(drawingScales.map { $0.name })
        let p = page
        page = p            // trigger binding after popup is configured
    }
    
    func showScaleForPage(page: ArsPage) {
        let pageScale = page.pageScale
        var (numerator, denominator) = ("\(pageScale)" , "1")
        var scaleTitle = "Custom"
        if pageScale < 1.0 {
            let invScale = 1.0 / pageScale
            switch invScale {
            case 96:
                (numerator, denominator) = ("1\"", "8'")
                scaleTitle = "Eighth Scale"
            case 48:
                (numerator, denominator) = ("1\"", "4'")
                scaleTitle = "Quarter Scale"
            case 24:
                (numerator, denominator) = ("1\"", "2'")
                scaleTitle = "Half Scale"
            case 12:
                (numerator, denominator) = ("1\"", "1'")
            default:
                (numerator, denominator) = ("1", "\(invScale)")
            }
        }
        pageScalePopup.selectItemWithTitle(scaleTitle)
        scaleNumerator.stringValue = numerator
        scaleDenominator.stringValue = denominator
    }
    
    @IBAction func pageSettingsChanged(sender: AnyObject?) {
        if let page = page {
            let index = pageSizePopup.indexOfSelectedItem
            if index == 0 {
                page.pageRect = nil
                return
            }
            let info = drawingSizes[index]
            let portrait = pageOrientation.selectedSegment == 0
            if portrait {
                page.pageRect = CGRect(x: 0, y: 0, width: info.size.width, height: info.size.height)
            } else {
                page.pageRect = CGRect(x: 0, y: 0, width: info.size.height, height: info.size.width)
            }
            self.page = page    // trigger reload of binding
        }
        drawingView.checkViewBoundries()
    }
    
    @IBAction func scaleSettingsChanged(sender: AnyObject?) {
        let index = pageScalePopup.indexOfSelectedItem
        if let _ = sender as? NSPopUpButton {
            if index == 0 {
                let num = distanceFromString(scaleNumerator.stringValue)
                let denom = distanceFromString(scaleDenominator.stringValue)
                let scale = num / denom
                
                page?.pageScale = scale
            } else {
                let scaleSetting = drawingScales[index]
                
                scaleNumerator.stringValue = scaleSetting.numerator
                scaleDenominator.stringValue = scaleSetting.denominator
                page?.pageScale = scaleSetting.scale
            }
        } else {
            let num = distanceFromString(scaleNumerator.stringValue)
            let denom = distanceFromString(scaleDenominator.stringValue)
            let scale = num / denom
            
            page?.pageScale = scale
        }
        if let page = page {
            showScaleForPage(page)
        }
        drawingView.checkViewBoundries()
    }
}

class PageInspectorController: NSObjectController
{
    @IBOutlet var view: PageInspectorView!
    
    override var content: AnyObject? {
        didSet {
            view.page = content as? ArsPage
        }
    }
}

class LayerInspectorView: NSView
{
    @IBOutlet var document: ArsDocument!
    @IBOutlet var gridSizeField: NSTextField!
    
    @IBAction func layerEnableChanged(sender: NSButton) {
        document.layerEnableChanged(sender)
    }    
}

class ParametricInspectorView: NSView
{
    @IBOutlet var document: ArsDocument!
}
