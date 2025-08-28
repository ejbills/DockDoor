import Foundation

enum ScriptAgentPaths {
    static let root = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Application Support/DockDoor/ScriptAgent")
    static let req = (root as NSString).appendingPathComponent("req.fifo")
    static let resp = (root as NSString).appendingPathComponent("resp.fifo")
    static let launchAgents = (NSHomeDirectory() as NSString).appendingPathComponent("Library/LaunchAgents")
    static let plistPath = (launchAgents as NSString).appendingPathComponent("com.dockdoor.scriptagent.plist")
    static let runnerPath = (root as NSString).appendingPathComponent("runner.sh")
}

enum ScriptAgentManager {
    static func ensureInstalled() {
        do {
            try FileManager.default.createDirectory(atPath: ScriptAgentPaths.root, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(atPath: ScriptAgentPaths.launchAgents, withIntermediateDirectories: true)

            // Write runner script
            let runner = runnerScript()
            if !FileManager.default.fileExists(atPath: ScriptAgentPaths.runnerPath) {
                try runner.write(toFile: ScriptAgentPaths.runnerPath, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: NSNumber(value: Int16(0o755))], ofItemAtPath: ScriptAgentPaths.runnerPath)
                print("[ScriptAgent] Wrote runner: \(ScriptAgentPaths.runnerPath)")
            }

            // Write LaunchAgent plist
            let plist = launchAgentPlist()
            try plist.write(toFile: ScriptAgentPaths.plistPath, atomically: true, encoding: .utf8)
            print("[ScriptAgent] Wrote plist: \(ScriptAgentPaths.plistPath)")

            // Try to bootstrap (load) the agent
            _ = runProcess("/bin/launchctl", ["bootstrap", "gui/\(geteuid())", ScriptAgentPaths.plistPath])
            _ = runProcess("/bin/launchctl", ["enable", "gui/\(geteuid())/com.dockdoor.scriptagent"])
            _ = runProcess("/bin/launchctl", ["kickstart", "-k", "gui/\(geteuid())/com.dockdoor.scriptagent"])
        } catch {
            print("[ScriptAgent] Installation error: \(error)")
        }
    }

    static func send(script: String, timeout: TimeInterval = 5.0) -> (output: String?, error: String?)? {
        // Require the FIFOs to exist (created by runner). If missing, try ensureInstalled and return nil to fallback
        guard FileManager.default.fileExists(atPath: ScriptAgentPaths.req),
              FileManager.default.fileExists(atPath: ScriptAgentPaths.resp)
        else {
            print("[ScriptAgent] FIFOs missing; installing agent…")
            ensureInstalled()
            return nil
        }

        let encoded = Data(script.utf8).base64EncodedString()
        do {
            // Write request
            let reqHandle = try FileHandle(forWritingTo: URL(fileURLWithPath: ScriptAgentPaths.req))
            if let data = (encoded + "\n").data(using: .utf8) {
                try reqHandle.write(contentsOf: data)
            }
            try reqHandle.close()

            // Read response with timeout
            let respURL = URL(fileURLWithPath: ScriptAgentPaths.resp)
            let start = Date()
            while Date().timeIntervalSince(start) < timeout {
                if let h = try? FileHandle(forReadingFrom: respURL) {
                    let data = try h.readToEnd() ?? Data()
                    try? h.close()
                    if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                        // Response is base64 of output or a JSON line; for simplicity, pass through
                        return (str.trimmingCharacters(in: .whitespacesAndNewlines), nil)
                    }
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
            return (nil, "agent timeout")
        } catch {
            return (nil, "agent IO error: \(error)")
        }
    }

    private static func runProcess(_ path: String, _ args: [String]) -> Int32 {
        let p = Process()
        p.launchPath = path
        p.arguments = args
        do { try p.run() } catch { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }

    private static func runnerScript() -> String {
        """
        #!/bin/bash
        set -euo pipefail
        ROOT="$HOME/Library/Application Support/DockDoor/ScriptAgent"
        REQ="$ROOT/req.fifo"
        RESP="$ROOT/resp.fifo"
        mkdir -p "$ROOT"
        [[ -p "$REQ" ]] || mkfifo "$REQ"
        [[ -p "$RESP" ]] || mkfifo "$RESP"
        while true; do
          if IFS= read -r line < "$REQ"; then
            script="$(: | /usr/bin/base64 -D <<<"$line")"
            out="$(: | /usr/bin/osascript -e "$script" 2>&1)"
            code=$?
            printf '%s\n' "$out" > "$RESP"
          fi
        done
        """
    }

    private static func launchAgentPlist() -> String {
        let program = ScriptAgentPaths.runnerPath
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>com.dockdoor.scriptagent</string>
          <key>ProgramArguments</key>
          <array>
            <string>\(program)</string>
          </array>
          <key>RunAtLoad</key>
          <true/>
          <key>KeepAlive</key>
          <true/>
          <key>StandardOutPath</key>
          <string>\(ScriptAgentPaths.root)/agent.log</string>
          <key>StandardErrorPath</key>
          <string>\(ScriptAgentPaths.root)/agent.err</string>
        </dict>
        </plist>
        """
    }
}
