import ApplicationServices
import Cocoa

final class WindowSeeder {
    func run() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(opts) else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            let myPID = ProcessInfo.processInfo.processIdentifier
            let apps = NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy == .regular && $0.processIdentifier != 0 && $0.processIdentifier != myPID }

            for app in apps {
                self.seedApp(app: app)
            }
        }
    }

    private func seedApp(app: NSRunningApplication) {
        let pid = app.processIdentifier
        let appAX = AXUIElementCreateApplication(pid)
        let axWindows = AXUIElement.allWindows(pid, appElement: appAX)
        if axWindows.isEmpty { return }

        let cgCandidates = getCGWindowCandidates(for: pid)
        var usedIDs = Set<CGWindowID>()
        let activeSpaceIDs = currentActiveSpaceIDs()

        for axWin in axWindows {
            if !isValidAXWindowCandidate(axWin) { continue }
            var id32: CGWindowID = 0
            if _AXUIElementGetWindow(axWin, &id32) == .success, id32 != 0 {
                usedIDs.insert(id32)
            } else if let fid = mapAXToCG(axWindow: axWin, candidates: cgCandidates, excluding: usedIDs) {
                id32 = fid
                usedIDs.insert(id32)
            } else { continue }

            if !isAtLeastNormalLevel(id32) { continue }

            if !isValidCGWindowCandidate(id32, in: cgCandidates) { continue }

            // Find matching CG entry for visibility flags
            guard let cgEntry = findCGEntry(for: id32, in: cgCandidates) else { continue }

            // Accept window if on-screen, SCK-backed (not in seeding), in other Space, or minimized/fullscreen/hidden
            let scBacked = false
            if !shouldAcceptWindow(axWindow: axWin, windowID: id32, cgEntry: cgEntry, app: app, activeSpaceIDs: activeSpaceIDs, scBacked: scBacked) {
                continue
            }

            guard let image = id32.cgsScreenshot() else { continue }

            let provider = AXFallbackProvider(cgID: id32)
            let isMinimized = (try? axWin.isMinimized()) ?? false
            var info = WindowInfo(
                windowProvider: provider,
                app: app,
                image: image,
                axElement: axWin,
                appAxElement: appAX,
                closeButton: try? axWin.closeButton(),
                isMinimized: isMinimized,
                isHidden: app.isHidden,
                lastAccessedTime: Date(),
                spaceID: id32.cgsSpaces().first.map { Int($0) }
            )
            info.windowName = id32.cgsTitle()

            WindowUtil.updateDesktopSpaceWindowCache(with: info)
        }
    }
}
