import AppKit
import Carbon

enum KeyboardLabel {
    static func localizedKey(for keyCode: UInt16) -> String {
        // Try Unicode key layout first
        if let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
           let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        {
            let cfData = unsafeBitCast(ptr, to: CFData.self)
            if let result = translate(from: cfData, keyCode: keyCode) {
                return result
            }
        }
        // As a last resort, return the key code itself
        return String(keyCode)
    }

    private static func translate(from data: CFData, keyCode: UInt16) -> String? {
        guard let bytes = CFDataGetBytePtr(data) else { return nil }

        var output: String?
        bytes.withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { layout in
            var deadKeyState: UInt32 = 0
            let maxLen = 8
            var chars = [UniChar](repeating: 0, count: maxLen)
            var length = 0

            let err = UCKeyTranslate(
                layout,
                keyCode,
                UInt16(kUCKeyActionDisplay),
                0, // no modifiers; we want the base display character for the key
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                maxLen,
                &length,
                &chars
            )

            if err == noErr, length > 0 {
                let str = String(utf16CodeUnits: chars, count: length)
                // Use uppercase for display consistency on letter keys
                output = str.uppercased()
            }
        }
        return output
    }
}
