import ApplicationServices
import Cocoa

final class WindowSeeder {
    func run() {
        // Ensure AX trust; prompt user if needed
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
            } else if let fid = fallbackMapAXToCG(axWindow: axWin, candidates: cgCandidates, excluding: usedIDs) {
                id32 = fid
                usedIDs.insert(fid)
            } else { continue }

            let level = id32.cgsLevel()
            let normalLevel = CGWindowLevelForKey(.normalWindow)
            if level < Int32(normalLevel) { continue }

            guard let image = id32.cgsScreenshot() else { continue }

            let provider = MinimalProvider(cgID: id32)
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

private struct MinimalProvider: WindowPropertiesProviding {
    let cgID: CGWindowID
    var windowID: CGWindowID { cgID }
    var frame: CGRect { .zero }
    var title: String? { nil }
    var owningApplicationBundleIdentifier: String? { nil }
    var owningApplicationProcessID: pid_t? { nil }
    var isOnScreen: Bool { true }
    var windowLayer: Int { 0 }
}

// Fallback mapping: try to find a CG window matching the AX window by title or geometry
private func fallbackMapAXToCG(axWindow: AXUIElement, candidates: [[String: AnyObject]], excluding: Set<CGWindowID>) -> CGWindowID? {
    let axTitle = (try? axWindow.title())?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let axPos = try? axWindow.position()
    let axSize = try? axWindow.size()

    // 1) Exact title match among unused candidates
    if !axTitle.isEmpty {
        if let match = candidates.first(where: { desc in
            let title = (desc[kCGWindowName as String] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let wid = CGWindowID((desc[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
            return title == axTitle && !excluding.contains(wid)
        }) {
            return CGWindowID((match[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
        }
    }

    // 2) Geometry match within tolerance
    if let p = axPos, let s = axSize, s != .zero {
        let tol: CGFloat = 2.0
        if let match = candidates.first(where: { desc in
            let wid = CGWindowID((desc[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
            if excluding.contains(wid) { return false }
            let bounds = desc[kCGWindowBounds as String] as? [String: AnyObject]
            let rx = CGFloat((bounds?["X"] as? NSNumber)?.doubleValue ?? .infinity)
            let ry = CGFloat((bounds?["Y"] as? NSNumber)?.doubleValue ?? .infinity)
            let rw = CGFloat((bounds?["Width"] as? NSNumber)?.doubleValue ?? .infinity)
            let rh = CGFloat((bounds?["Height"] as? NSNumber)?.doubleValue ?? .infinity)
            let r = CGRect(x: rx, y: ry, width: rw, height: rh)
            let posMatch = abs(r.origin.x - p.x) <= tol && abs(r.origin.y - p.y) <= tol
            let sizeMatch = abs(r.size.width - s.width) <= tol && abs(r.size.height - s.height) <= tol
            return posMatch && sizeMatch
        }) {
            return CGWindowID((match[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
        }
    }

    // 3) Fuzzy title contains
    if !axTitle.isEmpty {
        if let match = candidates.first(where: { desc in
            let title = ((desc[kCGWindowName as String] as? String) ?? "").lowercased()
            let wid = CGWindowID((desc[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
            return !excluding.contains(wid) && title.contains(axTitle.lowercased())
        }) {
            return CGWindowID((match[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
        }
    }

    return nil
}
