import SwiftUI

struct BlurView: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let effectView = NSVisualEffectView()
        effectView.state = .active
        effectView.material = .popover
        return effectView
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
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
