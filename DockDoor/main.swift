import AppKit

if CLIHandler.handleIfNeeded() {
    exit(0)
}

let appDelegate = AppDelegate()
NSApplication.shared.delegate = appDelegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
