import Defaults
import SwiftUI

enum HoverContainerPadding {
    static let container: CGFloat = 24
    static let dockStyleOuter: CGFloat = 2
    static let scrollOuter: CGFloat = 2
    static let contentInner: CGFloat = 20
    static let itemSpacing: CGFloat = 24

    static func totalPerSide(paddingMultiplier: CGFloat = Defaults[.globalPaddingMultiplier]) -> CGFloat {
        container + dockStyleOuter + scrollOuter + (contentInner * paddingMultiplier)
    }
}

struct BaseHoverContainer<Content: View>: View {
    @Default(.dockPreviewBackgroundOpacity) var dockPreviewBackgroundOpacity
    @Default(.hideHoverContainerBackground) var hideHoverContainerBackground
    @Default(.hideWidgetContainerBackground) var hideWidgetContainerBackground
    @Default(.showPreviewShadow) var showPreviewShadow
    @Default(.previewShadowRadius) var previewShadowRadius
    @Default(.previewShadowOpacity) var previewShadowOpacity

    let content: Content
    let bestGuessMonitor: NSScreen
    let mockPreviewActive: Bool
    let highlightColor: Color?
    let preventDockStyling: Bool
    let isWidget: Bool
    let backgroundAppearance: BackgroundAppearance
    let cornerRadius: Double

    init(bestGuessMonitor: NSScreen,
         mockPreviewActive: Bool = false,
         @ViewBuilder content: () -> Content,
         highlightColor: Color? = nil,
         preventDockStyling: Bool = false,
         isWidget: Bool = false,
         backgroundAppearance: BackgroundAppearance,
         cornerRadius: Double = CardRadius.Resolved.current().container)
    {
        self.bestGuessMonitor = bestGuessMonitor
        self.mockPreviewActive = mockPreviewActive
        self.content = content()
        self.highlightColor = highlightColor
        self.preventDockStyling = preventDockStyling
        self.isWidget = isWidget
        self.backgroundAppearance = backgroundAppearance
        self.cornerRadius = cornerRadius
    }

    private var shouldHideBackground: Bool {
        isWidget ? hideWidgetContainerBackground : hideHoverContainerBackground
    }

    private var backgroundOpacity: CGFloat {
        shouldHideBackground ? 0 : dockPreviewBackgroundOpacity
    }

    var body: some View {
        content
            .if(!preventDockStyling) { view in
                view
                    .background {
                        if showPreviewShadow, !mockPreviewActive, backgroundOpacity > 0 {
                            ContainerShadow(
                                cornerRadius: cornerRadius,
                                radius: previewShadowRadius,
                                opacity: previewShadowOpacity * backgroundOpacity
                            )
                            .padding(-ContainerShadow.room)
                            .allowsHitTesting(false)
                        }
                    }
                    .dockStyle(
                        backgroundAppearance: backgroundAppearance,
                        cornerRadius: cornerRadius,
                        highlightColor: highlightColor,
                        backgroundOpacity: backgroundOpacity
                    )
            }
            .padding(.all, mockPreviewActive ? 0 : HoverContainerPadding.container)
            .frame(maxWidth: bestGuessMonitor.visibleFrame.width, maxHeight: bestGuessMonitor.visibleFrame.height, alignment: .topLeading)
    }
}

private struct ContainerShadow: NSViewRepresentable {
    static let room = HoverContainerPadding.container + HoverContainerPadding.dockStyleOuter

    let cornerRadius: CGFloat
    let radius: CGFloat
    let opacity: CGFloat

    func makeNSView(context: Context) -> ContainerShadowView {
        ContainerShadowView()
    }

    func updateNSView(_ nsView: ContainerShadowView, context: Context) {
        nsView.configure(cornerRadius: cornerRadius, radius: radius, opacity: opacity)
    }
}

private final class ContainerShadowView: NSView {
    private let shadowLayer = CALayer()
    private let maskLayer = CAShapeLayer()
    private var cornerRadius: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        shadowLayer.shadowColor = NSColor.black.cgColor
        maskLayer.fillRule = .evenOdd
        shadowLayer.mask = maskLayer
        layer?.addSublayer(shadowLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func configure(cornerRadius: CGFloat, radius: CGFloat, opacity: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shadowLayer.shadowRadius = radius
        shadowLayer.shadowOpacity = Float(opacity)
        shadowLayer.shadowOffset = CGSize(width: 0, height: radius * 0.4)
        CATransaction.commit()

        guard cornerRadius != self.cornerRadius else { return }
        self.cornerRadius = cornerRadius
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .path(in: bounds.insetBy(dx: ContainerShadow.room, dy: ContainerShadow.room))
            .cgPath
        let mask = CGMutablePath()
        mask.addRect(bounds)
        mask.addPath(shape)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shadowLayer.frame = bounds
        maskLayer.frame = bounds
        shadowLayer.shadowPath = shape
        maskLayer.path = mask
        CATransaction.commit()
    }
}
