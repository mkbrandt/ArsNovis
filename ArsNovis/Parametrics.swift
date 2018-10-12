//
//  Parametrics.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/23/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Cocoa

enum MeasurementType: Int {
    case distance, angle
}

/// Parametric Value - represents a property of type CGFloat or CGPoint

class ParametricNode: NSObject, NSCoding, NSPasteboardReading, NSPasteboardWriting
{
    var context: ParametricContext?
    var value: NSValue
    var image = NSImage()
    var count: Int          { return 1 }
    
    init(context: ParametricContext?) {
        self.context = context
        value = NSNumber(value: 0)
        super.init()
        createImage()
    }
    
    required init?(coder decoder: NSCoder) {
        if let context = decoder.decodeObject(forKey: "context") as? ParametricContext {
            self.context = context
            self.value = NSNumber(value: 0)
        } else {
            return nil
        }
        super.init()
        createImage()
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [ParametricItemUTI]
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        return [ParametricItemUTI]
    }
    
    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any?
    {
        let data = NSKeyedArchiver.archivedData(withRootObject: self)
        return data
    }
    
    func encode(with encoder: NSCoder) {
        encoder.encode(context, forKey: "context")
    }
    
    var isVariable: Bool { return false }
    
    override var description: String { return "node" }
    
    func dependsOn(_ node: ParametricNode) -> Bool {
        return node == self
    }
    
    var variableNode: ParametricNode? { return nil }
    
    var targetString: String    { return "-node-" }
    var baseHue: CGFloat { return 0.6 }
    var origin = CGPoint(x: 0, y: 0)
    var frame: CGRect   { return CGRect(origin: origin, size: image.size) }

    func createImage(_ width: CGFloat = 0) {
        if self.targetString == "" {
            return
        }
        let targetString = AttributedString(string: self.targetString)
        var imageSize = targetString.size()
        let stringWidth = imageSize.width
        if width > 0 {
            imageSize.width = width
        } else {
            imageSize.width += 8
        }
        let offset = (imageSize.width - stringWidth) / 2
        image = NSImage(size: imageSize)
        image.lockFocus()
        let path = NSBezierPath(roundedRect: CGRect(origin: CGPoint(x: 0, y: 0), size: imageSize), xRadius: imageSize.height / 2, yRadius: imageSize.height / 2)
        var color = NSColor(calibratedHue: baseHue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
        color.setStroke()
        color = NSColor(calibratedHue: baseHue, saturation: 0.2, brightness: 1.0, alpha: 1.0)
        color.setFill()
        path.lineWidth = 0.5
        path.fill()
        path.stroke()
        targetString.draw(at: CGPoint(x: offset, y: 0))
        image.unlockFocus()
    }
    
    func itemAtIndex(_ index: Int) -> ParametricNode {
        return self
    }
    
    func insertItem(_ item: ParametricNode, atIndex index: Int) -> ParametricNode {
        return self
    }
    
    func removeItemAtIndex(_ index: Int) -> ParametricNode? {
        return nil
    }
    
    func removeItem(_ item: ParametricNode) -> ParametricNode? {
        if item != self {
            return self
        }
        return nil
    }
    
    func indexOfItem(_ item: ParametricNode) -> Int? {
        if item == self {
            return 0
        }
        return nil
    }
    
    func itemAtPoint(_ point: CGPoint) -> ParametricNode? {
        return frame.contains(point) ? self : nil
    }
}

class ParametricConstant: ParametricNode
{
    override var targetString: String { return "\(value)" }
    
    init(value: NSValue, context: ParametricContext?) {
        super.init(context: context)
        self.value = value
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        if let value = decoder.decodeObject(forKey: "value") as? NSValue {
            self.value = value
        } else {
            return nil
        }
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with encoder: NSCoder) {
        super.encode(with: encoder)
        encoder.encode(value, forKey: "value")
    }
    
    override var description: String { return "\(value)" }

    override func insertItem(_ item: ParametricNode, atIndex index: Int) -> ParametricNode {
        if index == 0 {
            if let op = item as? ParametricOperation {
                return ParametricOperation(op: op.op, left: op.left, right: self, context: context)
            }
            return ParametricOperation(op: "?", left: item, right: self, context: context)
        } else {
            if let op = item as? ParametricOperation {
                return ParametricOperation(op: op.op, left: self, right: op.right, context: context)
            }
            return ParametricOperation(op: "?", left: self, right: item, context: context)
        }
    }
}

class ParametricValue: ParametricNode
{
    var target: Graphic
    var name: String
    var type: InspectionType
    
