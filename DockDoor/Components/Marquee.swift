import Defaults
import SwiftUI

struct MarqueeText: View {
    var text: String
    var startDelay: Double
    var maxWidth: Double?

    @State private var textSize: CGSize = .zero
    @State private var containerWidth: CGFloat = 0
    @Default(.enableTitleMarquee) private var enableTitleMarquee

    init(text: String, startDelay: Double = 3.0, maxWidth: Double? = nil) {
        self.text = text
        self.startDelay = startDelay
        self.maxWidth = maxWidth
    }

    private var measured: Bool { textSize != .zero }

    private var available: CGFloat {
        if let maxWidth { return CGFloat(maxWidth) }
        return containerWidth
    }

    private var shouldScroll: Bool {
        enableTitleMarquee && measured && available > 0 && textSize.width > available
    }

    private var outerWidth: CGFloat? {
        if let maxWidth { return CGFloat(maxWidth) }
        guard measured, containerWidth > 0 else { return nil }
        if shouldScroll { return containerWidth }
        return min(textSize.width, containerWidth)
    }

    var body: some View {
        GeometryReader { geo in
            Group {
                if shouldScroll {
                    MarqueeNativeBridge(
                        text: text,
                        textWidth: textSize.width,
                        maxWidth: available,
                        delay: startDelay,
                        speed: 15,
                        spacing: 8,
                        fadeLength: 4
                    )
                    .frame(width: available, height: textSize.height)
                } else {
                    Text(text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .onAppear { containerWidth = geo.size.width }
            .onChange(of: geo.size.width) { newWidth in
                containerWidth = newWidth
            }
        }
        .frame(width: outerWidth, height: measured ? textSize.height : nil)
        .background {
            Text(text)
                .lineLimit(1)
                .fixedSize()
                .hidden()
                .measure($textSize)
        }
    }
}

private struct MarqueeNativeBridge: NSViewRepresentable {
    let text: String
    let textWidth: CGFloat
    let maxWidth: CGFloat
    let delay: Double
    let speed: Double
    let spacing: CGFloat
    let fadeLength: CGFloat

    func makeNSView(context _: Context) -> MarqueeNativeView {
        MarqueeNativeView()
    }

    func updateNSView(_ view: MarqueeNativeView, context: Context) {
        let content = AnyView(
            Text(text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.self, context.environment)
        )
        view.configure(
            text: text, content: content, textWidth: textWidth,
            maxWidth: maxWidth, delay: delay, speed: speed,
            spacing: spacing, fadeLength: fadeLength
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView _: MarqueeNativeView, context _: Context) -> CGSize? {
        CGSize(width: proposal.width ?? maxWidth, height: proposal.height ?? 16)
    }
}

final class MarqueeNativeView: NSView {
    private let scrollContainer = NSView()
    private var primaryHost: NSHostingView<AnyView>?
    private var duplicateHost: NSHostingView<AnyView>?
    private var activeConfig: Config?
    private var laidOutConfig: Config?
    private var didSetup = false

    private func setupIfNeeded() {
        guard !didSetup else { return }
        didSetup = true
        wantsLayer = true
        layer?.masksToBounds = true
        scrollContainer.wantsLayer = true
        addSubview(scrollContainer)
    }

    override func layout() {
        super.layout()
        guard let config = activeConfig, bounds.height > 0 else { return }
        guard config != laidOutConfig || scrollContainer.frame.height != bounds.height else { return }
        laidOutConfig = config
        applyLayout(config)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            scrollContainer.layer?.removeAnimation(forKey: "marquee")
        } else if let config = laidOutConfig {
            startAnimation(config)
        }
    }

    func configure(
        text: String, content: AnyView, textWidth: CGFloat, maxWidth: CGFloat,
        delay: Double, speed: Double, spacing: CGFloat, fadeLength: CGFloat
    ) {
        setupIfNeeded()
        let config = Config(
            text: text, textWidth: textWidth, maxWidth: maxWidth,
            delay: delay, speed: speed, spacing: spacing,
            fadeLength: fadeLength
        )
        guard config != activeConfig else {
            primaryHost?.rootView = content
            duplicateHost?.rootView = content
            return
        }
        scrollContainer.layer?.removeAnimation(forKey: "marquee")
        activeConfig = config

        if primaryHost == nil {
            primaryHost = NSHostingView(rootView: content)
            scrollContainer.addSubview(primaryHost!)
        } else {
            primaryHost!.rootView = content
        }

        if duplicateHost == nil {
            duplicateHost = NSHostingView(rootView: content)
            scrollContainer.addSubview(duplicateHost!)
        } else {
            duplicateHost!.rootView = content
        }

        needsLayout = true
    }

    private func applyLayout(_ config: Config) {
        let h = bounds.height
        let tw = config.textWidth
        let sp = config.spacing
        let fl = config.fadeLength
        let stride = tw + sp
        let hostW = tw + 100

        primaryHost?.frame = CGRect(x: fl, y: 0, width: hostW, height: h)
        duplicateHost?.frame = CGRect(x: fl + stride, y: 0, width: hostW, height: h)
        let totalW = fl + stride + hostW
        scrollContainer.frame = CGRect(x: 0, y: 0, width: totalW, height: h)

        let mask = CAGradientLayer()
        mask.frame = bounds
        mask.startPoint = CGPoint(x: 0, y: 0.5)
        mask.endPoint = CGPoint(x: 1, y: 0.5)
        let r = Double(fl / config.maxWidth)
        mask.colors = [CGColor.clear, CGColor.black, CGColor.black, CGColor.clear]
        mask.locations = [0, NSNumber(value: r), NSNumber(value: 1 - r), 1]
        layer?.mask = mask

        startAnimation(config)
    }

    private func startAnimation(_ config: Config) {
        scrollContainer.layer?.removeAnimation(forKey: "marquee")
        guard window != nil else { return }

        let dist = config.textWidth + config.spacing
        let scrollDuration = dist / config.speed
        let totalDuration = config.delay + scrollDuration
        let delayFrac = config.delay / totalDuration

        let anim = CAKeyframeAnimation(keyPath: "transform.tx")
        anim.values = [0.0, 0.0, -dist]
        anim.keyTimes = [0, NSNumber(value: delayFrac), 1.0]
        anim.duration = totalDuration
        anim.repeatCount = .infinity
        anim.calculationMode = .linear

        scrollContainer.layer?.add(anim, forKey: "marquee")
    }

    private struct Config: Equatable {
        let text: String
        let textWidth: CGFloat
        let maxWidth: CGFloat
        let delay: Double
        let speed: Double
        let spacing: CGFloat
        let fadeLength: CGFloat
    }
}
