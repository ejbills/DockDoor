import Carbon
import Cocoa
import Defaults

func askUserToRestartApplication() {
    MessageUtil.showAlert(
        title: String(localized: "Restart required"),
        message: String(localized: "Please restart the application to apply your changes. Click OK to quit the app."),
        actions: [.ok, .cancel],
        completion: { result in
            if result == .ok {
                let appDelegate = NSApplication.shared.delegate as! AppDelegate
                appDelegate.restartApp()
            }
        }
    )
}

func resetDefaultsToDefaultValues() {
    Defaults.removeAll()

    // reset the launched value
    Defaults[.launched] = true
}

func getWindowSize() -> CGSize {
    CGSize(width: optimisticScreenSizeWidth / Defaults[.sizingMultiplier], height: optimisticScreenSizeHeight / Defaults[.sizingMultiplier])
}

// Measure string length in px
func measureString(_ string: String, fontSize: CGFloat, fontWeight: NSFont.Weight = .regular) -> CGSize {
    let font = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let attributedString = NSAttributedString(string: string, attributes: attributes)
    let size = attributedString.size()
    return size
}

enum modifierConverter {
    static func toString(_ modifierIntValue: Int) -> String {
        if modifierIntValue == Defaults[.Int64maskCommand] {
            "⌘"
        } else if modifierIntValue == Defaults[.Int64maskAlternate] {
            "⌥"
        } else if modifierIntValue == Defaults[.Int64maskControl] {
            "⌃"
        } else {
            " "
        }
    }
}

enum KeyCodeConverter {
    static func toString(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 48:
            return "⇥" // Tab symbol
        case 51:
            return "⌫" // Delete symbol
        case 53:
            return "⎋" // Escape symbol
        case 36:
            return "↩︎" // Return symbol
        default:
            let source = TISCopyCurrentKeyboardInputSource().takeUnretainedValue()
            let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)

            guard let data = layoutData else {
                return "?"
            }

            let layout = unsafeBitCast(data, to: CFData.self)
            let keyboardLayout = unsafeBitCast(CFDataGetBytePtr(layout), to: UnsafePointer<UCKeyboardLayout>.self)

            var keysDown: UInt32 = 0
            var chars = [UniChar](repeating: 0, count: 4)
            var realLength = 0

            let result = UCKeyTranslate(keyboardLayout,
                                        keyCode,
                                        UInt16(kUCKeyActionDisplay),
                                        0,
                                        UInt32(LMGetKbdType()),
                                        UInt32(kUCKeyTranslateNoDeadKeysBit),
                                        &keysDown,
                                        chars.count,
                                        &realLength,
                                        &chars)

            if result == noErr {
                return String(utf16CodeUnits: chars, count: realLength)
            } else {
                return "?"
            }
        }
    }
}