    override var isVariable: Bool   { return true }
    
    override var value: NSValue {
        get {
            if let v = target.value(forKey: name) as? CGFloat {
                return v
            }
            return CGFloat(0)
        }
        set {
            if let val = target.value(forKey: name) as? NSValue, val != newValue {
                //print("\(context.prefix)set \(self) = \(newValue)")
                target.setValue(newValue, forKey: name)
            }
        }
    }
    
    init(target: Graphic, name: String, type: InspectionType, context: ParametricContext?) {
        self.target = target
        self.name = name
        self.type = type
        super.init(context: context)
    }
    
    required init?(coder decoder: NSCoder) {
        if let target = decoder.decodeObject(forKey: "target") as? Graphic, let name = decoder.decodeObject(forKey: "name") as? String {
            self.target = target
            self.name = name
            self.type = InspectionType(rawValue: decoder.decodeInteger(forKey: "type")) ?? .float
        } else {
            return nil
        }
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with encoder: NSCoder) {
        super.encode(with: encoder)
        encoder.encode(target, forKey: "target")
        encoder.encode(name, forKey: "name")
        encoder.encode(type.rawValue, forKey: "type")
    }
    
    override var description: String { return "G\(target.identifier).\(name)" }
    
    override var variableNode: ParametricNode? { return self }
    
    override var targetString: String { return "\(target.parametricName).\(name)" }

    override func insertItem(_ item: ParametricNode, atIndex index: Int) -> ParametricNode {
        if index == 0 {
            if let op = item as? ParametricOperation {
                return ParametricOperation(op: op.op, left: op.left, right: self, context: context)
            }
            return ParametricOperation(op: "?", left: item, right: self, context: context)
        } else {
            if let op = item as? ParametricOperation {
                return ParametricOperation(op: op.op, left: self, right: op.right, context: context)
            }
            return ParametricOperation(op: "?", left: self, right: item, context: context)
        }
    }
}

/// Parametric Variable - a named variable of type CGFloat or CGPoint

class ParametricVariable: ParametricNode
{
    override var targetString: String { return "\(name)" }
    
    var name: String
    override var value: NSValue {
        didSet {
            //print("\(context.prefix)\(self) set to \(value)")
            context?.resolve(self)
        }
    }
    var measurementType: MeasurementType
    override var isVariable: Bool { return true }
    
    var transformer: ValueTransformer { return measurementType == .angle ? AngleTransformer() : DistanceTransformer() }
    var stringValue: String {
        get {
            if let sv = transformer.transformedValue(value) as? String {
                return sv
            }
            return "\(value)"
        }
        set {
            if let v = transformer.reverseTransformedValue(newValue) as? NSValue {
                value = v
            }
        }
    }
    
    init(name: String, value: NSValue, type: MeasurementType, context: ParametricContext) {
        self.name = name
        measurementType = type
        super.init(context: context)
        self.value = value
    }
    
    required init?(coder decoder: NSCoder) {
        if let name = decoder.decodeObject(forKey: "name") as? String,
          let value = decoder.decodeObject(forKey: "value") as? NSValue {
            self.name = name
            measurementType = decoder.decodeBool(forKey: "isAngle") ? .angle : .distance
            super.init(coder: decoder)
            self.value = value
        } else {
            return nil
        }
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with encoder: NSCoder) {
        super.encode(with: encoder)
        encoder.encode(name, forKey: "name")
        encoder.encode(value, forKey: "value")
        encoder.encode(measurementType == .angle, forKey: "isAngle")
    }
    
    override var description: String { return "\(name)" }
    
    override var variableNode: ParametricNode? { return self }

