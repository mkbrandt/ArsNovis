//: Playground - noun: a place where people can play

import Cocoa

var str = "Hello, playground"

enum InspectionType {
    case normal, weird
}

class Graphic
{
    var parametricName: String
    
    init(name: String) {
        parametricName = name
    }
}

class ParametricItem: NSObject
{
    var image = NSImage()
    var targetString: String { return "item" }
    var baseHue: CGFloat { return 0.6 }
    
    var count: Int  { return 1 }
    
    func createImage() {
        let targetString = NSAttributedString(string: self.targetString)
        var imageSize = targetString.size()
        imageSize.width += 8
        image = NSImage(size: imageSize)
        image.lockFocus()
        let path = NSBezierPath(roundedRect: CGRect(origin: CGPoint(x: 0, y: 0), size: imageSize), xRadius: imageSize.height / 2, yRadius: imageSize.height / 2)
        var color = NSColor(calibratedHue: baseHue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        color.setStroke()
        color = NSColor(calibratedHue: baseHue, saturation: 0.2, brightness: 1.0, alpha: 1.0)
        color.setFill()
        path.fill()
        path.stroke()
        targetString.drawAtPoint(CGPoint(x: 4, y: 0))
        image.unlockFocus()
    }
    
    func itemAtIndex(index: Int) -> ParametricItem {
        return self
    }
    
    func insertItem(item: ParametricItem, atIndex index: Int) -> ParametricItem {
        return self
    }
    
    func removeItemAtIndex(index: Int) -> ParametricItem? {
        return nil
    }
}

class ParametricTarget: ParametricItem
{
    var target: Graphic
    var key: String
    var type: InspectionType
    
    override var targetString: String { return "\(target.parametricName).\(key)" }
    
    init(target: Graphic, key: String, type: InspectionType) {
        self.target = target
        self.key = key
        self.type = type
        super.init()
        createImage()
    }
    
    override func insertItem(item: ParametricItem, atIndex index: Int) -> ParametricItem {
        if index == 0 {
            if let op = item as? ParametricOperator {
                return ParametricOperator(operation: op.operation, left: op.left, right: self)
            }
            return ParametricOperator(operation: "?", left: item, right: self)
        } else {
            if let op = item as? ParametricOperator {
                return ParametricOperator(operation: op.operation, left: self, right: op.right)
            }
            return ParametricOperator(operation: "?", left: self, right: item)
        }
    }
}

class ParametricOperator: ParametricItem
{
    var left: ParametricItem?
    var right: ParametricItem?
    var operation: String
    
    override var baseHue: CGFloat {
        if operation == "?" || left == nil || right == nil {               // unknown operator is red
            return 0.0
        } else {
            return super.baseHue
        }
    }
    
    override var targetString: String { return operation }
    
    override var count: Int  {
        return (left?.count ?? 0) + (right?.count ?? 0) + 1
    }
    
    init(operation: String, left: ParametricItem?, right: ParametricItem?) {
        self.left = left
        self.right = right
        self.operation = operation
        super.init()
        createImage()
    }
    
    override func itemAtIndex(index: Int) -> ParametricItem {
        if let left = left where index < left.count {
            return left.itemAtIndex(index)
        }
        let index = index - (left?.count ?? 0)
        if index == 0 {
            return self
        }
        return right?.itemAtIndex(index - 1) ?? self
    }
    
    override func insertItem(item: ParametricItem, atIndex index: Int) -> ParametricItem {
        if let left = left where index < left.count {
            return ParametricOperator(operation: operation, left: left.insertItem(item, atIndex: index), right: right)
        } else {
            let index = index - (left?.count ?? 0)
            if index == 0 {
                if let op = item as? ParametricOperator {
                    return ParametricOperator(operation: op.operation, left: left, right: right)
                } else if left == nil {
                    return ParametricOperator(operation: operation, left: item, right: right)
                } else {
                    let newOp = ParametricOperator(operation: "?", left: left, right: item)
                    return ParametricOperator(operation: operation, left: newOp, right: right)
                }
            } else if let right = right {
                let newRight = right.insertItem(item, atIndex: index - 1)
                return ParametricOperator(operation: operation, left: left, right: newRight)
            } else {
                return ParametricOperator(operation: operation, left: left, right: item)
            }
        }
    }
    
    override func removeItemAtIndex(index: Int) -> ParametricItem? {
        if let left = left where index < left.count {
            return left.removeItemAtIndex(index)
        } else {
            let index = index - (left?.count ?? 0)
            if index == 0 {
                return ParametricOperator(operation: "?", left: left, right: right)
            } else {
                return right?.removeItemAtIndex(index - 1)
            }
        }
    }
}

class ParametricEquationEditor: NSView
{
    var equation: ParametricOperator? { didSet { invalidateIntrinsicContentSize(); needsDisplay = true }}
    let LineHeight = CGFloat(20)
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var drawnSize: NSSize?
    override var intrinsicContentSize: NSSize {
        let width = bounds.size.width
        var lines: CGFloat = 0
        
        if let equation = equation {
            let count = equation.count
            var x: CGFloat = 0
            
            for index in 0 ..< count {
                let item = equation.itemAtIndex(index)
                let image = item.image
                if x + image.size.width > width {
                    x = image.size.width
                    lines += 1
                }
            }
        }
        return CGSize(width: width, height: lines * LineHeight)
    }
    
    override func drawRect(dirtyRect: NSRect) {
        NSColor.whiteColor().set()
        NSRectFill(bounds)
        NSColor.blackColor().set()
        
        var cursor = CGPoint(x: bounds.origin.x, y: bounds.origin.y + bounds.size.height - LineHeight)
        if let equation = equation {
            let numObjects = equation.count
            
            for index in 0 ..< numObjects {
                let item = equation.itemAtIndex(index)
                Swift.print("display \(item.targetString)")
                let image = item.image
                if image.size.width + cursor.x > bounds.origin.x + bounds.size.width {
                    cursor.x = bounds.origin.x
                    cursor.y -= LineHeight
                }
                image.drawInRect(CGRect(origin: cursor, size: image.size))
                cursor.x += image.size.width + 4
            }
        }
    }
    
    override func mouseDown(theEvent: NSEvent) {
        Swift.print("mouseDown \(theEvent.locationInWindow)")
    }
}

let view = ParametricEquationEditor(frame: CGRect(x: 0, y: 0, width: 400, height: 200))

let a = ParametricTarget(target: Graphic(name: "alpha"), key: "origin", type: .normal)
let b = ParametricTarget(target: Graphic(name: "beta"), key: "origin", type: .normal)
let c = ParametricTarget(target: Graphic(name: "gamma"), key: "endPoint", type: .normal)
let add = ParametricOperator(operation: "+", left: b, right: c)
view.equation = ParametricOperator(operation: "=", left: a, right: add)

let minus = ParametricOperator(operation: "-", left: nil, right: nil)
let fubar = ParametricTarget(target: Graphic(name: "fubar"), key: "nork", type: .normal)
view.equation = view.equation!.insertItem(fubar, atIndex: 2) as? ParametricOperator

view.equation = view.equation!.insertItem(minus, atIndex: 3) as? ParametricOperator
view


