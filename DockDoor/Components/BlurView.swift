import SwiftUI

struct BlurView: NSViewRepresentable {
    var content: AnyView
    let cornerRadius: CGFloat

    init(@ViewBuilder content: () -> some View = { EmptyView() }, cornerRadius: CGFloat = 8) {
        self.content = AnyView(content().background(Color.clear))
        self.cornerRadius = cornerRadius
    }

    func makeNSView(context: Context) -> NSView {
        if #available(macOS 14, *) {
            if #available(macOS 26.0, *) {
                let glassView = NSGlassEffectView()
                glassView.cornerRadius = cornerRadius
                let hosting = NSHostingView(rootView: content)
                glassView.contentView = hosting
                return glassView
            }
        }
        // Fallback for older macOS
        let effectView = NSVisualEffectView()
        effectView.state = .active
        effectView.material = .popover
        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        effectView.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: effectView.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: effectView.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: effectView.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: effectView.trailingAnchor),
        ])
        return effectView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if #available(macOS 26.0, *), let glassView = nsView as? NSGlassEffectView {
            if let hosting = glassView.contentView as? NSHostingView<AnyView> {
                hosting.rootView = content
            }
        } else if let effectView = nsView as? NSVisualEffectView {
            for subview in effectView.subviews {
                if let hosting = subview as? NSHostingView<AnyView> {
                    hosting.rootView = content
                }
            }
        }
    }
}

struct MaterialBlurView: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context _: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}