    override func insertItem(_ item: ParametricNode, atIndex index: Int) -> ParametricNode {
        if index == 0 {
            if let op = item as? ParametricOperation {
                return ParametricOperation(op: op.op, left: op.left, right: self, context: context)
            }
            return ParametricOperation(op: "?", left: item, right: self, context: context)
        } else {
            if let op = item as? ParametricOperation {
                return ParametricOperation(op: op.op, left: self, right: op.right, context: context)
            }
            return ParametricOperation(op: "?", left: self, right: item, context: context)
        }
    }
}

class ParametricBinding: ParametricOperation
{
    override var value: NSValue {
        get { return right?.value ?? 0.0 }
        set {
            right?.value = newValue
            left?.value = newValue
        }
    }
    
    init(left: ParametricNode, right: ParametricNode, context: ParametricContext?) {
        super.init(op: "=", left: left, right: right, context: context)
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        op = "="
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with encoder: NSCoder) {
        super.encode(with: encoder)
        encoder.encode(left, forKey: "left")
        encoder.encode(right, forKey: "right")
    }
    
    func resolve() {
        if let left = left, let context = context, !context.isException(left) {
            //print("\(context.prefix)binding value \(left) = \(right) = \(right.value)")
            context.addException(left)
            if let v = right?.value {
                left.value = v
            }
        }
    }
    
    override var variableNode: ParametricNode? { return right?.variableNode }
}

class ParametricOperation: ParametricNode
{
    var op: String
    var left: ParametricNode?
    var right: ParametricNode?
    
    var leftValue: NSValue  { return left?.value ?? 0 }
    var rightValue: NSValue { return right?.value ?? 1 }

    override var value: NSValue {
        get {
            switch op {
            case "+":
                return leftValue + rightValue
            case "-":
                return leftValue - rightValue
            case "*":
                return leftValue * rightValue
            case "/":
                return leftValue / rightValue
            default:
                return rightValue
            }
        }
        set {
            //print("\(context.prefix)set \(self) = \(newValue)")
            switch op {
            case "+":
                if let left = left, left.isVariable {
                    left.value = newValue - rightValue
                } else if let right = right, right.isVariable {
                    right.value = newValue - leftValue
                }
            case "-":
                if let left = left, left.isVariable {
                    left.value = rightValue + newValue
                } else if let right = right, right.isVariable {
                    right.value = leftValue - newValue
                }
            case "*":
                if let left = left, left.isVariable {
                    left.value = newValue / rightValue
                } else if let right = right, right.isVariable {
                    right.value = newValue / leftValue
                }
            default:
                break
            }
        }
    }
    
    override var isVariable: Bool {
        if op == "=" {
            return right?.isVariable ?? false
        }
        return (left?.isVariable ?? false) || (right?.isVariable ?? false)
    }
    
    override var targetString: String { return op }
    
    init(op: String, left: ParametricNode?, right: ParametricNode?, context: ParametricContext?) {
        self.op = op
        self.left = left
        self.right = right
        super.init(context: context)
    }
    
    required init?(coder decoder: NSCoder) {
        if let op = decoder.decodeObject(forKey: "op") as? String,
            let left = decoder.decodeObject(forKey: "left") as? ParametricNode,
            let right = decoder.decodeObject(forKey: "right") as? ParametricNode {
                self.op = op
                self.left = left
                self.right = right
        } else {
            return nil
        }
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with encoder: NSCoder) {
        super.encode(with: encoder)
        encoder.encode(op, forKey: "op")
        encoder.encode(left, forKey: "left")
        encoder.encode(right, forKey: "right")
    }
    
    override var description: String { return "\(left) \(op) \(right)" }
    
    override func dependsOn(_ node: ParametricNode) -> Bool {
        if let left = left, left.dependsOn(node) {
            return true
        } else if let right = right, right.dependsOn(node) {
            return true
        } else {
            return super.dependsOn(node)
        }
    }
    
    override var variableNode: ParametricNode? { return left?.variableNode ?? right?.variableNode }
    
    override var count: Int {
        return (left?.count ?? 0) + 1 + (right?.count ?? 0)
    }

    override func itemAtIndex(_ index: Int) -> ParametricNode {
        if let left = left, index < left.count {
            return left.itemAtIndex(index)
        }
        let index = index - (left?.count ?? 0)
        if index == 0 {
            return self
        }
        return right?.itemAtIndex(index - 1) ?? self
    }
    
