import Defaults
import SwiftUI

struct BackgroundAppearance: Equatable {
    let style: DockBackgroundStyle
    let material: DockBackgroundMaterial
    let glassOpacity: CGFloat
    let glassBlurRadius: CGFloat
    let glassSaturation: CGFloat
    let glassVariant: Int
    let tintOpacity: CGFloat
    let borderOpacity: CGFloat
    let borderWidth: CGFloat
    let useOpaqueBackground: Bool
    let customBackgroundColor: Color?

    static let observedKeys: [Defaults._AnyKey] = [
        .dockBackgroundStyle, .dockBackgroundMaterial,
        .dockGlassOpacity, .dockGlassBlurRadius, .dockGlassSaturation, .dockGlassVariant,
        .dockBackgroundTintOpacity,
        .dockBackgroundBorderOpacity, .dockBackgroundBorderWidth,
        .useOpaquePreviewBackground, .customBackgroundColor,
    ]

    /// Variant 20 is a synthetic variant handled by DockDoor (not a native
    /// NSGlassEffectView value). The glass shader's own edge refraction serves
    /// as the border, so `borderedBackground` should be skipped.
    static let syntheticBlurVariant = 20

    var usesSyntheticBlur: Bool { style == .liquidGlass && glassVariant == Self.syntheticBlurVariant }

