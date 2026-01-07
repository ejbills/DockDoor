import Defaults
import SwiftUI

struct BlurView: View {
    @Default(.useLiquidGlass) private var useLiquidGlass
    let variant: Int?
    let frostedTranslucentLayer: Bool

    init(variant: Int? = nil, frostedTranslucentLayer: Bool = false) {
        self.variant = variant
        self.frostedTranslucentLayer = frostedTranslucentLayer
    }

    var body: some View {
        if #available(macOS 26.0, *), useLiquidGlass {
            GlassEffectView(variant: variant, frostedTranslucentLayer: frostedTranslucentLayer)
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}

// MARK: - Liquid Glass Container View

@available(macOS 26.0, *)
class LiquidGlassContainerView: NSView {
    var variant: Int = 18
    var frostedTranslucentLayer: Bool = false
    var backgroundOpacity: CGFloat = 0.725
    private var hasConfigured = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !hasConfigured else { return }

        hasConfigured = true

        // Configure backdrop layers once after a short delay for layer setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.configureBackdropLayers()
        }
    }

    private func configureBackdropLayers() {
        for subview in subviews {
            guard let glassView = subview as? NSGlassEffectView, let layer = glassView.layer else { continue }
            setBackdropProperties(in: layer)
        }
    }

    private func setBackdropProperties(in layer: CALayer) {
        if NSStringFromClass(type(of: layer)).contains("CABackdropLayer") {
            layer.setValue(true, forKey: "windowServerAware")
        }
        layer.sublayers?.forEach { setBackdropProperties(in: $0) }
    }
}

@available(macOS 26.0, *)
struct GlassEffectView: NSViewRepresentable {
    let variant: Int
    let frostedTranslucentLayer: Bool
    let backgroundOpacity: CGFloat = 0.725

    init(variant: Int? = 19, frostedTranslucentLayer: Bool = false) {
        self.variant = max(0, min(19, variant ?? 18))
        self.frostedTranslucentLayer = frostedTranslucentLayer
    }

    func makeNSView(context: Context) -> LiquidGlassContainerView {
        let containerView = LiquidGlassContainerView()
        containerView.variant = variant
        containerView.frostedTranslucentLayer = frostedTranslucentLayer
        containerView.backgroundOpacity = backgroundOpacity

        if variant == 19, frostedTranslucentLayer {
            let tintLayer = NSView()
            tintLayer.wantsLayer = true
            tintLayer.layer?.backgroundColor = NSColor.black.cgColor
            tintLayer.alphaValue = 0.1

            let backgroundGlass = NSGlassEffectView()
            backgroundGlass.setValue(NSNumber(value: 17), forKey: "_variant")
            backgroundGlass.alphaValue = backgroundOpacity

            let foregroundGlass = NSGlassEffectView()
            foregroundGlass.setValue(NSNumber(value: variant), forKey: "_variant")

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
        } else {
            let glassView = NSGlassEffectView()
            glassView.setValue(NSNumber(value: variant), forKey: "_variant")
            glassView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(glassView)
            NSLayoutConstraint.activate([
                glassView.topAnchor.constraint(equalTo: containerView.topAnchor),
                glassView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                glassView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                glassView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            ])
        }

        return containerView
    }

    func updateNSView(_ nsView: LiquidGlassContainerView, context: Context) {}
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
