import Foundation

enum AppleScriptExecutor {
    @discardableResult
    static func run(_ script: String, timeout: TimeInterval = 5.0) -> (output: String?, error: String?) {
        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            return (nil, "Failed to create NSAppleScript object")
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
            return (nil, "AppleScript execution timed out")
        }

        return result
    }
}
