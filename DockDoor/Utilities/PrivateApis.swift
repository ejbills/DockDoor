import Cocoa

// returns the CGWindowID of the provided AXUIElement
// * macOS 10.10+
@_silgen_name("_AXUIElementGetWindow") @discardableResult
func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError

// for some reason, these attributes are missing from AXAttributeConstants
let kAXFullscreenAttribute = "AXFullScreen"

// returns CoreDock orientation and pinning state
@_silgen_name("CoreDockGetOrientationAndPinning")
func CoreDockGetOrientationAndPinning(_ outOrientation: UnsafeMutablePointer<Int32>, _ outPinning: UnsafeMutablePointer<Int32>)

@_silgen_name("CoreDockGetRect")
func CoreDockGetRect(_ outRect: UnsafeMutablePointer<CGRect>)
func getDockRect() -> CGRect {
    var rect = CGRect.zero
    CoreDockGetRect(&rect)
    return rect
}
