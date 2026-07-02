import Cocoa
import Defaults
import SwiftUI

final class ActiveAppIndicatorModel: ObservableObject {
    @Published var windowCount: Int = 0
}

/// A borderless window that displays the indicator line next to the active dock app.
final class ActiveAppIndicatorWindow: NSPanel {
    private var indicatorView: NSHostingView<ActiveAppIndicatorView>?
    private let model = ActiveAppIndicatorModel()

    init() {
        let styleMask: NSWindow.StyleMask = [
            .nonactivatingPanel, .fullSizeContentView, .borderless,
        ]
        super.init(
            contentRect: .zero,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        setupWindow()
    }

    private func setupWindow() {
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovableByWindowBackground = false
        collectionBehavior = [
            .canJoinAllSpaces, .transient, .fullScreenAuxiliary, .ignoresCycle,
        ]
        hidesOnDeactivate = false
        ignoresMouseEvents = true
        animationBehavior = .none

        let view = ActiveAppIndicatorView(model: model)
        let hostingView = NSHostingView(rootView: view)
        contentView = hostingView
        indicatorView = hostingView
    }

    func updateWindowCount(_ count: Int) {
        model.windowCount = count
    }
}

/// The SwiftUI view that draws the indicator line or window count badge.
struct ActiveAppIndicatorView: View {
    @ObservedObject var model: ActiveAppIndicatorModel
    @Default(.activeAppIndicatorColor) var indicatorColor
    @Default(.activeAppIndicatorStyle) var indicatorStyle

    var body: some View {
        // Frame is controlled by the window - Capsule fills it and adapts shape automatically
        switch indicatorStyle {
        case .bar:
            Capsule()
                .fill(indicatorColor)
        case .windowCount:
            GeometryReader { proxy in
                Capsule()
                    .fill(indicatorColor)
                    .overlay(
                        Text("\(model.windowCount)")
                            .font(.system(size: proxy.size.height * 0.72, weight: .bold, design: .rounded))
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .foregroundColor(badgeTextColor)
                            .padding(.horizontal, 2)
                    )
            }
        }
    }

    private var badgeTextColor: Color {
        guard let color = NSColor(indicatorColor).usingColorSpace(.sRGB) else { return .white }
        let luminance = 0.299 * color.redComponent + 0.587 * color.greenComponent + 0.114 * color.blueComponent
        return luminance > 0.6 ? .black : .white
    }
}
