import SwiftUI

final class DragPreviewCoordinator {
    static let shared = DragPreviewCoordinator()
    private var previewWindow: NSWindow?
    private var initialWindowFrame: CGRect?
    private var dragStartLocation: CGPoint?
    private var initialScreenForDrag: NSScreen?
    private let previewScale: CGFloat = 0.2
    private let previewOpacity: CGFloat = 0.5

    func startDragging(windowInfo: WindowInfo, at location: CGPoint) {
        endDragging()

        initialScreenForDrag = NSScreen.screenContainingMouse(location)
        dragStartLocation = location

        guard let image = windowInfo.image else { return }

        let scaledSize = CGSize(
            width: CGFloat(image.width) * previewScale,
            height: CGFloat(image.height) * previewScale
        )

        let scaledFrame = CGRect(
            x: location.x,
            y: location.y - scaledSize.height,
            width: scaledSize.width,
            height: scaledSize.height
        )

        let previewWindow = NSWindow(
            contentRect: scaledFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        previewWindow.backgroundColor = .clear
        previewWindow.isOpaque = false
        previewWindow.hasShadow = true
        previewWindow.level = .popUpMenu

        let imageView = NSImageView(frame: NSRect(origin: .zero, size: scaledFrame.size))
        imageView.image = NSImage(cgImage: image, size: scaledFrame.size)
        imageView.imageScaling = .scaleAxesIndependently
        imageView.alphaValue = previewOpacity

        previewWindow.contentView = imageView
        initialWindowFrame = scaledFrame
        previewWindow.setFrame(scaledFrame, display: true)
        previewWindow.orderFront(nil)
        previewWindow.alphaValue = 1

        self.previewWindow = previewWindow
    }

    func updatePreviewPosition(to currentLocation: CGPoint) {
        guard let startLocation = dragStartLocation,
              let initialFrame = initialWindowFrame,
              let previewWindow else { return }

        let deltaX = currentLocation.x - startLocation.x
        let deltaY = currentLocation.y - startLocation.y
        var newFrame = initialFrame
        newFrame.origin.x += deltaX
        newFrame.origin.y += deltaY
        previewWindow.setFrame(newFrame, display: true)
    }

    func endDragging() {
        guard let window = previewWindow else { return }
        window.alphaValue = 0
        previewWindow = nil
        dragStartLocation = nil
        initialWindowFrame = nil
        initialScreenForDrag = nil
    }
}
