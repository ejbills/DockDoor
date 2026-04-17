import Defaults
import SwiftUI

struct BackgroundAppearance: Equatable {
    let style: DockBackgroundStyle
    let material: DockBackgroundMaterial
    let glassOpacity: CGFloat
    let glassBlurRadius: CGFloat
    let glassSaturation: CGFloat
    let tintOpacity: CGFloat
    let borderOpacity: CGFloat
    let borderWidth: CGFloat
    let useOpaqueBackground: Bool
    let customBackgroundColor: Color?

    static let observedKeys: [Defaults._AnyKey] = [
        .dockBackgroundStyle, .dockBackgroundMaterial,
        .dockGlassOpacity, .dockGlassBlurRadius, .dockGlassSaturation,
        .dockBackgroundTintOpacity,
        .dockBackgroundBorderOpacity, .dockBackgroundBorderWidth,
        .useOpaquePreviewBackground, .customBackgroundColor,
    ]

    static func resolve() -> BackgroundAppearance {
        BackgroundAppearance(
            style: Defaults[.dockBackgroundStyle],
            material: Defaults[.dockBackgroundMaterial],
            glassOpacity: Defaults[.dockGlassOpacity],
            glassBlurRadius: Defaults[.dockGlassBlurRadius],
            glassSaturation: Defaults[.dockGlassSaturation],
            tintOpacity: Defaults[.dockBackgroundTintOpacity],
            borderOpacity: Defaults[.dockBackgroundBorderOpacity],
            borderWidth: Defaults[.dockBackgroundBorderWidth],
            useOpaqueBackground: Defaults[.useOpaquePreviewBackground],
            customBackgroundColor: Defaults[.customBackgroundColor]
        )
    }
}

struct BlurView: View {
    let cornerRadius: CGFloat
    let appearance: BackgroundAppearance

    init(cornerRadius: CGFloat = 0, appearance: BackgroundAppearance) {
        self.cornerRadius = cornerRadius
        self.appearance = appearance
    }

    var body: some View {
        if let customColor = appearance.customBackgroundColor {
            Rectangle().fill(customColor)
        } else if appearance.useOpaqueBackground {
            Rectangle().fill(Color(nsColor: .windowBackgroundColor))
        } else {
            styledBackground
        }
    }

    @ViewBuilder
    private var styledBackground: some View {
        switch appearance.style {
        case .liquidGlass:
            if #available(macOS 26.0, *) {
                LiquidGlassRepresentable(
                    cornerRadius: cornerRadius,
                    glassOpacity: appearance.glassOpacity,
                    tintOpacity: appearance.tintOpacity,
                    blurRadius: appearance.glassBlurRadius,
                    saturation: appearance.glassSaturation
                )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(appearance.material.swiftUIMaterial)
            }
        case .frostedMaterial:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(appearance.material.swiftUIMaterial)
        case .clear:
            Color.clear
        }
    }
}

@available(macOS 26.0, *)
struct LiquidGlassRepresentable: NSViewRepresentable {
    let cornerRadius: CGFloat
    var glassOpacity: CGFloat
    var tintOpacity: CGFloat
    var blurRadius: CGFloat
    var saturation: CGFloat

    func makeNSView(context: Context) -> LiquidGlassContainerView {
        let container = LiquidGlassContainerView()
        container.cornerRadius = cornerRadius
        container.glassOpacity = glassOpacity
        container.tintOpacity = tintOpacity
        container.blurRadius = blurRadius
        container.saturation = saturation
        return container
    }

    func updateNSView(_ container: LiquidGlassContainerView, context: Context) {
        container.glassOpacity = glassOpacity
        container.tintOpacity = tintOpacity
        container.blurRadius = blurRadius
        container.saturation = saturation
        container.cornerRadius = cornerRadius
        container.applyGlassOpacity()
        container.updateCornerRadius()
        container.applyBackdropOverrides()
    }
}

@available(macOS 26.0, *)
class LiquidGlassContainerView: NSView {
    var cornerRadius: CGFloat = 14
    var glassOpacity: CGFloat = 0.95
    var tintOpacity: CGFloat = 0.3 {
        didSet { updateTintColor() }
    }

