import Defaults
import Foundation

/// Debug logger for tracking performance-critical operations
enum DebugLogger {
    private static let queue = DispatchQueue(label: "DebugLogger", qos: .utility)
    private static let logFileURL: URL = {
        let tempDir = FileManager.default.temporaryDirectory
        return tempDir.appendingPathComponent("DockDoor-Debug.log")
    }()

    private static func formattedTimestamp() -> String { Date.now.description }

    private static func writeToFile(_ line: String) {
        queue.async {
            guard let data = (line + "\n").data(using: .utf8) else { return }

            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: logFileURL, options: .atomic)
            }

            print(line)
        }
    }

    /// Log an operation with optional details
    static func log(_ operation: String, details: String? = nil) {
        guard Defaults[.debugMode] else { return }

        var logLine = "[\(formattedTimestamp())] \(operation)"
        if let details {
            logLine += " - \(details)"
        }
        writeToFile(logLine)
    }

    /// Log an operation with measured duration
    static func logWithDuration(_ operation: String, details: String? = nil, duration: TimeInterval) {
        guard Defaults[.debugMode] else { return }

        var logLine = "[\(formattedTimestamp())] \(operation)"
        logLine += String(format: " (%.3fms)", duration * 1000)
        if let details {
            logLine += " - \(details)"
        }
        writeToFile(logLine)
    }

    /// Measure and log the execution time of a block
    @discardableResult
    static func measure<T>(_ operation: String, details: String? = nil, block: () throws -> T) rethrows -> T {
        guard Defaults[.debugMode] else {
            return try block()
        }

        let startTime = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(startTime)

        logWithDuration(operation, details: details, duration: duration)
        return result
    }

    /// Measure and log the execution time of an async block
    @discardableResult
    static func measureAsync<T>(_ operation: String, details: String? = nil, block: () async throws -> T) async rethrows -> T {
        guard Defaults[.debugMode] else {
            return try await block()
        }

        let startTime = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(startTime)

        logWithDuration(operation, details: details, duration: duration)
        return result
    }

    /// Export logs to a file and return the URL
    static func exportLogs() -> URL? {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else { return nil }
        return logFileURL
    }

    /// Clear all logs
    static func clearLogs() {
        queue.async {
            try? FileManager.default.removeItem(at: logFileURL)
        }
    }

    /// Get log count
    static func getLogCount() -> Int {
        queue.sync {
            guard FileManager.default.fileExists(atPath: logFileURL.path),
                  let content = try? String(contentsOf: logFileURL, encoding: .utf8)
            else { return 0 }

            return content.components(separatedBy: .newlines).filter { !$0.isEmpty }.count
        }
    }
}
