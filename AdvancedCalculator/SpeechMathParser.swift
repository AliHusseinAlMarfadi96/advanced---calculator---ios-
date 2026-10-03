import Foundation

enum SpeechInterpretation: Equatable {
    case success(expression: String, result: Double)
    case notUnderstood
    case mathError(EvalFailure)
}

enum SpeechMathParser {
    /// `memory`, when set, is prefixed onto a leading-operator phrase (`+ 5`, `ناقص خمسة`, `x5`)
    /// so the phrase continues the running total. A full expression such as `2x5` does not start
    /// with an operator after normalization and replaces that total instead.
    static func interpret(_ spoken: String, continuingFrom memory: Double? = nil) -> SpeechInterpretation {
        let normalized = normalize(spoken)
        guard !normalized.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .notUnderstood
        }
        var rest = normalized
        var output = ""
        var sawUnknownWord = false
        while !rest.isEmpty {
            if rest.first?.isWhitespace == true {
                output.append(" ")
                while rest.first?.isWhitespace == true { rest.removeFirst() }
                continue
            }
            if let match = matchReplacement(in: rest) {
                if !match.token.isEmpty {
                    output.append(" ")
                    output.append(match.token)
                    output.append(" ")
                }
                rest.removeFirst(match.length)
                continue
            }
            let character = rest.removeFirst()
            if character.isNumber || "()+-*/^!%.,".contains(character) {
                output.append(character)
                continue
            }
            if character.isLetter {
                sawUnknownWord = true
                output.append(character)
                while let next = rest.first, next.isLetter {
                    output.append(next)
                    rest.removeFirst()
                }
                continue
            }
        }
        if sawUnknownWord || containsArabic(output) {
            return .notUnderstood
        }
        let expression = tidy(output)
        let solvable: String
        if isContinuation(expression) {
            // "+5" / "*5" / "-5" keep going from the remembered total. "*" alone is not math.
            guard hasMathValue(expression) else { return .notUnderstood }
            solvable = ExpressionEvaluator.format(memory ?? 0) + expression
        } else {
            guard hasMathValue(expression) else { return .notUnderstood }
            solvable = expression
        }
        do {
            let value = try ExpressionEvaluator.evaluate(solvable)
            return .success(expression: solvable, result: value)
        } catch let failure as EvalFailure {
            switch failure {
            case .syntax:
                return .notUnderstood
            case .divideByZero, .domain:
                return .mathError(failure)
            }
        } catch {
            return .notUnderstood
        }
    }

    private struct Match {
        var token: String
        var length: Int
    }

    private static func matchReplacement(in text: String) -> Match? {
        for item in replacements {
            if let length = prefixLength(text, phrase: item.phrase) {
                return Match(token: item.token, length: length)
            }
        }
        return nil
    }

    /// Longest spoken phrase first. Token is the calculator expression fragment.
    /// An empty token drops a filler word.
    private static let replacements: [(phrase: String, token: String)] = {
        let pairs: [(String, String)] = [
            ("to the power of", "^"),
            ("raised to the power of", "^"),
            ("to the power", "^"),
            ("power of", "^"),
            ("raised to", "^"),
            ("divided by", "/"),
            ("divide by", "/"),
            ("multiplied by", "*"),
            ("square root of", "sqrt"),
            ("cube root of", "cbrt"),
            ("square root", "sqrt"),
            ("cube root", "cbrt"),
            ("open parenthesis", "("),
            ("close parenthesis", ")"),
            ("open parentheses", "("),
            ("close parentheses", ")"),
            ("open bracket", "("),
            ("close bracket", ")"),
            ("natural log of", "ln"),
            ("natural log", "ln"),
            ("square of", "square"),
            ("sine of", "sin"),
            ("cosine of", "cos"),
            ("tangent of", "tan"),
            ("what is", ""),
            ("what's", ""),
            ("whats", ""),
            ("calculate", ""),
            ("compute", ""),
            ("equals", ""),
            ("equal", ""),
            ("please", ""),
            ("times", "*"),
            ("plus", "+"),
            ("minus", "-"),
            ("power", "^"),
            ("divide", "/"),
            ("over", "/"),
            ("squared", "^2"),
            ("cubed", "^3"),
            ("factorial", "!"),
            ("percent", "%"),
            ("percentage", "%"),
            ("sine", "sin"),
            ("cosine", "cos"),
            ("tangent", "tan"),
            ("point", "."),
            ("dot", "."),
            ("zero", "0"),
            ("one", "1"),
            ("two", "2"),
            ("three", "3"),
            ("four", "4"),
            ("five", "5"),
            ("six", "6"),
            ("seven", "7"),
            ("eight", "8"),
            ("nine", "9"),
            ("ten", "10"),
            ("eleven", "11"),
            ("twelve", "12"),
            ("thirteen", "13"),
            ("fourteen", "14"),
            ("fifteen", "15"),
            ("sixteen", "16"),
            ("seventeen", "17"),
            ("eighteen", "18"),
            ("nineteen", "19"),
            ("twenty", "20"),
            ("thirty", "30"),
            ("forty", "40"),
            ("fifty", "50"),
            ("sixty", "60"),
            ("seventy", "70"),
            ("eighty", "80"),
            ("ninety", "90"),
            ("hundred", "100"),
            ("pi", "pi"),
            ("log", "log"),
            ("ln", "ln"),
            ("the", ""),
            ("of", ""),
            ("an", ""),
            ("a", ""),
            ("um", ""),
            ("uh", ""),
            ("x", "*"),
            ("euler", "e"),
            ("e", "e"),
            ("الى القوه", "^"),
            ("الي القوه", "^"),
            ("الجذر التكعيبي", "cbrt"),
            ("الجذر التربيعي", "sqrt"),
            ("جذر تكعيبي", "cbrt"),
            ("جذر تربيعي", "sqrt"),
            ("لوغاريتم طبيعي", "ln"),
            ("جيب التمام", "cos"),
            ("قسمه على", "/"),
            ("مقسوم على", "/"),
            ("الى اس", "^"),
            ("الي اس", "^"),
            ("قوس مفتوح", "("),
            ("قوس مغلق", ")"),
            ("في الميه", "%"),
            ("بالميه", "%"),
            ("ما ناتج", ""),
            ("ما هو", ""),
            ("لو سمحت", ""),
            ("من فضلك", ""),
            ("لوغاريتم", "log"),
            ("يساوي", ""),
            ("احسب", ""),
            ("تربيع", "^2"),
            ("تكعيب", "^3"),
            ("عاملي", "!"),
            ("مضروب", "!"),
            ("القوه", "^"),
            ("زائد", "+"),
            ("زائدا", "+"),
            ("ناقص", "-"),
            ("ناقصا", "-"),
            ("قسمه", "/"),
            ("ضرب", "*"),
            ("جذر", "sqrt"),
            ("جيب", "sin"),
            ("جتا", "cos"),
            ("قوه", "^"),
            ("فاصله", "."),
            ("نقطه", "."),
            ("ثمانيه", "8"),
            ("اثنين", "2"),
            ("اثنان", "2"),
            ("ثلاثه", "3"),
            ("اربعه", "4"),
            ("خمسه", "5"),
            ("سبعه", "7"),
            ("تسعه", "9"),
            ("عشره", "10"),
            ("صفر", "0"),
            ("واحد", "1"),
            ("ثلاث", "3"),
            ("اربع", "4"),
            ("خمس", "5"),
            ("سته", "6"),
            ("سبع", "7"),
            ("ثمان", "8"),
            ("تسع", "9"),
            ("عشر", "10"),
            ("اس", "^"),
            ("ظل", "tan"),
            ("ظا", "tan"),
            ("جا", "sin"),
            ("في", "*"),
            ("على", "/"),
            ("باي", "pi"),
            ("ست", "6"),
            ("كم", ""),
            ("هو", ""),
            ("ال", ""),
            ("ل", "")
        ]
        return pairs
            .map { (phrase: normalize($0.0), token: $0.1) }
            .sorted { $0.phrase.count > $1.phrase.count }
    }()

    private static func prefixLength(_ text: String, phrase: String) -> Int? {
        if boundaryPrefix(text, phrase: phrase) {
            return phrase.count
        }
        if text.hasPrefix("ال") {
            let stripped = String(text.dropFirst(2))
            if boundaryPrefix(stripped, phrase: phrase) {
                return phrase.count + 2
            }
        }
        return nil
    }

    private static func boundaryPrefix(_ text: String, phrase: String) -> Bool {
        guard text.hasPrefix(phrase) else { return false }
        let end = text.index(text.startIndex, offsetBy: phrase.count)
        if end == text.endIndex { return true }
        let next = text[end]
        if phrase.last?.isLetter == true && next.isLetter { return false }
        return true
    }

    private static func normalize(_ spoken: String) -> String {
        var text = spoken.lowercased()
        let dropping: Set<UnicodeScalar> = [
            "\u{064B}", "\u{064C}", "\u{064D}", "\u{064E}", "\u{064F}",
            "\u{0650}", "\u{0651}", "\u{0652}", "\u{0670}", "\u{0640}"
        ]
        text = String(text.unicodeScalars.filter { !dropping.contains($0) })
        let folds = [
            ("أ", "ا"), ("إ", "ا"), ("آ", "ا"), ("ى", "ي"),
            ("ؤ", "و"), ("ئ", "ي"), ("ة", "ه")
        ]
        for (from, to) in folds {
            text = text.replacingOccurrences(of: from, with: to)
        }
        let digits: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
            "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
            "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9",
            "×": "*", "÷": "/", "−": "-", "–": "-", "—": "-"
        ]
        var mapped = ""
        for character in text {
            if let digit = digits[character] {
                mapped.append(digit)
            } else if character == "π" {
                mapped.append(" pi ")
            } else if character == "'" || character == "’" {
                continue
            } else if "؟?,;؛:\"“”".contains(character) {
                mapped.append(" ")
            } else {
                mapped.append(character)
            }
        }
        return replaceStandaloneX(mapped)
    }

    /// Letter x between non-letters is multiplication ("2x5", "2 x 5"). Words that contain x stay intact.
    private static func replaceStandaloneX(_ text: String) -> String {
        var characters = Array(text)
        for index in characters.indices {
            guard characters[index] == "x" || characters[index] == "X" else { continue }
            let previousIsLetter = index > characters.startIndex && characters[characters.index(before: index)].isLetter
            let nextIndex = characters.index(after: index)
            let nextIsLetter = nextIndex < characters.endIndex && characters[nextIndex].isLetter
            if !previousIsLetter && !nextIsLetter {
                characters[index] = "*"
            }
        }
        return String(characters)
    }

    private static func tidy(_ raw: String) -> String {
        var text = raw.replacingOccurrences(
            of: #"(\d)\s*\.\s*(\d)"#,
            with: "$1.$2",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\s*([+*/^,%!\-])\s*"#,
            with: "$1",
            options: .regularExpression
        )
        text = text.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func hasMathValue(_ expression: String) -> Bool {
        if expression.contains(where: \.isNumber) { return true }
        return expression.contains("pi") || expression.contains("e")
    }

    private static func containsArabic(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0600...0x06FF).contains(Int($0.value)) }
    }

    /// Continuation when the normalized expression starts with + - * or /.
    /// `2*5` starts with a digit, so it is a standalone expression.
    /// Leading `+` and `-` are included even though the evaluator would treat them as unary.
    private static func isContinuation(_ expression: String) -> Bool {
        guard let first = expression.first else { return false }
        return "+-*/".contains(first)
    }

    /// Whole utterance as a voice command: trimmed, diacritics folded, punctuation ignored.
    static func commandKey(_ spoken: String) -> String {
        let normalized = normalize(spoken)
        var cleaned = ""
        for character in normalized {
            if character.isPunctuation || character.isSymbol {
                cleaned.append(" ")
            } else {
                cleaned.append(character)
            }
        }
        return cleaned.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// Arabic equation speech for the voice assistant ("عشرة زائد خمسة يساوي خمسة عشر").
enum ArabicEquationSpeech {
    static func sentence(expression: String, result: Double) -> String {
        let spokenExpression = verbalize(expression)
        let spokenResult = spell(result)
        if spokenExpression.isEmpty {
            return spokenResult
        }
        return spokenExpression + " يساوي " + spokenResult
    }

    static func spell(_ value: Double) -> String {
        spellLiteral(ExpressionEvaluator.format(value))
    }

    /// Integers from -999 through 999 become words. Everything else is spoken as digits.
    static func spellLiteral(_ literal: String) -> String {
        let negative = literal.hasPrefix("-")
        let body = negative ? String(literal.dropFirst()) : literal
        if let number = Int(body), body == String(number), number <= 999 {
            return spellInteger(negative ? -number : number)
        }
        return literal
    }

    private static let ones = ["", "واحد", "اثنان", "ثلاثة", "أربعة", "خمسة", "ستة", "سبعة", "ثمانية", "تسعة"]
    private static let teens = ["عشرة", "أحد عشر", "اثنا عشر", "ثلاثة عشر", "أربعة عشر", "خمسة عشر", "ستة عشر", "سبعة عشر", "ثمانية عشر", "تسعة عشر"]
    private static let tens = ["", "", "عشرون", "ثلاثون", "أربعون", "خمسون", "ستون", "سبعون", "ثمانون", "تسعون"]
    private static let hundreds = ["", "مئة", "مئتان", "ثلاثمئة", "أربعمئة", "خمسمئة", "ستمئة", "سبعمئة", "ثمانمئة", "تسعمئة"]

    private static func spellInteger(_ number: Int) -> String {
        if number < 0 {
            return "سالب " + spellInteger(-number)
        }
        if number == 0 { return "صفر" }
        if number < 10 { return ones[number] }
        if number < 20 { return teens[number - 10] }
        if number < 100 {
            let unit = number % 10
            let ten = number / 10
            if unit == 0 { return tens[ten] }
            return ones[unit] + " و" + tens[ten]
        }
        let hundred = number / 100
        let remainder = number % 100
        if remainder == 0 { return hundreds[hundred] }
        return hundreds[hundred] + " و" + spellInteger(remainder)
    }

    private static func verbalize(_ expression: String) -> String {
        let chars = Array(expression)
        var index = 0
        var parts: [String] = []
        var expectingOperand = true

        func skipSpaces() {
            while index < chars.count, chars[index].isWhitespace {
                index += 1
            }
        }

        func readNumber() -> String {
            var token = ""
            var sawDot = false
            while index < chars.count {
                let character = chars[index]
                if character.isNumber {
                    token.append(character)
                    index += 1
                } else if character == ".", !sawDot {
                    sawDot = true
                    token.append(character)
                    index += 1
                } else {
                    break
                }
            }
            return token
        }

        func readWord() -> String {
            var token = ""
            while index < chars.count, chars[index].isLetter {
                token.append(chars[index])
                index += 1
            }
            return token
        }

        while index < chars.count {
            skipSpaces()
            if index >= chars.count { break }
            let character = chars[index]

            if character == "-", expectingOperand {
                var look = index + 1
                while look < chars.count, chars[look].isWhitespace { look += 1 }
                if look < chars.count, chars[look].isNumber || chars[look] == "." {
                    index += 1
                    skipSpaces()
                    let token = readNumber()
                    if !token.isEmpty {
                        parts.append(spellLiteral("-" + token))
                        expectingOperand = false
                    }
                    continue
                }
            }

            if "+-*/^".contains(character) {
                parts.append(operatorWord(character))
                expectingOperand = true
                index += 1
                continue
            }
            if character == "(" {
                parts.append("قوس مفتوح")
                expectingOperand = true
                index += 1
                continue
            }
            if character == ")" {
                parts.append("قوس مغلق")
                expectingOperand = false
                index += 1
                continue
            }
            if character == "," {
                parts.append("فاصلة")
                expectingOperand = true
                index += 1
                continue
            }
            if character.isNumber || character == "." {
                let token = readNumber()
                if !token.isEmpty {
                    parts.append(spellLiteral(token))
                    expectingOperand = false
                }
                continue
            }
            if character.isLetter {
                let word = readWord()
                if !word.isEmpty {
                    parts.append(functionWord(word))
                    expectingOperand = false
                }
                continue
            }
            index += 1
        }
        return parts.joined(separator: " ")
    }

    private static func operatorWord(_ character: Character) -> String {
        switch character {
        case "+": return "زائد"
        case "-": return "ناقص"
        case "*": return "ضرب"
        case "/": return "قسمة"
        case "^": return "أس"
        default: return String(character)
        }
    }

    private static func functionWord(_ word: String) -> String {
        switch word {
        case "sin": return "جيب"
        case "cos": return "جيب التمام"
        case "tan": return "ظل"
        case "ln": return "لوغاريتم طبيعي"
        case "log": return "لوغاريتم"
        case "sqrt": return "جذر"
        case "cbrt": return "جذر تكعيبي"
        case "square": return "تربيع"
        case "nroot": return "جذر نوني"
        case "pi": return "باي"
        case "e": return "إي"
        default: return word
        }
    }
}
