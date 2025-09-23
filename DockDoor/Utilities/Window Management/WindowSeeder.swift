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

        let cgAll = (CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: AnyObject]]) ?? []
        let cgCandidates = cgAll.filter { desc in
            let owner = (desc[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
            let layer = (desc[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
            return owner == pid && layer == 0
        }
        var usedIDs = Set<CGWindowID>()

        for axWin in axWindows {
            var id32: CGWindowID = 0
            if _AXUIElementGetWindow(axWin, &id32) == .success, id32 != 0 {
                usedIDs.insert(id32)
            } else if let fid = mapAXToCG(axWindow: axWin, candidates: cgCandidates, excluding: usedIDs) {
                id32 = fid
                usedIDs.insert(fid)
            } else { continue }

            let level = id32.cgsLevel()
            let normalLevel = CGWindowLevelForKey(.normalWindow)
            if level < Int32(normalLevel) { continue }

            guard let image = id32.cgsScreenshot() else { continue }

            let provider = AXFallbackProvider(cgID: id32)
            var info = WindowInfo(
                windowProvider: provider,
                app: app,
                image: image,
                axElement: axWin,
                appAxElement: appAX,
                closeButton: try? axWin.closeButton(),
                isMinimized: (try? axWin.isMinimized()) ?? false,
                isHidden: app.isHidden,
                lastAccessedTime: Date(),
                spaceID: id32.cgsSpaces().first.map { Int($0) }
            )
            info.windowName = id32.cgsTitle()
            WindowUtil.updateDesktopSpaceWindowCache(with: info)
        }
    }
}
