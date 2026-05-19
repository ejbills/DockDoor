import ApplicationServices
import Cocoa
import Defaults

// Minimal provider used when we only have a CGWindowID (no SCWindow available)
struct AXFallbackProvider: WindowPropertiesProviding {
    let cgID: CGWindowID
    var windowID: CGWindowID { cgID }
    var frame: CGRect { .zero }
    var title: String? { nil }
    var owningApplicationBundleIdentifier: String? { nil }
    var owningApplicationProcessID: pid_t? { nil }
    var isOnScreen: Bool { true }
    var windowLayer: Int { 0 }
}

/// Heuristic mapping from AX window to CG window when _AXUIElementGetWindow fails
func mapAXToCG(axWindow: AXUIElement, candidates: [[String: AnyObject]], excluding: Set<CGWindowID>) -> CGWindowID? {
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

// MARK: - Shared Helper Functions

/// Returns CG window candidates for a given PID on layer 0
func getCGWindowCandidates(for pid: pid_t) -> [[String: AnyObject]] {
    let cgAll = (CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: AnyObject]]) ?? []
    return cgAll.filter { desc in
        let owner = (desc[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
        let layer = (desc[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
        return owner == pid && layer == 0
    }
}

/// Finds the CG window entry matching a given window ID in the candidates list
func findCGEntry(for windowID: CGWindowID, in candidates: [[String: AnyObject]]) -> [String: AnyObject]? {
    candidates.first { desc in
        let wid = CGWindowID((desc[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
        return wid == windowID
    }
}

// MARK: - Shared Validation

let AXMinWindowSize: CGSize = .init(width: 100, height: 100)

func isValidAXWindowCandidate(_ axWindow: AXUIElement) -> Bool {
    DebugLogger.measureSlow("isValidAXWindowCandidate", thresholdMs: 50) {
        if let role = try? axWindow.role(), role != kAXWindowRole { return false }
        if let subrole = try? axWindow.subrole(),
           ![kAXStandardWindowSubrole, kAXDialogSubrole].contains(subrole)
        { return false }
        if let s = try? axWindow.size(), let p = try? axWindow.position() {
            if s == .zero { return false }
            if !Defaults[.disableMinWindowSizeFilter], s.width < AXMinWindowSize.width || s.height < AXMinWindowSize.height { return false }
            if !p.x.isFinite || !p.y.isFinite { return false }
        }
        return true
    }
}

func isAtLeastNormalLevel(_ id: CGWindowID) -> Bool {
    let level = id.cgsLevel()
    let normalLevel = CGWindowLevelForKey(.normalWindow)
    return level >= Int32(normalLevel)
}

func isValidCGWindowCandidate(_ id: CGWindowID, in candidates: [[String: AnyObject]]) -> Bool {
    guard let match = candidates.first(where: { desc -> Bool in
        let wid = CGWindowID((desc[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
        return wid == id
    }) else { return false }

    let bounds = match[kCGWindowBounds as String] as? [String: AnyObject]
    let rw = CGFloat((bounds?["Width"] as? NSNumber)?.doubleValue ?? 0)
    let rh = CGFloat((bounds?["Height"] as? NSNumber)?.doubleValue ?? 0)
    let alpha = CGFloat((match[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0)
    if rw < AXMinWindowSize.width || rh < AXMinWindowSize.height { return false }
    if alpha <= 0.01 { return false }
    return true
}

// Returns the set of currently active Space IDs across all displays.
func currentActiveSpaceIDs() -> Set<Int> {
    // Primary: ask macOS directly for the current space per display
    if let displays = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [[String: AnyObject]] {
        var result = Set<Int>()
        for display in displays {
            if let currentSpace = display["Current Space"] as? [String: AnyObject],
               let spaceID = (currentSpace["ManagedSpaceID"] as? NSNumber)?.intValue
            {
                result.insert(spaceID)
            }
        }
        if !result.isEmpty { return result }
    }

    // Fallback: infer from on-screen windows
    var result = Set<Int>()
    guard let list = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: AnyObject]] else { return result }
    for desc in list {
        let layer = (desc[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1
        let isOnscreen = (desc[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
        guard layer == 0, isOnscreen else { continue }
        let wid = CGWindowID((desc[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
        for space in wid.cgsSpaces() {
            result.insert(Int(space))
        }
    }
    return result
}

enum WindowSpaces {
    private struct ManagedDisplay {
        let identifier: String
        let currentSpaceID: CGSSpaceID?
        let spaceIDs: Set<CGSSpaceID>
    }

    private static func spaceID(from dictionary: [String: AnyObject]?) -> CGSSpaceID? {
        if let managedSpaceID = dictionary?["ManagedSpaceID"] as? NSNumber {
            return managedSpaceID.uint64Value
        }
        if let id64 = dictionary?["id64"] as? NSNumber {
            return id64.uint64Value
        }
        return nil
    }

    private static func managedDisplays() -> [ManagedDisplay] {
        guard let displays = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [[String: AnyObject]] else {
            return []
        }

        return displays.compactMap { display in
            guard let identifier = display["Display Identifier"] as? String else { return nil }
            let currentSpace = display["Current Space"] as? [String: AnyObject]
            let spaces = display["Spaces"] as? [[String: AnyObject]] ?? []

            return ManagedDisplay(
                identifier: identifier,
                currentSpaceID: spaceID(from: currentSpace),
                spaceIDs: Set(spaces.compactMap { spaceID(from: $0) })
            )
        }
    }

    private static func displayIdentifiers(for screen: NSScreen) -> Set<String> {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return []
        }

        let displayID = CGDirectDisplayID(screenNumber.uint32Value)
        var identifiers: Set<String> = [String(displayID)]

        if let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
           let uuidString = CFUUIDCreateString(nil, uuid) as String?
        {
            identifiers.insert(uuidString)
        }

        return identifiers
    }

    private static func screenContainingMouse(_ mouseLocation: CGPoint) -> NSScreen? {
        NSScreen.screens.first { screen in
            NSPointInRect(mouseLocation, screen.frame)
        }
    }

    static func currentManagedSpaceID(mouseLocation: CGPoint = NSEvent.mouseLocation) -> CGSSpaceID? {
        let displays = managedDisplays()
        guard !displays.isEmpty else { return nil }

        if let mouseScreen = screenContainingMouse(mouseLocation) {
            let screenIdentifiers = displayIdentifiers(for: mouseScreen)
                .map { $0.lowercased() }

            if let display = displays.first(where: { display in
                screenIdentifiers.contains(display.identifier.lowercased())
            }) {
                return display.currentSpaceID
            }
        }

        return displays.first?.currentSpaceID
    }

    @discardableResult
    static func move(windowID: CGWindowID, toManagedSpace targetSpaceID: CGSSpaceID) -> Bool {
        let displays = managedDisplays()
        guard displays.contains(where: { display in
            display.currentSpaceID == targetSpaceID || display.spaceIDs.contains(targetSpaceID)
        }) else {
            DebugLogger.log("WindowSpaces.move", details: "Target Space \(targetSpaceID) not found")
            return false
        }

        if windowID.cgsSpaces().contains(targetSpaceID) {
            return true
        }

        return SLSMoveWindowsToManagedSpace([windowID], targetSpaceID)
    }
}

// Decide if a window should be accepted considering on-screen state,
// ScreenCaptureKit presence, multi-Space, and window/app state.
func shouldAcceptWindow(axWindow: AXUIElement,
                        windowID: CGWindowID,
                        cgEntry: [String: AnyObject],
                        app: NSRunningApplication,
                        activeSpaceIDs: Set<Int>,
                        scBacked: Bool) -> Bool
{
    // Base: role/subrole, level, size/alpha checks already enforced by caller
    let isOnscreen = (cgEntry[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false
    let axIsFullscreen = (try? axWindow.isFullscreen()) ?? false
    let axIsMinimized = (try? axWindow.isMinimized()) ?? false
    let windowSpaces = Set(windowID.cgsSpaces().map { Int($0) })

    let isOnActiveSpace = !windowSpaces.isEmpty && !windowSpaces.isDisjoint(with: activeSpaceIDs)
    let isGhostWindow = !isOnscreen && isOnActiveSpace && !axIsMinimized && !axIsFullscreen && !app.isHidden
    if isGhostWindow { return false }

    if isOnscreen || scBacked { return true }

    if app.isHidden || axIsFullscreen || axIsMinimized { return true }

    // Window on different Space — but reject if not onscreen and not minimized/fullscreen/hidden (ghost with stale space ID)
    if !windowSpaces.isEmpty, windowSpaces.isDisjoint(with: activeSpaceIDs) {
        if !isOnscreen, !axIsMinimized, !axIsFullscreen, !app.isHidden {
            return false
        }
        return true
    }

    // Fallback: if AX marks it as main, consider it significant and include.
    // This helps when CGS space mapping is unreliable or empty for other-Spaces windows.
    if (try? axWindow.attribute(kAXMainAttribute, Bool.self)) == true {
        return true
    }

    return false
}
