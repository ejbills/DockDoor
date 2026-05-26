import ApplicationServices
import Cocoa
import Defaults
import ScreenCaptureKit

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

struct WindowCandidateAttributes {
    let title: String?
    let role: String?
    let subrole: String?
    let size: CGSize?
    let position: CGPoint?

    init(axWindow: AXUIElement) {
        title = try? axWindow.title()
        role = try? axWindow.role()
        subrole = try? axWindow.subrole()
        size = try? axWindow.size()
        position = try? axWindow.position()
    }
}

enum WindowOwnerResolver {
    static func ownerApp(for window: SCWindow) -> NSRunningApplication? {
        guard let pid = window.owningApplication?.processID else { return nil }
        return NSRunningApplication(processIdentifier: pid)
    }

    static func windowBelongsToDisplayApp(_ window: SCWindow, displayApp: NSRunningApplication) -> Bool {
        guard let owner = ownerApp(for: window) else { return false }
        return ownerBelongsToDisplayApp(owner, displayApp: displayApp)
    }

    static func ownerBelongsToDisplayApp(_ owner: NSRunningApplication, displayApp: NSRunningApplication) -> Bool {
        if owner.processIdentifier == displayApp.processIdentifier {
            return true
        }

        guard canResolveThroughDisplayApp(owner) else {
            return false
        }

        if helperBundleBelongsToDisplayApp(owner.bundleIdentifier, displayApp.bundleIdentifier) {
            return true
        }

        return executableRootsMatch(owner: owner, displayApp: displayApp)
    }

    static func displayApp(forOwner owner: NSRunningApplication) -> NSRunningApplication {
        guard canResolveThroughDisplayApp(owner) else {
            return owner
        }

        let candidates = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && ownerBelongsToDisplayApp(owner, displayApp: $0)
        }

        if let parentBundleApp = candidates
            .filter({ $0.processIdentifier != owner.processIdentifier && bundleIsParent($0.bundleIdentifier, of: owner.bundleIdentifier) })
            .sorted(by: { displayAppScore($0, forOwner: owner) > displayAppScore($1, forOwner: owner) })
            .first
        {
            return parentBundleApp
        }

        return candidates.sorted { first, second in
            displayAppScore(first, forOwner: owner) > displayAppScore(second, forOwner: owner)
        }.first ?? owner
    }

    static func isAuxiliaryOwner(_ owner: NSRunningApplication) -> Bool {
        guard canResolveThroughDisplayApp(owner) else {
            return false
        }

        return displayApp(forOwner: owner).processIdentifier != owner.processIdentifier
    }

    private static func canResolveThroughDisplayApp(_ owner: NSRunningApplication) -> Bool {
        owner.activationPolicy != .regular || owner.bundleIdentifier == nil
    }

    private static func helperBundleBelongsToDisplayApp(_ ownerBundle: String?, _ displayBundle: String?) -> Bool {
        guard let ownerBundle, let displayBundle else { return false }
        return ownerBundle == displayBundle ||
            ownerBundle.hasPrefix(displayBundle + ".")
    }

    private static func bundleIsParent(_ parentBundle: String?, of childBundle: String?) -> Bool {
        guard let parentBundle, let childBundle else { return false }
        return childBundle.hasPrefix(parentBundle + ".")
    }

    private static func executableRootsMatch(owner: NSRunningApplication, displayApp: NSRunningApplication) -> Bool {
        guard let ownerPath = owner.executableURL?.standardizedFileURL.path,
              let displayPath = displayApp.executableURL?.standardizedFileURL.path
        else { return false }

        let ownerComponents = ownerPath.split(separator: "/")
        let displayComponents = displayPath.split(separator: "/")
        let commonPrefixCount = zip(ownerComponents, displayComponents).prefix { $0 == $1 }.count

        return commonPrefixCount >= 5
    }

    private static func displayAppScore(_ displayApp: NSRunningApplication, forOwner owner: NSRunningApplication) -> Int {
        var score = 0
        if owner.processIdentifier == displayApp.processIdentifier { score += 100 }
        if owner.bundleIdentifier == displayApp.bundleIdentifier { score += 80 }
        if let ownerBundle = owner.bundleIdentifier,
           let displayBundle = displayApp.bundleIdentifier,
           ownerBundle.hasPrefix(displayBundle + ".")
        {
            score += 90
            score += max(0, 30 - (displayBundle.count / 4))
        } else if helperBundleBelongsToDisplayApp(owner.bundleIdentifier, displayApp.bundleIdentifier) {
            score += 50
        }
        if executableRootsMatch(owner: owner, displayApp: displayApp) { score += 10 }
        return score
    }
}

enum WindowCandidateDiscriminator {
    private static let minimumSize = CGSize(width: 100, height: 50)
    private static let normalLevel = CGWindowLevelForKey(.normalWindow)
    private static let floatingLevel = CGWindowLevelForKey(.floatingWindow)
    private static let unknownSubrole = "AXUnknown"
    private static let documentWindowSubrole = "AXDocumentWindow"

