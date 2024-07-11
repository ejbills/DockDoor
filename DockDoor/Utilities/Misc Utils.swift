//
//  Misc Utils.swift
//  DockDoor
//
//  Created by Ethan Bills on 6/13/24.
//

import Cocoa
import Defaults
import Carbon

func quitApp() {
    // Terminate the current application
    NSApplication.shared.terminate(nil)
}

func restartApplication ()-> Void {
    MessageUtil.showMessage(title: String(localized: "Restart required"), message: String(localized: "Please restart the application to apply your changes. Click OK to quit the app."), completion: { result in
        if result == .ok {
            quitApp()
        }})
}

func getWindowSize() -> CGSize {
    return CGSize(width: optimisticScreenSizeWidth / Defaults[.sizingMultiplier], height: optimisticScreenSizeHeight / Defaults[.sizingMultiplier])
}

// Helper extension to calculate distance between CGPoints
extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
}

// Measure string length in px
func measureString(_ string: String, fontSize: CGFloat, fontWeight: NSFont.Weight = .regular) -> CGSize {
    let font = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
    let attributes: [NSAttributedString.Key: Any] = [.font: font]
    let attributedString = NSAttributedString(string: string, attributes: attributes)
    let size = attributedString.size()
    return size
}

struct modifierConverter {
    static func toString(_ modifierIntValue: Int) -> String {
        if modifierIntValue == Defaults[.Int64maskCommand] {
            return "⌘"
        }
        else if modifierIntValue == Defaults[.Int64maskAlternate] {
            return "⌥"
        }
        else if modifierIntValue == Defaults[.Int64maskControl] {
            return "⌃"
        }
        else {
            return " "
        }
    }
}

struct KeyCodeConverter {
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
            var realLength: Int = 0
            
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
