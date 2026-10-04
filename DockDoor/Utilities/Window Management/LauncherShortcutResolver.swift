import AppKit

private final class InPlaceReexecApplication: NSRunningApplication {
    private let base: NSRunningApplication
    private let pid: pid_t

    init(base: NSRunningApplication, pid: pid_t) {
        self.base = base
        self.pid = pid
        super.init()
    }

    override var processIdentifier: pid_t { pid }
    override var bundleIdentifier: String? { base.bundleIdentifier }
    override var bundleURL: URL? { base.bundleURL }
    override var executableURL: URL? { base.executableURL }
    override var localizedName: String? { base.localizedName }
    override var icon: NSImage? { base.icon }
    override var launchDate: Date? { base.launchDate }
    override var activationPolicy: NSApplication.ActivationPolicy { base.activationPolicy }
    override var executableArchitecture: Int { base.executableArchitecture }
    override var isActive: Bool { base.isActive }
    override var isHidden: Bool { base.isHidden }
    override var isTerminated: Bool { base.isTerminated }
    override var isFinishedLaunching: Bool { base.isFinishedLaunching }
    override var ownsMenuBar: Bool { base.ownsMenuBar }
    override var hash: Int { Int(pid) }

    override func isEqual(_ object: Any?) -> Bool {
        (object as? NSRunningApplication)?.processIdentifier == pid
    }

    override func hide() -> Bool { base.hide() }
    override func unhide() -> Bool { base.unhide() }
    override func activate(options: NSApplication.ActivationOptions) -> Bool { base.activate(options: options) }
    @available(macOS 14.0, *)
    override func activate(from application: NSRunningApplication, options: NSApplication.ActivationOptions) -> Bool {
        base.activate(from: application, options: options)
    }

    override func terminate() -> Bool { base.terminate() }
    override func forceTerminate() -> Bool { base.forceTerminate() }
}

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

    static func application(forProcessIdentifier pid: pid_t) -> NSRunningApplication? {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return nil }
        return app.processIdentifier == -1 ? InPlaceReexecApplication(base: app, pid: pid) : app
    }

    static func resolvingInPlaceReexec(_ app: NSRunningApplication) -> NSRunningApplication {
        guard app.processIdentifier == -1, let pid = inPlaceReexecProcessIdentifier(of: app) else { return app }
        return InPlaceReexecApplication(base: app, pid: pid)
    }

    static func resolvingInPlaceReexecs(_ apps: [NSRunningApplication]) -> [NSRunningApplication] {
        guard apps.contains(where: { $0.processIdentifier == -1 }) else { return apps }
        return apps.map(resolvingInPlaceReexec)
    }

    static func runningApplications(forBundleAt url: URL, bundleIdentifier: String) -> [NSRunningApplication] {
        let direct = resolvingInPlaceReexecs(NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier))
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
            return dockShowsOnShortcutTile(app, shortcutURL: shortcutURL) ? launchIdentifier : nil
        }

        let launchers = NSRunningApplication.runningApplications(withBundleIdentifier: launchIdentifier)
        return launchers.contains { isResidentLauncher($0, of: app) } ? launchIdentifier : nil
    }

    static func siblingInstances(of app: NSRunningApplication) -> [NSRunningApplication] {
        guard let bundleIdentifier = app.bundleIdentifier, !bundleIdentifier.isEmpty else { return [app] }
        let owner = owningShortcutBundleIdentifier(of: app)
        let siblings = resolvingInPlaceReexecs(NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier))
            .filter { owningShortcutBundleIdentifier(of: $0) == owner }
        return siblings.isEmpty ? [app] : siblings
    }

    private static func shortcutInstances(at url: URL, shortcutBundleIdentifier: String, launchers: [NSRunningApplication]) -> [NSRunningApplication] {
        if let manifest = parallManifest(at: url) {
            return resolvingInPlaceReexecs(NSRunningApplication.runningApplications(withBundleIdentifier: manifest.targetBundleIdentifier)).filter { app in
                guard app.activationPolicy == .regular else { return false }
                if dockShowsOnShortcutTile(app, shortcutURL: url), let process = processStrings(of: app.processIdentifier) {
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

    private static func inPlaceReexecProcessIdentifier(of app: NSRunningApplication) -> pid_t? {
        guard !app.isTerminated,
              let executablePath = app.executableURL?.resolvingSymlinksInPath().path
        else { return nil }

        var pids = [pid_t](repeating: 0, count: Int(proc_listallpids(nil, 0)) + 64)
        let count = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)

        return pids.prefix(max(count, 0)).first { pid in
            pid > 0 &&
                proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count)) > 0 &&
                URL(fileURLWithPath: String(cString: pathBuffer)).resolvingSymlinksInPath().path == executablePath &&
                NSRunningApplication(processIdentifier: pid)?.isEqual(app) == true
        }
    }

    private static func dockShowsOnShortcutTile(_ app: NSRunningApplication, shortcutURL: URL) -> Bool {
        guard app is InPlaceReexecApplication else { return dockSawLaunch(of: app) }
        let shortcutPath = shortcutURL.standardizedFileURL.path
        return (try? ActiveAppIndicatorDockDetection.dockList()?.children())?.contains { item in
            (try? item.subrole()) == "AXApplicationDockItem" &&
                (try? item.appIsRunning()) == true &&
                (try? item.attribute(kAXURLAttribute, NSURL.self)?.absoluteURL)?.standardizedFileURL.path == shortcutPath
        } ?? false
    }

    private static func dockSawLaunch(of app: NSRunningApplication) -> Bool {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first,
              let dockStart = startTime(of: dock.processIdentifier),
              let start = startTime(of: app.processIdentifier)
        else { return true }
        return dockStart <= start
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
