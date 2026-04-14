import Defaults
import SwiftUI

struct DockBackgroundView: View {
    var cornerRadius: CGFloat

    @Default(.dockBackgroundTintOpacity) private var tintOpacity
    @Default(.dockBackgroundBorderOpacity) private var borderOpacity
    @Default(.dockBackgroundBorderWidth) private var borderWidth
    @Default(.dockBackgroundMaterial) private var material
    @Default(.dockBackgroundStyle) private var backgroundStyle
    @Default(.dockGlassOpacity) private var glassOpacity
    @Default(.dockGlassBlurRadius) private var glassBlurRadius
    @Default(.dockGlassSaturation) private var glassSaturation

    var body: some View {
        backgroundLayer
            .borderedBackground(
                .white.opacity(borderOpacity),
                lineWidth: borderWidth,
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch backgroundStyle {
        case .liquidGlass:
            if #available(macOS 26.0, *) {
                DockGlassRepresentable(
                    cornerRadius: cornerRadius,
                    glassOpacity: glassOpacity,
                    tintOpacity: tintOpacity,
                    blurRadius: glassBlurRadius,
                    saturation: glassSaturation
                )
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material.swiftUIMaterial)
            }
        case .frostedMaterial:
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(material.swiftUIMaterial)
        case .clear:
            Color.clear
        }
    }
}

// MARK: - NSViewRepresentable Bridge

@available(macOS 26.0, *)
struct DockGlassRepresentable: NSViewRepresentable {
    let cornerRadius: CGFloat
    var glassOpacity: CGFloat
    var tintOpacity: CGFloat
    var blurRadius: CGFloat
    var saturation: CGFloat

    func makeNSView(context: Context) -> DockGlassContainerView {
        let container = DockGlassContainerView()
        container.cornerRadius = cornerRadius
        container.glassOpacity = glassOpacity
        container.tintOpacity = tintOpacity
        container.blurRadius = blurRadius
        container.saturation = saturation
        return container
    }

    func updateNSView(_ container: DockGlassContainerView, context: Context) {
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

// MARK: - Glass Container (NSView)

@available(macOS 26.0, *)
class DockGlassContainerView: NSView {
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

    // MARK: - Public configuration

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

    // MARK: - Setup

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

    // MARK: - Lifecycle

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

    // MARK: - CABackdropLayer configuration

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

    // MARK: - Appearance

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
