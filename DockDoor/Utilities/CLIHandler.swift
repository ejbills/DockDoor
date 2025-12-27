import AppKit

/// Handles CLI arguments when DockDoor is invoked from the command line
enum CLIHandler {
    /// Returns true if CLI args were handled (app should exit), false otherwise
    static func handleIfNeeded() -> Bool {
        let args = Array(CommandLine.arguments.dropFirst())
        guard !args.isEmpty else { return false }

        // Parse all --key=value arguments
        var parsedArgs: [String: String] = [:]
        var command: String?

        for arg in args {
            guard arg.hasPrefix("--") else { continue }
            let stripped = String(arg.dropFirst(2))
            let parts = stripped.split(separator: "=", maxSplits: 1)
            let key = String(parts[0])
            let value = parts.count > 1 ? String(parts[1]) : nil

            if command == nil, !["x", "y"].contains(key) {
                command = key
                if let value {
                    parsedArgs[parameterName(for: key)] = value
                }
            } else {
                parsedArgs[key] = value ?? ""
            }
        }

        guard let command else { return false }

        if command == "help" {
            printHelp()
            return true
        }

        // Build URL with all parameters
        var urlString = "dockdoor-cli://\(command)"
        if !parsedArgs.isEmpty {
            let queryItems = parsedArgs.compactMap { key, value -> String? in
                guard let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
                return "\(key)=\(encoded)"
            }
            urlString += "?" + queryItems.joined(separator: "&")
        }

        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        return true
    }

    private static func parameterName(for command: String) -> String {
        switch command {
        case "show-preview": "app"
        case "show-preview-pid": "pid"
        case "show-preview-bundle": "bundle"
        case "focus", "minimize", "close", "maximize", "hide", "fullscreen", "center",
             "fill-left", "fill-right", "fill-top", "fill-bottom",
             "fill-top-left", "fill-top-right", "fill-bottom-left", "fill-bottom-right":
            "window"
        default: "value"
        }
    }

    private static func printHelp() {
        print("""
        DockDoor CLI - Control DockDoor from the command line

        Preview Commands:
          --show-preview=<app>       Show preview for app by name
          --show-preview-pid=<pid>   Show preview for app by process ID
          --show-preview-bundle=<id> Show preview for app by bundle ID
          --hide-preview             Hide the current preview window
          --trigger-switcher         Show the window switcher

        Position (optional, use with preview commands):
          --x=<pixels>               X coordinate for preview position
          --y=<pixels>               Y coordinate for preview position

        Window Actions:
          --focus=<id>               Focus window
          --minimize=<id>            Minimize window
          --close=<id>               Close window
          --maximize=<id>            Maximize window
          --hide=<id>                Hide window
          --fullscreen=<id>          Toggle fullscreen
          --center=<id>              Center window

        Window Positioning:
          --fill-left=<id>           Fill left half
          --fill-right=<id>          Fill right half
          --fill-top=<id>            Fill top half
          --fill-bottom=<id>         Fill bottom half
          --fill-top-left=<id>       Fill top-left quarter
          --fill-top-right=<id>      Fill top-right quarter
          --fill-bottom-left=<id>    Fill bottom-left quarter
          --fill-bottom-right=<id>   Fill bottom-right quarter

        Other:
          --help                     Show this help message

        Examples:
          DockDoor --show-preview=Safari
          DockDoor --show-preview=Safari --x=100 --y=500
          DockDoor --trigger-switcher
          DockDoor --focus=12345

        Note: DockDoor must be running.
        """)
    }
}
