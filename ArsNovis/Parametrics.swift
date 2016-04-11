//
//  Parametrics.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/23/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Foundation

enum MeasurementType: Int {
    case Distance, Angle
}

/// Parametric Value - represents a property of type CGFloat or CGPoint

class ParametricNode: NSObject, NSCoding
{
    var context: ParametricContext
    var value: NSValue
    
    init(context: ParametricContext) {
        self.context = context
        value = 0
        super.init()
    }
    
    required init?(coder decoder: NSCoder) {
        if let context = decoder.decodeObjectForKey("context") as? ParametricContext {
            self.context = context
            self.value = 0
        } else {
            return nil
        }
        super.init()
    }
    
    func encodeWithCoder(encoder: NSCoder) {
        encoder.encodeObject(context, forKey: "context")
    }
    
    var isVariable: Bool { return false }
    
    override var description: String { return "node" }
    
    func dependsOn(node: ParametricNode) -> Bool {
        return node == self
    }
    
    var variableNode: ParametricNode? { return nil }
}

class ParametricConstant: ParametricNode
{
    init(value: NSValue, context: ParametricContext) {
        super.init(context: context)
        self.value = value
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        if let value = decoder.decodeObjectForKey("value") as? NSValue {
            self.value = value
        } else {
            return nil
        }
    }
    
    override func encodeWithCoder(encoder: NSCoder) {
        super.encodeWithCoder(encoder)
        encoder.encodeObject(value, forKey: "value")
    }
    
    override var description: String { return "\(value)" }
}

class ParametricValue: ParametricNode
{
    var target: Graphic
    var name: String
    
    override var isVariable: Bool   { return true }
    
    override var value: NSValue {
        get {
            if let v = target.valueForKey(name) as? CGFloat {
                return v
            }
            return CGFloat(0)
        }
        set {
            if let val = target.valueForKey(name) as? NSValue where val != newValue {
                //print("\(context.prefix)set \(self) = \(newValue)")
                target.setValue(newValue, forKey: name)
            }
        }
    }
    
    init(target: Graphic, name: String, context: ParametricContext) {
        self.target = target
        self.name = name
        super.init(context: context)
    }
    
    required init?(coder decoder: NSCoder) {
        if let target = decoder.decodeObjectForKey("target") as? Graphic, let name = decoder.decodeObjectForKey("name") as? String {
            self.target = target
            self.name = name
        } else {
            return nil
        }
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(encoder: NSCoder) {
        super.encodeWithCoder(encoder)
        encoder.encodeObject(target, forKey: "target")
        encoder.encodeObject(name, forKey: "name")
    }
    
    override var description: String { return "G\(target.identifier).\(name)" }
    
    override var variableNode: ParametricNode? { return self }
}

/// Parametric Variable - a named variable of type CGFloat or CGPoint

class ParametricVariable: ParametricNode
{
    var name: String
    override var value: NSValue {
        didSet {
            //print("\(context.prefix)\(self) set to \(value)")
            context.resolve(self)
        }
    }
    var measurementType: MeasurementType
    override var isVariable: Bool { return true }
    
    var transformer: NSValueTransformer { return measurementType == .Angle ? AngleTransformer() : DistanceTransformer() }
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
        if let name = decoder.decodeObjectForKey("name") as? String,
          let value = decoder.decodeObjectForKey("value") as? NSValue {
            self.name = name
            measurementType = decoder.decodeBoolForKey("isAngle") ? .Angle : .Distance
            super.init(coder: decoder)
            self.value = value
        } else {
            return nil
        }
    }
    
    override func encodeWithCoder(encoder: NSCoder) {
        super.encodeWithCoder(encoder)
        encoder.encodeObject(name, forKey: "name")
        encoder.encodeObject(value, forKey: "value")
        encoder.encodeBool(measurementType == .Angle, forKey: "isAngle")
    }
    
    override var description: String { return "\(name)" }
    
    override var variableNode: ParametricNode? { return self }
}

class ParametricBinding: ParametricNode
{
    var left: ParametricNode
    var right: ParametricNode
    
