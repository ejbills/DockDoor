import AppKit

enum LauncherShortcutResolver {
    private struct ParallManifest {
        let targetBundleIdentifier: String
        let dataStoragePath: String?
    }

    private struct CoalitionInfo {
        var coalitionIDs: (UInt64, UInt64) = (0, 0)
        var reserved: (UInt64, UInt64, UInt64) = (0, 0, 0)
    }

    private static let procPIDCoalitionInfoFlavor: Int32 = 20
    private static let launchBundleIdentifierPrefix = "__CFBundleIdentifier="

    static func runningApplications(forBundleAt url: URL, bundleIdentifier: String) -> [NSRunningApplication] {
        let direct = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { owningShortcutBundleIdentifier(of: $0) == nil }
        if direct.contains(where: { $0.activationPolicy == .regular }) {
            return direct
        }

        let instances = shortcutInstances(at: url, shortcutBundleIdentifier: bundleIdentifier, launchers: direct)
        return instances.isEmpty ? direct : instances
    }

    static func owningShortcutBundleIdentifier(of app: NSRunningApplication) -> String? {
        guard let bundleIdentifier = app.bundleIdentifier,
              let launchIdentifier = processStrings(of: app.processIdentifier).flatMap(launchBundleIdentifier),
              launchIdentifier != bundleIdentifier
        else { return nil }

        if let shortcutURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: launchIdentifier),
           parallManifest(at: shortcutURL)?.targetBundleIdentifier == bundleIdentifier
        {
            return launchIdentifier
        }

        let launchers = NSRunningApplication.runningApplications(withBundleIdentifier: launchIdentifier)
        return launchers.contains { isResidentLauncher($0, of: app) } ? launchIdentifier : nil
    }

    static func siblingInstances(of app: NSRunningApplication) -> [NSRunningApplication] {
        guard let bundleIdentifier = app.bundleIdentifier, !bundleIdentifier.isEmpty else { return [app] }
        let owner = owningShortcutBundleIdentifier(of: app)
        let siblings = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { owningShortcutBundleIdentifier(of: $0) == owner }
        return siblings.isEmpty ? [app] : siblings
    }

    private static func shortcutInstances(at url: URL, shortcutBundleIdentifier: String, launchers: [NSRunningApplication]) -> [NSRunningApplication] {
        if let manifest = parallManifest(at: url) {
            return NSRunningApplication.runningApplications(withBundleIdentifier: manifest.targetBundleIdentifier).filter { app in
                guard app.activationPolicy == .regular else { return false }
                if let process = processStrings(of: app.processIdentifier) {
                    if launchBundleIdentifier(process) == shortcutBundleIdentifier {
                        return true
                    }
                    if let dataStoragePath = manifest.dataStoragePath,
                       process.arguments.contains(where: { $0.hasSuffix(dataStoragePath) || $0.contains(dataStoragePath + "/") })
                    {
                        return true
                    }
                }
                return launchers.contains { isResidentLauncher($0, of: app) }
            }
        }

        guard !launchers.isEmpty else { return [] }
        return NSWorkspace.shared.runningApplications.filter { app in
            app.activationPolicy == .regular && launchers.contains { isResidentLauncher($0, of: app) }
        }
    }

    private static func isResidentLauncher(_ launcher: NSRunningApplication, of app: NSRunningApplication) -> Bool {
        let launcherPID = launcher.processIdentifier
        let pid = app.processIdentifier
        guard launcherPID != pid,
              let coalition = coalitionID(of: pid),
              coalitionID(of: launcherPID) == coalition,
              launcher.activationPolicy != .regular,
              launcher.bundleIdentifier != app.bundleIdentifier,
              let launcherPath = launcher.bundleURL?.standardizedFileURL.path,
              let appPath = app.bundleURL?.standardizedFileURL.path,
              launcherPath != appPath,
              !launcherPath.hasPrefix(appPath + "/"),
              !appPath.hasPrefix(launcherPath + "/"),
              !launcherPath.contains(".framework/"),
              let launcherStart = startTime(of: launcherPID),
              let start = startTime(of: pid)
        else { return false }
        return launcherStart <= start
    }

    private static func parallManifest(at url: URL) -> ParallManifest? {
        guard let info = Bundle(url: url)?.infoDictionary,
              let target = info["ParallAppBundleId"] as? String,
              !target.isEmpty
        else { return nil }

        let dataStoragePath = (info["ParallDataStorage"] as? String)
            .flatMap { $0.isEmpty ? nil : ($0 as NSString).standardizingPath }
        return ParallManifest(targetBundleIdentifier: target, dataStoragePath: dataStoragePath)
    }

    private static func launchBundleIdentifier(_ process: (arguments: [String], environment: [String])) -> String? {
        process.environment
            .first { $0.hasPrefix(launchBundleIdentifierPrefix) }
            .map { String($0.dropFirst(launchBundleIdentifierPrefix.count)) }
    }

    private static func processStrings(of pid: pid_t) -> (arguments: [String], environment: [String])? {
        var mib = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }

        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, u_int(mib.count), &buffer, &size, nil, 0) == 0 else { return nil }

        let argc = Int(buffer.withUnsafeBytes { $0.load(as: Int32.self) })
        var index = MemoryLayout<Int32>.size
        while index < size, buffer[index] != 0 {
            index += 1
        }
        while index < size, buffer[index] == 0 {
            index += 1
        }

        func nextString() -> String? {
            guard index < size else { return nil }
            let start = index
            while index < size, buffer[index] != 0 {
                index += 1
            }
            defer { index += 1 }
            return String(decoding: buffer[start ..< index], as: UTF8.self)
        }

        var arguments: [String] = []
        while arguments.count < argc, let argument = nextString() {
            arguments.append(argument)
        }

        var environment: [String] = []
        while let variable = nextString(), !variable.isEmpty {
            environment.append(variable)
        }

        return (arguments, environment)
    }

    private static func coalitionID(of pid: pid_t) -> UInt64? {
        var info = CoalitionInfo()
        let size = Int32(MemoryLayout<CoalitionInfo>.size)
        let returned = withUnsafeMutablePointer(to: &info) {
            proc_pidinfo(pid, procPIDCoalitionInfoFlavor, 0, $0, size)
        }
        guard returned == size, info.coalitionIDs.0 != 0 else { return nil }
        return info.coalitionIDs.0
    }

    private static func startTime(of pid: pid_t) -> Double? {
        var mib = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        let start = info.kp_proc.p_starttime
        guard start.tv_sec != 0 else { return nil }
        return Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
    }
}