    override func insertItem(_ item: ParametricNode, atIndex index: Int) -> ParametricNode {
        if let left = left, index < left.count {
            return ParametricOperation(op: op, left: left.insertItem(item, atIndex: index), right: right, context: context)
        } else {
            let index = index - (left?.count ?? 0)
            if index == 0 {
                if let op = item as? ParametricOperation {
                    return ParametricOperation(op: op.op, left: left, right: right, context: context)
                } else if left == nil {
                    return ParametricOperation(op: op, left: item, right: right, context: context)
                } else {
                    let newOp = ParametricOperation(op: "?", left: left, right: item, context: context)
                    return ParametricOperation(op: op, left: newOp, right: right, context: context)
                }
            } else if let right = right {
                let newRight = right.insertItem(item, atIndex: index - 1)
                return ParametricOperation(op: op, left: left, right: newRight, context: context)
            } else {
                return ParametricOperation(op: op, left: left, right: item, context: context)
            }
        }
    }
    
    override func removeItemAtIndex(_ index: Int) -> ParametricNode? {
        if let left = left, index < left.count {
            return left.removeItemAtIndex(index)
        } else {
            let index = index - (left?.count ?? 0)
            if index == 0 {
                return ParametricOperation(op: "?", left: left, right: right, context: context)
            } else {
                return right?.removeItemAtIndex(index - 1)
            }
        }
    }
    
    override func removeItem(_ item: ParametricNode) -> ParametricNode? {
        if item == self {
            return ParametricOperation(op: "?", left: left, right: right, context: context)
        } else {
            return ParametricOperation(op: op, left: left?.removeItem(item), right: right?.removeItem(item), context: context)
        }
    }
    
    override func itemAtPoint(_ point: CGPoint) -> ParametricNode? {
        return super.itemAtPoint(point) ?? left?.itemAtPoint(point) ?? right?.itemAtPoint(point)
    }
    
    override func indexOfItem(_ item: ParametricNode) -> Int? {
        if item == self {
            return left?.count ?? 0
        } else if let index = left?.indexOfItem(item) {
            return index
        } else if let index = right?.indexOfItem(item) {
            return (left?.count ?? 0) + 1 + index
        } else {
            return nil
        }
    }
}

private func +(a: NSValue, b: NSValue) -> NSValue {
    if let a = a as? CGFloat, let b = b as? CGFloat {
        return a + b
    } else {
        return NSValue(point: a.pointValue + b.pointValue)
    }
}

private func -(a: NSValue, b: NSValue) -> NSValue {
    if let a = a as? CGFloat, let b = b as? CGFloat {
        return a - b
    } else {
        return NSValue(point: a.pointValue - b.pointValue)
    }
}

private func *(a: NSValue, b: NSValue) -> NSValue {
    if let a = a as? CGFloat, let b = b as? CGFloat {
        return a + b
    } else if let a = a as? CGFloat {
        return NSValue(point: a * b.pointValue)
    } else if let b = b as? CGFloat {
        return NSValue(point: a.pointValue * b)
    } else {
        return 1
    }
}

private func /(a: NSValue, b: NSValue) -> NSValue {
    if let a = a as? CGFloat, let b = b as? CGFloat {
        return a + b
    } else if let b = b as? CGFloat {
        return NSValue(point: a.pointValue / b)
    }
    return 1
}


@objc protocol ParametricContextDelegate {
    @objc optional func parametricContextDidUpdate(_ parametricContext: ParametricContext)
}

struct ObservationInfo {
    var target: Graphic
    var property: String
}

class ParametricContext: NSObject, NSCoding
{
    var variablesByName: [String: ParametricVariable] = [:]
    var variables: [ParametricVariable] = []
    var parametrics: [ParametricBinding] = []
    var delegate: ParametricContextDelegate?
    var exceptions: [ParametricNode] = []
    var prefix: String = ""
    
    var observing: [ObservationInfo] = []
    var suspendCount = 0
    
    override init() {
        super.init()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init()
        if let variables = decoder.decodeObject(forKey: "variables") as? [ParametricVariable] {
            self.variables = variables
            for v in variables {
                variablesByName[v.name] = v
            }
        }
        if let parametrics = decoder.decodeObject(forKey: "parametrics") as? [ParametricBinding] {
            self.parametrics = parametrics
            for p in parametrics {
                if let left = p.left as? ParametricValue {
                    let target = left.target
                    startObserving(target, property: left.name)
                }
            }
        }
        print("New parametric context \(self)")
        showVariables()
        showParametrics()
    }
    