    static func resolve() -> BackgroundAppearance {
        BackgroundAppearance(
            style: Defaults[.dockBackgroundStyle],
            material: Defaults[.dockBackgroundMaterial],
            glassOpacity: Defaults[.dockGlassOpacity],
            glassBlurRadius: Defaults[.dockGlassBlurRadius],
            glassSaturation: Defaults[.dockGlassSaturation],
            glassVariant: Defaults[.dockGlassVariant],
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
                    saturation: appearance.glassSaturation,
                    variant: appearance.glassVariant
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

// MARK: - Liquid Glass NSViewRepresentable

@available(macOS 26.0, *)
struct LiquidGlassRepresentable: NSViewRepresentable {
    let cornerRadius: CGFloat
    var glassOpacity: CGFloat
    var tintOpacity: CGFloat
    var blurRadius: CGFloat
    var saturation: CGFloat
    var variant: Int

    func makeNSView(context: Context) -> LiquidGlassContainerView {
        let container = LiquidGlassContainerView()
        container.cornerRadius = cornerRadius
        container.glassOpacity = glassOpacity
        container.tintOpacity = tintOpacity
        container.blurRadius = blurRadius
        container.saturation = saturation
        container.glassVariant = variant
        container.updateCornerRadius()
        container.applyGlassOpacity()
        return container
    }

    func updateNSView(_ container: LiquidGlassContainerView, context: Context) {
        container.glassOpacity = glassOpacity
        container.tintOpacity = tintOpacity
        container.blurRadius = blurRadius
        container.saturation = saturation
        container.cornerRadius = cornerRadius
        container.glassVariant = variant
        container.applyGlassOpacity()
        container.updateCornerRadius()
        container.applyGlassVariant()
        container.applyBackdropOverrides()
    }
}

// MARK: - Liquid Glass Container

/// Variant 20 is a synthetic variant that pairs the specular look of variant 19
/// with a separate blur underlay (a manually-inserted CABackdropLayer beneath
/// the glass). Variants 0-19 are native NSGlassEffectView `_variant` values
/// whose backdrop layers are managed by the system.
@available(macOS 26.0, *)
class LiquidGlassContainerView: NSView {
    private static let nativeVariantForSynthetic = 19

    var cornerRadius: CGFloat = 14
    var glassOpacity: CGFloat = 0.95
    var tintOpacity: CGFloat = 0.3 {
        didSet { updateTintColor() }
    }

    var blurRadius: CGFloat = 0
    var saturation: CGFloat = 1.0
    var glassVariant: Int = 4
    private var appliedNativeVariant: Int?

    private var hasConfigured = false
    private var glass: NSGlassEffectView?
    private var tintLayer: NSView?
    private var backdropLayers: [CALayer] = []
    private var blurUnderlayLayer: CALayer?

    private var isSyntheticVariant: Bool { glassVariant == BackgroundAppearance.syntheticBlurVariant }
    private var effectiveNativeVariant: Int {
        isSyntheticVariant ? Self.nativeVariantForSynthetic : glassVariant
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layer?.cornerRadius = cornerRadius
        layer?.cornerCurve = .continuous
        layer?.masksToBounds = true
        setupGlass()
    }

    func applyGlassOpacity() {
        glass?.alphaValue = glassOpacity
    }

    func applyGlassVariant() {
        guard let glass else { return }
        let target = effectiveNativeVariant
        let variantChanged = appliedNativeVariant != target
        if variantChanged {
            setNativeVariant(on: glass, target)
            appliedNativeVariant = target
            syncBlurUnderlay()
            refreshBackdropLayers()
        }
    }

    /// Sets the corner radius on the clipping container. For variant 20 the
    /// radius is also forwarded to the glass view so the shader renders edge
    /// refraction along the curve.
    func updateCornerRadius() {
        layer?.cornerRadius = cornerRadius
        if isSyntheticVariant {
            glass?.cornerRadius = cornerRadius
        }
    }

    /// Routes user blur/saturation overrides to the correct backend: native
    /// variants (0-19) are unchanged from upstream and use KVC on the glass
    /// view's own CABackdropLayers; the synthetic variant (20) uses CAFilters
    /// on its separate blur underlay instead.
    func applyBackdropOverrides() {
        if isSyntheticVariant {
            applyBlurUnderlayFilters()
        } else {
            applyNativeBackdropOverrides()
        }
    }

    // MARK: - Setup

    private func setupGlass() {
        let tint = NSView()
        tint.translatesAutoresizingMaskIntoConstraints = false
        tint.wantsLayer = true
        addSubview(tint)

        let glassView = NSGlassEffectView()
        glassView.style = .clear
        setNativeVariant(on: glassView, effectiveNativeVariant)
        if isSyntheticVariant {
            glassView.contentView = NSView()
            glassView.cornerRadius = cornerRadius
            glassView.wantsLayer = true
            glassView.layer?.masksToBounds = true
        }
        glassView.translatesAutoresizingMaskIntoConstraints = false
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

    // MARK: - Native variant helpers (0-19)

    /// Calls the private `set_variant:` on NSGlassEffectView. No-ops if the
    /// selector is unavailable.
    private func setNativeVariant(on view: NSView, _ variant: Int) {
        let sel = NSSelectorFromString("set_variant:")
        guard view.responds(to: sel), let imp = view.method(for: sel) else { return }
        typealias Setter = @convention(c) (NSObject, Selector, Int64) -> Void
        unsafeBitCast(imp, to: Setter.self)(view, sel, Int64(variant))
    }

    private func applyNativeBackdropOverrides() {
        for backdrop in backdropLayers {
            if blurRadius > 0 {
                backdrop.setValue(blurRadius, forKey: "gaussianRadius")
            }
            backdrop.setValue(saturation, forKey: "saturationFactor")
        }
    }

    // MARK: - Synthetic blur underlay (variant 20)

    /// Creates or tears down the blur underlay CABackdropLayer depending on
    /// whether the current variant needs it.
    private func syncBlurUnderlay() {
        if isSyntheticVariant {
            ensureBlurUnderlay()
        } else {
            removeBlurUnderlay()
        }
    }

    private func ensureBlurUnderlay() {
        guard blurUnderlayLayer == nil,
              let containerLayer = layer,
              let backdropClass = NSClassFromString("CABackdropLayer") as? CALayer.Type else { return }

        let backdrop = backdropClass.init()
        backdrop.setValue(true, forKey: "windowServerAware")
        backdrop.setValue(1.0, forKey: "scale")
        backdrop.frame = containerLayer.bounds
        backdrop.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        containerLayer.insertSublayer(backdrop, at: 0)
        blurUnderlayLayer = backdrop
    }

    private func removeBlurUnderlay() {
        blurUnderlayLayer?.removeFromSuperlayer()
        blurUnderlayLayer = nil
    }

    private func applyBlurUnderlayFilters() {
        guard let backdrop = blurUnderlayLayer else { return }
        var filters: [Any] = []
        if blurRadius > 0, let blur = makeCAFilter("gaussianBlur") {
            blur.setValue(blurRadius, forKey: "inputRadius")
            blur.setValue(true, forKey: "inputNormalizeEdges")
            filters.append(blur)
        }
        if saturation != 1.0, let saturate = makeCAFilter("colorSaturate") {
            saturate.setValue(saturation, forKey: "inputAmount")
            filters.append(saturate)
        }
        backdrop.filters = filters
        backdrop.isHidden = filters.isEmpty
    }

    private func makeCAFilter(_ type: String) -> NSObject? {
        guard let cls = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
        let sel = NSSelectorFromString("filterWithType:")
        guard cls.responds(to: sel) else { return nil }
        return cls.perform(sel, with: type)?.takeUnretainedValue() as? NSObject
    }

    // MARK: - Layout & lifecycle

    override func layout() {
        super.layout()
        if let containerLayer = layer {
            blurUnderlayLayer?.frame = containerLayer.bounds
        }
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
        removeBlurUnderlay()
        super.removeFromSuperview()
    }

    // MARK: - Backdrop layer management

    private func configureBackdropLayers() {
        if let layer = glass?.layer {
            setBackdropProperties(in: layer)
            observeBackdropLayers(in: layer)
        }
        syncBlurUnderlay()
        applyBackdropOverrides()
    }

    private func refreshBackdropLayers() {
        for backdrop in backdropLayers {
            backdrop.removeObserver(self, forKeyPath: "windowServerAware")
            backdrop.removeObserver(self, forKeyPath: "scale")
        }
        backdropLayers.removeAll()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.configureBackdropLayers()
        }
    }

    /// WindowServer resets `scale` to 0.5 for non-key windows, causing half-res
    /// blur. We observe both `scale` and `windowServerAware` via KVO so we can
    /// force them back to the correct values.
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

// MARK: - Material Blur View

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
