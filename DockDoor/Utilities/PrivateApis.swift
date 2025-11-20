import Cocoa

// Borrows from: https://github.com/lwouis/alt-tab-macos/blob/master/src/api-wrappers/private-apis/SkyLight.framework.swift

struct CGSWindowCaptureOptions: OptionSet {
    let rawValue: UInt32
    static let ignoreGlobalClipShape = CGSWindowCaptureOptions(rawValue: 1 << 11)
    // on a retina display, 1px is spread on 4px, so nominalResolution is 1/4 of bestResolution
    static let nominalResolution = CGSWindowCaptureOptions(rawValue: 1 << 9)
    static let bestResolution = CGSWindowCaptureOptions(rawValue: 1 << 8)
    // when Stage Manager is enabled, screenshots can become skewed. This param gets us full-size screenshots regardless
    static let fullSize = CGSWindowCaptureOptions(rawValue: 1 << 19)
}

// returns the CGWindowID of the provided AXUIElement
// * macOS 10.10+
@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError

// for some reason, these attributes are missing from AXAttributeConstants
let kAXFullscreenAttribute = "AXFullScreen"

// returns CoreDock orientation and pinning state
@_silgen_name("CoreDockGetOrientationAndPinning")
func CoreDockGetOrientationAndPinning(_ outOrientation: UnsafeMutablePointer<Int32>, _ outPinning: UnsafeMutablePointer<Int32>)

// Toggles the Dock's auto-hide state
@_silgen_name("CoreDockSetAutoHideEnabled")
func CoreDockSetAutoHideEnabled(_ flag: Bool)

// Retrieves the current auto-hide state of the Dock
@_silgen_name("CoreDockGetAutoHideEnabled")
func CoreDockGetAutoHideEnabled() -> Bool

// Retrieves the current magnification state of the Dock
@_silgen_name("CoreDockIsMagnificationEnabled")
func CoreDockIsMagnificationEnabled() -> Bool

// Define the private API types
typealias CGSConnectionID = UInt32
typealias CGSWindowCount = UInt32
typealias CGSSpaceID = UInt64
typealias CGSSpaceMask = UInt64

// All spaces mask (private constant)
let kCGSAllSpacesMask: CGSSpaceMask = 0xFFFF_FFFF_FFFF_FFFF

// Define the private API functions with @_silgen_name
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSHWCaptureWindowList")
func CGSHWCaptureWindowList(
    _ cid: CGSConnectionID,
    _ windowList: UnsafePointer<UInt32>,
    _ count: CGSWindowCount,
    _ options: CGSWindowCaptureOptions
) -> CFArray?

// Private spaces API: returns array of space IDs corresponding to the provided windows
@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(
    _ cid: CGSConnectionID,
    _ mask: CGSSpaceMask,
    _ windowIDs: CFArray
) -> CFArray?

// Private: get window level
@_silgen_name("CGSGetWindowLevel")
func CGSGetWindowLevel(
    _ cid: CGSConnectionID,
    _ wid: UInt32,
    _ outLevel: UnsafeMutablePointer<Int32>
) -> Int32

// Private: copy window property (e.g., kCGSWindowTitle)
@_silgen_name("CGSCopyWindowProperty")
func CGSCopyWindowProperty(
    _ cid: CGSConnectionID,
    _ wid: UInt32,
    _ key: CFString,
    _ outValue: UnsafeMutablePointer<CFTypeRef?>
) -> Int32

// Private: create AXUIElement from remote token (used for brute-force window enumeration)
@_silgen_name("_AXUIElementCreateWithRemoteToken")
func _AXUIElementCreateWithRemoteToken(_ token: CFData) -> Unmanaged<AXUIElement>?

// MARK: - SkyLight Private APIs for Window Focusing

// Process Serial Number (legacy Carbon API type)
struct ProcessSerialNumber {
    var highLongOfPSN: UInt32 = 0
    var lowLongOfPSN: UInt32 = 0
}

// Get ProcessSerialNumber for a given PID (from ApplicationServices)
@_silgen_name("GetProcessForPID")
func GetProcessForPID(_ pid: pid_t, _ psn: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

enum SLPSMode: UInt32 {
    case allWindows = 0x100
    case userGenerated = 0x200
    case noWindows = 0x400
}

// MARK: SkyLight Function Loading

typealias SLPSSetFrontProcessWithOptionsType = @convention(c) (
    UnsafeMutableRawPointer,
    CGWindowID,
    UInt32
) -> CGError

typealias SLPSPostEventRecordToType = @convention(c) (
    UnsafeMutableRawPointer,
    UnsafeMutablePointer<UInt8>
) -> CGError

private var skyLightHandle: UnsafeMutableRawPointer?
private var setFrontProcessPtr: SLPSSetFrontProcessWithOptionsType?
private var postEventRecordPtr: SLPSPostEventRecordToType?

private func loadSkyLightFunctions() {
    guard skyLightHandle == nil else { return }

    let skyLightPath = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
    guard let handle = dlopen(skyLightPath, RTLD_LAZY) else {
        print("Failed to load SkyLight framework")
        return
    }

    skyLightHandle = handle

    if let symbol = dlsym(handle, "_SLPSSetFrontProcessWithOptions") {
        setFrontProcessPtr = unsafeBitCast(symbol, to: SLPSSetFrontProcessWithOptionsType.self)
    }

    if let symbol = dlsym(handle, "SLPSPostEventRecordTo") {
        postEventRecordPtr = unsafeBitCast(symbol, to: SLPSPostEventRecordToType.self)
    }
}

func _SLPSSetFrontProcessWithOptions(_ psn: UnsafeMutablePointer<ProcessSerialNumber>, _ wid: CGWindowID, _ mode: SLPSMode.RawValue) -> CGError {
    loadSkyLightFunctions()
    guard let fn = setFrontProcessPtr else { return CGError(rawValue: -1)! }
    return fn(psn, wid, mode)
}

func SLPSPostEventRecordTo(_ psn: UnsafeMutablePointer<ProcessSerialNumber>, _ bytes: UnsafeMutablePointer<UInt8>) -> CGError {
    loadSkyLightFunctions()
    guard let fn = postEventRecordPtr else { return CGError(rawValue: -1)! }
    return fn(psn, bytes)
}
