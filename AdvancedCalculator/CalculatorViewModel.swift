import Combine
import Foundation

final class CalculatorViewModel: ObservableObject {
    @Published private(set) var expression: String = "0"
    @Published private(set) var resultText: String = "0"
    @Published private(set) var failure: EvalFailure?
    @Published private(set) var justEvaluated = false

    private var history: HistoryStore?
    private let binaryOperators: Set<Character> = ["+", "-", "*", "/", "^"]

    func attach(_ store: HistoryStore) {
        if history == nil {
            history = store
        }
    }

    func clearDisplay() {
        expression = "0"
        resultText = "0"
        failure = nil
        justEvaluated = false
    }

    func backspace() {
        if justEvaluated {
            clearDisplay()
            return
        }
        guard expression != "0" else { return }
        expression = deletingLastToken(from: expression)
        if expression.isEmpty {
            expression = "0"
        }
        justEvaluated = false
        refresh(showSyntaxErrors: false)
    }

    func toggleSign() {
        if justEvaluated, !resultText.isEmpty {
            expression = resultText
            justEvaluated = false
        }
        if expression.hasSuffix("*(-1)") {
            expression.removeLast("*(-1)".count)
            refresh(showSyntaxErrors: false)
            return
        }
        if let range = expression.range(of: #"\(\-(\d+\.?\d*)\)$"#, options: .regularExpression) {
            let wrapped = String(expression[range])
            let inner = wrapped.dropFirst(2).dropLast()
            expression.replaceSubrange(range, with: inner)
            if expression.isEmpty { expression = "0" }
            refresh(showSyntaxErrors: false)
            return
        }
        guard let range = expression.range(of: #"(\d+\.?\d*)$"#, options: .regularExpression) else {
            if expression == "0" {
                expression = "-"
            } else {
                expression += "*(-1)"
            }
            refresh(showSyntaxErrors: false)
            return
        }
        let number = String(expression[range])
        if range.lowerBound > expression.startIndex {
            let minusIndex = expression.index(before: range.lowerBound)
            if expression[minusIndex] == "-", isUnaryMinus(at: minusIndex) {
                expression.remove(at: minusIndex)
                if expression.isEmpty { expression = "0" }
                refresh(showSyntaxErrors: false)
                return
            }
        }
        if range.lowerBound == expression.startIndex {
            expression = "-" + number
        } else {
            expression.replaceSubrange(range, with: "(-" + number + ")")
        }
        refresh(showSyntaxErrors: false)
    }

    func input(_ token: String) {
        if justEvaluated {
            let continues = token.count == 1 && token.first.map { binaryOperators.contains($0) } == true
                || token == "!" || token == "%" || token == "^2" || token == "^"
            if continues, !resultText.isEmpty {
                expression = resultText
            } else {
                expression = "0"
            }
            justEvaluated = false
        }
        if token == "." {
            appendDecimal()
            refresh(showSyntaxErrors: false)
            return
        }
        if token.count == 1, let character = token.first, binaryOperators.contains(character) {
            appendOperator(character)
            refresh(showSyntaxErrors: false)
            return
        }
        if expression == "0", replacesLeadingZero(token) {
            expression = ""
        }
        if !expression.isEmpty, endsWithValue(expression), startsValue(token) {
            expression += "*"
        }
        expression += token
        refresh(showSyntaxErrors: false)
    }

    func equals() {
        refresh(showSyntaxErrors: true)
        guard failure == nil else {
            justEvaluated = false
            return
        }
        history?.add(expression: expression, result: resultText)
        justEvaluated = true
    }

    func useHistory(_ entry: HistoryEntry) {
        expression = entry.expression
        resultText = entry.result
        failure = nil
        justEvaluated = false
    }

    private func appendDecimal() {
        if justEvaluated {
            expression = "0"
            justEvaluated = false
        }
        let segment = currentNumberSegment(expression)
        if segment.contains(".") { return }
        if expression.isEmpty || expression == "0" {
            expression = "0."
            return
        }
        if let last = expression.last, last.isNumber {
            expression += "."
        } else {
            if endsWithValue(expression) {
                expression += "*"
            }
            expression += "0."
        }
    }

    private func appendOperator(_ op: Character) {
        if expression.isEmpty || expression == "-" {
            if op == "-" { expression = "-" }
            return
        }
        if let last = expression.last, binaryOperators.contains(last) {
            expression.removeLast()
            expression.append(op)
            return
        }
        expression.append(op)
    }

    private func replacesLeadingZero(_ token: String) -> Bool {
        if token == "!" || token == "%" || token == "^" || token == "^2" { return false }
        return true
    }

    private func endsWithValue(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        if last.isNumber || last == ")" || last == "!" || last == "%" { return true }
        if text.hasSuffix("pi") { return true }
        if text.hasSuffix("e"), text.dropLast().last?.isLetter != true { return true }
        return false
    }

    private func startsValue(_ token: String) -> Bool {
        if token == "pi" || token == "e" || token == "(" { return true }
        if token.hasSuffix("(") { return true }
        if token.first?.isNumber == true { return true }
        return false
    }

    private func isUnaryMinus(at index: String.Index) -> Bool {
        if index == expression.startIndex { return true }
        let previous = expression.index(before: index)
        return "+-*/^(".contains(expression[previous])
    }

    private func currentNumberSegment(_ text: String) -> String {
        var segment = ""
        for character in text.reversed() {
            if character.isNumber || character == "." {
                segment.insert(character, at: segment.startIndex)
            } else {
                break
            }
        }
        return segment
    }

    private func deletingLastToken(from text: String) -> String {
        let tokens = [
            "nroot(", "square(", "sqrt(", "cbrt(", "sin(", "cos(", "tan(", "log(", "ln(",
            "nroot", "square", "sqrt", "cbrt", "sin", "cos", "tan", "log", "ln", "pi"
        ]
        for token in tokens where text.hasSuffix(token) {
            return String(text.dropLast(token.count))
        }
        return String(text.dropLast())
    }

    private func refresh(showSyntaxErrors: Bool) {
        let source = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.isEmpty || source == "-" {
            resultText = source == "-" ? "" : "0"
            failure = showSyntaxErrors ? .syntax : nil
            return
        }
        do {
            let value = try ExpressionEvaluator.evaluate(source)
            resultText = ExpressionEvaluator.format(value)
            failure = nil
        } catch let error as EvalFailure {
            switch error {
            case .syntax:
                if showSyntaxErrors {
                    failure = .syntax
                    resultText = ""
                } else {
                    failure = nil
                    resultText = ""
                }
            case .divideByZero, .domain:
                failure = error
                resultText = ""
            }
        } catch {
            if showSyntaxErrors {
                failure = .syntax
                resultText = ""
            }
        }
    }
}