    static func hasUsableSize(_ size: CGSize?) -> Bool {
        guard let size, size.width > 0, size.height > 0 else { return false }
        if Defaults[.disableMinWindowSizeFilter] { return true }
        return size.width >= minimumSize.width && size.height >= minimumSize.height
    }

    static func hasUsableGeometry(_ attributes: WindowCandidateAttributes) -> Bool {
        guard hasUsableSize(attributes.size) else { return false }
        if let position = attributes.position {
            return position.x.isFinite && position.y.isFinite
        }
        return true
    }

    static func isActualWindow(app: NSRunningApplication,
                               windowID: CGWindowID,
                               level: Int32,
                               attributes: WindowCandidateAttributes) -> Bool
    {
        rejectionReason(app: app, windowID: windowID, level: level, attributes: attributes) == nil
    }

    static func rejectionReason(app: NSRunningApplication,
                                windowID: CGWindowID,
                                level: Int32,
                                attributes: WindowCandidateAttributes) -> String?
    {
        guard windowID != 0 else { return "missing CGWindowID" }
        return potentialRejectionReason(app: app, level: level, attributes: attributes)
    }

    static func isPotentialAXWindow(app: NSRunningApplication,
                                    level: Int32?,
                                    attributes: WindowCandidateAttributes) -> Bool
    {
        potentialRejectionReason(app: app, level: level, attributes: attributes) == nil
    }

    private static func potentialRejectionReason(app: NSRunningApplication,
                                                 level: Int32?,
                                                 attributes: WindowCandidateAttributes) -> String?
    {
        guard hasUsableGeometry(attributes) else { return "unusable geometry" }

        let specialApp = books(app) ||
            keynote(app) ||
            preview(app, attributes.subrole) ||
            iina(app) ||
            openFLStudio(app, attributes.title) ||
            (level.map { crossoverWindow(app, attributes.role, attributes.subrole, $0) } ?? false) ||
            (level.map { alwaysOnTopScrcpy(app, $0, attributes.role, attributes.subrole) } ?? false)

        let standardSubrole = [kAXStandardWindowSubrole, kAXDialogSubrole].contains(attributes.subrole)
        let appSpecificSubrole = openBoard(app) ||
            adobeAudition(app, attributes.subrole) ||
            adobeAfterEffects(app, attributes.subrole) ||
            steam(app, attributes.title, attributes.role) ||
            worldOfWarcraft(app, attributes.role) ||
            battleNetBootstrapper(app, attributes.role) ||
            firefox(app, attributes.role, attributes.size) ||
            vlcFullscreenVideo(app, attributes.role) ||
            sanGuoShaAirWD(app) ||
            dvdFab(app) ||
            drBetotte(app) ||
            androidEmulator(app, attributes.title, attributes.role, level) ||
            autocad(app, attributes.subrole)

        guard specialApp || standardSubrole || appSpecificSubrole else {
            return "subrole is not standard/dialog and no app-specific rule matched"
        }

        if !specialApp {
            guard mustHaveIfJetBrainsApp(app, attributes.title, attributes.subrole, attributes.size),
                  mustHaveIfSteam(app, attributes.title, attributes.role),
                  mustHaveIfFusion360(app, attributes.title),
                  mustHaveIfColorSlurp(app, attributes.subrole)
            else { return "app-specific hard requirement failed" }
        }

        return nil
    }

