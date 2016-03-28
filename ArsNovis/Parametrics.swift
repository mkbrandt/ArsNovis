//
//  Parametrics.swift
//  ArsNovis
//
//  Created by Matt Brandt on 3/23/16.
//  Copyright © 2016 WalkingDog Design. All rights reserved.
//

import Foundation

/// Parametric Value - represents a property of type CGFloat or CGPoint

class ParametricValue: NSObject
{
    var target: NSObject
    var name: String
    
    var value: NSValue {
        get {
            if let v = target.valueForKey(name) as? CGFloat {
                return v
            }
            return CGFloat(0)
        }
        set { target.setValue(newValue, forKey: name) }
    }
    
    init(target: NSObject, name: String) {
        self.target = target
        self.name = name
        super.init()
    }
}

/// Parametric Variable - a named variable of type CGFloat or CGPoint

class ParametricVariable: NSObject
{
    var name: String
    var value: NSValue
    
    init(name: String, value: NSValue) {
        self.name = name
        self.value = value
        super.init()
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

/// Parametric - Represents a parametric equation node

indirect enum Parametric {
    case Value(ParametricValue)
    case Variable(ParametricVariable)
    case Constant(NSValue)
    case Plus(Parametric, Parametric)
    case Minus(Parametric, Parametric)
    case Times(Parametric, Parametric)
    case Divide(Parametric, Parametric)
    case Equal(Parametric, Parametric)
    
    /// value - returns the value of a parametric equation node
    
    var value: NSValue {
        get {
            switch self {
            case let .Value(pv):
                return pv.value
            case let .Constant(k):
                return k
            case let .Variable(v):
                return v.value
            case let .Plus(left, right):
                return left.value + right.value
            case let .Minus(left, right):
                return left.value - right.value
            case let .Times(left, right):
                return left.value * right.value
            case let .Divide(left, right):
                return left.value / right.value
            case let .Equal(_, right):
                return right.value
            }
        }
        set {
            switch self {
            case let .Value(pv):
                pv.value = newValue
            case let .Variable(v):
                v.value = newValue
            default:
                break
            }
        }
    }
    
    /// resolve - do any assignments in a parametric equation
    
    func resolve() {
        if case let .Equal(left, right) = self {
            if case let .Value(pv) = left {
                pv.value = right.value
            }
        }
    }
}

class ParametricContext: NSObject
{
    var variablesByName: [String: Parametric] = [:]
    var variables: [ParametricVariable] = []
    var parametrics: [Parametric] = []
    
    override func setValue(value: AnyObject?, forUndefinedKey key: String) {
        if let value = value as? NSValue {
            if let v = variablesByName[key] {
                switch v {
                case let .Value(val):
                    val.value = value
                case let .Variable(v):
                    v.value = value
                default:
                    variablesByName[key] = invertValue(value, forNode: v)
                }
            } else {
                let pv = ParametricVariable(name: key, value: value)
                variables.append(pv)
                variablesByName[key] = .Variable(pv)
            }
        } else if let equation = value as? Parametric {
            variablesByName[key] = equation
        }
    }
    
    override func valueForUndefinedKey(key: String) -> AnyObject? {
        if let pv = variablesByName[key] {
            return pv.value
        }
        return nil
    }
    
    func parametricForKey(key: String) -> Parametric {
        if let p = variablesByName[key] {
            return p
        } else {
            let pv = ParametricVariable(name: key, value: CGFloat(0))
            variables.append(pv)
            let p = Parametric.Variable(pv)
            variablesByName[key] = p
            return p
        }
    }
    
    func resolve() { parametrics.forEach { $0.resolve() }}
    
    func invertValue(value: NSValue, forNode node: Parametric) -> Parametric {
        switch node {
        case let .Variable(pv):
            pv.value = value
            return node
        case .Plus(let .Constant(a), let b):
            return invertValue(value - a, forNode: b)
        case .Plus(let a, let .Constant(b)):
            return invertValue(value - b, forNode: a)
        case .Minus(let a, let .Constant(b)):
            return invertValue(value + b, forNode: a)
        case .Times(let .Constant(a), let b):
            return invertValue(value / a, forNode: b)
        case .Equal(_, let b):
            invertValue(value, forNode: b)
        default:
            break
        }
        return node
    }

    func assign(target: NSObject, property: String, expression: Parametric) {
        let param = ParametricValue(target: target, name: property)
        let assignment = Parametric.Equal(.Value(param), expression)
        observeExpression(expression)
        parametrics = parametrics.filter {
            if case .Equal(.Value(let pv), _) = $0 {
                if pv.target === target && pv.name == property {
                    return false
                }
            }
            return true
        }
        parametrics.append(assignment)
    }
    
    func observeExpression(expr: Parametric) {
        switch expr {
        case let .Value(pv):
            addObserver(pv.target, forKeyPath: pv.name, options: NSKeyValueObservingOptions.New, context: nil)
        case let .Plus(a, b):
            observeExpression(a)
            observeExpression(b)
        case let .Minus(a, b):
            observeExpression(a)
            observeExpression(b)
        case let .Times(a, b):
            observeExpression(a)
            observeExpression(b)
        case let .Divide(a, b):
            observeExpression(a)
            observeExpression(b)
        default:
            break
        }
    }
    
    /// Calls resolve to update any parametrics that depepend on this value
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        resolve()
    }
}

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
    var expression: Parametric = .Constant(0.0)
    var value: NSValue {
        return expression.value
    }

    private let EOF: Character = "\0"
    private var content = ""
    private var location: String.Index
    private var lastToken: ParseToken
    private var lastch: Character {
        if location == content.endIndex {
            return EOF
        }
        return content[location]
    }
    
    init(context: ParametricContext, string: String) {
        content = string
        location = content.startIndex
        self.context = context
        lastToken = .EOF
        if let t = try? getToken() {
            lastToken = t
        }
        if let v = try? addOperation() {
            expression = v
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
    
    private func unary() throws -> Parametric {
        switch lastToken {
        case .Operator("-"):
            try nextToken()
            switch try unary() {
            case .Constant(let n):
                return .Constant(0 - n)
            case let p:
                return .Minus(.Constant(0), p)
            }
        case let .ID(s):
            try nextToken()
            return context.parametricForKey(s)
        case let .Number(n):
            var n = n
            var p = Parametric.Constant(n)
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
                p = Parametric.Constant(n * (100 / 25.4))
                try nextToken()
            case .ID("in"), .Operator("\""):
                p = Parametric.Constant(n * 100)
                try nextToken()
            case .ID("ft"), .Operator("'"):
                p = Parametric.Constant(n * 1200)
                try nextToken()
            default:
                break;
            }
            return p
        default:
            throw ParseError.BadExpression
        }
    }
    
    private func timesOperation() throws -> Parametric {
        let p = try unary()
        switch lastToken {
        case .Operator("*"):
            try nextToken()
            return try Parametric.Times(p, timesOperation())
        case .Operator("/"):
            try nextToken()
            return try Parametric.Divide(p, timesOperation())
        default:
            return p
        }
    }
    
    private func addOperation() throws -> Parametric {
        let p = try timesOperation()
        switch lastToken {
        case .Operator("+"):
            try nextToken()
            return try Parametric.Plus(p, addOperation())
        case .Operator("-"):
            try nextToken()
            return try Parametric.Minus(p, addOperation())
        default:
            return p
        }
    }
}
