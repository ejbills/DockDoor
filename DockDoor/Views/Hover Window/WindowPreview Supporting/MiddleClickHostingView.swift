import SwiftUI

class MiddleClickHostingView<HostedContent: View>: NSView {
    private var hostingController: NSHostingController<HostedContent>?
    var onMiddleClick: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setContent(_ content: HostedContent) {
        if hostingController == nil {
            hostingController = NSHostingController(rootView: content)
            guard let hcView = hostingController?.view else { return }

            hcView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(hcView)
            NSLayoutConstraint.activate([
                hcView.leadingAnchor.constraint(equalTo: leadingAnchor),
                hcView.trailingAnchor.constraint(equalTo: trailingAnchor),
                hcView.topAnchor.constraint(equalTo: topAnchor),
                hcView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        } else {
            hostingController?.rootView = content
        }
        hostingController?.view.needsLayout = true
    }

    override func otherMouseDown(with event: NSEvent) {
        if event.buttonNumber == 2 {
            onMiddleClick?()
        } else {
            super.otherMouseDown(with: event)
        }
    }

    // Ensure context menus defined in SwiftUI content are correctly displayed.
    override func menu(for event: NSEvent) -> NSMenu? {
        hostingController?.view.menu(for: event) ?? super.menu(for: event)
    }
}

struct MiddleClickWrapper<Content: View>: NSViewRepresentable {
    let content: Content
    let onMiddleClick: () -> Void

    func makeNSView(context: Context) -> MiddleClickHostingView<Content> {
        let view = MiddleClickHostingView<Content>()
        view.setContent(content)
        view.onMiddleClick = onMiddleClick
        return view
    }

    func updateNSView(_ nsView: MiddleClickHostingView<Content>, context: Context) {
        nsView.setContent(content)
        nsView.onMiddleClick = onMiddleClick
    }
}