    override var value: NSValue {
        get { return right.value }
        set {
            right.value = newValue
            left.value = newValue
        }
    }
    
    init(left: ParametricNode, right: ParametricNode, context: ParametricContext) {
        self.left = left
        self.right = right
        super.init(context: context)
    }
    
    required init?(coder decoder: NSCoder) {
        if let left = decoder.decodeObjectForKey("left") as? ParametricNode, let right = decoder.decodeObjectForKey("right") as? ParametricNode {
            self.left = left
            self.right = right
        } else {
            return nil
        }
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(encoder: NSCoder) {
        super.encodeWithCoder(encoder)
        encoder.encodeObject(left, forKey: "left")
        encoder.encodeObject(right, forKey: "right")
    }
    
    func resolve() {
        if !context.isException(left) {
            //print("\(context.prefix)binding value \(left) = \(right) = \(right.value)")
            context.addException(left)
            left.value = right.value
        }
    }
    
    override var description: String { return "\(left) = \(right)" }
    
    override func dependsOn(node: ParametricNode) -> Bool {
        return left.dependsOn(node) || right.dependsOn(node) || super.dependsOn(node)
    }
    
    override var variableNode: ParametricNode? { return right.variableNode }
}

class ParametricOperation: ParametricNode
{
    var op: String
    var left: ParametricNode
    var right: ParametricNode

    override var value: NSValue {
        get {
            switch op {
            case "+":
                return left.value + right.value
            case "-":
                return left.value - right.value
            case "*":
                return left.value * right.value
            case "/":
                return left.value / right.value
            default:
                return right.value
            }
        }
        set {
            //print("\(context.prefix)set \(self) = \(newValue)")
            switch op {
            case "+":
                if left.isVariable {
                    left.value = newValue - right.value
                } else if right.isVariable {
                    right.value = newValue - left.value
                }
            case "-":
                if left.isVariable {
                    left.value = right.value + newValue
                } else if right.isVariable {
                    right.value = left.value - newValue
                }
            case "*":
                if left.isVariable {
                    left.value = newValue / right.value
                } else if right.isVariable {
                    right.value = newValue / left.value
                }
            default:
                break
            }
        }
    }
    
    override var isVariable: Bool {
        if op == "=" {
            return right.isVariable
        }
        return left.isVariable || right.isVariable
    }
    
    init(op: String, left: ParametricNode, right: ParametricNode, context: ParametricContext) {
        self.op = op
        self.left = left
        self.right = right
        super.init(context: context)
    }
    
