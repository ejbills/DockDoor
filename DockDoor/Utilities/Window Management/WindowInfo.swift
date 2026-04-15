import ApplicationServices
import Cocoa
import ScreenCaptureKit
import SQLite3
import SwiftUI

struct WindowInfo: Identifiable, Hashable {
    let id: CGWindowID
    let windowProvider: WindowPropertiesProviding
    let app: NSRunningApplication
    var windowName: String?
    var image: CGImage?
    var axElement: AXUIElement
    var appAxElement: AXUIElement
    var closeButton: AXUIElement?
    var spaceID: Int?
    var screenIdentifier: String?
    var lastAccessedTime: Date
    var creationTime: Date
    var imageCapturedTime: Date
    var isMinimized: Bool
    var isHidden: Bool

    private var _scWindow: SCWindow?

    init(windowProvider: WindowPropertiesProviding, app: NSRunningApplication, image: CGImage?, axElement: AXUIElement, appAxElement: AXUIElement, closeButton: AXUIElement?, lastAccessedTime: Date, creationTime: Date? = nil, imageCapturedTime: Date? = nil, spaceID: Int? = nil, screenIdentifier: String? = nil, isMinimized: Bool, isHidden: Bool) {
        id = windowProvider.windowID
        self.windowProvider = windowProvider
        self.app = app
        windowName = (try? axElement.title()) ?? windowProvider.title
        self.image = image
        self.axElement = axElement
        self.appAxElement = appAxElement
        self.closeButton = closeButton
        self.spaceID = spaceID
        self.screenIdentifier = screenIdentifier
        self.lastAccessedTime = lastAccessedTime
        self.creationTime = creationTime ?? lastAccessedTime
        self.imageCapturedTime = imageCapturedTime ?? lastAccessedTime
        self.isMinimized = isMinimized
        self.isHidden = isHidden
        _scWindow = windowProvider as? SCWindow
    }

    var frame: CGRect { windowProvider.frame }
    var scWindow: SCWindow? { _scWindow }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        lhs.id == rhs.id &&
            lhs.app.processIdentifier == rhs.app.processIdentifier &&
            lhs.axElement == rhs.axElement
    }
}

struct WindowTitleBadgeStyle {
    let backgroundColor: Color
    let borderColor: Color
    let foregroundColor: Color
}

private enum SafariProfileColorResolver {
    private static let safariBundleIdentifier = "com.apple.Safari"
    private static let safariTabsDatabaseURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent("Library/Containers/com.apple.Safari/Data/Library/Safari/SafariTabs.db")

    private static let cacheLock = NSLock()
    private static var cachedProfilesByName: [String: NSColor] = [:]
    private static var cachedDatabaseModificationDate: Date?

    static func color(for window: WindowInfo) -> NSColor? {
        guard window.app.bundleIdentifier == safariBundleIdentifier,
              let windowTitle = window.windowName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !windowTitle.isEmpty
        else {
            return nil
        }

        let profilesByName = loadProfilesIfNeeded()
        guard let matchedProfileName = matchingProfileName(in: windowTitle, availableProfileNames: Array(profilesByName.keys)) else {
            return nil
        }

        return profilesByName[matchedProfileName]
    }

    private static func loadProfilesIfNeeded() -> [String: NSColor] {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        let modificationDate = (try? FileManager.default.attributesOfItem(atPath: safariTabsDatabaseURL.path)[.modificationDate]) as? Date
        if modificationDate == cachedDatabaseModificationDate, !cachedProfilesByName.isEmpty {
            return cachedProfilesByName
        }

        let loadedProfiles = loadProfilesFromDatabase()
        cachedProfilesByName = loadedProfiles
        cachedDatabaseModificationDate = modificationDate
        return loadedProfiles
    }

