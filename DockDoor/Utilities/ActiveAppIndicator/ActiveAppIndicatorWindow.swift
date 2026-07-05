import Cocoa
import Defaults
import SwiftUI

/// A borderless window that displays the indicator line next to the active dock app.
final class ActiveAppIndicatorWindow: NSPanel {
    private var indicatorView: NSHostingView<ActiveAppIndicatorView>?

    init() {
        let styleMask: NSWindow.StyleMask = [
            .nonactivatingPanel, .fullSizeContentView, .borderless,
        ]
        super.init(
            contentRect: .zero,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        setupWindow()
    }

    private func setupWindow() {
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        collectionBehavior = [
            .canJoinAllSpaces, .transient, .fullScreenAuxiliary, .ignoresCycle,
        ]
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        animationBehavior = .none

        let view = ActiveAppIndicatorView()
        let hostingView = NSHostingView(rootView: view)
        contentView = hostingView
        indicatorView = hostingView
    }
}

/// The SwiftUI view that draws the indicator line.
struct ActiveAppIndicatorView: View {
    @Default(.activeAppIndicatorColor) var indicatorColor

    var body: some View {
        Capsule()
            .fill(indicatorColor)
        // Frame is controlled by the window - Capsule fills it and adapts shape automatically
    }
}
