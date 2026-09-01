#if DEBUG
    import Cocoa
    import Defaults

    final class DebugTestHarness {
        struct Hooks {
            var simulateWake: () -> Void
            var resetKeybind: () -> Void
            var switcherSessionActive: () -> Bool
            var previewVisible: () -> Bool
            var previewWindowCount: () -> Int
        }

        private static let prefix = "com.ethanbills.DockDoor.debug."
        private static let diagnosticsLog = "/tmp/DockDoor-Diagnostics.log"
        private static let memoryLog = "/tmp/DockDoor-Memory.log"
        private static let settingsLog = "/tmp/DockDoor-Settings.log"
        private static let refreshLog = "/tmp/DockDoor-FullRefresh.log"

        private let hooks: Hooks
        private var observers: [NSObjectProtocol] = []

        init(hooks: Hooks) {
            self.hooks = hooks
            let center = DistributedNotificationCenter.default()
            let handlers: [(String, (Notification) -> Void)] = [
                ("memorySnapshot", { [weak self] _ in self?.writeMemorySnapshot() }),
                ("toggleDefault", { n in Self.toggleDefault(n.object as? String) }),
                ("setDefault", { n in Self.setDefault(n.object as? String) }),
                ("settingsQuery", { _ in Self.writeSettings() }),
                ("diagnostics", { [weak self] _ in self?.writeDiagnostics() }),
                ("fullRefresh", { _ in Self.runFullRefresh() }),
                ("purgeCache", { _ in WindowUtil.purgeAllCaches() }),
                ("simulateWake", { [weak self] _ in self?.hooks.simulateWake() }),
                ("resetKeybind", { [weak self] _ in self?.hooks.resetKeybind() }),
            ]
            for (name, handler) in handlers {
                let token = center.addObserver(forName: Notification.Name(Self.prefix + name), object: nil, queue: .main, using: handler)
                observers.append(token)
            }
        }

        deinit {
            let center = DistributedNotificationCenter.default()
            for token in observers {
                center.removeObserver(token)
            }
        }

        private static func write(_ text: String, to path: String, append: Bool = false) {
            guard let data = (text + "\n").data(using: .utf8) else { return }
            if append, let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }

        private static func residentBytes() -> UInt64 {
            var info = task_vm_info_data_t()
            var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
                }
            }
            return result == KERN_SUCCESS ? info.phys_footprint : 0
        }

        private static func cpuSeconds() -> Double {
            var usage = rusage()
            getrusage(RUSAGE_SELF, &usage)
            let user = Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000
            let system = Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000
            return user + system
        }

        private static func eventTapStats() -> [[String: Any]] {
            var count: UInt32 = 0
            CGGetEventTapList(0, nil, &count)
            var taps = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(count))
            CGGetEventTapList(count, &taps, &count)
            let pid = ProcessInfo.processInfo.processIdentifier
            return taps.prefix(Int(count)).filter { $0.tappingProcess == pid }.map { tap in
                [
                    "id": tap.eventTapID,
                    "enabled": tap.enabled,
                    "point": tap.tapPoint.rawValue,
                    "avgUsec": tap.avgUsecLatency,
                    "maxUsec": tap.maxUsecLatency,
                ]
            }
        }

        private func writeMemorySnapshot() {
            Self.write("\(Date().timeIntervalSince1970) \(Self.residentBytes())", to: Self.memoryLog, append: true)
        }

        private func writeDiagnostics() {
            let taps = Self.eventTapStats()
            let payload: [String: Any] = [
                "pid": ProcessInfo.processInfo.processIdentifier,
                "rss": Self.residentBytes(),
                "cpuSeconds": Self.cpuSeconds(),
                "cachedWindows": WindowUtil.cachedWindowCount(),
                "cachedApps": WindowUtil.cachedAppCount(),
                "eventTaps": taps,
                "enabledTaps": taps.filter { ($0["enabled"] as? Bool) == true }.count,
                "disabledTaps": taps.filter { ($0["enabled"] as? Bool) == false }.count,
                "switcherSessionActive": hooks.switcherSessionActive(),
                "previewVisible": hooks.previewVisible(),
                "previewWindowCount": hooks.previewWindowCount(),
                "keybind": ["keyCode": Defaults[.UserKeybind].keyCode, "modifierFlags": Defaults[.UserKeybind].modifierFlags],
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload), let json = String(data: data, encoding: .utf8) {
                Self.write(json, to: Self.diagnosticsLog)
            }
        }

        private static func writeSettings() {
            let domain = UserDefaults.standard.persistentDomain(forName: Bundle.main.bundleIdentifier ?? "") ?? [:]
            let serializable = domain.filter { JSONSerialization.isValidJSONObject([$0.value]) }
            if let data = try? JSONSerialization.data(withJSONObject: serializable), let json = String(data: data, encoding: .utf8) {
                write(json, to: settingsLog)
            }
        }

        private static func toggleDefault(_ key: String?) {
            guard let key else { return }
            let current = UserDefaults.standard.bool(forKey: key)
            UserDefaults.standard.set(!current, forKey: key)
        }

        private static func setDefault(_ payload: String?) {
            guard let payload, let separator = payload.firstIndex(of: "=") else { return }
            let key = String(payload[..<separator])
            let raw = String(payload[payload.index(after: separator)...])
            let defaults = UserDefaults.standard
            if raw == "true" || raw == "false" {
                defaults.set(raw == "true", forKey: key)
            } else if let int = Int(raw) {
                defaults.set(int, forKey: key)
            } else if let double = Double(raw) {
                defaults.set(double, forKey: key)
            } else {
                defaults.set(raw, forKey: key)
            }
        }

        private static func runFullRefresh() {
            Task {
                let start = CFAbsoluteTimeGetCurrent()
                let cpuStart = cpuSeconds()
                await WindowUtil.updateAllWindowsInCurrentSpace()
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
                let cpu = cpuSeconds() - cpuStart
                write("\(Date().timeIntervalSince1970) ms=\(Int(elapsed)) cpuSeconds=\(String(format: "%.3f", cpu)) windows=\(WindowUtil.cachedWindowCount())", to: refreshLog, append: true)
            }
        }
    }
#endif