    required init?(coder decoder: NSCoder) {
        if let op = decoder.decodeObjectForKey("op") as? String,
            let left = decoder.decodeObjectForKey("left") as? ParametricNode,
            let right = decoder.decodeObjectForKey("right") as? ParametricNode {
                self.op = op
                self.left = left
                self.right = right
        } else {
            return nil
        }
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(encoder: NSCoder) {
        super.encodeWithCoder(encoder)
        encoder.encodeObject(op, forKey: "op")
        encoder.encodeObject(left, forKey: "left")
        encoder.encodeObject(right, forKey: "right")
    }
    
    override var description: String { return "\(left) \(op) \(right)" }
    
    override func dependsOn(node: ParametricNode) -> Bool {
        return left.dependsOn(node) || right.dependsOn(node) || super.dependsOn(node)
    }
    
    override var variableNode: ParametricNode? { return left.variableNode ?? right.variableNode }
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
    optional func parametricContextDidUpdate(parametricContext: ParametricContext)
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
        if let variables = decoder.decodeObjectForKey("variables") as? [ParametricVariable] {
            self.variables = variables
            for v in variables {
                variablesByName[v.name] = v
            }
        }
        if let parametrics = decoder.decodeObjectForKey("parametrics") as? [ParametricBinding] {
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
    
    func encodeWithCoder(encoder: NSCoder) {
        encoder.encodeObject(variables, forKey: "variables")
        encoder.encodeObject(parametrics, forKey: "parametrics")
    }
    
    override func setValue(value: AnyObject?, forUndefinedKey key: String) {
        if let value = value as? NSValue {
            if let v = variablesByName[key] {
                v.value = value
            }
        }
    }
    
    override func valueForUndefinedKey(key: String) -> AnyObject? {
        if let pv = variablesByName[key] {
            return pv.value
        }
        return nil
    }
    
    func variableForKey(key: String) -> ParametricVariable? {
        return variablesByName[key]
    }
    
    func defineVariable(key: String, value: NSValue, type: MeasurementType) -> ParametricVariable {
        let pv = ParametricVariable(name: key, value: value, type: type, context: self)
        variables.append(pv)
        variablesByName[key] = pv
        return pv
    }
    
    func startObserving(target: Graphic, property: String) {
        print("\(self) registers for \(property) of G\(target.identifier)")
        observing.append(ObservationInfo(target: target, property: property))
        target.addObserver(self, forKeyPath: property, options: NSKeyValueObservingOptions.New, context: nil)
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
            info.target.addObserver(self, forKeyPath: info.property, options: NSKeyValueObservingOptions.New, context: nil)
        }
        
        for p in parametrics {
            if p.right.isVariable {             // reverse resolve to get new variables
                p.right.value = p.left.value
            }
        }
    }
    
    /// resolve -- propagate any changes to variable values to the rest of the context
    
    func resolve(depends: ParametricNode?) {
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
    
    func assign(target: Graphic, property: String, expression: ParametricNode) {
        let param = ParametricValue(target: target, name: property, context: self)
        let assignment = ParametricBinding(left: param, right: expression, context: self)
        startObserving(target, property: property)
        parametrics = parametrics.filter {
            if let p = $0.left as? ParametricValue where p.target == target && p.name == property {
                return false
            }
            return true
        }
        parametrics.append(assignment)
        showParametrics()
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if let target = object as? Graphic, let keyPath = keyPath {
            if isException(target, key: keyPath) {
                return
            }
            //print("\(prefix)start observing \(keyPath) for G\(target.identifier), context = \(self), change = \(change![NSKeyValueChangeNewKey])")
            let oldPrefix = prefix
            prefix += "  "
            let oldExceptions = exceptions
            for p in parametrics {
                if let pv = p.left as? ParametricValue where pv.target == target && pv.name == keyPath {
                    if p.left.value != p.right.value {
                        addException(p.left)
                        p.right.value = p.left.value
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
    
    func addException(node: ParametricNode) {
        exceptions.append(node)
        showExceptions()
    }
    
    func removeException(node: ParametricNode) {
        exceptions = exceptions.filter { $0 != node }
        showExceptions()
    }
    
    func isException(node: ParametricNode) -> Bool {
        return exceptions.contains(node)
    }
    
    func isException(graphic: Graphic, key: String) -> Bool {
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
    case Number(CGFloat)
    case ID(String)
    case Operator(String)
    case Error(String)
    case EOF
}

enum ParseError: ErrorType {
    case BadExpression
    case BadCharacter(Character)
    case BadNumber
    case BadFraction
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
    private var defaultValue: NSValue = 0
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
        lastToken = .EOF
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
            location = location.successor()
        }
    }
    
    private func skipSpace() {
        while lastch == " " || lastch == "\n" || lastch == "\t" {
            nextch()
        }
    }
    
    private func isUpperCase(c: Character) -> Bool {
        switch c {
        case "A"..."Z":
            return true
        default:
            return false
        }
    }
    
    private func isLowerCase(c: Character) -> Bool {
        switch c {
        case "a"..."z":
            return true
        default:
            return false
        }
    }
    
    private func isDigit(c: Character) -> Bool {
        switch c {
        case "0"..."9":
            return true
        default:
            return false
        }
    }
    
    private func isAlpha(c: Character) -> Bool { return isUpperCase(c) || isLowerCase(c) }
    private func isAlphaNumeric(c: Character) -> Bool { return isAlpha(c) || isDigit(c) }
    
    private func getToken() throws -> ParseToken {
        skipSpace()
        switch lastch {
        case "A"..."Z", "a"..."z":
            var s = ""
            while isAlphaNumeric(lastch) {
                s.append(lastch)
                nextch()
            }
            return .ID(s)
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
                return .Number(CGFloat(v))
            }
            throw ParseError.BadNumber
        case "+", "-", "*", "/", "(", ")", "\"", "'", "{", "}", ",":
            let op = String(lastch)
            nextch()
            return .Operator(op)
        case EOF:
            return .EOF
        default:
            let char = lastch
            nextch()
            throw ParseError.BadCharacter(char)
        }
    }
    
    private func nextToken() throws {
        lastToken = try getToken()
    }
    
    private var defaultUnitMultiplier: CGFloat {
        switch measurementUnits {
        case .Feet_dec, .Inches_dec, .Feet_frac, .Inches_frac:      // these default to inches
            return 100.0
        case .Millimeters:
            return 100 / 25.4                    // default to millimeters
        case .Meters:
            return 1000 * 100 / 25.4             // default to meters
        }
    }
    
    private var defaultUnitMultiplierNode: ParametricConstant {
        return ParametricConstant(value: defaultUnitMultiplier, context: context)
    }
    
    private func unary() throws -> ParametricNode {
        switch lastToken {
        case .Operator("-"):
            try nextToken()
            switch try unary() {
            case let p as ParametricConstant:
                return ParametricConstant(value: 0 - p.value, context: context)
            case let p:
                let zero = ParametricConstant(value: 0, context: context)
                return ParametricOperation(op: "-", left: zero, right: p, context: context)
            }
        case let .ID(s):
            try nextToken()
            if let p = context.variableForKey(s) {
                return p
            } else {
                newDefinitions.append(s)
                return context.defineVariable(s, value: 0, type: type)
            }
        case let .Number(n):
            var n = n
            let p = ParametricConstant(value: n, context: context)
            try nextToken()
            if case .Number(let numerator) = lastToken {
                try nextToken()
                if case .Operator("/") = lastToken {
                    try nextToken()
                    if case .Number(let denominator) = lastToken {
                        try nextToken()
                        n += numerator / denominator
                    } else {
                        throw ParseError.BadFraction
                    }
                } else {
                    throw ParseError.BadFraction
                }
            }
            
            switch lastToken {
            case .ID("mm"):
                p.value = n * (100 / 25.4)
                try nextToken()
            case .ID("m"):
                p.value = n * 1000 * (100 / 25.4)
                try nextToken()
            case .ID("in"), .Operator("\""):
                p.value = n * 100
                try nextToken()
            case .ID("ft"), .Operator("'"):
                p.value = n * 1200
                try nextToken()
            default:
                if type == .Angle {
                    p.value = n * PI / 180                       // convert from degrees
                } else {
                    p.value = n * defaultUnitMultiplier
                }
            }
            return p
        case .Operator("{"):
            try nextToken()
            let x = try anyOperation()
            if case .Operator(",") = lastToken {
                try nextToken()
            } else {
                throw ParseError.BadExpression
            }
            let y = try anyOperation()
            if case .Operator("}") = lastToken {
                try nextToken()
                if let xv = x.value as? CGFloat, yv = y.value as? CGFloat {
                    let pvalue = CGPoint(x: xv, y: yv)
                    return ParametricConstant(value: NSValue(point: pvalue), context: context)
                }
            }
            throw ParseError.BadExpression
        default:
            throw ParseError.BadExpression
        }
    }
    
    private func timesOperation() throws -> ParametricNode {
        let p = try unary()
        switch lastToken {
        case .Operator("*"):
            try nextToken()
            let q = try timesOperation()
            let qq = ParametricOperation(op: "/", left: q, right: defaultUnitMultiplierNode, context: context)
            return ParametricOperation(op: "*", left: p, right: qq, context: context)
        case .Operator("/"):
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
        case .Operator("+"):
            try nextToken()
            let q = try addOperation()
            return ParametricOperation(op: "+", left: p, right: q, context: context)
        case .Operator("-"):
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
