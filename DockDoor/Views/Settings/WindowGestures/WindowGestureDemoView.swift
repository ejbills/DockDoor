import SwiftUI

struct GestureDemo {
    enum Place {
        case titleBar
        case tab
        case dockIcon
        case menuBar
    }

    enum Motion {
        case swipe([GestureDirection])
        case pinch(inward: Bool)
        case doubleTap
    }

    enum Outcome {
        case snap(SnapRegion)
        case center
        case minimize
        case close
        case quit
        case fullScreen
        case closeTab
        case restore
        case switchApp
        case minimizeAll
        case restoreAll
    }

    let place: Place
    let motion: Motion
    let outcome: Outcome
}

extension WindowGesture {
    var demo: GestureDemo {
        switch self {
        case .snapHalves: GestureDemo(place: .titleBar, motion: .swipe([.right]), outcome: .snap(.rightHalf))
        case .snapMax: GestureDemo(place: .titleBar, motion: .swipe([.up]), outcome: .snap(.maximize))
        case .snapQuarters: GestureDemo(place: .titleBar, motion: .swipe([.right, .down]), outcome: .snap(.bottomRightQuarter))
        case .windowMinimize: GestureDemo(place: .titleBar, motion: .swipe([.down]), outcome: .minimize)
        case .windowClose: GestureDemo(place: .titleBar, motion: .pinch(inward: true), outcome: .close)
        case .tabClose: GestureDemo(place: .tab, motion: .pinch(inward: true), outcome: .closeTab)
        case .windowFullscreen: GestureDemo(place: .titleBar, motion: .pinch(inward: false), outcome: .fullScreen)
        case .snapCenter: GestureDemo(place: .titleBar, motion: .doubleTap, outcome: .center)
        case .appMinimize: GestureDemo(place: .dockIcon, motion: .swipe([.down]), outcome: .minimize)
        case .appUnminimize: GestureDemo(place: .dockIcon, motion: .swipe([.up]), outcome: .restore)
        case .appQuit: GestureDemo(place: .dockIcon, motion: .pinch(inward: true), outcome: .quit)
        case .menubarAppSwitcher: GestureDemo(place: .menuBar, motion: .swipe([.right]), outcome: .switchApp)
        case .menubarMinimize: GestureDemo(place: .menuBar, motion: .swipe([.down]), outcome: .minimizeAll)
        case .menubarUnminimize: GestureDemo(place: .menuBar, motion: .swipe([.up]), outcome: .restoreAll)
        }
    }
}

struct GestureDemoView: View {
    static let cycleDuration: TimeInterval = 3.2
    static let posterTime: CGFloat = 0.4

    let demo: GestureDemo
    var isPlaying: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    var body: some View {
        let animating = isPlaying && !reduceMotion
        TimelineView(.animation(minimumInterval: 1 / 60, paused: !animating)) { timeline in
            let elapsed = timeline.date.timeIntervalSince(startDate)
            let time = animating ? CGFloat(elapsed.truncatingRemainder(dividingBy: Self.cycleDuration) / Self.cycleDuration) : Self.posterTime
            Canvas { context, size in
                GestureDemoRenderer(demo: demo, time: max(time, 0)).draw(in: context, size: size)
            }
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                startDate = Date()
            }
        }
        .accessibilityHidden(true)
    }
}

