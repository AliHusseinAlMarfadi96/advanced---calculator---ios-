import Foundation

enum EvalFailure: Error, Equatable {
    case divideByZero
    case domain
    case syntax
}

enum ExpressionEvaluator {
    private static let prefixFunctions: Set<String> = [
        "sin", "cos", "tan", "ln", "log", "sqrt", "cbrt", "square"
    ]
    private static let callFunctions: Set<String> = [
        "sin", "cos", "tan", "ln", "log", "sqrt", "cbrt", "square", "nroot"
    ]

    static func evaluate(_ expression: String) throws -> Double {
        var parser = Parser(Array(expression.lowercased()))
        let value = try parser.parseExpression()
        parser.skipWhitespace()
        if parser.peek() != nil {
            throw EvalFailure.syntax
        }
        guard value.isFinite else { throw EvalFailure.domain }
        return value
    }

    static func format(_ value: Double) -> String {
        guard value.isFinite else { return "0" }
        if abs(value) < 1e-12 { return "0" }
        let nearest = value.rounded()
        if abs(value - nearest) < 1e-8 * max(1, abs(value)), abs(nearest) < 1e15 {
            return String(format: "%.0f", nearest)
        }
        return String(format: "%.10g", value)
    }

    private struct Parser {
        let chars: [Character]
        var index: Int = 0

        mutating func parseExpression() throws -> Double {
            var value = try parseTerm()
            while true {
                if match("+") {
                    value += try parseTerm()
                } else if match("-") {
                    value -= try parseTerm()
                } else {
                    break
                }
                if !value.isFinite { throw EvalFailure.domain }
            }
            return value
        }

        mutating func parseTerm() throws -> Double {
            var value = try parsePower()
            while true {
                if match("*") {
                    value *= try parsePower()
                } else if match("/") {
                    let divisor = try parsePower()
                    if abs(divisor) < 1e-12 { throw EvalFailure.divideByZero }
                    value /= divisor
                } else {
                    break
                }
                if !value.isFinite { throw EvalFailure.domain }
            }
            return value
        }

        mutating func parsePower() throws -> Double {
            let base = try parseUnary()
            if match("^") {
                let exponent = try parsePower()
                return try raise(base, exponent)
            }
            return base
        }

        mutating func parseUnary() throws -> Double {
            skipWhitespace()
            if match("+") { return try parseUnary() }
            if match("-") {
                let value = try parseUnary()
                return -value
            }
            let saved = index
            if let identifier = readIdentifier() {
                if prefixFunctions.contains(identifier) {
                    skipWhitespace()
                    if peek() != "(" {
                        let argument = try parseUnary()
                        return try apply(identifier, argument)
                    }
                }
                index = saved
            }
            return try parsePostfix()
        }

        mutating func parsePostfix() throws -> Double {
            var value = try parsePrimary()
            while true {
                if match("!") {
                    value = try factorial(value)
                } else if match("%") {
                    value /= 100
                } else {
                    break
                }
            }
            return value
        }

        mutating func parsePrimary() throws -> Double {
            skipWhitespace()
            if match("(") {
                let value = try parseExpression()
                guard match(")") else { throw EvalFailure.syntax }
                return value
            }
            if let number = readNumber() {
                return number
            }
            guard let identifier = readIdentifier() else { throw EvalFailure.syntax }
            if identifier == "pi" { return Double.pi }
            if identifier == "e" { return 2.718281828459045 }
            guard callFunctions.contains(identifier) else { throw EvalFailure.syntax }
            guard match("(") else { throw EvalFailure.syntax }
            if identifier == "nroot" {
                let indexValue = try parseExpression()
                guard match(",") else { throw EvalFailure.syntax }
                let radicand = try parseExpression()
                guard match(")") else { throw EvalFailure.syntax }
                return try nthRoot(indexValue, radicand)
            }
            let argument = try parseExpression()
            guard match(")") else { throw EvalFailure.syntax }
            return try apply(identifier, argument)
        }

        func peek() -> Character? {
            index < chars.count ? chars[index] : nil
        }

        mutating func skipWhitespace() {
            while let character = peek(), character.isWhitespace {
                index += 1
            }
        }

