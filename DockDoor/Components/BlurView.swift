import SwiftUI

struct BlurView: View {
    let variant: Int?
    let frostedTranslucentLayer: Bool

    init(variant: Int? = nil, frostedTranslucentLayer: Bool = false) {
        self.variant = variant
        self.frostedTranslucentLayer = frostedTranslucentLayer
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectView(variant: variant, frostedTranslucentLayer: frostedTranslucentLayer)
        } else {
        Rectangle().fill(.ultraThinMaterial)
        }
    }
}

 @available(macOS 26.0, *)
 struct GlassEffectView: NSViewRepresentable {
    let variant: Int
    let frostedTranslucentLayer: Bool
    let backgroundOpacity: CGFloat = 0.725

    init(variant: Int? = 19, frostedTranslucentLayer: Bool = false) {
        // Clamp variant to valid range 0-19
        self.variant = max(0, min(19, variant ?? 18))
        self.frostedTranslucentLayer = frostedTranslucentLayer
    }

    func makeNSView(context: Context) -> NSView {
        if variant == 19, frostedTranslucentLayer {
            let containerView = NSView()

            let tintLayer = NSView()
            tintLayer.wantsLayer = true
            tintLayer.layer?.backgroundColor = NSColor.black.cgColor
            tintLayer.alphaValue = 0.1

            let backgroundGlass = NSGlassEffectView()
            setGlassVariant(backgroundGlass, variant: 17)
            backgroundGlass.alphaValue = backgroundOpacity

            let foregroundGlass = NSGlassEffectView()
            setGlassVariant(foregroundGlass, variant: variant)

            for item in [tintLayer, backgroundGlass, foregroundGlass] {
                item.translatesAutoresizingMaskIntoConstraints = false
                containerView.addSubview(item)
                NSLayoutConstraint.activate([
                    item.topAnchor.constraint(equalTo: containerView.topAnchor),
                    item.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                    item.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                    item.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
                ])
            }

            return containerView
        } else {
            let glassView = NSGlassEffectView()
            setGlassVariant(glassView, variant: variant)
            return glassView
        }
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if variant == 19, frostedTranslucentLayer, let glassViews = nsView.subviews as? [NSGlassEffectView], glassViews.count >= 2 {
            setGlassVariant(glassViews[0], variant: 17)
            glassViews[0].alphaValue = backgroundOpacity
            setGlassVariant(glassViews[1], variant: variant)
        } else if let glassView = nsView as? NSGlassEffectView {
            setGlassVariant(glassView, variant: variant)
        }
    }

    private func setGlassVariant(_ glassView: NSGlassEffectView, variant: Int) {
        glassView.setValue(NSNumber(value: variant), forKey: "_variant")
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