    func encode(with encoder: NSCoder) {
        encoder.encode(variables, forKey: "variables")
        encoder.encode(parametrics, forKey: "parametrics")
    }
    
    override func setValue(_ value: AnyObject?, forKey key: String) {
        if let value = value as? NSValue {
            if let v = variablesByName[key] {
                v.value = value
            }
        }
    }
    
    override func value(forUndefinedKey key: String) -> AnyObject? {
        if let pv = variablesByName[key] {
            return pv.value
        }
        return nil
    }
    
    func variableForKey(_ key: String) -> ParametricVariable? {
        return variablesByName[key]
    }
    
    func defineVariable(_ key: String, value: NSValue, type: MeasurementType) -> ParametricVariable {
        let pv = ParametricVariable(name: key, value: value, type: type, context: self)
        variables.append(pv)
        variablesByName[key] = pv
        return pv
    }
    
    func startObserving(_ target: Graphic, property: String) {
        print("\(self) registers for \(property) of G\(target.identifier)")
        observing.append(ObservationInfo(target: target, property: property))
        target.addObserver(self, forKeyPath: property, options: NSKeyValueObservingOptions.new, context: nil)
    }
    
    func suspendObservation() {
        suspendCount += 1
        if suspendCount > 1 {
            return
        }
        //print("\(self) suspends observation")
        for info in observing {
            //print("  remove observer G\(info.target.identifier).\(info.property)")
            info.target.removeObserver(self, forKeyPath: info.property)
        }
    }
    
    func resumeObservation() {
        suspendCount -= 1
        if suspendCount > 0 {
            return
        }
        //print("\(self) resumes observation")
        for info in observing {
            //print("  add observer G\(info.target.identifier).\(info.property)")
            info.target.addObserver(self, forKeyPath: info.property, options: NSKeyValueObservingOptions.new, context: nil)
        }
        
        for p in parametrics {
            if let right = p.right, let left = p.left, right.isVariable {             // reverse resolve to get new variables
                right.value = left.value
            }
        }
    }
    
    /// resolve -- propagate any changes to variable values to the rest of the context
    
    func resolve(_ depends: ParametricNode?) {
        let oldExceptions = exceptions
        let oldPrefix = prefix
        //print("\(prefix)resolving \(depends)")
        prefix += "  "
        for p in parametrics {
            if depends == nil || p.dependsOn(depends!) {
                p.resolve()
            }
        }
        exceptions = oldExceptions
        prefix = oldPrefix
        //print("\(prefix)done resolving \(depends)")
        delegate?.parametricContextDidUpdate?(self)
    }
    
    func showVariables() {
        var vars: [String] = []
        for v in variables {
            vars.append(v.description)
        }
        print("\(prefix)variables: \(vars)")
    }
    
    func showParametrics() {
        for p in parametrics {
            print("\(prefix)parametric: \(p)")
        }
    }
    
    func assign(_ target: Graphic, property: String, expression: ParametricNode) {
        let param = ParametricValue(target: target, name: property, type: target.inspectionTypeForKey(property), context: self)
        let assignment = ParametricBinding(left: param, right: expression, context: self)
        startObserving(target, property: property)
        parametrics = parametrics.filter {
            if let p = $0.left as? ParametricValue, p.target == target && p.name == property {
                return false
            }
            return true
        }
        parametrics.append(assignment)
        showParametrics()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : AnyObject]?, context: UnsafeMutableRawPointer) {
        if let target = object as? Graphic, let keyPath = keyPath {
            if isException(target, key: keyPath) {
                return
            }
            //print("\(prefix)start observing \(keyPath) for G\(target.identifier), context = \(self), change = \(change![NSKeyValueChangeNewKey])")
            let oldPrefix = prefix
            prefix += "  "
            let oldExceptions = exceptions
            for p in parametrics {
                if let pv = p.left as? ParametricValue, pv.target == target && pv.name == keyPath {
                    if let left = p.left, let right = p.right, left.value != right.value {
                        addException(left)
                        right.value = left.value
                    }
                }
            }
            exceptions = oldExceptions
            prefix = oldPrefix
            //print("\(prefix)end observing \(keyPath) for G\(target.identifier), context = \(self)")
        }
    }
    