        mutating func match(_ expected: Character) -> Bool {
            skipWhitespace()
            guard peek() == expected else { return false }
            index += 1
            return true
        }

        mutating func readIdentifier() -> String? {
            skipWhitespace()
            guard let first = peek(), first.isLetter else { return nil }
            var text = ""
            while let character = peek(), character.isLetter {
                text.append(character)
                index += 1
            }
            return text
        }

        mutating func readNumber() -> Double? {
            skipWhitespace()
            let start = index
            var sawDigit = false
            var sawDot = false
            if peek() == "." {
                let next = index + 1
                if next < chars.count, chars[next].isNumber {
                    sawDot = true
                    index += 1
                }
            }
            while let character = peek() {
                if character.isNumber {
                    sawDigit = true
                    index += 1
                } else if character == ".", !sawDot {
                    sawDot = true
                    index += 1
                } else {
                    break
                }
            }
            guard sawDigit else {
                index = start
                return nil
            }
            var literal = String(chars[start..<index])
            if literal.hasSuffix(".") { literal.removeLast() }
            guard let value = Double(literal) else {
                index = start
                return nil
            }
            return value
        }
    }

    private static func apply(_ name: String, _ value: Double) throws -> Double {
        switch name {
        case "sin":
            return sin(value * .pi / 180)
        case "cos":
            return cos(value * .pi / 180)
        case "tan":
            let radians = value * .pi / 180
            let adjacent = cos(radians)
            if abs(adjacent) < 1e-12 { throw EvalFailure.domain }
            return sin(radians) / adjacent
        case "ln":
            if value <= 0 { throw EvalFailure.domain }
            return Foundation.log(value)
        case "log":
            if value <= 0 { throw EvalFailure.domain }
            return Foundation.log10(value)
        case "sqrt":
            if value < 0 { throw EvalFailure.domain }
            return Foundation.sqrt(value)
        case "cbrt":
            if value < 0 { return -Foundation.pow(-value, 1.0 / 3.0) }
            return Foundation.pow(value, 1.0 / 3.0)
        case "square":
            return value * value
        default:
            throw EvalFailure.syntax
        }
    }

    private static func raise(_ base: Double, _ exponent: Double) throws -> Double {
        if abs(exponent.rounded() - exponent) < 1e-9, abs(exponent) < 10000 {
            return try integerPower(base, Int(exponent.rounded()))
        }
        if base < 0 { throw EvalFailure.domain }
        let value = Foundation.pow(base, exponent)
        if !value.isFinite { throw EvalFailure.domain }
        return value
    }

    private static func integerPower(_ base: Double, _ exponent: Int) throws -> Double {
        if exponent == 0 { return 1 }
        if base == 0 {
            if exponent < 0 { throw EvalFailure.divideByZero }
            return 0
        }
        var result = 1.0
        var factor = base
        var remaining = abs(exponent)
        while remaining > 0 {
            if remaining & 1 == 1 { result *= factor }
            remaining >>= 1
            if remaining > 0 { factor *= factor }
            if !result.isFinite || !factor.isFinite { throw EvalFailure.domain }
        }
        if exponent < 0 {
            if result == 0 { throw EvalFailure.divideByZero }
            return 1 / result
        }
        return result
    }

    private static func factorial(_ value: Double) throws -> Double {
        if value < 0 || value > 170 || abs(value.rounded() - value) > 1e-8 {
            throw EvalFailure.domain
        }
        let limit = Int(value.rounded())
        if limit <= 1 { return 1 }
        var result = 1.0
        for step in 1...limit {
            result *= Double(step)
            if !result.isFinite { throw EvalFailure.domain }
        }
        return result
    }

    private static func nthRoot(_ index: Double, _ radicand: Double) throws -> Double {
        if abs(index) < 1e-12 || abs(index.rounded() - index) > 1e-8 {
            throw EvalFailure.domain
        }
        let degree = Int(index.rounded())
        if radicand < 0 && degree % 2 == 0 { throw EvalFailure.domain }
        if radicand < 0 {
            return -Foundation.pow(-radicand, 1.0 / Double(degree))
        }
        let value = Foundation.pow(radicand, 1.0 / Double(degree))
        if !value.isFinite { throw EvalFailure.domain }
        return value
    }
}