    private static func hasNonEmptyTitle(_ title: String?) -> Bool {
        guard let title else { return false }
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func mustHaveIfFusion360(_ app: NSRunningApplication, _ title: String?) -> Bool {
        app.bundleIdentifier != "com.autodesk.fusion360" || hasNonEmptyTitle(title)
    }

    private static func mustHaveIfJetBrainsApp(_ app: NSRunningApplication, _ title: String?, _ subrole: String?, _ size: CGSize?) -> Bool {
        guard let bundleIdentifier = app.bundleIdentifier,
              bundleIdentifier.hasPrefix("com.jetbrains.") || bundleIdentifier.hasPrefix("com.google.android.studio")
        else { return true }

        return (subrole == kAXStandardWindowSubrole || hasNonEmptyTitle(title)) &&
            (size?.width ?? 0) > 100 &&
            (size?.height ?? 0) > 100
    }

    private static func mustHaveIfColorSlurp(_ app: NSRunningApplication, _ subrole: String?) -> Bool {
        app.bundleIdentifier != "com.IdeaPunch.ColorSlurp" || subrole == kAXStandardWindowSubrole
    }

    private static func iina(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == "com.colliderli.iina"
    }

    private static func keynote(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == "com.apple.iWork.Keynote"
    }

    private static func preview(_ app: NSRunningApplication, _ subrole: String?) -> Bool {
        app.bundleIdentifier == "com.apple.Preview" && [kAXStandardWindowSubrole, kAXDialogSubrole].contains(subrole)
    }

    private static func openFLStudio(_ app: NSRunningApplication, _ title: String?) -> Bool {
        app.bundleIdentifier == "com.image-line.flstudio" && hasNonEmptyTitle(title)
    }

    private static func openBoard(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == "org.oe-f.OpenBoard"
    }

    private static func adobeAudition(_ app: NSRunningApplication, _ subrole: String?) -> Bool {
        app.bundleIdentifier == "com.adobe.Audition" && subrole == kAXFloatingWindowSubrole
    }

    private static func adobeAfterEffects(_ app: NSRunningApplication, _ subrole: String?) -> Bool {
        app.bundleIdentifier == "com.adobe.AfterEffects" && subrole == kAXFloatingWindowSubrole
    }

    private static func books(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == "com.apple.iBooksX"
    }

    private static func worldOfWarcraft(_ app: NSRunningApplication, _ role: String?) -> Bool {
        app.bundleIdentifier == "com.blizzard.worldofwarcraft" && role == kAXWindowRole
    }

    private static func battleNetBootstrapper(_ app: NSRunningApplication, _ role: String?) -> Bool {
        app.bundleIdentifier == "net.battle.bootstrapper" && role == kAXWindowRole
    }

    private static func drBetotte(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == "com.ssworks.drbetotte"
    }

    private static func dvdFab(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == "com.goland.dvdfab.macos"
    }

    private static func sanGuoShaAirWD(_ app: NSRunningApplication) -> Bool {
        app.bundleIdentifier == "SanGuoShaAirWD"
    }

    private static func steam(_ app: NSRunningApplication, _ title: String?, _ role: String?) -> Bool {
        app.bundleIdentifier == "com.valvesoftware.steam" && hasNonEmptyTitle(title) && role != nil
    }

    private static func mustHaveIfSteam(_ app: NSRunningApplication, _ title: String?, _ role: String?) -> Bool {
        app.bundleIdentifier != "com.valvesoftware.steam" || (hasNonEmptyTitle(title) && role != nil)
    }

    private static func firefox(_ app: NSRunningApplication, _ role: String?, _ size: CGSize?) -> Bool {
        (app.bundleIdentifier?.hasPrefix("org.mozilla.firefox") ?? false) &&
            role == kAXWindowRole &&
            (size?.height ?? 0) > 400
    }

    private static func vlcFullscreenVideo(_ app: NSRunningApplication, _ role: String?) -> Bool {
        (app.bundleIdentifier?.hasPrefix("org.videolan.vlc") ?? false) && role == kAXWindowRole
    }

    private static func androidEmulator(_ app: NSRunningApplication, _ title: String?, _ role: String?, _ level: Int32?) -> Bool {
        let title = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard app.bundleIdentifier == nil,
              role == kAXWindowRole,
              let title,
              !title.isEmpty,
              title != "Window",
              level == nil || level == normalLevel
        else { return false }
        return app.executableURL?.lastPathComponent.range(of: "qemu-system[^/]*$", options: .regularExpression) != nil
    }

    private static func crossoverWindow(_ app: NSRunningApplication, _ role: String?, _ subrole: String?, _ level: Int32) -> Bool {
        app.bundleIdentifier == nil &&
            role == kAXWindowRole &&
            subrole == unknownSubrole &&
            level == normalLevel &&
            (app.executableURL?.lastPathComponent == "wine64-preloader" || (app.executableURL?.absoluteString.contains("/winetemp-") ?? false))
    }

    private static func alwaysOnTopScrcpy(_ app: NSRunningApplication, _ level: Int32, _ role: String?, _ subrole: String?) -> Bool {
        app.executableURL?.lastPathComponent == "scrcpy" &&
            level == floatingLevel &&
            role == kAXWindowRole &&
            subrole == kAXStandardWindowSubrole
    }

    private static func autocad(_ app: NSRunningApplication, _ subrole: String?) -> Bool {
        (app.bundleIdentifier?.hasPrefix("com.autodesk.AutoCAD") ?? false) && subrole == documentWindowSubrole
    }
}

/// Heuristic mapping from AX window to CG window when _AXUIElementGetWindow fails
func mapAXToCG(attributes: WindowCandidateAttributes, candidates: [[String: AnyObject]], excluding: Set<CGWindowID>) -> CGWindowID? {
    let axTitle = attributes.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let axPos = attributes.position
    let axSize = attributes.size

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

/// Returns CG window candidates for a given PID.
func getCGWindowCandidates(for pid: pid_t) -> [[String: AnyObject]] {
    let cgAll = (CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: AnyObject]]) ?? []
    return cgAll.filter { desc in
        let owner = (desc[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
        return owner == pid
    }.sorted { first, second in
        let firstLayer = (first[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
        let secondLayer = (second[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
        return firstLayer == 0 && secondLayer != 0
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

func isValidCGWindowCandidate(_ id: CGWindowID, in candidates: [[String: AnyObject]]) -> Bool {
    guard let match = candidates.first(where: { desc -> Bool in
        let wid = CGWindowID((desc[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0)
        return wid == id
    }) else { return false }

    let bounds = match[kCGWindowBounds as String] as? [String: AnyObject]
    let rw = CGFloat((bounds?["Width"] as? NSNumber)?.doubleValue ?? 0)
    let rh = CGFloat((bounds?["Height"] as? NSNumber)?.doubleValue ?? 0)
    let alpha = CGFloat((match[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1.0)
    if !WindowCandidateDiscriminator.hasUsableSize(CGSize(width: rw, height: rh)) { return false }
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
