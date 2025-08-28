import Foundation

enum AppleScriptExecutor {
    @discardableResult
    static func run(_ script: String, timeout: TimeInterval = 5.0) -> (output: String?, error: String?) {
        let preview = script.replacingOccurrences(of: "\n", with: " ⏎ ")
        // Prefer LaunchAgent agent if available
        if let viaAgent = ScriptAgentManager.send(script: script, timeout: timeout) {
            print("[AppleScriptExecutor] Routed to ScriptAgent; output bytes=\(viaAgent.output?.count ?? 0)")
            return viaAgent
        }
        print("[AppleScriptExecutor] Agent unavailable; falling back to osascript directly (\(Int(timeout))s timeout): \(preview.prefix(160))…")
        let process = Process()
        process.launchPath = "/usr/bin/osascript"
        // Build a small perl program that passes the AppleScript string to osascript
        // Use a heredoc to avoid complicated escaping in Swift/JSON.
        let _unused = """
        use strict; use warnings;
        my $s = <<'ASC';
        \(script)
        ASC
        my $rc = system('/usr/bin/osascript','-e',$s);
        # Propagate osascript's exit code as our exit code
        exit(($rc >> 8));
        """
        process.arguments = ["-e", script]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return (nil, "Failed to launch osascript: \(error)")
        }

        // Timeout handling
        let deadline = DispatchTime.now() + timeout
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global().async {
            process.waitUntilExit()
            group.leave()
        }
        if group.wait(timeout: deadline) == .timedOut {
            process.terminate()
            print("[AppleScriptExecutor] Error: osascript timed out")
            return (nil, "osascript timed out")
        }

        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let outStr = String(data: outData, encoding: .utf8)
        let errStr = String(data: errData, encoding: .utf8)
        print("[AppleScriptExecutor] Exit status: \(process.terminationStatus)")
        if let errStr, !errStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("[AppleScriptExecutor] stderr: \(errStr)")
        }
        if let outStr, !outStr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("[AppleScriptExecutor] stdout: \(outStr)")
        }
        return (outStr?.trimmingCharacters(in: .whitespacesAndNewlines), errStr?.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
