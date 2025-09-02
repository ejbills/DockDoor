import Foundation

enum AppleScriptExecutor {
    @discardableResult
    static func run(_ script: String, timeoutSeconds: Int? = 5) -> String? {
        // Wrap the script with AppleScript's built-in timeout block when requested.
        let wrapped: String = if let t = timeoutSeconds {
            "with timeout of \(t) seconds\n\(script)\nend timeout"
        } else {
            script
        }

        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: wrapped) else {
            return nil
        }
        let output = scriptObject.executeAndReturnError(&error)
        guard error == nil else { return nil }
        return output.stringValue
    }
}