    func showExceptions() {
        var exs: [String] = []
        for ex in exceptions {
            exs.append(ex.description)
        }
        //print("\(prefix)exceptions: \(exs)")
    }
    
    func addException(_ node: ParametricNode) {
        exceptions.append(node)
        showExceptions()
    }
    
    func removeException(_ node: ParametricNode) {
        exceptions = exceptions.filter { $0 != node }
        showExceptions()
    }
    
    func isException(_ node: ParametricNode) -> Bool {
        return exceptions.contains(node)
    }
    
    func isException(_ graphic: Graphic, key: String) -> Bool {
        for ex in exceptions {
            if let pv = ex as? ParametricValue {
                if pv.target == graphic && pv.name == key {
                    return true
                }
            }
        }
        return false
    }
}

// MARK: PARSING

enum ParseToken {
    case number(CGFloat)
    case id(String)
    case `operator`(String)
    case error(String)
    case eof
}

enum ParseError: Error {
    case badExpression
    case badCharacter(Character)
    case badNumber
    case badFraction
}

class ParametricParser
{
    var context: ParametricContext
    var type: MeasurementType
    var expression: ParametricNode
    var value: NSValue {
        return expression.value
    }

    private let EOF: Character = "\0"
    private var content = ""
    private var location: String.Index
    private var lastToken: ParseToken
    private var newDefinitions: [String] = []
    private var defaultValue: NSValue = NSNumber(value: 0)
    private var lastch: Character {
        if location == content.endIndex {
            return EOF
        }
        return content[location]
    }
    
    init(context: ParametricContext, string: String, defaultValue: NSValue, type: MeasurementType) {
        self.defaultValue = defaultValue
        content = string
        location = content.startIndex
        self.context = context
        self.type = type
        lastToken = .eof
        expression = ParametricConstant(value: 0.0, context: context)
        if let t = try? getToken() {
            lastToken = t
        }
        if let v = try? addOperation() {
            expression = v
        }
        if newDefinitions.count > 0 {
            expression.value = defaultValue
        }
    }
    
    private func nextch() {
        if lastch != EOF && location != content.endIndex {
            location = content.index(after: location)
        }
    }
    
    private func skipSpace() {
        while lastch == " " || lastch == "\n" || lastch == "\t" {
            nextch()
        }
    }
    
    private func isUpperCase(_ c: Character) -> Bool {
        switch c {
        case "A"..."Z":
            return true
        default:
            return false
        }
    }
    
    private func isLowerCase(_ c: Character) -> Bool {
        switch c {
        case "a"..."z":
            return true
        default:
            return false
        }
    }
    
    private func isDigit(_ c: Character) -> Bool {
        switch c {
        case "0"..."9":
            return true
        default:
            return false
        }
    }
    
    private func isAlpha(_ c: Character) -> Bool { return isUpperCase(c) || isLowerCase(c) }
    private func isAlphaNumeric(_ c: Character) -> Bool { return isAlpha(c) || isDigit(c) }
    
    private func getToken() throws -> ParseToken {
        skipSpace()
        switch lastch {
        case "A"..."Z", "a"..."z":
            var s = ""
            while isAlphaNumeric(lastch) {
                s.append(lastch)
                nextch()
            }
            return .id(s)
        case "0"..."9":
            var s = ""
            while isDigit(lastch) {
                s.append(lastch)
                nextch()
            }
            if lastch == "." {
                s.append(lastch)
                nextch()
                while isDigit(lastch) {
                    s.append(lastch)
                    nextch()
                }
            }
            if lastch == "e" || lastch == "E" {
                s.append(lastch)
                nextch()
                if lastch == "-" {
                    s.append(lastch)
                    nextch()
                }
                while isDigit(lastch) {
                    s.append(lastch)
                    nextch()
                }
            }
            if let v = Double(s) {
                return .number(CGFloat(v))
            }
            throw ParseError.badNumber
        case "+", "-", "*", "/", "(", ")", "\"", "'", "{", "}", ",":
            let op = String(lastch)
            nextch()
            return .operator(op)
        case EOF:
            return .eof
        default:
            let char = lastch
            nextch()
            throw ParseError.badCharacter(char)
        }
    }
    
