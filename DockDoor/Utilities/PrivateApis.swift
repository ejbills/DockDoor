import Cocoa

// returns the CGWindowID of the provided AXUIElement
// * macOS 10.10+
#if !APPSTORE_BUILD
    @_silgen_name("_AXUIElementGetWindow") @discardableResult
    func _AXUIElementGetWindow(_ axUiElement: AXUIElement, _ wid: inout CGWindowID) -> AXError
#endif

// for some reason, these attributes are missing from AXAttributeConstants
let kAXFullscreenAttribute = "AXFullScreen"
