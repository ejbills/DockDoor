@testable import DockDoor
import Testing

@Suite("Preview activation dismissal")
struct PreviewActivationPolicyTests {
    @Test("Preserves a hovered preview when tap activation preservation is enabled")
    func preservesHoveredTapPreview() {
        let shouldDismiss = WindowManipulationObservers.shouldDismissPreviewOnAppActivation(
            isKeybindSessionActive: false,
            keepPreviewOnHoverActivation: true,
            previewHoverAction: .tap,
            mouseIsWithinPreviewWindow: true
        )

        #expect(!shouldDismiss)
    }

    @Test("Dismisses when the pointer has left the preview")
    func dismissesAfterPointerLeaves() {
        let shouldDismiss = WindowManipulationObservers.shouldDismissPreviewOnAppActivation(
            isKeybindSessionActive: false,
            keepPreviewOnHoverActivation: true,
            previewHoverAction: .tap,
            mouseIsWithinPreviewWindow: false
        )

        #expect(shouldDismiss)
    }

    @Test("Dismisses when preservation is disabled")
    func dismissesWhenDisabled() {
        let shouldDismiss = WindowManipulationObservers.shouldDismissPreviewOnAppActivation(
            isKeybindSessionActive: false,
            keepPreviewOnHoverActivation: false,
            previewHoverAction: .tap,
            mouseIsWithinPreviewWindow: true
        )

        #expect(shouldDismiss)
    }

    @Test("Does not affect keybind session dismissal")
    func preservesKeybindSessionBehavior() {
        let shouldDismiss = WindowManipulationObservers.shouldDismissPreviewOnAppActivation(
            isKeybindSessionActive: true,
            keepPreviewOnHoverActivation: false,
            previewHoverAction: .none,
            mouseIsWithinPreviewWindow: false
        )

        #expect(!shouldDismiss)
    }
}
