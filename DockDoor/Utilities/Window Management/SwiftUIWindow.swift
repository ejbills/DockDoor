import AppKit
import SwiftUI

class SwiftUIWindow<Content>: NSWindow, NSWindowDelegate where Content: View {
    private var viewBuilder: () -> Content
    private var onClose: (() -> Void)?

    init(styleMask: NSWindow.StyleMask, content: @escaping () -> Content, onClose: (() -> Void)? = nil) {
        viewBuilder = content
        self.onClose = onClose
        super.init(contentRect: NSRect(x: 0, y: 0, width: 0, height: 0), styleMask: styleMask, backing: .buffered, defer: true)
        delegate = self
    }

    func show() {
        let contentView = viewBuilder()
        let view = NSHostingView(rootView: contentView)
        self.contentView = view
        let intrinsicSize = view.intrinsicContentSize
        let screenF = screen?.frame.size ?? .zero

        var finalSize = intrinsicSize
        if toolbar != nil {
            finalSize.height += 51 // Add toolbar height if present
        }
        setContentSize(finalSize)
        setFrameOrigin(.init(
            x: (screenF.width - finalSize.width) / 2,
            y: (screenF.height - finalSize.height) / 2
        ))

        makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        contentView = nil
        onClose?()
    }
}
