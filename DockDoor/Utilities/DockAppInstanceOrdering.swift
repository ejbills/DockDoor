import Cocoa

final class DockAppInstanceOrdering {
    static let shared = DockAppInstanceOrdering()

    private struct Assignment {
        let item: AXUIElement
        let pid: pid_t
    }

    private var assignments: [String: [Assignment]] = [:]
    private var snapshots: [String: [String]] = [:]
    private var dockPID: pid_t?
    private var pending: (bundle: String, item: AXUIElement, expires: Date)?
    private var observer: NSObjectProtocol?

    private init() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self, let pending,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            self.pending = nil
            guard Date() < pending.expires,
                  app.bundleIdentifier == pending.bundle,
                  (try? pending.item.appIsRunning()) == true
            else { return }
            var entries = assignments[pending.bundle] ?? []
            entries.removeAll { CFEqual($0.item, pending.item) || $0.pid == app.processIdentifier }
            entries.append(Assignment(item: pending.item, pid: app.processIdentifier))
            assignments[pending.bundle] = entries
        }
    }

    func cancelPendingClick() {
        pending = nil
    }

    func observeNativeClick(on item: AXUIElement, bundleIdentifier: String) {
        pending = (bundleIdentifier, item, Date().addingTimeInterval(1))
    }

    func processIdentifiers(
        for apps: [NSRunningApplication],
        items: [AXUIElement],
        bundleIdentifier: String
    ) -> [pid_t?] {
        let currentDockPID = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.dock"
        ).first?.processIdentifier
        if dockPID != currentDockPID {
            dockPID = currentDockPID
            assignments.removeAll()
            snapshots.removeAll()
            pending = nil
        }
        // PID plus launch date prevents reuse of a terminated process's identity.
        let snapshot = apps.map {
            "\($0.processIdentifier):\($0.launchDate?.timeIntervalSince1970 ?? 0)"
        }.sorted()
        if snapshots[bundleIdentifier] != snapshot {
            snapshots[bundleIdentifier] = snapshot
            assignments[bundleIdentifier] = []
            pending = nil
        }
        let entries = assignments[bundleIdentifier] ?? []
        let known = items.map { item in
            entries.first { CFEqual($0.item, item) }?.pid
        }
        return Self.resolve(
            runningPIDs: apps.map(\.processIdentifier),
            runningStates: items.map { try? $0.appIsRunning() },
            knownPIDs: known
        )
    }

    static func resolve(
        runningPIDs: [pid_t],
        runningStates: [Bool?],
        knownPIDs: [pid_t?]
    ) -> [pid_t?] {
        guard runningStates.count == knownPIDs.count else {
            return Array(repeating: nil, count: runningStates.count)
        }
        var result = knownPIDs.indices.map { index -> pid_t? in
            guard runningStates[index] == true,
                  let pid = knownPIDs[index], runningPIDs.contains(pid),
                  knownPIDs.filter({ $0 == pid }).count == 1
            else { return nil }
            return pid
        }
        let missingPIDs = runningPIDs.filter { !result.contains($0) }
        let missingItems = runningStates.indices.filter {
            runningStates[$0] == true && result[$0] == nil
        }
        // Only infer an identity when occupancy and the remaining process agree.
        if runningStates.allSatisfy({ $0 != nil }),
           runningStates.filter({ $0 == true }).count == runningPIDs.count,
           missingPIDs.count == 1, missingItems.count == 1
        {
            result[missingItems[0]] = missingPIDs[0]
        }
        return result
    }
}
