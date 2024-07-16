import CoreGraphics
import ScreenCaptureKit
import Cocoa

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
    func toggleFullScreen()  {
        do {
            if let isCurrentlyInFullScreen = try axElement.attribute(kAXFullscreenAttribute, Bool.self){
                self.axElement.setAttribute(kAXFullscreenAttribute, !isCurrentlyInFullScreen)
            }
        } catch {
            print("An error occurred: \(error)")
        }
    }
    
    /// Toggles the minimize state of the window.
    func toggleMinimize() {
        if self.isMinimized {
            // Un-minimize the window
            self.axElement.setAttribute(kAXMinimizedAttribute, false)
            
            self.focus()
        } else {
            // Minimize the window
            self.axElement.setAttribute(kAXMinimizedAttribute, true)
        }
    }
    
    /// The following function was ported from https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468
    func makeKeyWindow(_ psn: ProcessSerialNumber) -> Void {
        var cgWindowId_ = self.wid
        var psn_ = psn
        var bytes1 = [UInt8](repeating: 0, count: 0xf8)
        bytes1[0x04] = 0xF8
        bytes1[0x08] = 0x01
        bytes1[0x3a] = 0x10
        var bytes2 = [UInt8](repeating: 0, count: 0xf8)
        bytes2[0x04] = 0xF8
        bytes2[0x08] = 0x02
        bytes2[0x3a] = 0x10
        memcpy(&bytes1[0x3c], &cgWindowId_, MemoryLayout<UInt32>.size)
        memset(&bytes1[0x20], 0xFF, 0x10)
        memcpy(&bytes2[0x3c], &cgWindowId_, MemoryLayout<UInt32>.size)
        memset(&bytes2[0x20], 0xFF, 0x10)
        [bytes1, bytes2].forEach { bytes in
            _ = bytes.withUnsafeBufferPointer() { pointer in
                SLPSPostEventRecordTo(&psn_, &UnsafeMutablePointer(mutating: pointer.baseAddress)!.pointee)
            }
        }
    }
    
    /// Brings the window to the front and focuses it.
    func focus() {
        self.app.activate()
        
        var psn = ProcessSerialNumber()
        GetProcessForPID(self.app.processIdentifier, &psn)
        _SLPSSetFrontProcessWithOptions(&psn, self.wid, SLPSMode.userGenerated.rawValue)
        self.makeKeyWindow(psn)
        
        self.axElement.performAction(kAXRaiseAction)
    }
    
    /// Close the window using its close button.
    func close() {
        self.closeButton?.performAction(kAXPressAction)
    }
    
    /// Terminates the window's application.
    func quitApp(force: Bool) {
        if force {
            self.app.forceTerminate()
        } else {
            self.app.terminate()
        }
    }
}
