import Cocoa

typealias CGSConnectionID = UInt32
typealias CGSSpaceID = UInt64

struct CGSWindowCaptureOptions: OptionSet {
    let rawValue: UInt32
    static let ignoreGlobalClipShape = CGSWindowCaptureOptions(rawValue: 1 << 11)
    // on a retina display, 1px is spread on 4px, so nominalResolution is 1/4 of bestResolution
    static let nominalResolution = CGSWindowCaptureOptions(rawValue: 1 << 9)
    static let bestResolution = CGSWindowCaptureOptions(rawValue: 1 << 8)
}

// returns the connection to the WindowServer. This connection ID is required when calling other APIs
// * macOS 10.10+
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

// returns the CGWindowID of the provided AXUIElement
// * macOS 10.10+
@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError

// returns an array of CGImage of the windows which ID is given as `windowList`. `windowList` is supposed to be an array of IDs but in my test on High Sierra, the function ignores other IDs than the first, and always returns the screenshot of the first window in the array
// * performance: the `HW` in the name seems to imply better performance, and it was observed by some contributors that it seems to be faster (see https://github.com/lwouis/alt-tab-macos/issues/45) than other methods
// * quality: medium
// * minimized windows: yes
// * windows in other spaces: yes
// * offscreen content: no
// * macOS 10.10+
@_silgen_name("CGSHWCaptureWindowList")
func CGSHWCaptureWindowList(_ cid: CGSConnectionID, _ windowList: inout CGWindowID, _ windowCount: UInt32, _ options: CGSWindowCaptureOptions) -> Unmanaged<CFArray>

// returns info about a given psn
// * macOS 10.9-10.15 (officially removed in 10.9, but available as a private API still)
@_silgen_name("GetProcessInformation") @discardableResult
func GetProcessInformation(_ psn: inout ProcessSerialNumber, _ info: inout ProcessInfoRec) -> OSErr
//
// returns the psn for a given pid
// * macOS 10.9-10.15 (officially removed in 10.9, but available as a private API still)
@_silgen_name("GetProcessForPID") @discardableResult
func GetProcessForPID(_ pid: pid_t, _ psn: inout ProcessSerialNumber) -> OSStatus

// returns window level (see definition in CGWindowLevel.h) of provided window
// * macOS 10.10+
@_silgen_name("CGSGetWindowLevel") @discardableResult
func CGSGetWindowLevel(_ cid: CGSConnectionID, _ wid: CGWindowID, _ level: inout CGWindowLevel) -> CGError

// for some reason, these attributes are missing from AXAttributeConstants
let kAXFullscreenAttribute = "AXFullScreen"
let kAXStatusLabelAttribute = "AXStatusLabel"

// for some reason, these attributes are missing from AXRoleConstants
let kAXDocumentWindowSubrole = "AXDocumentWindow"

// returns the provided CGWindow property for the provided CGWindowID
// * macOS 10.10+
@_silgen_name("CGSCopyWindowProperty") @discardableResult
func CGSCopyWindowProperty(_ cid: CGSConnectionID, _ wid: CGWindowID, _ property: CFString, _ value: inout CFTypeRef?) -> CGError

enum CGSSpaceMask: Int {
    case current = 5
    case other = 6
    case all = 7
}

// get the CGSSpaceIDs for the given windows (CGWindowIDs)
// * macOS 10.10+
@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(_ cid: CGSConnectionID, _ mask: CGSSpaceMask.RawValue, _ wids: CFArray) -> CFArray

enum SLPSMode: UInt32 {
    case allWindows = 0x100
    case userGenerated = 0x200
    case noWindows = 0x400
}

// focuses the front process
// * macOS 10.12+
@_silgen_name("_SLPSSetFrontProcessWithOptions") @discardableResult
func _SLPSSetFrontProcessWithOptions(_ psn: inout ProcessSerialNumber, _ wid: CGWindowID, _ mode: SLPSMode.RawValue) -> CGError

// sends bytes to the WindowServer
// more context: https://github.com/Hammerspoon/hammerspoon/issues/370#issuecomment-545545468
// * macOS 10.12+
@_silgen_name("SLPSPostEventRecordTo") @discardableResult
func SLPSPostEventRecordTo(_ psn: inout ProcessSerialNumber, _ bytes: inout UInt8) -> CGError
