# Advanced Calculator

Scientific calculator for iOS, written in SwiftUI. It supports Arabic and English, VoiceOver, a persisted calculation history, spoken keypad buttons, and an on-device voice assistant.

Bundle id: `com.alimarfadi.advancedcalculator`. Minimum iOS 17.

## Features

- Basic arithmetic (`+ − × ÷`), decimal point, percent, sign toggle, and equals.
- Scientific operations: power, square, square root, cube root, nth root (`nroot(3, 8)`), sine, cosine, and tangent in degrees, natural log, log base 10, factorial (integers 0 through 170), pi, e, and parentheses.
- Expressions are evaluated on device. Divide-by-zero and domain errors are shown on screen.
- History stores each successful equals result (expression and result) in `UserDefaults`. Tap a row to load it again.
- Two separate delete controls:
  - **C** clears the current display to zero and does not touch history.
  - **Clear History** deletes every saved calculation and does not clear the current display.
  - Backspace removes the last digit or function from the current entry.
- Keypad buttons can be spoken with `AVSpeechSynthesizer` in `ar-SA` or `en-US` when keyboard speech is on.
- Voice assistant screen with exactly four actions: Cancel, Pause (or Resume), Save Calculation, and Exit.
  - Spoken math such as "5 times 5" and "5 to the power of 5" is parsed locally, including Arabic phrases such as في، أس، جذر، زائد، ناقص، and قسمة على.
  - If the phrase is not math, the assistant shows and (when spoken output is on) speaks exactly: `لم أفهم شيء، ستتم إعادة المحاولة بعد عدة ثواني`, waits a few seconds, then listens again unless you cancelled or exited.
  - Recognition uses `SFSpeechRecognizer` and sets `requiresOnDeviceRecognition = true` when that locale supports on-device recognition.
  - A short beep can play when listening starts. The tone is synthesized; the app does not ship an audio file.
- Settings: app language (Arabic or English, applied immediately and saved), keyboard speech, assistant spoken output, and the start beep.
- The settings screen ends with exactly: `تم تطوير هذا التطبيق بواسطة علي حسين المرفدي`. That line and the voice error phrase are intentionally the same in both languages.
- VoiceOver labels, useful hints, button traits, Dynamic Type, and right-to-left layout when the app language is Arabic. The numeric keypad and expression stay left-to-right so formulas remain readable.

## Open in Xcode

1. Open `AdvancedCalculator.xcodeproj` on a Mac with Xcode 15 or newer.
2. The shared scheme is `AdvancedCalculator`.
3. Signing in the project is left unsigned (`CODE_SIGNING_ALLOWED` is NO) so a continuous-integration Mac can archive without an Apple Developer team. To run on your own iPhone from Xcode, open Signing & Capabilities, enable signing, and choose your personal team.
4. Speech recognition and the microphone need a physical device for a realistic test. The simulator often has no microphone and may not support on-device recognition for `ar-SA` or `en-US`.

Privacy strings are in `Info.plist`, with Arabic and English copies in `InfoPlist.strings`. There is no background mode.

## Ad-hoc IPA

`.github/workflows/ios-adhoc-ipa.yml` runs on `macos-latest` for pushes to `main` and for manual `workflow_dispatch`.

The workflow archives for a generic iOS device with code signing disabled, copies `AdvancedCalculator.app` into `Payload/`, signs that app with `codesign --force --deep --sign -` (ad-hoc identity, not an Apple certificate), and zips it as `AdvancedCalculator-adhoc.ipa`. The artifact name is `AdvancedCalculator-adhoc` and it is kept for 14 days.

That IPA is for sideload tools such as TrollStore. It is not an App Store build and it is not signed with a paid Apple Developer certificate. This repository does not contain a Team ID or a distribution certificate. Downloading the artifact requires a logged-in GitHub account; Actions artifact URLs are not permanent anonymous links.