    private static func matchingProfileName(in title: String, availableProfileNames: [String]) -> String? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        for profileName in availableProfileNames.sorted(by: { $0.count > $1.count }) {
            let trimmedProfileName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedProfileName.isEmpty else { continue }

            if trimmedTitle == trimmedProfileName ||
                trimmedTitle.hasPrefix(trimmedProfileName + " —") ||
                trimmedTitle.hasPrefix(trimmedProfileName + " –") ||
                trimmedTitle.hasPrefix(trimmedProfileName + " -")
            {
                return profileName
            }
        }

        return nil
    }

    private static func loadProfilesFromDatabase() -> [String: NSColor] {
        guard FileManager.default.fileExists(atPath: safariTabsDatabaseURL.path) else {
            return [:]
        }

        var database: OpaquePointer?
        let openResult = sqlite3_open_v2(
            safariTabsDatabaseURL.path,
            &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX,
            nil
        )

        guard openResult == SQLITE_OK, let database else {
            sqlite3_close(database)
            return [:]
        }

        defer { sqlite3_close(database) }
        sqlite3_busy_timeout(database, 50)

        let query = """
        SELECT b.title, s.value
        FROM settings s
        JOIN bookmarks b ON b.id = s.parent
        WHERE s.key = 'ProfileColor'
          AND s.deleted = 0
          AND b.deleted = 0
          AND b.title IS NOT NULL
          AND b.title != ''
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK, let statement else {
            sqlite3_finalize(statement)
            return [:]
        }

        defer { sqlite3_finalize(statement) }

        var resolvedProfiles: [String: NSColor] = [:]

        while sqlite3_step(statement) == SQLITE_ROW {
            guard let titleCString = sqlite3_column_text(statement, 0) else {
                continue
            }

            let profileName = String(cString: titleCString).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !profileName.isEmpty else {
                continue
            }

            let blobLength = Int(sqlite3_column_bytes(statement, 1))
            guard blobLength > 0, let blobPointer = sqlite3_column_blob(statement, 1) else {
                continue
            }

            let archivedValue = Data(bytes: blobPointer, count: blobLength)
            if let color = decodeColor(from: archivedValue) {
                resolvedProfiles[profileName] = color
            }
        }

        return resolvedProfiles
    }

    private static func decodeColor(from archivedValue: Data) -> NSColor? {
        guard let plist = try? PropertyListSerialization.propertyList(from: archivedValue, options: [], format: nil) as? [String: Any],
              let objects = plist["$objects"] as? [Any],
              let top = plist["$top"] as? [String: Any],
              let root = resolveArchivedObject(at: top["root"], objects: objects) as? [String: Any]
        else {
            return nil
        }

        let colorName = resolveArchivedObject(at: root["colorName"], objects: objects) as? String
        if colorName == "clear" {
            return nil
        }

        guard let red = (resolveArchivedObject(at: root["redComponent"], objects: objects) as? NSNumber)?.doubleValue,
              let green = (resolveArchivedObject(at: root["greenComponent"], objects: objects) as? NSNumber)?.doubleValue,
              let blue = (resolveArchivedObject(at: root["blueComponent"], objects: objects) as? NSNumber)?.doubleValue,
              let alpha = (resolveArchivedObject(at: root["alphaComponent"], objects: objects) as? NSNumber)?.doubleValue
        else {
            return nil
        }

        return NSColor(
            calibratedRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(alpha)
        )
    }

    private static func resolveArchivedObject(at reference: Any?, objects: [Any]) -> Any? {
        guard let reference else {
            return nil
        }

        if let index = archivedObjectIndex(from: reference), objects.indices.contains(index) {
            return objects[index]
        }

        return reference
    }

    private static func archivedObjectIndex(from reference: Any) -> Int? {
        if let number = reference as? NSNumber {
            return number.intValue
        }

        let description = String(describing: reference)
        guard let valueRange = description.range(of: "value = ") else {
            return nil
        }

        let digits = description[valueRange.upperBound...].prefix { $0.isNumber }
        return Int(digits)
    }
}

extension WindowInfo {
    var safariProfileBadgeStyle: WindowTitleBadgeStyle? {
        guard let badgeColor = SafariProfileColorResolver.color(for: self) else {
            return nil
        }

        let backgroundColor = Color(nsColor: badgeColor)

        return WindowTitleBadgeStyle(
            backgroundColor: backgroundColor,
            borderColor: backgroundColor.darker(by: 0.18),
            foregroundColor: badgeColor.preferredPillForegroundColor
        )
    }

    @discardableResult
    mutating func toggleMinimize() -> Bool? {
        if isMinimized {
            if app.isHidden {
                app.unhide()
            }
            do {
                try axElement.setAttribute(kAXMinimizedAttribute, false)
                app.activate()
                bringToFront()
                isMinimized = false
                WindowUtil.updateCachedWindowState(self, isMinimized: false)
                return false
            } catch {
                return nil
            }
        } else {
            do {
                try axElement.setAttribute(kAXMinimizedAttribute, true)
                isMinimized = true
                WindowUtil.updateCachedWindowState(self, isMinimized: true)
                return true
            } catch {
                return nil
            }
        }
    }

    @discardableResult
    mutating func toggleHidden() -> Bool? {
        let newHiddenState = !isHidden

        do {
            try appAxElement.setAttribute(kAXHiddenAttribute, newHiddenState)
            if !newHiddenState {
                app.activate()
                bringToFront()
            }
            isHidden = newHiddenState
            WindowUtil.updateCachedWindowState(self, isHidden: newHiddenState)
            return newHiddenState
        } catch {
            print("Error toggling hidden state of application")
            return nil
        }
    }

    mutating func toggleFullScreen() {
        if let isCurrentlyInFullScreen = try? axElement.isFullscreen() {
            do {
                try axElement.setAttribute(kAXFullscreenAttribute, !isCurrentlyInFullScreen)
            } catch {
                print("Failed to toggle full screen")
            }
        } else {
            print("Failed to determine current full screen state")
        }
    }

    func zoom() {
        positionWindow(rect: .full)
    }

    // MARK: - Window Positioning

    enum WindowPositionRect {
        case full
        case leftHalf
        case rightHalf
        case topHalf
        case bottomHalf
        case topLeftQuarter
        case topRightQuarter
        case bottomLeftQuarter
        case bottomRightQuarter
        case center

        func frame(in visibleFrame: CGRect, currentSize: CGSize? = nil) -> CGRect {
            switch self {
            case .full:
                return visibleFrame
            case .leftHalf:
                return CGRect(
                    x: visibleFrame.origin.x,
                    y: visibleFrame.origin.y,
                    width: visibleFrame.width / 2,
                    height: visibleFrame.height
                )
            case .rightHalf:
                return CGRect(
                    x: visibleFrame.origin.x + visibleFrame.width / 2,
                    y: visibleFrame.origin.y,
                    width: visibleFrame.width / 2,
                    height: visibleFrame.height
                )
            case .topHalf:
                return CGRect(
                    x: visibleFrame.origin.x,
                    y: visibleFrame.origin.y + visibleFrame.height / 2,
                    width: visibleFrame.width,
                    height: visibleFrame.height / 2
                )
            case .bottomHalf:
                return CGRect(
                    x: visibleFrame.origin.x,
                    y: visibleFrame.origin.y,
                    width: visibleFrame.width,
                    height: visibleFrame.height / 2
                )
            case .topLeftQuarter:
                return CGRect(
                    x: visibleFrame.origin.x,
                    y: visibleFrame.origin.y + visibleFrame.height / 2,
                    width: visibleFrame.width / 2,
                    height: visibleFrame.height / 2
                )
            case .topRightQuarter:
                return CGRect(
                    x: visibleFrame.origin.x + visibleFrame.width / 2,
                    y: visibleFrame.origin.y + visibleFrame.height / 2,
                    width: visibleFrame.width / 2,
                    height: visibleFrame.height / 2
                )
            case .bottomLeftQuarter:
                return CGRect(
                    x: visibleFrame.origin.x,
                    y: visibleFrame.origin.y,
                    width: visibleFrame.width / 2,
                    height: visibleFrame.height / 2
                )
            case .bottomRightQuarter:
                return CGRect(
                    x: visibleFrame.origin.x + visibleFrame.width / 2,
                    y: visibleFrame.origin.y,
                    width: visibleFrame.width / 2,
                    height: visibleFrame.height / 2
                )
            case .center:
                let size = currentSize ?? CGSize(width: visibleFrame.width * 0.6, height: visibleFrame.height * 0.6)
                return CGRect(
                    x: visibleFrame.origin.x + (visibleFrame.width - size.width) / 2,
                    y: visibleFrame.origin.y + (visibleFrame.height - size.height) / 2,
                    width: size.width,
                    height: size.height
                )
            }
        }
    }

    private func currentWindowPlacementContext() -> (screen: NSScreen, size: CGSize)? {
        guard let currentSize = try? axElement.size(),
              let windowFrame = Self.currentWindowFrame(for: axElement)
        else {
            return nil
        }

        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(windowFrame) }) ?? NSScreen.main else {
            return nil
        }

        return (screen, currentSize)
    }

    static func currentWindowFrame(for element: AXUIElement) -> CGRect? {
        guard let currentPosition = try? element.position(),
              let currentSize = try? element.size()
        else {
            return nil
        }

        let primaryScreenMaxY = NSScreen.screens.first?.frame.maxY ?? NSScreen.main?.frame.maxY ?? 0
        return CGRect(
            x: currentPosition.x,
            y: primaryScreenMaxY - currentPosition.y - currentSize.height,
            width: currentSize.width,
            height: currentSize.height
        )
    }

    func currentWindowFrame() -> CGRect? {
        Self.currentWindowFrame(for: axElement)
    }

    private func applyWindowFrame(_ targetFrame: CGRect, on screen: NSScreen) {
        let primaryScreenMaxY = NSScreen.screens.first?.frame.maxY ?? screen.frame.maxY
        let axY = primaryScreenMaxY - targetFrame.maxY
        let newPosition = CGPoint(x: targetFrame.origin.x, y: axY)
        let newSize = CGSize(width: targetFrame.width, height: targetFrame.height)

        guard let positionValue = AXValue.from(point: newPosition),
              let sizeValue = AXValue.from(size: newSize)
        else {
            return
        }

        try? axElement.setAttribute(kAXPositionAttribute, positionValue)
        try? axElement.setAttribute(kAXSizeAttribute, sizeValue)
    }

    func setWindowFrame(_ targetFrame: CGRect) {
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(targetFrame) })
            ?? currentWindowPlacementContext()?.screen
            ?? NSScreen.main
        else {
            return
        }

        applyWindowFrame(targetFrame, on: screen)
    }

    private func positionWindow(rect: WindowPositionRect) {
        guard let context = currentWindowPlacementContext() else {
            return
        }

        let visibleFrame = context.screen.visibleFrame
        let targetFrame = rect.frame(in: visibleFrame, currentSize: context.size)
        applyWindowFrame(targetFrame, on: context.screen)
    }

    func fillLeftHalf() {
        positionWindow(rect: .leftHalf)
    }

    func fillRightHalf() {
        positionWindow(rect: .rightHalf)
    }

    func fillTopHalf() {
        positionWindow(rect: .topHalf)
    }

    func fillBottomHalf() {
        positionWindow(rect: .bottomHalf)
    }

    func fillTopLeftQuarter() {
        positionWindow(rect: .topLeftQuarter)
    }

    func fillTopRightQuarter() {
        positionWindow(rect: .topRightQuarter)
    }

    func fillBottomLeftQuarter() {
        positionWindow(rect: .bottomLeftQuarter)
    }

    func fillBottomRightQuarter() {
        positionWindow(rect: .bottomRightQuarter)
    }

    func centerWindow() {
        positionWindow(rect: .center)
    }

    func centerWindow(scale: CGFloat) {
        guard let context = currentWindowPlacementContext() else {
            return
        }

        let visibleFrame = context.screen.visibleFrame
        let clampedScale = min(max(scale, 0.2), 1.0)
        let targetSize = CGSize(
            width: visibleFrame.width * clampedScale,
            height: visibleFrame.height * clampedScale
        )
        let targetFrame = WindowPositionRect.center.frame(in: visibleFrame, currentSize: targetSize)
        applyWindowFrame(targetFrame, on: context.screen)
    }

    func centerWindow(widthScale: CGFloat, heightScale: CGFloat, lockAspectRatio: Bool) {
        guard let context = currentWindowPlacementContext() else {
            return
        }

        let visibleFrame = context.screen.visibleFrame

        let clampedWidthScale = min(max(widthScale, 0.2), 1.0)
        let clampedHeightScale = min(max(heightScale, 0.2), 1.0)

        let maxWidth = visibleFrame.width * clampedWidthScale
        let maxHeight = visibleFrame.height * clampedHeightScale

        let targetSize: CGSize
        if lockAspectRatio {
            let currentSize = context.size
            guard currentSize.width > 0, currentSize.height > 0 else {
                targetSize = CGSize(width: maxWidth, height: maxHeight)
                let targetFrame = WindowPositionRect.center.frame(in: visibleFrame, currentSize: targetSize)
                applyWindowFrame(targetFrame, on: context.screen)
                return
            }

            let scaleFactor = min(maxWidth / currentSize.width, maxHeight / currentSize.height)
            targetSize = CGSize(width: currentSize.width * scaleFactor, height: currentSize.height * scaleFactor)
        } else {
            targetSize = CGSize(width: maxWidth, height: maxHeight)
        }

        let targetFrame = WindowPositionRect.center.frame(in: visibleFrame, currentSize: targetSize)
        applyWindowFrame(targetFrame, on: context.screen)
    }

    func bringToFront() {
        let maxRetries = 3
        var retryCount = 0

        func attemptActivation() -> Bool {
            do {
                var psn = ProcessSerialNumber()
                _ = GetProcessForPID(app.processIdentifier, &psn)
                _ = _SLPSSetFrontProcessWithOptions(&psn, UInt32(id), SLPSMode.userGenerated.rawValue)

                WindowUtil.makeKeyWindow(&psn, windowID: id)

                try axElement.performAction(kAXRaiseAction)
                try axElement.setAttribute(kAXMainWindowAttribute, true)

                return true
            } catch {
                print("Attempt \(retryCount + 1) failed to bring window to front: \(error)")
                if error is AxError {
                    WindowUtil.removeWindowFromDesktopSpaceCache(with: id, in: app.processIdentifier)
                }
                return false
            }
        }

        while retryCount < maxRetries {
            if attemptActivation() {
                WindowUtil.updateTimestampOptimistically(for: self)
                return
            }
            retryCount += 1
            if retryCount < maxRetries {
                usleep(50000)
            }
        }

        print("Failed to bring window to front after \(maxRetries) attempts")
    }

    func close() {
        guard closeButton != nil else {
            print("Error: closeButton is nil.")
            return
        }

        do {
            try closeButton?.performAction(kAXPressAction)
            WindowUtil.removeWindowFromDesktopSpaceCache(with: id, in: app.processIdentifier)
        } catch {
            print("Error closing window")
        }
    }

    func quit(force: Bool) {
        if force {
            app.forceTerminate()
        } else {
            app.terminate()
        }
        WindowUtil.purgeAppCache(with: app.processIdentifier)
    }
}
