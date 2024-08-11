import Cocoa
import CoreGraphics
import ScreenCaptureKit

class Window: Equatable {
    let wid: CGWindowID
    let level: CGWindowLevel
    let title: String!
    let size: CGSize?
    let appName: String
    let bundleID: String?
    let app: NSRunningApplication
    var image: CGImage?
    var axElement: AXUIElement!
    var closeButton: AXUIElement?
    let isMinimized: Bool
    let isFullscreen: Bool

    // Equatable protocol
    static func == (lhs: Window, rhs: Window) -> Bool {
        return lhs.wid == rhs.wid
    }

    init(wid: CGWindowID, app: NSRunningApplication, level: CGWindowLevel, title: String!, size: CGSize?, appName: String, bundleID: String?, image: CGImage? = nil, axElement: AXUIElement, closeButton: AXUIElement? = nil, isMinimized: Bool, isFullscreen: Bool) {
        self.wid = wid
        self.app = app
        self.level = level
        self.title = title
        self.size = size
        self.appName = appName
        self.bundleID = bundleID
        self.image = image
        self.axElement = axElement
        self.closeButton = closeButton
        self.isMinimized = isMinimized
        self.isFullscreen = isFullscreen
    }

    /// Toggles the full-screen state of a window.
    func toggleFullScreen() {
        do {
            if let isCurrentlyInFullScreen = try axElement.attribute(kAXFullscreenAttribute, Bool.self) {
                axElement.setAttribute(kAXFullscreenAttribute, !isCurrentlyInFullScreen)
            }
        } catch {
            print("An error occurred: \(error)")
        }
    }

    /// Toggles the minimize state of the window.
    func toggleMinimize() {
        if isMinimized {
            // Un-minimize the window
            axElement.setAttribute(kAXMinimizedAttribute, false)

            focus()
        } else {
            // Minimize the window
            axElement.setAttribute(kAXMinimizedAttribute, true)
        }
    }

    /// The following function was ported from https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468
    func makeKeyWindow(_ psn: ProcessSerialNumber) {
        var cgWindowId_ = wid
        var psn_ = psn
        var bytes1 = [UInt8](repeating: 0, count: 0xF8)
        bytes1[0x04] = 0xF8
        bytes1[0x08] = 0x01
        bytes1[0x3A] = 0x10
        var bytes2 = [UInt8](repeating: 0, count: 0xF8)
        bytes2[0x04] = 0xF8
        bytes2[0x08] = 0x02
        bytes2[0x3A] = 0x10
        memcpy(&bytes1[0x3C], &cgWindowId_, MemoryLayout<UInt32>.size)
        memset(&bytes1[0x20], 0xFF, 0x10)
        memcpy(&bytes2[0x3C], &cgWindowId_, MemoryLayout<UInt32>.size)
        memset(&bytes2[0x20], 0xFF, 0x10)
        for bytes in [bytes1, bytes2] {
            _ = bytes.withUnsafeBufferPointer { pointer in
                SLPSPostEventRecordTo(&psn_, &UnsafeMutablePointer(mutating: pointer.baseAddress)!.pointee)
            }
        }
    }

    /// Brings the window to the front and focuses it.
    func focus() {
        app.activate()

        var psn = ProcessSerialNumber()
        GetProcessForPID(app.processIdentifier, &psn)
        _SLPSSetFrontProcessWithOptions(&psn, wid, SLPSMode.userGenerated.rawValue)
        makeKeyWindow(psn)

        axElement.performAction(kAXRaiseAction)
    }

    /// Close the window using its close button.
    func close() {
        closeButton?.performAction(kAXPressAction)
    }

    /// Terminates the window's application.
    func quitApp(force: Bool) {
        if force {
            app.forceTerminate()
        } else {
            app.terminate()
        }
    }
}
