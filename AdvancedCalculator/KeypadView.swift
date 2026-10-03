import SwiftUI

struct KeypadView: View {
    @EnvironmentObject private var settings: AppSettings
    @ObservedObject var model: CalculatorViewModel
    @ObservedObject var speaker: ButtonSpeaker

    @ScaledMetric(relativeTo: .title3) private var keyHeight = 54

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(keys) { key in
                keyButton(key)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .contain)
    }

    private var keys: [CalcKey] {
        [
            sin, cos, tan, squareRoot,
            ln, log, square, power,
            cubeRoot, nthRoot, factorial, percent,
            pi, e, openParen, closeParen,
            clear, backspace, sign, divide,
            digit("7"), digit("8"), digit("9"), multiply,
            digit("4"), digit("5"), digit("6"), subtract,
            digit("1"), digit("2"), digit("3"), add,
            digit("0"), decimal, comma, equals
        ]
    }

    private func keyButton(_ key: CalcKey) -> some View {
        let label = L10n.text(key.labelKey, language: settings.language)
        let speech = L10n.text(key.speechKey, language: settings.language)
        let hint = key.hintKey.map { L10n.text($0, language: settings.language) }
        return Button {
            if key.special == .equals {
                model.equals()
                speakEqualsResult(buttonSpeech: speech)
            } else {
                speaker.speak(
                    speech,
                    languageCode: settings.language.speechLocale,
                    enabled: settings.keyboardSpeech,
                    rate: settings.speechRate
                )
                perform(key)
            }
        } label: {
            Text(key.title)
                .font(.title3.weight(.semibold))
                .minimumScaleFactor(0.4)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: keyHeight)
                .foregroundStyle(foreground(key.tone))
        }
        .buttonStyle(.plain)
        .background(background(key.tone), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityLabel(label)
        .modifier(OptionalAccessibilityHint(hint: hint))
        .accessibilityAddTraits(.isButton)
    }

    private func speakEqualsResult(buttonSpeech: String) {
        let succeeded = model.failure == nil && !model.resultText.isEmpty
        if settings.speakResultAfterEquals && succeeded {
            let sentence = L10n.text("voice.resultSpoken", language: settings.language)
                .replacingOccurrences(of: "%@", with: model.resultText)
            let phrase = settings.keyboardSpeech ? "\(buttonSpeech). \(sentence)" : sentence
            speaker.speak(
                phrase,
                languageCode: settings.language.speechLocale,
                enabled: true,
                rate: settings.speechRate
            )
        } else {
            speaker.speak(
                buttonSpeech,
                languageCode: settings.language.speechLocale,
                enabled: settings.keyboardSpeech,
                rate: settings.speechRate
            )
        }
    }

    private func perform(_ key: CalcKey) {
        switch key.special {
        case .clear:
            model.clearDisplay()
        case .backspace:
            model.backspace()
        case .equals:
            model.equals()
        case .sign:
            model.toggleSign()
        case nil:
            if let token = key.token {
                model.input(token)
            }
        }
    }

    private func background(_ tone: KeyTone) -> Color {
        switch tone {
        case .digit: return Color(red: 0.17, green: 0.19, blue: 0.23)
        case .function: return Color(red: 0.11, green: 0.24, blue: 0.38)
        case .operation: return Color(red: 1.0, green: 0.62, blue: 0.04)
        case .clear: return Color(red: 0.92, green: 0.25, blue: 0.22)
        case .equals: return Color(red: 0.18, green: 0.78, blue: 0.38)
        }
    }

    private func foreground(_ tone: KeyTone) -> Color {
        switch tone {
        case .operation, .equals: return .black
        default: return .white
        }
    }

    private func digit(_ value: String) -> CalcKey {
        CalcKey(
            id: "d\(value)",
            title: value,
            labelKey: "key.digit.\(value)",
            hintKey: nil,
            speechKey: "speak.digit.\(value)",
            tone: .digit,
            token: value,
            special: nil
        )
    }

    private var decimal: CalcKey { key("decimal", title: ".", label: "key.decimal", speech: "speak.decimal", tone: .digit, token: ".") }
    private var comma: CalcKey { key("comma", title: ",", label: "key.comma", hint: "key.comma.hint", speech: "speak.comma", tone: .function, token: ",") }
    private var add: CalcKey { key("add", title: "+", label: "key.add", speech: "speak.add", tone: .operation, token: "+") }
    private var subtract: CalcKey { key("sub", title: "−", label: "key.subtract", speech: "speak.subtract", tone: .operation, token: "-") }
    private var multiply: CalcKey { key("mul", title: "×", label: "key.multiply", speech: "speak.multiply", tone: .operation, token: "*") }
    private var divide: CalcKey { key("div", title: "÷", label: "key.divide", speech: "speak.divide", tone: .operation, token: "/") }
    private var percent: CalcKey { key("pct", title: "%", label: "key.percent", hint: "key.percent.hint", speech: "speak.percent", tone: .function, token: "%") }
    private var power: CalcKey { key("pow", title: "xʸ", label: "key.power", hint: "key.power.hint", speech: "speak.power", tone: .function, token: "^") }
    private var square: CalcKey { key("sq", title: "x²", label: "key.square", hint: "key.square.hint", speech: "speak.square", tone: .function, token: "^2") }
    private var squareRoot: CalcKey { key("sqrt", title: "√", label: "key.sqrt", speech: "speak.sqrt", tone: .function, token: "sqrt(") }
    private var cubeRoot: CalcKey { key("cbrt", title: "∛", label: "key.cbrt", speech: "speak.cbrt", tone: .function, token: "cbrt(") }
    private var nthRoot: CalcKey { key("nroot", title: "ⁿ√", label: "key.nroot", hint: "key.nroot.hint", speech: "speak.nroot", tone: .function, token: "nroot(") }
    private var sin: CalcKey { key("sin", title: "sin", label: "key.sin", speech: "speak.sin", tone: .function, token: "sin(") }
    private var cos: CalcKey { key("cos", title: "cos", label: "key.cos", speech: "speak.cos", tone: .function, token: "cos(") }
    private var tan: CalcKey { key("tan", title: "tan", label: "key.tan", speech: "speak.tan", tone: .function, token: "tan(") }
    private var ln: CalcKey { key("ln", title: "ln", label: "key.ln", speech: "speak.ln", tone: .function, token: "ln(") }
    private var log: CalcKey { key("log", title: "log", label: "key.log", speech: "speak.log", tone: .function, token: "log(") }
    private var factorial: CalcKey { key("fact", title: "n!", label: "key.factorial", hint: "key.factorial.hint", speech: "speak.factorial", tone: .function, token: "!") }
    private var pi: CalcKey { key("pi", title: "π", label: "key.pi", speech: "speak.pi", tone: .function, token: "pi") }
    private var e: CalcKey { key("e", title: "e", label: "key.e", speech: "speak.e", tone: .function, token: "e") }
    private var openParen: CalcKey { key("open", title: "(", label: "key.open", speech: "speak.open", tone: .function, token: "(") }
    private var closeParen: CalcKey { key("close", title: ")", label: "key.close", speech: "speak.close", tone: .function, token: ")") }
    private var sign: CalcKey { key("sign", title: "±", label: "key.sign", hint: "key.sign.hint", speech: "speak.sign", tone: .function, special: .sign) }
    private var backspace: CalcKey { key("del", title: "⌫", label: "key.backspace", hint: "key.backspace.hint", speech: "speak.backspace", tone: .function, special: .backspace) }
    private var clear: CalcKey { key("clear", title: "C", label: "key.clear", hint: "key.clear.hint", speech: "speak.clear", tone: .clear, special: .clear) }
    private var equals: CalcKey { key("eq", title: "=", label: "key.equals", hint: "key.equals.hint", speech: "speak.equals", tone: .equals, special: .equals) }

    private func key(
        _ id: String,
        title: String,
        label: String,
        hint: String? = nil,
        speech: String,
        tone: KeyTone,
        token: String? = nil,
        special: CalcKey.Special? = nil
    ) -> CalcKey {
        CalcKey(id: id, title: title, labelKey: label, hintKey: hint, speechKey: speech, tone: tone, token: token, special: special)
    }
}

private struct CalcKey: Identifiable {
    enum Special { case clear, backspace, equals, sign }
    let id: String
    let title: String
    let labelKey: String
    let hintKey: String?
    let speechKey: String
    let tone: KeyTone
    let token: String?
    let special: Special?
}

private enum KeyTone {
    case digit, operation, function, clear, equals
}

private struct OptionalAccessibilityHint: ViewModifier {
    let hint: String?
    @ViewBuilder
    func body(content: Content) -> some View {
        if let hint, !hint.isEmpty {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}
