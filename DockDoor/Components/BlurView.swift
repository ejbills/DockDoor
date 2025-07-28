import SwiftUI

struct BlurView: View {
    let variant: Int?

    init(variant: Int? = nil) {
        self.variant = variant
    }

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectView(variant: variant)
        } else {
            Rectangle().fill(.ultraThinMaterial)
        }
    }
}

@available(macOS 26.0, *)
struct GlassEffectView: NSViewRepresentable {
    let variant: Int

    init(variant: Int? = 19) {
        // Clamp variant to valid range 0-19
        self.variant = max(0, min(19, variant ?? 18))
    }

    func makeNSView(context: Context) -> NSGlassEffectView {
        let glassView = NSGlassEffectView()
        setGlassVariant(glassView, variant: variant)
        return glassView
    }

    func updateNSView(_ nsView: NSGlassEffectView, context: Context) {
        setGlassVariant(nsView, variant: variant)
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