    private func nextToken() throws {
        lastToken = try getToken()
    }
    
    private var defaultUnitMultiplier: CGFloat {
        switch measurementUnits {
        case .feet_dec, .inches_dec, .feet_frac, .inches_frac:      // these default to inches
            return 100.0
        case .millimeters:
            return 100 / 25.4                    // default to millimeters
        case .meters:
            return 1000 * 100 / 25.4             // default to meters
        }
    }
    
    private var defaultUnitMultiplierNode: ParametricConstant {
        return ParametricConstant(value: defaultUnitMultiplier, context: context)
    }
    
    private func unary() throws -> ParametricNode {
        switch lastToken {
        case .operator("-"):
            try nextToken()
            switch try unary() {
            case let p as ParametricConstant:
                return ParametricConstant(value: 0 - p.value, context: context)
            case let p:
                let zero = ParametricConstant(value: 0, context: context)
                return ParametricOperation(op: "-", left: zero, right: p, context: context)
            }
        case let .id(s):
            try nextToken()
            if let p = context.variableForKey(s) {
                return p
            } else {
                newDefinitions.append(s)
                return context.defineVariable(s, value: 0, type: type)
            }
        case let .number(n):
            var n = n
            let p = ParametricConstant(value: n, context: context)
            try nextToken()
            if case .number(let numerator) = lastToken {
                try nextToken()
                if case .operator("/") = lastToken {
                    try nextToken()
                    if case .number(let denominator) = lastToken {
                        try nextToken()
                        n += numerator / denominator
                    } else {
                        throw ParseError.badFraction
                    }
                } else {
                    throw ParseError.badFraction
                }
            }
            
            switch lastToken {
            case .id("mm"):
                p.value = n * (100 / 25.4)
                try nextToken()
            case .id("m"):
                p.value = n * 1000 * (100 / 25.4)
                try nextToken()
            case .id("in"), .operator("\""):
                p.value = n * 100
                try nextToken()
            case .id("ft"), .operator("'"):
                p.value = n * 1200
                try nextToken()
                if case .number(_) = lastToken {
                    let u = try unary()
                    p.value = p.value + u.value
                }
            default:
                if type == .angle {
                    p.value = n * PI / 180                       // convert from degrees
                } else {
                    p.value = n * defaultUnitMultiplier
                }
            }
            return p
        case .operator("{"):
            try nextToken()
            let x = try anyOperation()
            if case .operator(",") = lastToken {
                try nextToken()
            } else {
                throw ParseError.badExpression
            }
            let y = try anyOperation()
            if case .operator("}") = lastToken {
                try nextToken()
                if let xv = x.value as? CGFloat, let yv = y.value as? CGFloat {
                    let pvalue = CGPoint(x: xv, y: yv)
                    return ParametricConstant(value: NSValue(point: pvalue), context: context)
                }
            }
            throw ParseError.badExpression
        default:
            throw ParseError.badExpression
        }
    }
    
    private func timesOperation() throws -> ParametricNode {
        let p = try unary()
        switch lastToken {
        case .operator("*"):
            try nextToken()
            let q = try timesOperation()
            let qq = ParametricOperation(op: "/", left: q, right: defaultUnitMultiplierNode, context: context)
            return ParametricOperation(op: "*", left: p, right: qq, context: context)
        case .operator("/"):
            try nextToken()
            let q = try timesOperation()
            let qq = ParametricOperation(op: "/", left: q, right: defaultUnitMultiplierNode, context: context)
            return ParametricOperation(op: "/", left: p, right: qq, context: context)
        default:
            return p
        }
    }
    
    private func addOperation() throws -> ParametricNode {
        let p = try timesOperation()
        switch lastToken {
        case .operator("+"):
            try nextToken()
            let q = try addOperation()
            return ParametricOperation(op: "+", left: p, right: q, context: context)
        case .operator("-"):
            try nextToken()
            let q = try addOperation()
            return ParametricOperation(op: "-", left: p, right: q, context: context)
        default:
            return p
        }
    }
    
    private func anyOperation() throws -> ParametricNode {
        return try addOperation()
    }
}