struct GestureDemoCarousel: View {
    let gestures: [WindowGesture]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60, paused: reduceMotion)) { timeline in
            let elapsed = max(timeline.date.timeIntervalSince(startDate), 0)
            let cycle = Int(elapsed / GestureDemoView.cycleDuration)
            let gesture = gestures[cycle % max(gestures.count, 1)]
            let time = reduceMotion ? GestureDemoView.posterTime : CGFloat(elapsed.truncatingRemainder(dividingBy: GestureDemoView.cycleDuration) / GestureDemoView.cycleDuration)

            VStack(alignment: .leading, spacing: 8) {
                Canvas { context, size in
                    GestureDemoRenderer(demo: gesture.demo, time: time).draw(in: context, size: size)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                HStack(spacing: 6) {
                    GestureRecipeView(demo: gesture.demo)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                    Text(gesture.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct GestureRecipeView: View {
    let demo: GestureDemo

    var body: some View {
        HStack(spacing: 4) {
            motionChips
            Text(placeLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var motionChips: some View {
        switch demo.motion {
        case let .swipe(directions):
            ForEach(Array(directions.enumerated()), id: \.offset) { _, direction in
                RecipeChip(systemImage: Self.arrow(direction))
            }
        case let .pinch(inward):
            RecipeChip(systemImage: inward ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
        case .doubleTap:
            RecipeChip(systemImage: "hand.tap", text: "×2")
        }
    }

    private var placeLabel: String {
        switch demo.place {
        case .titleBar: String(localized: "on a title bar", comment: "Where a window gesture happens")
        case .tab: String(localized: "on a tab", comment: "Where a window gesture happens")
        case .dockIcon: String(localized: "on a Dock icon", comment: "Where a window gesture happens")
        case .menuBar: String(localized: "on the menu bar", comment: "Where a window gesture happens")
        }
    }

    static func arrow(_ direction: GestureDirection) -> String {
        switch direction {
        case .left: "arrow.left"
        case .right: "arrow.right"
        case .up: "arrow.up"
        case .down: "arrow.down"
        }
    }
}

private struct RecipeChip: View {
    let systemImage: String
    var text: String?

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 9, weight: .bold))
            if let text {
                Text(verbatim: text)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 5)
        .frame(height: 18)
        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
    }
}

private struct GestureDemoRenderer {
    let demo: GestureDemo
    let time: CGFloat

    private struct Layout {
        let size: CGSize
        let menuHeight: CGFloat
        let workspace: CGRect
        let dock: CGRect
        let icons: [CGRect]

        var targetIcon: CGRect { icons[2] }
        var floating: CGRect {
            CGRect(x: workspace.midX - workspace.width * 0.3, y: workspace.minY + workspace.height * 0.14, width: workspace.width * 0.6, height: workspace.height * 0.66)
        }

        func frame(for region: SnapRegion) -> CGRect {
            let frame = region.frame(in: CGRect(origin: .zero, size: workspace.size)).insetBy(dx: 1, dy: 1)
            return CGRect(x: workspace.minX + frame.minX, y: workspace.minY + workspace.height - frame.maxY, width: frame.width, height: frame.height)
        }
    }

    private enum Phase {
        static let fingersIn: ClosedRange<CGFloat> = 0.04 ... 0.12
        static let motion: ClosedRange<CGFloat> = 0.12 ... 0.52
        static let outcome: ClosedRange<CGFloat> = 0.54 ... 0.8
        static let fingersOut: ClosedRange<CGFloat> = 0.56 ... 0.66
        static let fadeOut: ClosedRange<CGFloat> = 0.93 ... 1
    }

    func draw(in context: GraphicsContext, size: CGSize) {
        var context = context
        context.opacity = 1 - progress(Phase.fadeOut) * 0.85
        drawDesktop(in: &context, size: size)
    }

    // MARK: - Timing

    private func progress(_ range: ClosedRange<CGFloat>) -> CGFloat {
        min(max((time - range.lowerBound) / (range.upperBound - range.lowerBound), 0), 1)
    }

    private func eased(_ range: ClosedRange<CGFloat>) -> CGFloat {
        let value = progress(range)
        return value < 0.5 ? 2 * value * value : 1 - pow(-2 * value + 2, 2) / 2
    }

    private var outcomeProgress: CGFloat { eased(Phase.outcome) }

    private var fingerOpacity: CGFloat {
        progress(Phase.fingersIn) * (1 - progress(Phase.fingersOut))
    }

    // MARK: - Layout

    private func layout(for size: CGSize) -> Layout {
        let menuHeight = max(size.height * 0.075, 6)
        let dockHeight = size.height * 0.14
        let dockWidth = size.width * 0.46
        let dock = CGRect(x: (size.width - dockWidth) / 2, y: size.height - dockHeight - size.height * 0.03, width: dockWidth, height: dockHeight)
        let iconSize = dockHeight * 0.68
        let spacing = (dockWidth - iconSize * 5) / 6
        let icons = (0 ..< 5).map { index in
            CGRect(x: dock.minX + spacing + CGFloat(index) * (iconSize + spacing), y: dock.midY - iconSize / 2, width: iconSize, height: iconSize)
        }
        let top = menuHeight + size.height * 0.03
        let bottom = dock.minY - size.height * 0.03
        let workspace = CGRect(x: size.width * 0.03, y: top, width: size.width * 0.94, height: bottom - top)
        return Layout(size: size, menuHeight: menuHeight, workspace: workspace, dock: dock, icons: icons)
    }

    // MARK: - Scenes

    private func drawDesktop(in context: inout GraphicsContext, size: CGSize) {
        let layout = layout(for: size)
        let e = outcomeProgress
        drawWallpaper(in: &context, rect: CGRect(origin: .zero, size: size))

        var chromeOpacity: CGFloat = 1
        if case .fullScreen = demo.outcome {
            chromeOpacity = 1 - e
        }
        drawMenuBar(in: &context, layout: layout, opacity: chromeOpacity)
        drawDock(in: &context, layout: layout, opacity: chromeOpacity)

        let start = startFrame(layout)
        var fingerAnchor = CGPoint(x: start.midX, y: start.minY + titleBarHeight(for: start) / 2)

        switch demo.outcome {
        case let .snap(region):
            let target = layout.frame(for: region)
            if e > 0 {
                drawGhost(in: &context, rect: target, opacity: (1 - e) * 0.9)
            }
            drawWindow(in: &context, rect: lerp(start, target, e), color: .blue)

        case .center:
            if e > 0 {
                drawGhost(in: &context, rect: layout.floating, opacity: (1 - e) * 0.9)
            }
            drawWindow(in: &context, rect: lerp(start, layout.floating, e), color: .blue)

        case .minimize:
            let iconCenter = layout.targetIcon.center
            let frame = scaled(start, toward: iconCenter, by: e)
            drawWindow(in: &context, rect: frame, color: .blue, opacity: 1 - e * 0.85)
            if demo.place == .dockIcon {
                fingerAnchor = iconCenter
            }

        case .close:
            drawWindow(in: &context, rect: start.insetBy(dx: start.width * 0.06 * e, dy: start.height * 0.06 * e), color: .blue, opacity: 1 - e)

        case .quit:
            if demo.place == .dockIcon {
                fingerAnchor = layout.targetIcon.center
            }
            let sibling = start.offsetBy(dx: -start.width * 0.22, dy: -start.height * 0.12)
            drawWindow(in: &context, rect: sibling.insetBy(dx: sibling.width * 0.06 * e, dy: sibling.height * 0.06 * e), color: .blue, opacity: 1 - e)
            drawWindow(in: &context, rect: start.insetBy(dx: start.width * 0.06 * e, dy: start.height * 0.06 * e), color: .blue, opacity: 1 - e)
            drawRunningDot(in: &context, layout: layout, opacity: 1 - e)

        case .fullScreen:
            let full = CGRect(origin: .zero, size: size)
            drawWindow(in: &context, rect: lerp(start, full, e), color: .blue, cornerRadius: 4 * (1 - e))

        case .closeTab:
            drawTabbedWindow(in: &context, rect: start, e: e)
            fingerAnchor = tabRect(in: start, index: 1).center

        case .restore:
            fingerAnchor = layout.targetIcon.center
            if e > 0 {
                drawWindow(in: &context, rect: scaled(start, toward: layout.targetIcon.center, by: 1 - e), color: .blue, opacity: 0.2 + 0.8 * e)
            }

        case .switchApp:
            fingerAnchor = CGPoint(x: size.width * 0.62, y: layout.menuHeight / 2)
            let a = start.offsetBy(dx: -start.width * 0.15, dy: -start.height * 0.06)
            let b = start.offsetBy(dx: start.width * 0.12, dy: start.height * 0.08)
            if e < 0.5 {
                drawWindow(in: &context, rect: b, color: .purple)
                drawWindow(in: &context, rect: a, color: .blue)
            } else {
                drawWindow(in: &context, rect: a, color: .blue)
                drawWindow(in: &context, rect: b, color: .purple)
            }
            drawMenuBarAppName(in: &context, layout: layout, highlighted: e >= 0.5)

        case .minimizeAll, .restoreAll:
            fingerAnchor = CGPoint(x: size.width * 0.62, y: layout.menuHeight / 2)
            let restoring = if case .restoreAll = demo.outcome { true } else { false }
            let amount = restoring ? 1 - e : e
            let left = layout.frame(for: .leftHalf).insetBy(dx: 4, dy: 6)
            let right = layout.frame(for: .rightHalf).insetBy(dx: 4, dy: 6)
            drawWindow(in: &context, rect: scaled(left, toward: layout.icons[1].center, by: amount), color: .purple, opacity: 1 - amount * 0.85)
            drawWindow(in: &context, rect: scaled(right, toward: layout.icons[3].center, by: amount), color: .blue, opacity: 1 - amount * 0.85)
        }

        if demo.place == .menuBar {
            fingerAnchor = CGPoint(x: size.width * 0.62, y: layout.menuHeight / 2)
        }
        drawFingers(in: &context, at: fingerAnchor, size: size)
    }

    // MARK: - Pieces

    private func startFrame(_ layout: Layout) -> CGRect {
        if case .center = demo.outcome {
            return layout.frame(for: .leftHalf)
        }
        return layout.floating
    }

    private func titleBarHeight(for rect: CGRect) -> CGFloat {
        min(max(rect.height * 0.16, 6), 14)
    }

    private func drawWallpaper(in context: inout GraphicsContext, rect: CGRect) {
        let path = Path(roundedRect: rect, cornerRadius: min(rect.width, rect.height) * 0.05, style: .continuous)
        context.fill(path, with: .linearGradient(
            Gradient(colors: [
                Color(hue: 0.6, saturation: 0.45, brightness: 0.85),
                Color(hue: 0.72, saturation: 0.5, brightness: 0.6),
            ]),
            startPoint: CGPoint(x: rect.minX, y: rect.minY),
            endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
        ))
    }

    private func drawMenuBar(in context: inout GraphicsContext, layout: Layout, opacity: CGFloat) {
        guard opacity > 0 else { return }
        var bar = context
        bar.opacity *= opacity
        bar.fill(Path(CGRect(x: 0, y: 0, width: layout.size.width, height: layout.menuHeight)), with: .color(.white.opacity(0.45)))
        let dot = layout.menuHeight * 0.5
        bar.fill(Path(ellipseIn: CGRect(x: layout.size.width * 0.03, y: (layout.menuHeight - dot) / 2, width: dot, height: dot)), with: .color(.black.opacity(0.55)))
        for index in 0 ..< 3 {
            let width = layout.size.width * 0.05
            bar.fill(
                Path(roundedRect: CGRect(x: layout.size.width * 0.08 + CGFloat(index) * width * 1.3, y: layout.menuHeight * 0.32, width: width, height: layout.menuHeight * 0.36), cornerRadius: 1),
                with: .color(.black.opacity(0.3))
            )
        }
    }

    private func drawMenuBarAppName(in context: inout GraphicsContext, layout: Layout, highlighted: Bool) {
        let rect = CGRect(x: layout.size.width * 0.08, y: layout.menuHeight * 0.22, width: layout.size.width * 0.08, height: layout.menuHeight * 0.56)
        context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(highlighted ? .purple : .blue))
    }

    private func drawDock(in context: inout GraphicsContext, layout: Layout, opacity: CGFloat) {
        guard opacity > 0, layout.dock.height > 0 else { return }
        var dock = context
        dock.opacity *= opacity
        dock.fill(Path(roundedRect: layout.dock, cornerRadius: layout.dock.height * 0.3, style: .continuous), with: .color(.white.opacity(0.35)))
        let colors: [Color] = [.orange, .green, .blue, .pink, .gray]
        for (index, icon) in layout.icons.enumerated() {
            dock.fill(Path(roundedRect: icon, cornerRadius: icon.width * 0.25, style: .continuous), with: .color(colors[index]))
            if index != 4, !(index == 2 && isQuit) {
                let dot = max(icon.width * 0.12, 1.5)
                dock.fill(Path(ellipseIn: CGRect(x: icon.midX - dot / 2, y: layout.dock.maxY - dot * 1.6, width: dot, height: dot)), with: .color(.black.opacity(0.5)))
            }
        }
        if demo.place == .dockIcon {
            let ring = layout.targetIcon.insetBy(dx: -2, dy: -2)
            dock.stroke(Path(roundedRect: ring, cornerRadius: ring.width * 0.28, style: .continuous), with: .color(.white.opacity(0.9)), lineWidth: 1.2)
        }
    }

    private var isQuit: Bool {
        if case .quit = demo.outcome { return true }
        return false
    }

    private func drawRunningDot(in context: inout GraphicsContext, layout: Layout, opacity: CGFloat) {
        let icon = layout.targetIcon
        let dot = max(icon.width * 0.12, 1.5)
        context.fill(Path(ellipseIn: CGRect(x: icon.midX - dot / 2, y: layout.dock.maxY - dot * 1.6, width: dot, height: dot)), with: .color(.black.opacity(0.5 * opacity)))
    }

    private func drawWindow(in context: inout GraphicsContext, rect: CGRect, color: Color, opacity: CGFloat = 1, cornerRadius: CGFloat = 4) {
        guard opacity > 0.01, rect.width > 2, rect.height > 2 else { return }
        var window = context
        window.opacity *= opacity
        let path = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        var shadowed = window
        shadowed.addFilter(.shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1))
        shadowed.fill(path, with: .color(Color(nsColor: .windowBackgroundColor)))

        let titleHeight = titleBarHeight(for: rect)
        let title = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: titleHeight)
        var clipped = window
        clipped.clip(to: path)
        clipped.fill(Path(title), with: .color(color.opacity(0.28)))

        let light = min(titleHeight * 0.42, 5)
        let lights: [Color] = [.red, .yellow, .green]
        for (index, lightColor) in lights.enumerated() {
            let x = rect.minX + light * 0.9 + CGFloat(index) * light * 1.45
            window.fill(Path(ellipseIn: CGRect(x: x, y: title.midY - light / 2, width: light, height: light)), with: .color(lightColor.opacity(0.85)))
        }

        let lineHeight = max(min(rect.height * 0.05, 3), 1)
        for index in 0 ..< 3 {
            let width = rect.width * [0.7, 0.55, 0.62][index]
            let y = title.maxY + rect.height * 0.12 + CGFloat(index) * lineHeight * 2.4
            guard y + lineHeight < rect.maxY - 2 else { break }
            window.fill(Path(roundedRect: CGRect(x: rect.minX + rect.width * 0.08, y: y, width: width, height: lineHeight), cornerRadius: lineHeight / 2), with: .color(.secondary.opacity(0.35)))
        }
        window.stroke(path, with: .color(.black.opacity(0.12)), lineWidth: 0.5)
    }

    private func drawGhost(in context: inout GraphicsContext, rect: CGRect, opacity: CGFloat) {
        let path = Path(roundedRect: rect, cornerRadius: 5, style: .continuous)
        context.fill(path, with: .color(.white.opacity(0.22 * opacity)))
        context.stroke(path, with: .color(.white.opacity(0.9 * opacity)), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
    }

    private func tabRect(in window: CGRect, index: Int) -> CGRect {
        let titleHeight = titleBarHeight(for: window)
        let barTop = window.minY + titleHeight
        let width = window.width / 3
        return CGRect(x: window.minX + CGFloat(index) * width, y: barTop, width: width, height: titleHeight * 0.9)
    }

    private func drawTabbedWindow(in context: inout GraphicsContext, rect: CGRect, e: CGFloat) {
        drawWindow(in: &context, rect: rect, color: .blue)
        for index in 0 ..< 3 {
            var tab = tabRect(in: rect, index: index)
            var opacity: CGFloat = 1
            if index == 1 {
                tab.size.width *= 1 - e
                opacity = 1 - e
            } else if index == 2 {
                tab.origin.x -= tabRect(in: rect, index: 1).width * e
            }
            var tabContext = context
            tabContext.opacity *= opacity
            tabContext.fill(Path(roundedRect: tab.insetBy(dx: 1, dy: 1), cornerRadius: 2), with: .color(index == 1 ? Color.accentColor.opacity(0.45) : .secondary.opacity(0.25)))
        }
    }

    private func drawFingers(in context: inout GraphicsContext, at anchor: CGPoint, size: CGSize) {
        let opacity = fingerOpacity
        guard opacity > 0 else { return }
        let radius = max(min(size.width, size.height) * 0.052, 3.5)
        let distance = min(size.width, size.height) * 0.17
        let m = progress(Phase.motion)

        var offset = CGVector.zero
        var spread: CGFloat = 1
        var scale: CGFloat = 1
        var trail: CGVector?

        switch demo.motion {
        case let .swipe(directions):
            offset = swipeOffset(directions, progress: m, distance: distance)
            trail = offset
        case let .pinch(inward):
            spread = pinchSpread(inward: inward, progress: m)
        case .doubleTap:
            let pulse = max(bump(m, center: 0.25), bump(m, center: 0.6))
            scale = 1 - 0.25 * pulse
        }

        var fingers = context
        fingers.opacity *= opacity
        let center = CGPoint(x: anchor.x + offset.dx, y: anchor.y + offset.dy)

        if let trail, abs(trail.dx) + abs(trail.dy) > 1 {
            var path = Path()
            path.move(to: anchor)
            path.addLine(to: center)
            fingers.stroke(path, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: radius * 0.6, lineCap: .round, dash: [radius * 0.2, radius * 0.7]))
            if case let .swipe(directions) = demo.motion, let last = directions.last {
                drawArrowhead(in: &fingers, at: center, direction: last, size: radius * 1.6)
            }
        }

        for side in [-1.0, 1.0] {
            let point = CGPoint(x: center.x + CGFloat(side) * radius * 1.4 * spread, y: center.y)
            let r = radius * scale
            var finger = fingers
            finger.addFilter(.shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1))
            finger.fill(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.92)))
            fingers.stroke(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2)), with: .color(Color.accentColor.opacity(0.8)), lineWidth: 1)
        }

        if case .doubleTap = demo.motion {
            let ripple = max(bump(m, center: 0.25, width: 0.3), bump(m, center: 0.6, width: 0.3))
            if ripple > 0 {
                let r = radius * (2 + 2 * (1 - ripple))
                fingers.stroke(Path(ellipseIn: CGRect(x: center.x - r * 1.6, y: center.y - r, width: r * 3.2, height: r * 2)), with: .color(.white.opacity(Double(ripple))), lineWidth: 1)
            }
        }
    }

    private func drawArrowhead(in context: inout GraphicsContext, at point: CGPoint, direction: GestureDirection, size: CGFloat) {
        let unit = switch direction {
        case .left: CGVector(dx: -1, dy: 0)
        case .right: CGVector(dx: 1, dy: 0)
        case .up: CGVector(dx: 0, dy: -1)
        case .down: CGVector(dx: 0, dy: 1)
        }
        let tip = CGPoint(x: point.x + unit.dx * size * 2.2, y: point.y + unit.dy * size * 2.2)
        let base = CGPoint(x: tip.x - unit.dx * size, y: tip.y - unit.dy * size)
        let normal = CGVector(dx: -unit.dy, dy: unit.dx)
        var path = Path()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: base.x + normal.dx * size * 0.6, y: base.y + normal.dy * size * 0.6))
        path.addLine(to: CGPoint(x: base.x - normal.dx * size * 0.6, y: base.y - normal.dy * size * 0.6))
        path.closeSubpath()
        context.fill(path, with: .color(Color.accentColor))
        context.stroke(path, with: .color(.white.opacity(0.9)), lineWidth: 1)
    }

    // MARK: - Math

    private func swipeOffset(_ directions: [GestureDirection], progress: CGFloat, distance: CGFloat) -> CGVector {
        guard !directions.isEmpty else { return .zero }
        let segment = 1 / CGFloat(directions.count)
        var offset = CGVector.zero
        for (index, direction) in directions.enumerated() {
            let start = CGFloat(index) * segment
            var local = min(max((progress - start) / segment, 0), 1)
            if index > 0, directions[index - 1] == direction {
                local = max((local - 0.35) / 0.65, 0)
            }
            let eased = local < 0.5 ? 2 * local * local : 1 - pow(-2 * local + 2, 2) / 2
            let unit = switch direction {
            case .left: CGVector(dx: -1, dy: 0)
            case .right: CGVector(dx: 1, dy: 0)
            case .up: CGVector(dx: 0, dy: -1)
            case .down: CGVector(dx: 0, dy: 1)
            }
            let length = distance / CGFloat(directions.count > 1 ? 1.4 : 1)
            offset.dx += unit.dx * length * eased
            offset.dy += unit.dy * length * eased
        }
        return offset
    }

    private func pinchSpread(inward: Bool, progress: CGFloat) -> CGFloat {
        let squeeze = min(progress / 0.7, 1)
        return inward ? 2.2 - 1.6 * squeeze : 0.7 + 1.6 * squeeze
    }

    private func bump(_ value: CGFloat, center: CGFloat, width: CGFloat = 0.15) -> CGFloat {
        let distance = abs(value - center)
        return distance >= width ? 0 : 1 - distance / width
    }

    private func lerp(_ from: CGRect, _ to: CGRect, _ amount: CGFloat) -> CGRect {
        CGRect(
            x: from.minX + (to.minX - from.minX) * amount,
            y: from.minY + (to.minY - from.minY) * amount,
            width: from.width + (to.width - from.width) * amount,
            height: from.height + (to.height - from.height) * amount
        )
    }

    private func scaled(_ rect: CGRect, toward point: CGPoint, by amount: CGFloat) -> CGRect {
        let factor = 1 - 0.92 * amount
        let center = CGPoint(x: rect.midX + (point.x - rect.midX) * amount, y: rect.midY + (point.y - rect.midY) * amount)
        return CGRect(x: center.x - rect.width * factor / 2, y: center.y - rect.height * factor / 2, width: rect.width * factor, height: rect.height * factor)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
