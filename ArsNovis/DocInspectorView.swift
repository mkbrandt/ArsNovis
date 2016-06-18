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
    
    @IBAction func setInspectorFrom(_ sender: InspectorButton) {
        if let inspector = currentInspector {
            removeConstraints(inspectorConstraints)
            inspector.removeFromSuperview()
        }
        if let inspector = sender.inspector {
            inspectorConstraints = []
            inspector.translatesAutoresizingMaskIntoConstraints = false
            inspectorView.addSubview(inspector)
            inspectorConstraints.append(NSLayoutConstraint(item: inspector, attribute: .left, relatedBy: .equal, toItem: inspectorView, attribute: .left, multiplier: 1, constant: 0))
            inspectorConstraints.append(NSLayoutConstraint(item: inspector, attribute: .right, relatedBy: .equal, toItem: inspectorView, attribute: .right, multiplier: 1, constant: 0))
            inspectorConstraints.append(NSLayoutConstraint(item: inspector, attribute: .top, relatedBy: .equal, toItem: inspectorView, attribute: .top, multiplier: 1, constant: 0))
            inspectorConstraints.append(NSLayoutConstraint(item: inspector, attribute: .bottom, relatedBy: .equal, toItem: inspectorView, attribute: .bottom, multiplier: 1, constant: 0))
            addConstraints(inspectorConstraints)
            currentInspector = inspector
        }
    }
    
    @IBAction func toggleVisibility(_ sender: AnyObject?) {
        if widthConstraint.constant == 0 {
            widthConstraint.constant = 200
        } else {
            widthConstraint.constant = 0
        }
        DispatchQueue.main.after(when: DispatchTime.now() + Double(1000000) / Double(NSEC_PER_SEC)) {
            self.drawingView.zoomByFactor(2.0)
            self.drawingView.zoomByFactor(0.5)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let context = NSGraphicsContext.current()?.cgContext
        
        NSColor(white: 0.95, alpha: 1.0).set()
        context?.fill(bounds)
        NSColor.lightGray().set()
        NSBezierPath.setDefaultLineWidth(1.0)
        NSBezierPath.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))
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
                    pageSizePopup.selectItem(at: 0)
                    return
                }
                
                for dwgSize in drawingSizes {
                    if dwgSize.size.width == page.pageRect?.width && dwgSize.size.height == page.pageRect?.height {
                        pageSizePopup.selectItem(withTitle: dwgSize.name)
                        pageOrientation.selectedSegment = 0
                        return
                    } else if dwgSize.size.width == page.pageRect?.height && dwgSize.size.height == page.pageRect?.width {
                        pageSizePopup.selectItem(withTitle: dwgSize.name)
                        pageOrientation.selectedSegment = 1
                        return
                    }
                }
                pageSizePopup.selectItem(at: 1)
            }
        }
    }
    
    override func awakeFromNib() {
        pageSizePopup.removeAllItems()
        pageSizePopup.addItems(withTitles: drawingSizes.map { $0.name })
        pageScalePopup.removeAllItems()
        pageScalePopup.addItems(withTitles: drawingScales.map { $0.name })
        let p = page
        page = p            // trigger binding after popup is configured
    }
    
    func showScaleForPage(_ page: ArsPage) {
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
        pageScalePopup.selectItem(withTitle: scaleTitle)
        scaleNumerator.stringValue = numerator
        scaleDenominator.stringValue = denominator
    }
    
    @IBAction func pageSettingsChanged(_ sender: AnyObject?) {
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
    
    @IBAction func scaleSettingsChanged(_ sender: AnyObject?) {
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
    
    @IBAction func layerEnableChanged(_ sender: NSButton) {
        document.layerEnableChanged(sender)
    }    
}

class ParametricInspectorView: NSView
{
    @IBOutlet var document: ArsDocument!
}