    var blurRadius: CGFloat = 0
    var saturation: CGFloat = 1.0

    private var hasConfigured = false
    private var glass: NSGlassEffectView?
    private var tintLayer: NSView?
    private var backdropLayers: [CALayer] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupGlass()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGlass()
    }

    func applyGlassOpacity() {
        glass?.alphaValue = glassOpacity
    }

    func applyBackdropOverrides() {
        for backdrop in backdropLayers {
            if blurRadius > 0 {
                backdrop.setValue(blurRadius, forKey: "gaussianRadius")
            }
            backdrop.setValue(saturation, forKey: "saturationFactor")
        }
    }

    func updateCornerRadius() {
        glass?.cornerRadius = cornerRadius
        tintLayer?.layer?.cornerRadius = cornerRadius
    }

    private func setupGlass() {
        let tint = NSView()
        tint.translatesAutoresizingMaskIntoConstraints = false
        tint.wantsLayer = true
        tint.layer?.cornerRadius = cornerRadius
        tint.layer?.cornerCurve = .continuous
        tint.layer?.masksToBounds = true
        addSubview(tint)

        let glassView = NSGlassEffectView()
        glassView.style = .clear
        glassView.translatesAutoresizingMaskIntoConstraints = false
        glassView.cornerRadius = cornerRadius
        addSubview(glassView)

        for view in [tint, glassView] {
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: topAnchor),
                view.leadingAnchor.constraint(equalTo: leadingAnchor),
                view.trailingAnchor.constraint(equalTo: trailingAnchor),
                view.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
        }

        tintLayer = tint
        glass = glassView
        updateTintColor()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !hasConfigured else { return }
        hasConfigured = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.configureBackdropLayers()
        }
    }

    override func removeFromSuperview() {
        for backdrop in backdropLayers {
            backdrop.removeObserver(self, forKeyPath: "windowServerAware")
            backdrop.removeObserver(self, forKeyPath: "scale")
        }
        backdropLayers.removeAll()
        super.removeFromSuperview()
    }

    private func configureBackdropLayers() {
        if let layer = glass?.layer {
            setBackdropProperties(in: layer)
            observeBackdropLayers(in: layer)
            applyBackdropOverrides()
        }
    }

    // WindowServer resets `scale` to 0.5 for non-key windows, causing half-res blur.
    // We observe `scale` via KVO and force it back to 1.0.
    // We also observe `windowServerAware` — when false, the backdrop loses its
    // connection to WindowServer state. Reconfigure to restore it.
    private func observeBackdropLayers(in layer: CALayer) {
        guard backdropLayers.isEmpty else { return }
        backdropLayers = collectBackdropLayers(in: layer)
        for backdrop in backdropLayers {
            backdrop.addObserver(self, forKeyPath: "windowServerAware", options: [.old, .new], context: nil)
            backdrop.addObserver(self, forKeyPath: "scale", options: [.old, .new], context: nil)
        }
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "windowServerAware" {
            if change?[.newKey] as? Bool == false {
                configureBackdropLayers()
            }
        } else if keyPath == "scale" {
            if let newVal = change?[.newKey] as? Double, newVal != 1.0, let layer = object as? CALayer {
                layer.setValue(1.0, forKey: "scale")
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }

    private func collectBackdropLayers(in layer: CALayer) -> [CALayer] {
        var results: [CALayer] = []
        if NSStringFromClass(type(of: layer)).contains("CABackdropLayer") {
            results.append(layer)
        }
        layer.sublayers?.forEach { results.append(contentsOf: collectBackdropLayers(in: $0)) }
        return results
    }

    private func setBackdropProperties(in layer: CALayer) {
        if NSStringFromClass(type(of: layer)).contains("CABackdropLayer") {
            layer.setValue(true, forKey: "windowServerAware")
            layer.setValue(1.0, forKey: "scale")
        }
        layer.sublayers?.forEach { setBackdropProperties(in: $0) }
    }

    private func updateTintColor() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        tintLayer?.layer?.backgroundColor = (isDark ? NSColor.black : NSColor.white)
            .withAlphaComponent(tintOpacity).cgColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTintColor()
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
