import Cocoa

final class DockAppInstanceOrdering: @unchecked Sendable {
    struct Process: Hashable {
        let pid: pid_t
        let launchDate: Date?

        init(pid: pid_t, launchDate: Date? = nil) {
            self.pid = pid
            self.launchDate = launchDate
        }

        init(_ app: NSRunningApplication) {
            self.init(pid: app.processIdentifier, launchDate: app.launchDate)
        }
    }

    struct Item: Equatable {
        let element: AXUIElement
        let isRunning: Bool?

        static func == (lhs: Self, rhs: Self) -> Bool {
            CFEqual(lhs.element, rhs.element) && lhs.isRunning == rhs.isRunning
        }
    }

    private struct Assignment {
        let item: AXUIElement
        let pid: pid_t
    }

    private struct Snapshot: Equatable {
        let processes: Set<Process>
        let items: [Item]
    }

    private let lock = NSLock()
    private var assignments: [String: [Assignment]] = [:]
    private var snapshots: [String: Snapshot] = [:]
    private var pending: (bundle: String, item: AXUIElement, started: Date, expires: Date)?

    var hasPendingClick: Bool {
        lock.withLock { pending != nil }
    }

    func reset() {
        lock.withLock {
            assignments.removeAll()
            snapshots.removeAll()
            pending = nil
        }
    }

    func cancelPendingClick() {
        lock.withLock { pending = nil }
    }

    func observeNativeClick(on item: AXUIElement, bundleIdentifier: String, now: Date = Date()) {
        lock.withLock {
            guard snapshots[bundleIdentifier]?.items.contains(where: {
                CFEqual($0.element, item) && $0.isRunning == true
            }) == true else { return }
            pending = (bundleIdentifier, item, now, now.addingTimeInterval(1))
        }
    }

    func recordActivation(of process: Process, bundleIdentifier: String, now: Date = Date()) {
        lock.withLock {
            guard let pending, now >= pending.started else { return }
            self.pending = nil
            guard now < pending.expires, bundleIdentifier == pending.bundle,
                  snapshots[bundleIdentifier]?.processes.contains(process) == true
            else { return }
            var entries = assignments[bundleIdentifier] ?? []
            entries.removeAll { CFEqual($0.item, pending.item) || $0.pid == process.pid }
            entries.append(Assignment(item: pending.item, pid: process.pid))
            assignments[bundleIdentifier] = entries
        }
    }

    func processIdentifiers(
        for processes: [Process],
        items: [Item],
        bundleIdentifier: String
    ) -> [pid_t?] {
        lock.withLock {
            let snapshot = Snapshot(processes: Set(processes), items: items)
            if snapshots[bundleIdentifier] != snapshot {
                snapshots[bundleIdentifier] = snapshot
                assignments[bundleIdentifier] = []
                if pending?.bundle == bundleIdentifier {
                    pending = nil
                }
            }
            let entries = assignments[bundleIdentifier] ?? []
            let known = items.map { item in
                entries.first { CFEqual($0.item, item.element) }?.pid
            }
            return Self.resolve(
                runningPIDs: processes.map(\.pid),
                runningStates: items.map(\.isRunning),
                knownPIDs: known
            )
        }
    }

    static func fallbackProcessIdentifiers(
        runningPIDs: [pid_t],
        runningStates: [Bool?],
        resolvedPIDs: [pid_t?]
    ) -> [pid_t?] {
        guard runningStates.count == resolvedPIDs.count else {
            return Array(repeating: nil, count: runningStates.count)
        }
        let remaining = runningPIDs.sorted().filter { !resolvedPIDs.contains($0) }
        var next = remaining.makeIterator()
        return resolvedPIDs.indices.map { index in
            guard runningStates[index] != false else { return nil }
            return resolvedPIDs[index] ?? next.next()
        }
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
        if runningStates.allSatisfy({ $0 != nil }),
           runningStates.filter({ $0 == true }).count == runningPIDs.count,
           missingPIDs.count == 1, missingItems.count == 1
        {
            result[missingItems[0]] = missingPIDs[0]
        }
        return result
    }
}
