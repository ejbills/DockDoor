import ApplicationServices
import Cocoa
import ScreenCaptureKit

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
    var lastAccessedTime: Date
    var imageCapturedTime: Date
    var isMinimized: Bool
    var isHidden: Bool

    private var _scWindow: SCWindow?

    init(windowProvider: WindowPropertiesProviding, app: NSRunningApplication, image: CGImage?, axElement: AXUIElement, appAxElement: AXUIElement, closeButton: AXUIElement?, lastAccessedTime: Date, imageCapturedTime: Date? = nil, spaceID: Int? = nil, isMinimized: Bool, isHidden: Bool) {
        id = windowProvider.windowID
        self.windowProvider = windowProvider
        self.app = app
        windowName = windowProvider.title
        self.image = image
        self.axElement = axElement
        self.appAxElement = appAxElement
        self.closeButton = closeButton
        self.spaceID = spaceID
        self.lastAccessedTime = lastAccessedTime
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

extension WindowInfo {
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
