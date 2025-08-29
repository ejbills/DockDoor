import Foundation

enum AppleScriptExecutor {
    @discardableResult
    static func run(_ script: String, timeout: TimeInterval = 5.0) -> (output: String?, error: String?) {
        let preview = script.replacingOccurrences(of: "\n", with: " ⏎ ")
        print("[AppleScriptExecutor] Executing AppleScript (\(Int(timeout))s timeout): \(preview.prefix(160))…")

        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            let errorMsg = "Failed to create NSAppleScript object"
            print("[AppleScriptExecutor] Error: \(errorMsg)")
            return (nil, errorMsg)
        }

        // Execute with timeout handling using DispatchSemaphore
        let semaphore = DispatchSemaphore(value: 0)
        var result: (output: String?, error: String?) = (nil, nil)

        DispatchQueue.global().async {
            let output = scriptObject.executeAndReturnError(&error)
            result = (output.stringValue, nil)
            semaphore.signal()
        }

        let timeoutResult = semaphore.wait(timeout: .now() + timeout)
        if timeoutResult == .timedOut {
            let errorMsg = "AppleScript execution timed out"
            print("[AppleScriptExecutor] Error: \(errorMsg)")
            return (nil, errorMsg)
        }

        if let output = result.output {
            print("[AppleScriptExecutor] stdout: \(output)")
        }
        if let error = result.error {
            print("[AppleScriptExecutor] error: \(error)")
        }

        return result
    }
}
